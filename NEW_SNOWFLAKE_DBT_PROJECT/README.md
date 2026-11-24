# Enterprise Snowflake dbt + DCM Project: RAW_COMPUTE_DB + BUSINESS_DB

This is the same enterprise setup as [`NEW_SNOWFLAKE_DCM_PROJECT`](../NEW_SNOWFLAKE_DCM_PROJECT/README.md),
with the **transformation logic written in dbt**. dbt runs natively inside
Snowflake as a *dbt project object*, with no dbt server and no extra tools.
Everything else is the same: two databases, separate security, developer
isolation (schema and database level), cloning kept separate, DEV → QA → PROD,
and Git with pull requests.

Everything was **executed for real** in account `PYPSAGL-HO49439` on 2026-11-24
(see [Execution record](#8-execution-record)).

---

## 1. Who does what

```
                 Git (GitHub)  ── one commit ──┬──────────────────────────────┐
                                               ▼                              ▼
             DCM  (dcm_project/)                          dbt  (dbt_project/)
             "the building"                               "what happens inside"
   ┌───────────────────────────────────────┐   ┌────────────────────────────────────────┐
   │ databases, schemas                    │   │ COMPUTE.V_CUSTOMER_CLEANSED   (view)   │
   │ RAW.CUSTOMER_SRC, RAW.V_..._LATEST    │──►│ COMPUTE.CUSTOMER  (incremental MERGE   │
   │ COMPUTE.CUSTOMER  (structure + masking)│   │                    into the DCM table) │
   │ database roles, hierarchy, grants     │   │ BUSINESS_READY.CUSTOMER_PROFILE (view) │
   │ masking + row access POLICIES         │   │ data tests (not_null, unique, values)  │
   └───────────────────────────────────────┘   │ post-hooks ATTACH the DCM policies     │
            1st: DCM PLAN / DEPLOY             └────────────────────────────────────────┘
                                                        2nd: dbt build
```

| Concern | DCM-only project | **dbt + DCM project** |
|---|---|---|
| Databases, schemas, RAW layer | DCM | DCM |
| Roles, hierarchy, grants, policies | DCM | DCM |
| COMPUTE cleansing view | DCM `DEFINE VIEW` | **dbt model** |
| Load COMPUTE.CUSTOMER | stored procedure `SP_LOAD_CUSTOMER` | **dbt incremental model** (procedure no longer needed) |
| BUSINESS_READY view | DCM `DEFINE VIEW` | **dbt model** |
| Data tests | – | **dbt tests** (12) |
| Order of deployment | DCM | **DCM first, then dbt** |

Why not dbt only: dbt cannot create databases, database roles or policies in a
versioned, plan-before-apply way. DCM can. Why not DCM only: dbt adds
`ref()`-based dependencies, tests and incremental loads. Each tool does what it
is good at.

---

## 2. Folder structure

`[DCM]` deployed by DCM · `[dbt]` deployed and run by dbt · `[RUN]` executed separately

```
NEW_SNOWFLAKE_DBT_PROJECT/
├── dcm_project/                                   [DCM] containers + security
│   ├── manifest.yml                                     targets DEV, QA, PROD, DEV_A, DEV_B
│   └── sources/definitions/
│       ├── databases/raw_compute/raw_compute_db.sql     database, RAW, COMPUTE (managed access), GOVERNANCE
│       ├── databases/raw_compute/raw/tables/customer_src.sql
│       ├── databases/raw_compute/raw/views/v_customer_src_latest.sql
│       ├── databases/raw_compute/compute/tables/customer.sql   PII table: structure owned by DCM
│       ├── databases/business/business_db.sql           database, BUSINESS_READY, GOVERNANCE
│       └── security/ roles/ role_hierarchy/ grants/ masking_policies/ row_access_policies/
│
├── dbt_project/                                   [dbt] transformations
│   ├── dbt_project.yml                                  env mapping (vars.environments), folder configs, post-hooks
│   ├── profiles.yml                                     targets dev, qa, prod, dev_a, dev_b (no secrets)
│   ├── macros/generate_database_name.sql                LOGICAL db (RAW_COMPUTE_DB/BUSINESS_DB) -> physical
│   ├── macros/generate_schema_name.sql                  COMPUTE + schema_suffix (e.g. COMPUTE_DEV_B)
│   ├── macros/governance/governance.sql                 attach row access policy, then grant
│   └── models/
│       ├── sources.yml                                  RAW (built by DCM)
│       ├── compute/v_customer_cleansed.sql  customer.sql  _compute.yml
│       └── business_ready/customer_profile.sql  _business_ready.yml
│
├── platform_setup/        [RUN] 01 bootstrap · 02 control plane ENT_DBT_CTRL_DB · 03 Git · 04 account roles
├── environments/          [RUN] dev|qa|prod: 01_create_projects.sql, 02_deploy.sql · load_sample_source_data.sql
├── developer_isolation/   [RUN] developer_database_setup/ · developer_schema_setup/ · developer_mapping/README.md
├── database_cloning/      [RUN] refresh_procedures/ · clone_scripts/ · selective_refresh/ · post_refresh/
└── ci_cd/github-actions-dbt-dcm-pipeline.yml     template (not activated)
```

---

## 3. Names are never hardcoded

| | DCM | dbt |
|---|---|---|
| Developer writes | `{{ raw_compute_db }}.COMPUTE{{ schema_suffix }}.CUSTOMER` | `ref('customer')`, `source('raw', …)`, `+database: BUSINESS_DB` (logical) |
| Mapping lives in | `dcm_project/manifest.yml` → `templating.configurations` | `dbt_project/dbt_project.yml` → `vars.environments` |
| Selected by | `USING CONFIGURATION DEV` / `--target DEV` | `--target dev` |

| Env | RAW_COMPUTE_DB | BUSINESS_DB | Schemas |
|---|---|---|---|
| DEV / dev | `DBT_DEV_RAW_COMPUTE_DB` | `DBT_DEV_BUSINESS_DB` | RAW, COMPUTE, … |
| QA / qa | `DBT_QA_RAW_COMPUTE_DB` | `DBT_QA_BUSINESS_DB` | RAW, COMPUTE, … |
| PROD / prod | `DBT_PROD_RAW_COMPUTE_DB` | `DBT_PROD_BUSINESS_DB` | RAW, COMPUTE, … |
| DEV_A / dev_a | `SBX_DBT_DEV_A_RAW_COMPUTE_DB` | `SBX_DBT_DEV_A_BUSINESS_DB` | RAW, COMPUTE, … |
| DEV_B / dev_b | `DBT_DEV_RAW_COMPUTE_DB` | `DBT_DEV_BUSINESS_DB` | `*_DEV_B` |

The two mapping tables must agree. That is the one extra thing to review in a
pull request that onboards an environment or a developer.

---

## 4. Security with dbt in the picture

`CREATE OR REPLACE` (how dbt builds views) **drops** policy attachments and
grants. The project solves this as follows. Each point was checked in the account.

| Object | Built by | Policy / grant handled by |
|---|---|---|
| `COMPUTE.CUSTOMER` (PII) | **DCM** structure; dbt `incremental` + `merge` + `full_refresh: false` loads it | Masking attached **by DCM**. dbt never replaces the table, so masking stays on it (verified even with `dbt build --full-refresh`) |
| `COMPUTE.V_CUSTOMER_CLEANSED` | dbt | `GRANT SELECT ON FUTURE VIEWS` in DCM. COMPUTE is a **managed access** schema, which lets the schema owner keep future grants without MANAGE GRANTS |
| `BUSINESS_READY.CUSTOMER_PROFILE` | dbt | dbt post-hooks: **1. attach** the DCM-defined `CUSTOMER_COUNTRY_RAP`, **2. then grant** SELECT to `BUSINESS_READER`. The view is never readable without its policy |
| Policies, database roles, hierarchy, database/schema grants | DCM | DCM (unchanged from the DCM-only project) |
| Account roles | security team | `platform_setup/04_account_roles.sql` |

Result as a normal user (masked, US only):

```
CUSTOMER_ID | CUSTOMER_NAME | EMAIL             | COUNTRY | CUSTOMER_SEGMENT
1           | John Smith    | *****@example.com | US      | LOYAL
2           | Maria Garcia  | *****@example.com | US      | ESTABLISHED
5           | David Brown   | *****@example.com | US      | ESTABLISHED
```

---

## 5. Developer isolation

Details: [`developer_isolation/developer_mapping/README.md`](developer_isolation/developer_mapping/README.md).

| | Developer A: database-level | Developer B: schema-level |
|---|---|---|
| Sandbox | `SBX_DBT_DEV_A_*` (zero-copy clones of DBT_DEV) | `*_DEV_B` schemas inside `DBT_DEV_*` (RAW cloned) |
| DCM | target `DEV_A`, project `DCM_DEV_A` | target `DEV_B`, project `DCM_DEV_B` (`owns_databases: false`) |
| dbt | target `dev_a`, project `DBT_DEV_A` built **from the feature branch** | target `dev_b`, project `DBT_DEV_B` built **from the feature branch** |
| Change | `models/compute/v_customer_cleansed.sql`: ISO country codes | `models/business_ready/customer_profile.sql`: `CUSTOMER_SEGMENT` + test |
| Verified | sandbox `US,US,GB,DE,US,GB`; shared DEV still `US,USA,UK,DE,UNITED STATES,GB`; sandbox view reads `SBX_DBT_DEV_A_…` | sandbox has `CUSTOMER_SEGMENT`; shared view unchanged |

What a developer does:

```
git checkout -b feature/dbt-dev-a-country-codes
# edit dbt_project/models/compute/v_customer_cleansed.sql
git commit -am "..." && git push -u origin feature/dbt-dev-a-country-codes
# Snowsight worksheet:
developer_isolation/developer_database_setup/02_deploy_feature_branch.sql
#   = DCM deploy (DEV_A) + CREATE DBT PROJECT from the branch + dbt build --target dev_a
# then open a pull request with the sandbox evidence
```

---

## 6. Promotion: DEV → QA → PROD

| Env | DCM reads | dbt reads |
|---|---|---|
| DEV | `branches/main` | `branches/main` (`ALTER DBT PROJECT … ADD VERSION` after each merge) |
| QA | `commits/1630b73…` (release commit) | `branches/main`, taken while main = the release commit. A dbt project version is an immutable snapshot |
| PROD | same commit | **a copy of QA's dbt version** (`FROM 'snow://dbt/…DBT_QA/versions/live/'`), so PROD runs exactly what QA tested |

Found while running it: dbt project objects accept **branch** paths only
(`commits/<sha>` → *"Invalid git branch path"*). In your organisation, cut a
protected release branch (`release/dbt-dcm-1.0.0`) and point QA at it. I could
not create one from this environment (see section 8).

---

## 7. Cloning and refresh (separate from deployments)

`ENT_DBT_CTRL_DB.OPS.SP_REFRESH_DATABASE(source_env, target_env, scope, take_backup)`.
Same rules as the DCM project: it refuses any PROD target, supports
`ALL | RAW_COMPUTE_DB | BUSINESS_DB`, takes an optional zero-copy backup, and
deploys no code.

After every refresh run `database_cloning/post_refresh/after_refresh.sql`:
**DCM DEPLOY** (containers, security) **then dbt build** (views re-pointed,
policies re-attached).

Observed (PROD → QA):
1. BUSINESS_DB-only refresh: QA's view read `DBT_PROD_RAW_COMPUTE_DB.COMPUTE.customer`,
   so **QA showed PROD rows (4 instead of 3)**.
2. DCM DEPLOY + dbt build → the view reads `DBT_QA_RAW_COMPUTE_DB`, 3 rows.
3. Full refresh (`ALL`) → DCM PLAN 19 ALTERs → DEPLOY → dbt build PASS=12.
   QA now has PROD's data (8 RAW rows, Olivia Jones visible), with masking and
   row access re-attached.

Teardown order matters with dbt: **drop the dbt views first, then purge DCM**.
DCM cannot drop `CUSTOMER_COUNTRY_RAP` while a dbt view still uses it (observed).
The `99_drop_*` scripts follow this order.

---

## 8. Execution record

**Pull requests** (`MonicaSivasamy/snowflake-dcm-devops-demo`):

| PR | What |
|---|---|
| [#9](https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo/pull/9) | onboard the dbt + DCM project (scratch test before merge: PASS=11) |
| [#10](https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo/pull/10) | create dbt project objects only after the first DCM deploy |
| [#11](https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo/pull/11) | Developer A, ISO country codes (dbt model) |
| [#12](https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo/pull/12) | Developer B, `CUSTOMER_SEGMENT` + `accepted_values` test |
| this PR | README, QA/PROD promotion scripts, sandbox alias fix |

**Snowflake** (`ENT_DBT_CTRL_DB.PROJECTS`): `DCM_DEV`, `DCM_QA`, `DCM_PROD`,
`DCM_DEV_A`, `DCM_DEV_B` and `DBT_DEV`, `DBT_QA`, `DBT_PROD`, `DBT_DEV_A`, `DBT_DEV_B`.
Every `dbt build` in DEV, QA and PROD passed (PASS=12).

Issues found and fixed on the way:
* `var()` cannot be used inside `dbt_project.yml` configs, so the logical→physical mapping moved into `generate_database_name`.
* `CREATE DBT PROJECT` compiles immediately and fails until the databases exist ([#10](https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo/pull/10)).
* dbt 1.10 here rejects the `arguments:` test syntax (Developer B fixed it on the branch).
* DCM aliases are unique, so re-running a sandbox script failed. Sandbox scripts now deploy without an alias.
* While checking the refresh, I re-ran a script that still contained the refresh call, so QA's BUSINESS_DB was cloned from PROD a second time. QA was repaired with DCM DEPLOY + dbt build, and the extra backups were dropped.

**Not done:**
* `platform_setup/01` and `04` need ACCOUNTADMIN / SECURITYADMIN (written, not executed).
* Creating a release branch was refused by this environment's permission
  policy, so QA's dbt version was taken from `main` at the release commit.
* The CI template is not activated, and its `snow dbt execute` steps were not run from CI.
