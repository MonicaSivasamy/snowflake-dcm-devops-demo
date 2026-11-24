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

```text
NEW_SNOWFLAKE_DCM_PROJECT/dcm_project/            NEW_SNOWFLAKE_DCM_DBT_PROJECT/dcm_project/
├── manifest.yml                                  ├── manifest.yml                 (+ dbt_project, dbt_target per env)
└── sources/definitions/                          ├── sources/definitions/         ◄── DCM PLAN / DEPLOY
    ├── databases/raw_compute/                    │   ├── databases/raw_compute/
    │   ├── raw_compute_db.sql                    │   │   ├── raw_compute_db.sql
    │   ├── raw/tables/customer_src.sql           │   │   ├── raw/tables/customer_src.sql
    │   ├── raw/views/v_customer_src_latest.sql   │   │   ├── raw/views/v_customer_src_latest.sql
    │   ├── compute/tables/customer.sql           │   │   └── compute/tables/customer.sql      (structure + masking)
    │   ├── compute/views/v_customer_cleansed.sql │   ├── databases/business/business_db.sql
    │   └── compute/procedures/sp_load_customer.sql   ├── security/  (identical)
    ├── databases/business/                       │   └── orchestration/run_dbt_task.sql   ◄ NEW: task that runs dbt
    │   ├── business_db.sql                       │
    │   └── business_ready/views/customer_profile.sql
    └── security/                                 └── dbt_project/                 ◄── dbt (DCM ignores: outside sources/)
                                                      ├── dbt_project.yml, profiles.yml, macros/
                                                      └── models/
                                                          ├── raw_compute/raw/sources.yml
                                                          ├── raw_compute/compute/v_customer_cleansed.sql   ◄ replaces the DCM view
                                                          ├── raw_compute/compute/customer.sql              ◄ replaces the procedure
                                                          └── business/business_ready/customer_profile.sql  ◄ replaces the DCM view
```

The dbt `models/` folders mirror the old DCM folders (`raw_compute/compute`,
`business/business_ready`), so every replaced SQL file has an obvious new home.

| Old DCM SQL file | New dbt model |
|---|---|
| `compute/views/v_customer_cleansed.sql` | `dbt_project/models/raw_compute/compute/v_customer_cleansed.sql` |
| `compute/procedures/sp_load_customer.sql` | `dbt_project/models/raw_compute/compute/customer.sql` (incremental MERGE) |
| `business_ready/views/customer_profile.sql` | `dbt_project/models/business/business_ready/customer_profile.sql` |

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
| Databases, schemas, RAW tables, `COMPUTE.CUSTOMER` structure | **DCM PLAN** (code vs. live target) |
| Roles, grants, masking and row access policies | **DCM PLAN** |
| The dbt task: which dbt project and target it runs, warehouse, schedule | **DCM PLAN** (shown live after a refresh, see section 6) |
| dbt model logic | Git pull request diff + `dbt build` tests in the developer sandbox |
| Rows, column types of dbt models | dbt tests, `on_schema_change: fail`, `full_refresh: false` on the PII table |

Security on dbt-built objects works as in the dbt + DCM demo:
- **PII table:** DCM owns it and dbt only MERGEs into it, so masking stays.
- **COMPUTE views:** get their grants from future grants (COMPUTE is a managed access schema).
- **Business view:** a dbt post-hook attaches the row access policy *before* granting SELECT.

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
| this PR | README, release SHA in the QA/PROD scripts |

Snowflake (`ENT_DCMDBT_CTRL_DB.PROJECTS`): `DCM_DEV/QA/PROD/DEV_A/DEV_B` and
`DBT_DEV/QA/PROD/DEV_A/DEV_B`. `dbt build` passed in DEV, QA and PROD (PASS=12).

**Not done:**
* `EXECUTE TASK` and the `platform_setup/04` account roles need an administrator.
* No release branch (the environment blocked creating one), so QA's dbt version was taken from `main` at the release commit.
* The CI template is not activated.
