-- =============================================================================
-- ENVIRONMENT PROD - create the project objects (once)  (NOT DCM- or dbt-managed)
--   DCM project ENT_DBT_CTRL_DB.PROJECTS.DCM_PROD  (manifest target PROD)
--   dbt project ENT_DBT_CTRL_DB.PROJECTS.DBT_PROD  (dbt target prod)
-- Databases: DBT_PROD_RAW_COMPUTE_DB, DBT_PROD_BUSINESS_DB
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

alter git repository ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO fetch;

create dcm project if not exists ENT_DBT_CTRL_DB.PROJECTS.DCM_PROD
    comment = 'Enterprise dbt + DCM project - PROD infrastructure and security';

-- a dbt project object is a versioned copy of the dbt files, taken from Git
create dbt project if not exists ENT_DBT_CTRL_DB.PROJECTS.DBT_PROD
    from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/commits/<RELEASE_SHA>/NEW_SNOWFLAKE_DBT_PROJECT/dbt_project'
    default_target = 'prod'
    comment = 'Enterprise dbt + DCM project - PROD transformations';
