# Developer mapping

Every developer works on the **same SQL files**. What differs is the **target**
they deploy to, which is defined once in `dcm_project/manifest.yml`.

| Developer | Isolation | Git branch (example) | DCM target | DCM project object | Where the objects land |
|---|---|---|---|---|---|
| Developer A | database-level | `feature/dev-a-country-codes` | `DEV_A` | `ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_DEV_A` | `SBX_DEV_A_RAW_COMPUTE_DB.{RAW,COMPUTE,GOVERNANCE}`, `SBX_DEV_A_BUSINESS_DB.{BUSINESS_READY,GOVERNANCE}` |
| Developer B | schema-level | `feature/dev-b-customer-segment` | `DEV_B` | `ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_DEV_B` | `DEV_RAW_COMPUTE_DB.{RAW_DEV_B,COMPUTE_DEV_B,GOVERNANCE_DEV_B}`, `DEV_BUSINESS_DB.{BUSINESS_READY_DEV_B,GOVERNANCE_DEV_B}` |
| (shared) | none | `main` | `DEV` | `ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_DEV` | `DEV_RAW_COMPUTE_DB.{RAW,COMPUTE,GOVERNANCE}`, `DEV_BUSINESS_DB.{BUSINESS_READY,GOVERNANCE}` |

## How one line of SQL lands in three different places

```sql
define view {{ business_db }}.BUSINESS_READY{{ schema_suffix }}.CUSTOMER_PROFILE as ...
```

| target | `business_db` | `schema_suffix` | object created |
|---|---|---|---|
| DEV   | DEV_BUSINESS_DB       | (empty) | `DEV_BUSINESS_DB.BUSINESS_READY.CUSTOMER_PROFILE` |
| DEV_A | SBX_DEV_A_BUSINESS_DB | (empty) | `SBX_DEV_A_BUSINESS_DB.BUSINESS_READY.CUSTOMER_PROFILE` |
| DEV_B | DEV_BUSINESS_DB       | `_DEV_B` | `DEV_BUSINESS_DB.BUSINESS_READY_DEV_B.CUSTOMER_PROFILE` |
| PROD  | PROD_BUSINESS_DB      | (empty) | `PROD_BUSINESS_DB.BUSINESS_READY.CUSTOMER_PROFILE` |

## Why the developers cannot affect each other

1. **Separate DCM project objects.** A Snowflake object can be managed by only
   one DCM project. DEV_A's project cannot alter or drop an object owned by DEV
   or DEV_B, and DCM refuses with *"can't be defined in this project, as it is
   managed by DCM project …"* (seen live while onboarding Developer A).
2. **Separate names.** Each target resolves to different databases or schemas.
3. **Separate branches.** Each developer only changes their own feature branch.
   Nothing reaches `main` without a reviewed pull request.

## Schema-level or database-level?

| | Schema-level (Developer B) | Database-level (Developer A) |
|---|---|---|
| What the developer gets | own schemas inside shared DEV databases | own databases (zero-copy clones) |
| Setup time / cost | seconds, no extra databases | seconds, storage only for changed data |
| Can test database-level objects (database roles, grants, database settings) | **no**: `owns_databases: false` skips them | **yes**: full copy of everything |
| Shared-DEV clutter | extra `*_DEV_B` schemas in DEV | none |
| Data | clone of the RAW schema | clone of complete DEV databases |
| Choose when | many developers, SQL logic changes only | security or structure work, large changes, or a strict separation policy |

## Onboarding developer C

1. In `manifest.yml`, copy the `DEV_A:` target and configuration (or `DEV_B:`)
   and rename them to `DEV_C` / `SBX_DEV_C_…` (or `_DEV_C`).
2. Raise a pull request for the manifest change (platform team approves).
3. Copy and adapt `developer_database_setup/01_…` (or `developer_schema_setup/01_…`).
4. The developer runs `snow dcm deploy --target DEV_C` from their branch.
