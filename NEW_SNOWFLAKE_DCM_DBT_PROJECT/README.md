# Enterprise DCM Project with dbt inside: RAW_COMPUTE_DB + BUSINESS_DB

This is the **same demo as [`NEW_SNOWFLAKE_DCM_PROJECT`](../NEW_SNOWFLAKE_DCM_PROJECT/README.md)**
(two databases, separate security, developer isolation, cloning, DEV → QA →
PROD, Git with pull requests), with one change:

> The transformation SQL files are **replaced by dbt models**, and the dbt
> project is **maintained inside the DCM project folder**. A DCM-defined task
> runs it.

Everything was **executed for real** in account `PYPSAGL-HO49439` on
2026-11-24 (see [Execution record](#7-execution-record)).

---

## 1. Side by side with the DCM-only project

**Rule: everything dbt can build is a dbt model. DCM keeps only what dbt cannot create.**

```text
NEW_SNOWFLAKE_DCM_PROJECT/dcm_project/            NEW_SNOWFLAKE_DCM_DBT_PROJECT/dcm_project/
├── manifest.yml                                  ├── manifest.yml               (+ dbt_project, dbt_target per env)
└── sources/definitions/                          ├── sources/definitions/       ◄── DCM PLAN / DEPLOY
    ├── databases/raw_compute/                    │   ├── databases/raw_compute/
    │   ├── raw_compute_db.sql                    │   │   ├── raw_compute_db.sql           database + schemas
    │   ├── raw/tables/customer_src.sql           │   │   └── raw/tables/customer_src.sql  RAW landing table
    │   ├── raw/views/v_customer_src_latest.sql   │   ├── databases/business/business_db.sql   database + schemas
    │   ├── compute/tables/customer.sql           │   ├── security/                roles, hierarchy, grants,
    │   ├── compute/views/v_customer_cleansed.sql │   │                            masking + row access POLICIES
    │   └── compute/procedures/sp_load_customer.sql   └── orchestration/run_dbt_task.sql   task that runs dbt
    ├── databases/business/                       │
    │   ├── business_db.sql                       └── dbt_project/               ◄── dbt (DCM ignores: outside sources/)
    │   └── business_ready/views/customer_profile.sql   ├── dbt_project.yml, profiles.yml
    └── security/  (incl. masking assignments)        ├── macros/governance/   attach DCM policies, then grant
                                                      └── models/
                                                          ├── raw_compute/raw/sources.yml          reads CUSTOMER_SRC
                                                          ├── raw_compute/raw/v_customer_src_latest.sql
                                                          ├── raw_compute/compute/v_customer_cleansed.sql
                                                          ├── raw_compute/compute/customer.sql     (table + masking)
                                                          └── business/business_ready/customer_profile.sql
```

| DCM-only project file | Now |
|---|---|
| `raw/views/v_customer_src_latest.sql` | dbt model `models/raw_compute/raw/v_customer_src_latest.sql` |
| `compute/views/v_customer_cleansed.sql` | dbt model `models/raw_compute/compute/v_customer_cleansed.sql` |
| `compute/tables/customer.sql` + `compute/procedures/sp_load_customer.sql` | **one** dbt model `models/raw_compute/compute/customer.sql` (dbt builds and loads the table) |
| `business_ready/views/customer_profile.sql` | dbt model `models/business/business_ready/customer_profile.sql` |
| `security/masking_policies/pii_masking_assignments.sql` | dbt post-hooks on `customer.sql` (the policy **definitions** stay in DCM) |

What stays in DCM, and why dbt can't take it over:

| DCM file | Why not dbt |
|---|---|
| `raw_compute_db.sql`, `business_db.sql` | dbt models create tables and views only, not databases or schemas (managed access, retention) |
| `raw/tables/customer_src.sql` | the landing table must exist **before** ingestion loads data; dbt only reads sources |
| `security/*` | roles, grants and policy definitions are not dbt models; DCM PLAN shows every change to them |
| `orchestration/run_dbt_task.sql` | a task is a Snowflake object; DCM PLAN catches a task pointing at the wrong environment |

The other folders (`platform_setup/`, `environments/`, `developer_isolation/`,
`database_cloning/`, `ci_cd/`) have the same roles as in the DCM-only project.

---

## 2. Why this layout is supported (official Snowflake docs)

* DCM deploys only `manifest.yml` and the definition files under `sources/definitions/`.
  Other files belong *"in a folder outside of the `sources` folder"*, and the
  CLI *"uploads `manifest.yml` and the files under `sources`"*.
  See [DCM Projects files and templates](https://docs.snowflake.com/en/user-guide/dcm-projects/dcm-projects-files).
  So `dcm_project/dbt_project/` is stored in the DCM project but never deployed as DCM definitions.
* Definition files may contain only `DEFINE`, `GRANT` and `ATTACH`, so dbt models
  (`SELECT` + `ref()`) cannot be DCM definitions. *DBT PROJECT* is not a
  [supported DCM entity](https://docs.snowflake.com/en/user-guide/dcm-projects/dcm-projects-supported-entities),
  but **Task** is.
* A DCM project can combine *"the tasks that orchestrate procedures, Code
  Bundles, and dbt projects"*. See the [DCM Projects overview](https://docs.snowflake.com/en/user-guide/dcm-projects/dcm-projects-overview).
  This is the DCM-managed task `RUN_DBT_BUILD`.
* The dbt project object: [dbt Projects on Snowflake](https://docs.snowflake.com/en/user-guide/data-engineering/dbt-projects-on-snowflake),
  [CREATE DBT PROJECT](https://docs.snowflake.com/en/sql-reference/sql/create-dbt-project).

---

## 3. What DCM tracks vs. what dbt tracks

| Change | Tracked by |
|---|---|
| Databases, schemas, RAW landing table | **DCM PLAN** (code vs. live target) |
| Roles, grants, masking and row access policy **definitions** | **DCM PLAN** |
| The dbt task: which dbt project and target it runs | **DCM PLAN** (shown live after a refresh, see section 6) |
| Every view and table built by dbt, and its policy attachments | Git pull request diff + `dbt build` (models + 14 tests) in the developer sandbox |

**Security on dbt-built objects.** Every build re-creates the object without
policies or grants, so dbt post-hooks re-apply them in a fixed order:
**policies first, SELECT grant last**.

| dbt object | Post-hooks |
|---|---|
| `COMPUTE.CUSTOMER` (PII table) | `MASK_EMAIL` on EMAIL, `MASK_PHONE` on PHONE, then SELECT to `COMPUTE_READER` |
| `BUSINESS_READY.CUSTOMER_PROFILE` | `CUSTOMER_COUNTRY_RAP` on COUNTRY, then SELECT to `BUSINESS_READER` |
| `RAW.V_CUSTOMER_SRC_LATEST` | SELECT to `RAW_READER` |
| `COMPUTE.V_CUSTOMER_CLEANSED` | DCM future grant on views (COMPUTE is a managed access schema) |

Checked: after two consecutive builds, both masking policies are attached to
the rebuilt table, readers see `*****@example.com`, and DCM PLAN reports no
drift. The policies cannot be dropped while dbt objects use them, so teardown
removes the dbt objects first (`99_drop_*` scripts).

---

## 4. Deploy sequence (every environment)

```text
1. DCM PLAN + DEPLOY  dcm_project/              databases, schemas, RAW, security, task RUN_DBT_BUILD
2. CREATE DBT PROJECT / ADD VERSION             from dcm_project/dbt_project (Git)
3. run dbt                                       EXECUTE DBT PROJECT … build   (= what the task runs)
                                                 or EXECUTE TASK <db>.COMPUTE.RUN_DBT_BUILD
```

Scripts: `environments/<env>/01_create_projects.sql`, `02_deploy.sql`.

| Env | DCM reads | dbt project object |
|---|---|---|
| DEV  | `branches/main` | `DBT_DEV` from `branches/main` (new version after each merge) |
| QA   | `commits/6ae5037…` (release) | `DBT_QA` from `branches/main` while main = release. dbt objects accept branch paths only |
| PROD | same commit | `DBT_PROD` = **copy of QA's dbt version** (`snow://dbt/…DBT_QA/versions/live/`) |

**One admin grant is still needed.** Running the task needs
`GRANT EXECUTE TASK ON ACCOUNT TO ROLE DCM_DEMO_ADMIN` (ACCOUNTADMIN, in
`platform_setup/01`). Until then, `EXECUTE TASK` fails with *"EXECUTE TASK
privilege must be granted to owner role"* (observed), so the scripts run the
identical `EXECUTE DBT PROJECT` command directly. DCM deploys and tracks the
task either way.

---

## 5. Developer isolation

| | Developer A: database-level | Developer B: schema-level |
|---|---|---|
| Sandbox | `SBX_DCMDBT_DEV_A_*` (clones of DCMDBT_DEV) | `*_DEV_B` schemas in `DCMDBT_DEV_*` |
| Projects | `DCM_DEV_A` + `DBT_DEV_A` (from the feature branch) | `DCM_DEV_B` + `DBT_DEV_B` (from the feature branch) |
| Change | ISO country codes ([#16](https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo/pull/16)) | `CUSTOMER_SEGMENT` + test ([#17](https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo/pull/17)) |
| Result | sandbox `US,US,GB,DE,US,GB`; shared DEV `US,USA,UK,DE,UNITED STATES,GB` | sandbox has the new column; shared view unchanged |

Details: [`developer_isolation/developer_mapping/README.md`](developer_isolation/developer_mapping/README.md).

---

## 6. Refresh: why the DCM-managed task matters

Refresh PROD → QA (`SP_REFRESH_DATABASE('DCMDBT_PROD','DCMDBT_QA','ALL',true)`):

| After the clone | After DCM DEPLOY + dbt build (`post_refresh/after_refresh.sql`) |
|---|---|
| QA view reads `DCMDBT_PROD_RAW_COMPUTE_DB.COMPUTE.customer` | reads `DCMDBT_QA_RAW_COMPUTE_DB.COMPUTE.customer` |
| QA task runs `DBT_PROD … --target prod`, which would rebuild **PROD** from QA (cloned tasks start suspended, so nothing ran) | runs `DBT_QA … --target qa` |
| | DCM PLAN listed it: `ALTER TASK DCMDBT_QA_RAW_COMPUTE_DB.COMPUTE.RUN_DBT_BUILD` (20 ALTERs in total) |

Because the task is a DCM object, DCM PLAN detects and fixes this. With an
unmanaged task, nothing would have flagged it.

Teardown order: dbt views first, then DCM purge. DCM cannot drop the row access
policy while a dbt view still uses it. The `99_drop_*` scripts follow this order.

---

## 7. Execution record

| PR | What |
|---|---|
| [#15](https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo/pull/15) | onboard the project (DCM PLAN checked, including the task) |
| [#16](https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo/pull/16) | Developer A, country codes |
| [#17](https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo/pull/17) | Developer B, customer segment |
| [#18](https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo/pull/18) | README, release SHA in the QA/PROD scripts |
| this PR | move every transformable object to dbt (RAW view, CUSTOMER table + masking) |

Snowflake (`ENT_DCMDBT_CTRL_DB.PROJECTS`): `DCM_DEV/QA/PROD/DEV_A/DEV_B` and
`DBT_DEV/QA/PROD/DEV_A/DEV_B`. `dbt build` passes in DEV, QA and PROD.

**Not done:**
* `EXECUTE TASK` and the `platform_setup/04` account roles need an administrator.
* No release branch (the environment blocked creating one), so QA's dbt version was taken from `main` at the release commit.
* The CI template is not activated.
