-- =============================================================================
-- ENVIRONMENT QA - create the project objects (once)  (NOT DCM-managed)
--   DCM project ENT_DCMDBT_CTRL_DB.PROJECTS.DCM_QA  (manifest target QA)
--   dbt project ENT_DCMDBT_CTRL_DB.PROJECTS.DBT_QA  (dbt target qa, created in 02_deploy.sql)
-- Databases: DCMDBT_QA_RAW_COMPUTE_DB, DCMDBT_QA_BUSINESS_DB
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

alter git repository ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO fetch;

create dcm project if not exists ENT_DCMDBT_CTRL_DB.PROJECTS.DCM_QA
    comment = 'Enterprise DCM-with-dbt project - QA infrastructure and security';

-- The dbt project object DBT_QA is created by 02_deploy.sql AFTER the first
-- DCM DEPLOY: creating it compiles the dbt project, which needs the databases.
