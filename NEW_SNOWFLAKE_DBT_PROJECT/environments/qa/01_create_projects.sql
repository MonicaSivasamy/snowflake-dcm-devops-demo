-- =============================================================================
-- ENVIRONMENT QA - create the project objects (once)  (NOT DCM- or dbt-managed)
--   DCM project ENT_DBT_CTRL_DB.PROJECTS.DCM_QA  (manifest target QA)
--   dbt project ENT_DBT_CTRL_DB.PROJECTS.DBT_QA  (dbt target qa)
-- Databases: DBT_QA_RAW_COMPUTE_DB, DBT_QA_BUSINESS_DB
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

alter git repository ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO fetch;

create dcm project if not exists ENT_DBT_CTRL_DB.PROJECTS.DCM_QA
    comment = 'Enterprise dbt + DCM project - QA infrastructure and security';

-- a dbt project object is a versioned copy of the dbt files, taken from Git
create dbt project if not exists ENT_DBT_CTRL_DB.PROJECTS.DBT_QA
    from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/commits/<RELEASE_SHA>/NEW_SNOWFLAKE_DBT_PROJECT/dbt_project'
    default_target = 'qa'
    comment = 'Enterprise dbt + DCM project - QA transformations';
