# Developer mapping (dbt + DCM)

Every developer works on the **same files**. Each developer has their own
**DCM target** (containers and security) and **dbt target** (transformations).

| Developer | Isolation | Git branch (example) | DCM target / project | dbt target / project | Objects land in |
|---|---|---|---|---|---|
| Developer A | database-level | `feature/dbt-dev-a-country-codes` | `DEV_A` / `DCM_DEV_A` | `dev_a` / `DBT_DEV_A` | `SBX_DBT_DEV_A_RAW_COMPUTE_DB`, `SBX_DBT_DEV_A_BUSINESS_DB` |
| Developer B | schema-level | `feature/dbt-dev-b-customer-segment` | `DEV_B` / `DCM_DEV_B` | `dev_b` / `DBT_DEV_B` | `*_DEV_B` schemas in `DBT_DEV_*` databases |
| (shared) | none | `main` | `DEV` / `DCM_DEV` | `dev` / `DBT_DEV` | `DBT_DEV_RAW_COMPUTE_DB`, `DBT_DEV_BUSINESS_DB` |

All project objects live in `ENT_DBT_CTRL_DB.PROJECTS`.

## How names are resolved

| Tool | Developer writes | Mapping file | Example (target dev_b) |
|---|---|---|---|
| DCM | `{{ raw_compute_db }}.COMPUTE{{ schema_suffix }}` | `dcm_project/manifest.yml` | `DBT_DEV_RAW_COMPUTE_DB.COMPUTE_DEV_B` |
| dbt | `+database: RAW_COMPUTE_DB`, `+schema: COMPUTE`, `ref('customer')` | `dbt_project/dbt_project.yml` → `vars.environments`, plus `macros/generate_database_name.sql` and `macros/generate_schema_name.sql` | `DBT_DEV_RAW_COMPUTE_DB.COMPUTE_DEV_B.CUSTOMER` |

dbt models never contain a database name. They use `ref()` / `source()` and
the logical names `RAW_COMPUTE_DB` / `BUSINESS_DB`.

## Schema-level or database-level?

Same trade-offs as in the DCM-only project
(`NEW_SNOWFLAKE_DCM_PROJECT/developer_isolation/developer_mapping/README.md`).
One dbt-specific point: with schema-level isolation, dbt `ref()` resolves to
the developer's own `*_DEV_B` schemas, so a sandbox never reads shared DEV's
COMPUTE objects.

## Onboarding developer C

1. `manifest.yml`: copy the `DEV_A` (or `DEV_B`) target and configuration.
2. `dbt_project.yml` → `vars.environments`: copy the `dev_a` (or `dev_b`) row.
   In `profiles.yml`, copy the matching output.
3. Raise a pull request (platform team approves), then copy and adapt the `01_` setup script.
