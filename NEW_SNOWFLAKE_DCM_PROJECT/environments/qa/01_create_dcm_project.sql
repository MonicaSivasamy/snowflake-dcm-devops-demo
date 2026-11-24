-- =============================================================================
-- ENVIRONMENT QA - create the DCM project object (once)      (NOT DCM-managed)
-- manifest.yml target QA  ->  project ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_QA
--                          ->  databases QA_RAW_COMPUTE_DB, QA_BUSINESS_DB
-- The project object stores the deployment history of this environment.
-- =============================================================================
use role DCM_DEMO_ADMIN;

create dcm project if not exists ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_QA
    comment = 'Enterprise DCM project - QA environment';

show dcm projects in schema ENT_DCM_CTRL_DB.PROJECTS;
