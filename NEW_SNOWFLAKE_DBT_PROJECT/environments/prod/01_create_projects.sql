-- =============================================================================
-- ENVIRONMENT PROD - create the project objects (once)  (NOT DCM- or dbt-managed)
--   DCM project ENT_DBT_CTRL_DB.PROJECTS.DCM_PROD  (manifest target PROD)
--   dbt project ENT_DBT_CTRL_DB.PROJECTS.DBT_PROD  (dbt target prod, created in 02_deploy.sql)
-- Databases: DBT_PROD_RAW_COMPUTE_DB, DBT_PROD_BUSINESS_DB
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

alter git repository ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO fetch;

create dcm project if not exists ENT_DBT_CTRL_DB.PROJECTS.DCM_PROD
    comment = 'Enterprise dbt + DCM project - PROD infrastructure and security';

-- The dbt project object DBT_PROD is created by 02_deploy.sql AFTER the first
-- DCM DEPLOY: creating it compiles the dbt project, which needs the databases.
