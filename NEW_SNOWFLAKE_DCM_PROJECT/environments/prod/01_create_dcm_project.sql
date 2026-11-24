-- =============================================================================
-- ENVIRONMENT PROD - create the DCM project object (once)      (NOT DCM-managed)
-- manifest.yml target PROD  ->  project ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_PROD
--                          ->  databases PROD_RAW_COMPUTE_DB, PROD_BUSINESS_DB
-- The project object stores the deployment history of this environment.
-- =============================================================================
use role DCM_DEMO_ADMIN;

create dcm project if not exists ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_PROD
    comment = 'Enterprise DCM project - PROD environment';

show dcm projects in schema ENT_DCM_CTRL_DB.PROJECTS;
