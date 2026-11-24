-- =============================================================================
-- ENVIRONMENT QA - create the project objects (once)  (NOT DCM- or dbt-managed)
--   DCM project ENT_DBT_CTRL_DB.PROJECTS.DCM_QA  (manifest target QA)
--   dbt project ENT_DBT_CTRL_DB.PROJECTS.DBT_QA  (dbt target qa, created in 02_deploy.sql)
-- Databases: DBT_QA_RAW_COMPUTE_DB, DBT_QA_BUSINESS_DB
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

alter git repository ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO fetch;

create dcm project if not exists ENT_DBT_CTRL_DB.PROJECTS.DCM_QA
    comment = 'Enterprise dbt + DCM project - QA infrastructure and security';

-- The dbt project object DBT_QA is created by 02_deploy.sql AFTER the first
-- DCM DEPLOY: creating it compiles the dbt project, which needs the databases.
