# Enterprise Snowflake DCM Project: RAW_COMPUTE_DB + BUSINESS_DB

This project shows how a team moves from **SQL scripts kept in shared Snowflake
worksheets** to a **Git-versioned Snowflake DCM project** that is reviewed in
pull requests and deployed safely to DEV, QA and PROD.

It is a new, self-contained project. It shares nothing with the older demo in
this repository (`dcm/`, `streamlit/`, …) except the account's automation role
`DCM_DEMO_ADMIN` and warehouse `DCM_DEMO_WH`.

Everything below was **executed for real** in Snowflake account
`PYPSAGL-HO49439` on 2026-11-24 (see [Execution record](#9-execution-record)).

---

## 1. The idea in one picture

```
           worksheets (before)                          DCM + Git (after)
  ┌──────────────────────────────────┐     ┌───────────────────────────────────────────────┐
  │ CREATE VIEW PROD_..._DB.X ...    │     │ GitHub  main ──PR── feature/dev-a-...          │
  │ copied & edited per environment  │ ──► │           └───PR── feature/dev-b-...           │
  │ no history, no review, no plan   │     │ Snowflake  GIT REPOSITORY (read-only copy)     │
  └──────────────────────────────────┘     │            DCM PROJECT per environment          │
                                           │            PLAN  -> review the changeset        │
                                           │            DEPLOY-> create/alter/drop to match  │
                                           └───────────────────────────────────────────────┘
```

* You write **what the object should look like** (`DEFINE TABLE …`, `DEFINE VIEW …`).
  You do not write `CREATE` / `ALTER` / `DROP`.
* **PLAN** compares the files with the account and lists what would change.
* **DEPLOY** applies that change and stores a numbered deployment in the project's history.
* The **same files** are deployed to every environment. Database names come
  from `manifest.yml`.

Data flow: `Source (CRM) → RAW → COMPUTE → BUSINESS_READY`

```
RAW_COMPUTE_DB.RAW.CUSTOMER_SRC              table   customer records as delivered
RAW_COMPUTE_DB.RAW.V_CUSTOMER_SRC_LATEST     view    latest record per customer
RAW_COMPUTE_DB.COMPUTE.V_CUSTOMER_CLEANSED   view    trim / initcap / lower e-mail / country codes / dates
RAW_COMPUTE_DB.COMPUTE.SP_LOAD_CUSTOMER()    proc    rebuilds COMPUTE.CUSTOMER from the view
RAW_COMPUTE_DB.COMPUTE.CUSTOMER              table   cleansed customers  (EMAIL, PHONE masked)
BUSINESS_DB.BUSINESS_READY.CUSTOMER_PROFILE  view    business view  (row access policy on COUNTRY)
```

---

## 2. Folder structure: where each SQL file belongs

`[DCM]` = deployed by DCM PLAN/DEPLOY. `[RUN]` = executed separately (worksheet or `snow sql -f`).

```
NEW_SNOWFLAKE_DCM_PROJECT/
│
├── dcm_project/                                  [DCM] the deployment unit: ONLY this folder is deployed
│   ├── manifest.yml                                    targets (DEV, QA, PROD, DEV_A, DEV_B) + name mapping
│   └── sources/definitions/                            DCM reads .sql files only below here
│       ├── databases/
│       │   ├── raw_compute/                            logical database RAW_COMPUTE_DB
│       │   │   ├── raw_compute_db.sql                  database + schemas RAW, COMPUTE, GOVERNANCE
│       │   │   ├── raw/tables/customer_src.sql
│       │   │   ├── raw/views/v_customer_src_latest.sql
│       │   │   ├── compute/tables/customer.sql
│       │   │   ├── compute/views/v_customer_cleansed.sql
│       │   │   └── compute/procedures/sp_load_customer.sql
│       │   └── business/                               logical database BUSINESS_DB
│       │       ├── business_db.sql                     database + schemas BUSINESS_READY, GOVERNANCE
│       │       └── business_ready/views/customer_profile.sql
│       └── security/                                   database-scoped security, separate from transformations
│           ├── roles/database_roles.sql
│           ├── role_hierarchy/database_role_hierarchy.sql
│           ├── grants/database_schema_grants.sql
│           ├── grants/object_grants.sql                table / view / procedure permissions
│           ├── masking_policies/pii_masking_policies.sql       definitions
│           ├── masking_policies/pii_masking_assignments.sql    ATTACH … TO TABLE … COLUMN …
│           ├── row_access_policies/customer_country_policy.sql
│           └── row_access_policies/customer_country_assignment.sql
│
├── platform_setup/                               [RUN] once, by platform / security admins
│   ├── 01_platform_bootstrap.sql                       ACCOUNTADMIN: deploy role, warehouse, privileges
│   ├── 02_control_plane.sql                            ENT_DCM_CTRL_DB (the project's Snowflake "folder")
│   ├── 03_git_integration.sql                          API integration + GIT REPOSITORY + FETCH
│   └── 04_account_roles.sql                            SECURITYADMIN: account roles, hierarchy, links
│
├── environments/                                 [RUN] per environment
│   ├── dev/  01_create_dcm_project.sql  02_plan_and_deploy.sql     (deploys branch main)
│   ├── qa/   01_create_dcm_project.sql  02_plan_and_deploy.sql     (deploys a release commit/tag)
│   ├── prod/ 01_create_dcm_project.sql  02_plan_and_deploy.sql     (deploys the same release)
│   └── load_sample_source_data.sql                     simulates CRM ingestion + runs the COMPUTE load
│
├── developer_isolation/                          [RUN]
│   ├── developer_database_setup/                       Developer A: own cloned databases
│   ├── developer_schema_setup/                         Developer B: own schemas in shared DEV
│   └── developer_mapping/README.md                     who deploys where, and how to add developer C
│
├── database_cloning/                             [RUN] never part of a deployment
│   ├── refresh_procedures/sp_refresh_database.sql      installs ENT_DCM_CTRL_DB.OPS.SP_REFRESH_DATABASE
│   ├── clone_scripts/clone_prod_to_qa.sql | clone_prod_to_dev.sql
│   ├── selective_refresh/refresh_single_database.sql   only RAW_COMPUTE_DB or only BUSINESS_DB
│   └── post_refresh/after_refresh.sql                  PLAN + DEPLOY after every refresh
│
└── ci_cd/github-actions-dcm-pipeline.yml         template: PR → plan, merge → DEV, tag → QA → PROD
```

### What was verified about DCM's conventions (and how the proposed layout was adapted)

| Finding (tested in the account) | Consequence for the layout |
|---|---|
| DCM reads `manifest.yml` plus `.sql` files under `sources/definitions/` **only**. A probe file placed elsewhere was ignored. | The proposed `databases/` and `security/` folders sit **inside** `dcm_project/sources/definitions/`. Cloning, isolation setup and environment scripts sit **outside**, so they can never be deployed by accident. |
| Sub-folders below `sources/definitions/` are free-form. | The client's layout (`raw/tables`, `compute/procedures`, …) is kept exactly. |
| Supported and used: `DEFINE DATABASE / SCHEMA / TABLE / VIEW / PROCEDURE / DATABASE ROLE / MASKING POLICY / ROW ACCESS POLICY`, `GRANT …`, `ATTACH MASKING POLICY … TO TABLE t COLUMN c`, `ATTACH ROW ACCESS POLICY … TO VIEW v ON (col)`, Jinja `{{ var }}` and `{% if %}`. | Roles, grants and policies are DCM-managed and versioned like code. |
| `ALTER …` statements are rejected ("only DEFINE statements are allowed"). Inline `WITH MASKING POLICY` in `DEFINE TABLE` fails at deploy ("CREATE OR ALTER does not support setting policies"). | Policy assignments use `ATTACH` in their own files, separate from the table definitions. |
| `DEFINE ROLE` (account role) needs `CREATE ROLE` on the account, which the deploy role deliberately lacks. | Account roles stay with the security team: `platform_setup/04_account_roles.sql`. |

---

## 3. Two databases in one project, with no hardcoded names

Logical names (`RAW_COMPUTE_DB`, `BUSINESS_DB`) map to physical names per target in `manifest.yml`:

```yaml
templating:
  defaults:      { schema_suffix: "", owns_databases: true, data_retention_days: 1 }
  configurations:
    DEV:   { raw_compute_db: "DEV_RAW_COMPUTE_DB",       business_db: "DEV_BUSINESS_DB" }
    QA:    { raw_compute_db: "QA_RAW_COMPUTE_DB",        business_db: "QA_BUSINESS_DB" }
    PROD:  { raw_compute_db: "PROD_RAW_COMPUTE_DB",      business_db: "PROD_BUSINESS_DB", data_retention_days: 7 }
    DEV_A: { raw_compute_db: "SBX_DEV_A_RAW_COMPUTE_DB", business_db: "SBX_DEV_A_BUSINESS_DB" }
    DEV_B: { raw_compute_db: "DEV_RAW_COMPUTE_DB",       business_db: "DEV_BUSINESS_DB",
             schema_suffix: "_DEV_B", owns_databases: false }
```

Every SQL file uses the variables, including **cross-database references**:

```sql
define view {{ business_db }}.BUSINESS_READY{{ schema_suffix }}.CUSTOMER_PROFILE as
select ... from {{ raw_compute_db }}.COMPUTE{{ schema_suffix }}.CUSTOMER;
```

DEV's view therefore reads DEV and PROD's view reads PROD. Nobody edits a
database name to promote code.

Each target is backed by its **own DCM project object** in
`ENT_DCM_CTRL_DB.PROJECTS` (`ENT_DCM_DEV`, `ENT_DCM_QA`, `ENT_DCM_PROD`,
`ENT_DCM_DEV_A`, `ENT_DCM_DEV_B`). A Snowflake object can be managed by only
one DCM project, and each environment keeps its own deployment history.

> Physical names carry an environment prefix even in PROD because this demo
> shares one account with other projects (a `BUSINESS_DB` already exists). In
> an account dedicated to production you could set PROD's values to
> `RAW_COMPUTE_DB` / `BUSINESS_DB`.

---

## 4. Roles and security

| Layer | Object | Where | Managed by |
|---|---|---|---|
| Database roles | `RAW_READER`, `COMPUTE_READER`, `COMPUTE_ENGINEER`, `PII_READER` (in RAW_COMPUTE_DB); `BUSINESS_READER`, `ALL_COUNTRIES_READER` (in BUSINESS_DB) | `security/roles/` | DCM |
| Hierarchy inside a database | `COMPUTE_ENGINEER ⊃ COMPUTE_READER + RAW_READER`; `ALL_COUNTRIES_READER ⊃ BUSINESS_READER` | `security/role_hierarchy/` | DCM |
| Grants | USAGE on databases and schemas; SELECT, INSERT, … on tables and views; USAGE on the procedure | `security/grants/` | DCM (a grant removed from the file is revoked) |
| Masking | `MASK_EMAIL` → `*****@example.com`, `MASK_PHONE` → `*******1234`, attached to `COMPUTE.CUSTOMER` | `security/masking_policies/` | DCM |
| Row access | `CUSTOMER_COUNTRY_RAP`: all rows for `ALL_COUNTRIES_READER`, otherwise `COUNTRY = 'US'` | `security/row_access_policies/` | DCM |
| Account roles | `<ENV>_ENT_ANALYST`, `<ENV>_ENT_PII_ANALYST`, `<ENV>_ENT_ENGINEER`, their hierarchy to SYSADMIN, and links to the database roles | `platform_setup/04_account_roles.sql` | Security team (SECURITYADMIN) |

Why database roles: they live **inside** the database, so they are versioned,
deployed, cloned and restored together with it. Policies check them with
`is_database_role_in_session('PII_READER')`. The name is **unqualified** on
purpose, because inside a policy Snowflake resolves it in the policy's own
database. A qualified name (`'DEV_RAW_COMPUTE_DB.PII_READER'`) never matches
(this was found and fixed in [PR #2](https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo/pull/2)).
As a result, the policy bodies are identical in every environment.

Security changes follow the same path as code changes: a branch, a pull
request reviewed by the security owner, then PLAN (which shows every grant
added or revoked) and DEPLOY.

---

## 5. Developer isolation

Both developers work from the **same project and the same files**. They differ
only in Git branch and DCM target. Details: [`developer_isolation/developer_mapping/README.md`](developer_isolation/developer_mapping/README.md).

### What the developer sees

```
$ git checkout -b feature/dev-a-country-codes          # 1. own branch
$ vi NEW_SNOWFLAKE_DCM_PROJECT/dcm_project/sources/definitions/databases/raw_compute/compute/views/v_customer_cleansed.sql
$ snow dcm plan   --target DEV_A --from NEW_SNOWFLAKE_DCM_PROJECT/dcm_project   # 2. preview in MY sandbox
$ snow dcm deploy --target DEV_A --from NEW_SNOWFLAKE_DCM_PROJECT/dcm_project   # 3. deploy to MY sandbox
$ git commit -am "..." && git push -u origin feature/dev-a-country-codes        # 4. share, open a PR
```

The Snowsight worksheet equivalent (deploying the pushed branch from the Git
repository object) is in `developer_isolation/*/02_deploy_feature_branch.sql`.

### Database-level isolation (Developer A)

1. `developer_database_setup/01_create_developer_databases.sql` zero-copy
   clones `DEV_RAW_COMPUTE_DB` → `SBX_DEV_A_RAW_COMPUTE_DB` and
   `DEV_BUSINESS_DB` → `SBX_DEV_A_BUSINESS_DB`, then creates project `ENT_DCM_DEV_A`.
2. The first DEPLOY to target `DEV_A` **adopts** the cloned objects (22 ALTERs,
   0 creates, 0 drops) and re-points their code to `SBX_DEV_A_*`.

> ⚠ Never CALL a cloned procedure before that first DEPLOY. A clone's code
> still names the source database. In this demo the cloned
> `SP_LOAD_CUSTOMER` reloaded shared DEV's table before the sandbox was
> deployed. The data was identical so nothing was harmed, but it shows why
> clone → DEPLOY → run is the only safe order.

### Schema-level isolation (Developer B)

1. `developer_schema_setup/01_create_developer_schemas.sql` clones only the
   RAW schema (`RAW` → `RAW_DEV_B`, for data) and creates project `ENT_DCM_DEV_B`.
2. DEPLOY to target `DEV_B` creates `COMPUTE_DEV_B`, `GOVERNANCE_DEV_B`,
   `BUSINESS_READY_DEV_B`, … with masking and row access active.
   `owns_databases: false` skips the databases, database roles and grants, which
   stay owned by shared DEV.
3. Shared DEV's PLAN afterwards reported **no changes**. DCM only touches what
   its own project manages.

| Choose | when |
|---|---|
| **Schema-level** | many developers, SQL logic changes, minimal overhead |
| **Database-level** | changes to security, database roles or database settings; large refactors; strict separation |

### From sandbox to shared environments

```
feature branch ──PR + review──► main ──► DEV (every merge)
                                  └─ release commit / tag ──► QA ──approval──► PROD (same commit)
```

---

## 6. Cloning and refresh: separate from deployments

| Activity | Moves | Tool | When |
|---|---|---|---|
| **Database cloning / refresh** | **data** (plus a copy of the source's objects) | `ENT_DCM_CTRL_DB.OPS.SP_REFRESH_DATABASE` | on request or schedule, by operations |
| **DCM PLAN / DEPLOY** | **code**: object definitions, database roles, grants, policies | `EXECUTE DCM PROJECT` / `snow dcm` | every merge / release |
| **Git-based code restoration** | the approved version of the code | DEPLOY an earlier commit or tag | after a refresh or a bad change |
| **Security restoration** | account role → database role links | `platform_setup/04_account_roles.sql` | after a refresh |

`SP_REFRESH_DATABASE(source_env, target_env, scope, take_backup)`:
* refuses `PROD` as a target and source = target;
* `scope` = `ALL` | `RAW_COMPUTE_DB` | `BUSINESS_DB` (selective refresh);
* `take_backup` = zero-copy `<db>_BKP_<timestamp>` before replacing;
* deploys **no** code. It tells you to run PLAN + DEPLOY next.

**What happens to DCM-managed objects (observed live, PROD → QA):**

1. After refreshing only BUSINESS_DB, QA's `CUSTOMER_PROFILE` read
   `from PROD_RAW_COMPUTE_DB.COMPUTE.CUSTOMER`. **QA was showing PROD data.**
2. `PLAN` (QA, release commit) listed exactly that drift: `ALTER VIEW`, `ALTER ROW_ACCESS_POLICY`, … (7 ALTERs, no drops).
3. `DEPLOY` re-pointed the view to `QA_RAW_COMPUTE_DB`.
4. After a full refresh (`ALL`), PLAN showed 22 ALTERs (procedure, views,
   policies, …). After DEPLOY, the procedure writes `QA_RAW_COMPUTE_DB.COMPUTE.CUSTOMER`,
   masking is attached to QA's table, and the database role grants are back.
   QA kept PROD's data (8 RAW rows, including PROD's newest customer).

**Protecting developer WIP:** sandboxes are separate databases or schemas, so
a refresh of DEV or QA never touches them. A developer's sandbox is refreshed
only on request (`SP_REFRESH_DATABASE('DEV','SBX_DEV_A',…)`), with a backup,
followed by a redeploy of **their feature branch**. Work that is committed and
pushed cannot be lost. Uncommitted edits exist only on the developer's laptop
and never in Snowflake, so the rule is *push before you refresh*.

---

## 7. Environments

| Env | DCM target / project | Deploys from | Data |
|---|---|---|---|
| DEV  | `DEV` / `ENT_DCM_DEV`   | branch `main` (every merged PR) | sample data |
| QA   | `QA` / `ENT_DCM_QA`     | release commit `7c7309b` (tag `ent-dcm-v1.0.0` when created) | sample data, then refreshed from PROD |
| PROD | `PROD` / `ENT_DCM_PROD` | the **same** release commit | simulated ingestion |

Environment differences live only in `manifest.yml` (names, retention: PROD
keeps 7 days of Time Travel). The SQL files are identical everywhere.

---

## 8. End-to-end workflow (execution sequence)

| # | Step | How |
|---|---|---|
| 1 | Bootstrap the account (once) | `platform_setup/01_platform_bootstrap.sql` (ACCOUNTADMIN) |
| 2 | Create the project's Snowflake folder | `platform_setup/02_control_plane.sql` → `ENT_DCM_CTRL_DB.{PROJECTS,GIT,OPS}` |
| 3 | Connect Git | `platform_setup/03_git_integration.sql` (`CREATE GIT REPOSITORY …` + `FETCH`) |
| 4 | Create one DCM project object per environment | `environments/<env>/01_create_dcm_project.sql` |
| 5 | Merge the project to `main`, then PLAN + DEPLOY DEV | `environments/dev/02_plan_and_deploy.sql` |
| 6 | Load data and run the COMPUTE load | `environments/load_sample_source_data.sql` |
| 7 | Link account roles | `platform_setup/04_account_roles.sql` (SECURITYADMIN, per env) |
| 8 | Developer A: feature branch + database sandbox | `developer_isolation/developer_database_setup/` |
| 9 | Developer B: feature branch + schema sandbox | `developer_isolation/developer_schema_setup/` |
| 10 | Commit, push, open a pull request with sandbox evidence and DEV PLAN | GitHub |
| 11 | Review and merge | GitHub |
| 12 | PLAN DEV from `main` (review the changeset) | `environments/dev/02_plan_and_deploy.sql` |
| 13 | DEPLOY DEV | same file |
| 14 | Cut a release (tag / commit), PLAN + DEPLOY QA, approve, PLAN + DEPLOY PROD | `environments/qa/…`, `environments/prod/…` |
| 15 | Refresh QA from PROD when needed, then PLAN + DEPLOY QA | `database_cloning/…` |

CI/CD: `ci_cd/github-actions-dcm-pipeline.yml` automates steps 12–14 with the
Snowflake CLI (`snow dcm plan|deploy --target …`). Copy it to
`.github/workflows/` and add the secrets listed in its header. GitHub
environment approvals provide the QA and PROD gates. The commands are the same
in Azure DevOps.

---

## 9. Execution record

**Git** (repository `MonicaSivasamy/snowflake-dcm-devops-demo`):

| PR | Branch | What | DCM PLAN shown in the PR |
|---|---|---|---|
| [#1](https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo/pull/1) | `claude/admiring-meitner-7hywdr` | onboard the project | DEV: 24 creates |
| [#2](https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo/pull/2) | `hotfix/policy-role-resolution` | policies: unqualified database role names | DEV: 3 ALTER POLICY |
| [#3](https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo/pull/3) | `platform/sandbox-naming` | `SBX_` prefix (name collision caught by DCM) | – |
| [#4](https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo/pull/4) | `feature/dev-a-country-codes` (author *Developer A*) | ISO country codes | DEV: 1 ALTER VIEW |
| [#5](https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo/pull/5) | `feature/dev-b-customer-segment` (author *Developer B*) | `CUSTOMER_SEGMENT` column | DEV: 1 ALTER VIEW |
| [#6](https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo/pull/6) | `platform/fix-deployment-aliases` | alias rules (no `/`, unique) | – |

**Snowflake** (`ENT_DCM_CTRL_DB.PROJECTS`):

| Project | Deployments |
|---|---|
| `ENT_DCM_DEV`   | `main` → `main (policy fix)` → `main-c5611e0` (both features) |
| `ENT_DCM_DEV_A` | `dev-a-country-codes` |
| `ENT_DCM_DEV_B` | `dev-b-customer-segment` |
| `ENT_DCM_QA`    | `release-1.0.0-7c7309b` → `…-after-business-refresh` → `…-after-full-refresh` |
| `ENT_DCM_PROD`  | `release-1.0.0-7c7309b` |

Results seen as `DCM_DEMO_ADMIN`, which holds no PII or all-countries role:

```
DEV_BUSINESS_DB.BUSINESS_READY.CUSTOMER_PROFILE (after release 1.0.0)
CUSTOMER_ID | CUSTOMER_NAME | EMAIL             | COUNTRY | CUSTOMER_SEGMENT
1           | John Smith    | *****@example.com | US      | LOYAL
2           | Maria Garcia  | *****@example.com | US      | ESTABLISHED     <- was "USA", hidden by RAP
5           | David Brown   | *****@example.com | US      | ESTABLISHED     <- was "UNITED STATES"
```

With `PII_READER` and `ALL_COUNTRIES_READER` granted (test only, then revoked),
all 6 customers appear with real e-mails and phone numbers.

### Not done in this run (and why)

* `platform_setup/01` and `04` need ACCOUNTADMIN / SECURITYADMIN, which the
  automation role does not have. They were written but not executed, so the
  account roles `<ENV>_ENT_*` do not exist yet.
* The tag `ent-dcm-v1.0.0` could not be pushed from this environment (Git
  proxy refused it, HTTP 403). QA and PROD were deployed from the release's
  commit SHA instead. Create the tag in GitHub if you want tag-based promotion.
* The CI template is not activated (it needs repository secrets).

Note: `SP_LOAD_CUSTOMER` returns Snowflake's `SQLROWCOUNT` for `INSERT OVERWRITE`.
When the table already has data, this count is higher than the number of
customers (for example "12 rows" for 6 customers). It appears to count the
replaced rows as well.

### Clean up

```
developer_isolation/developer_database_setup/99_drop_developer_databases.sql
developer_isolation/developer_schema_setup/99_drop_developer_schemas.sql
EXECUTE DCM PROJECT ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_<ENV> PURGE;   -- drops only what that project manages
```
