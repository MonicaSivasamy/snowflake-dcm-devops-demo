# Snowflake DCM DevOps & Developer Isolation - live prototype

A working demonstration, running against a real Snowflake account, of how
**Git + Snowflake DCM Projects** manage database objects, why **Git branches do
not isolate Snowflake objects**, how **developer-specific targets** do, and why
**DCM PLAN/DEPLOY is not a data test**.

Everything shown in the app is executed in Snowflake: SQL, `EXECUTE DCM PROJECT`
PLAN/DEPLOY/TEST ALL, zero-copy clones, and business-rule validation. Synthetic data only.

* Presenter script: [`docs/DEMO_SCRIPT.md`](docs/DEMO_SCRIPT.md)
* Architecture diagrams: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
* Cleanup: [`cleanup/cleanup.sql`](cleanup/cleanup.sql)

## Repository layout

```
admin/00_admin_bootstrap.sql          one-time ACCOUNTADMIN setup (role, warehouse, service user, PAT)
setup/01_shared_worksheet_objects.sql the "before" state: shared worksheet SQL (idempotent)
setup/02_control_objects.sql          control DB, audit log, Git API integration + repository object
dcm/manifest.yml                      DCM manifest v2: 5 targets, Jinja configurations
dcm/sources/definitions/
  00_databases.sql                    DEFINE DATABASE / SCHEMA
  01_raw/raw_tables.sql               DEFINE TABLE (RAW_CUSTOMERS, RAW_PRODUCTS, RAW_ORDERS)
  02_compute/compute_views.sql        DEFINE VIEW (CUSTOMER_SALES, PRODUCT_SALES, DAILY_SALES)
  03_business_ready/*.sql             DEFINE VIEW (VW_CUSTOMER_SALES, VW_PRODUCT_PERFORMANCE, VW_DAILY_REVENUE)
  04_data_quality/expectations.sql    data metric functions + expectations (DCM TEST ALL)
validation/business_rules.sql         independent business-rule & reconciliation tests (13 checks)
streamlit/streamlit_app.py            Streamlit in Snowflake app (8 sections + guided mode)
streamlit/dcm_core.py                 shared engine: DCM / Git / validation / audit SQL
scripts/demo_cli.py                   terminal runner using the same engine
cleanup/cleanup.sql                   removes only objects created by this prototype
```

## Branches

| Branch | VW_CUSTOMER_SALES rule | Purpose |
|---|---|---|
| `main` | 10 % (after merge of A) | integration / promotion source |
| `feature/developer-A` | `DISCOUNT_PCT 0.10`, `NET = SALES * 0.90` | Developer A |
| `feature/developer-B` | `DISCOUNT_PCT 0.20`, `NET = SALES * 0.80` | Developer B (not merged) |
| `feature/developer-A-defect` | `DISCOUNT_PCT 0.10`, `NET = SALES * 1.10` | valid SQL, wrong logic |
| commit `1123996` | `0.00`, `* 1.00` | immutable baseline used by Reset buttons |

## Snowflake objects

| Object | Purpose |
|---|---|
| Role `DCM_DEMO_ADMIN`, warehouse `DCM_DEMO_WH` | own / run everything |
| User `DCM_DEMO_SVC` (service, PAT-only, role-restricted) | automation from outside Snowflake |
| `DCM_DEMO_CTRL_DB.GIT.DCM_DEMO_REPO` | Git repository object (GitHub mirror) |
| `DCM_DEMO_CTRL_DB.PROJECTS.DCM_SHARED_DEV / DCM_DEV_A / DCM_DEV_B / DCM_UAT / DCM_PROD` | one DCM project per target |
| `ANALYTICS_DB`, `BUSINESS_DB` | shared DEV (integration) |
| `DEV_A_*`, `DEV_B_*` | developer sandboxes (zero-copy clone + own DCM project) |
| `UAT_*` | UAT |
| `PROD_*` | **never created** - PROD is PLAN only |
| `DCM_DEMO_CTRL_DB.AUDIT.EXECUTION_LOG` | every step: SQL, branch, commit, status, output, query ID |
| `DCM_DEMO_CTRL_DB.APP.DCM_DEVOPS_DEMO` | the Streamlit app |

## Setup - exact steps (as executed)

Prerequisites: Snowflake CLI ≥ 3.16 (verified with 3.34.0), Python 3.10+, Git.

1. **Admin bootstrap** (Snowsight, role ACCOUNTADMIN): run `admin/00_admin_bootstrap.sql`
   and copy the `token_secret` of `DCM_DEMO_PAT` (shown once).
2. **Credentials** - environment variables only, never in files:
   ```bash
   export SNOWFLAKE_ACCOUNT=<org>-<account>      # e.g. PYPSAGL-HO49439
   export SNOWFLAKE_USER=DCM_DEMO_SVC
   export SNOWFLAKE_PASSWORD=<programmatic access token>
   ```
3. **Install tooling**
   ```bash
   python -m venv .venv && . .venv/bin/activate && pip install snowflake-cli
   ```
4. **Shared worksheet objects + control plane**
   ```bash
   snow sql -x --role DCM_DEMO_ADMIN --warehouse DCM_DEMO_WH -f setup/01_shared_worksheet_objects.sql
   snow sql -x --role DCM_DEMO_ADMIN --warehouse DCM_DEMO_WH -f setup/02_control_objects.sql
   ```
