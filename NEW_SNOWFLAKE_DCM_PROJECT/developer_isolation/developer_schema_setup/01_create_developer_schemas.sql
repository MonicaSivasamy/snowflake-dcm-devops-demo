-- =============================================================================
-- SCHEMA-LEVEL ISOLATION - Developer B                        (NOT DCM-managed)
-- Developer B works INSIDE the shared DEV databases, in private schemas:
--     DEV_RAW_COMPUTE_DB.RAW_DEV_B / COMPUTE_DEV_B / GOVERNANCE_DEV_B
--     DEV_BUSINESS_DB.BUSINESS_READY_DEV_B / GOVERNANCE_DEV_B
-- Target DEV_B in manifest.yml sets  schema_suffix = '_DEV_B'  and
-- owns_databases = false (the databases, database roles and grants stay
-- owned by the shared DEV project).
--
-- Only the RAW schema is cloned (to get data); DCM creates everything else.
-- Next step: 02_deploy_feature_branch.sql
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

create schema if not exists DEV_RAW_COMPUTE_DB.RAW_DEV_B clone DEV_RAW_COMPUTE_DB.RAW;

create dcm project if not exists ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_DEV_B
    comment = 'Developer B sandbox (schema-level isolation)';
