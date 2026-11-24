-- =============================================================================
-- ENVIRONMENT DEV - create the project objects (once)  (NOT DCM- or dbt-managed)
--   DCM project ENT_DBT_CTRL_DB.PROJECTS.DCM_DEV  (manifest target DEV)
--   dbt project ENT_DBT_CTRL_DB.PROJECTS.DBT_DEV  (dbt target dev)
-- Databases: DBT_DEV_RAW_COMPUTE_DB, DBT_DEV_BUSINESS_DB
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

alter git repository ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO fetch;

create dcm project if not exists ENT_DBT_CTRL_DB.PROJECTS.DCM_DEV
    comment = 'Enterprise dbt + DCM project - DEV infrastructure and security';

-- a dbt project object is a versioned copy of the dbt files, taken from Git
create dbt project if not exists ENT_DBT_CTRL_DB.PROJECTS.DBT_DEV
    from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/branches/main/NEW_SNOWFLAKE_DBT_PROJECT/dbt_project'
    default_target = 'dev'
    comment = 'Enterprise dbt + DCM project - DEV transformations';