5. **First DCM PLAN / DEPLOY (adopts the worksheet objects)**
   ```bash
   cd dcm
   snow dcm create --target SHARED_DEV --if-not-exists -x --role DCM_DEMO_ADMIN --warehouse DCM_DEMO_WH
   snow dcm plan   --target SHARED_DEV -x --role DCM_DEMO_ADMIN --warehouse DCM_DEMO_WH
   cd ..
   python scripts/demo_cli.py fetch
   python scripts/demo_cli.py deploy SHARED_DEV main --alias baseline-main
   ```
6. **Developer / UAT targets**
   ```bash
   python scripts/demo_cli.py provision DEV_A && python scripts/demo_cli.py create DEV_A
   python scripts/demo_cli.py provision DEV_B && python scripts/demo_cli.py create DEV_B
   python scripts/demo_cli.py provision UAT   && python scripts/demo_cli.py create UAT
   python scripts/demo_cli.py create PROD
   python scripts/demo_cli.py record-git
   ```
7. **Streamlit app**
   ```bash
   cd streamlit && snow streamlit deploy --replace -x --role DCM_DEMO_ADMIN --warehouse DCM_DEMO_WH
   ```
   Open it in Snowsight → Projects → Streamlit → `DCM_DEVOPS_DEMO` with role `DCM_DEMO_ADMIN`
   (granted to your user by the bootstrap).

## Running steps from the terminal

```bash
python scripts/demo_cli.py plan     SHARED_DEV feature/developer-A --actor "Developer A"
python scripts/demo_cli.py deploy   SHARED_DEV feature/developer-A --actor "Developer A"
python scripts/demo_cli.py query    SHARED_DEV
python scripts/demo_cli.py validate DEV_A
python scripts/demo_cli.py test     DEV_A          # EXECUTE DCM PROJECT ... TEST ALL
python scripts/demo_cli.py deployments SHARED_DEV
```

Every command writes to `DCM_DEMO_CTRL_DB.AUDIT.EXECUTION_LOG`.

## Verified results (run of 2026-11-21)

| Step | Result |
|---|---|
| First PLAN of shared DEV | 14 objects adopted (0 create, 14 alter, 0 drop) - data untouched |
| Second PLAN after deploy | 0 changes (idempotent) |
| Scenario 1: A then B to `DCM_SHARED_DEV` | view went 0 % → 10 % (684,182.00) → 20 % (608,161.71) |
| Scenario 2: A to `DCM_DEV_A`, B to `DCM_DEV_B` | DEV_A 10 %, DEV_B 20 %, shared DEV unchanged; 13/13 validation each |
| Defect branch to DEV_A | commit ✅ PLAN ✅ DEPLOY ✅ TEST ALL 9/9 ✅ - NET 836,222.39 > gross; validation 3 FAIL |
| Promotion | shared DEV 13/13 → UAT PLAN/DEPLOY, 13/13 + 9/9 → PROD PLAN: 16 creates, not deployed |

## Findings worth telling the customer

1. **DCM PLAN catches structural problems.** Changing the literal `0.00` to `0.10`
   changes the view column type from `NUMBER(1,0)` to `NUMBER(2,1)`; PLAN refused:
   *"changing the scale of a number is not supported"*. Fix: pin column types
   (`::number(5,4)`) in definitions. The failed PLAN is in the audit log.
2. **One object, one DCM project.** Isolation needs a separate target (databases +
   project object + Jinja configuration) per developer - a Git branch is not enough.
3. **Zero-copy clones copy definitions too.** Cloned COMPUTE views still referenced
   `ANALYTICS_DB` until the developer's DCM deploy re-rendered them against
   `DEV_A_ANALYTICS_DB`. Always deploy after cloning.
4. **DCM + Jinja does not run under owner's rights.** Streamlit in Snowflake (and any
   `EXECUTE AS OWNER` procedure) gets *"Unsupported feature 'Jinja templating in owner's
   rights stored procedure'"*. The app therefore submits PLAN/DEPLOY to a one-shot task
   owned by `DCM_DEMO_ADMIN` (needs `GRANT EXECUTE TASK ON ACCOUNT`) and reads the result
   from `DCM_DEMO_CTRL_DB.APP.DCM_RUNS`. Everything else (Git, TEST ALL, queries) runs directly.
5. **Green pipeline ≠ correct data.** Generic expectations (nulls, duplicates,
   volume) pass on wrong business logic. Encode business rules as tests.

## Safety

* Everything is owned by `DCM_DEMO_ADMIN` and commented `DCM_DEMO`.
* No `DROP` in any PLAN that was deployed; Reset aborts if the PLAN contains a DROP.
* DEPLOY buttons are disabled until the PLAN for the same target/branch has been run and ticked as reviewed.
* PROD is PLAN-only. The app's cleanup drops only listed demo databases owned by
  `DCM_DEMO_ADMIN` with a `DCM_DEMO` comment, after typing a confirmation phrase.
* The automation token is role-restricted to `DCM_DEMO_ADMIN` and expires after 30 days.

## Cleanup

Review and run [`cleanup/cleanup.sql`](cleanup/cleanup.sql): Part 1 as `DCM_DEMO_ADMIN`,
Part 2 as `ACCOUNTADMIN`. It names every object explicitly; nothing else is touched.
