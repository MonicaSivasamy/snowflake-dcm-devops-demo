-- =============================================================================
-- ENVIRONMENT DEV - create the DCM project object (once)      (NOT DCM-managed)
-- manifest.yml target DEV  ->  project ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_DEV
--                          ->  databases DEV_RAW_COMPUTE_DB, DEV_BUSINESS_DB
-- The project object stores the deployment history of this environment.
-- =============================================================================
use role DCM_DEMO_ADMIN;

create dcm project if not exists ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_DEV
    comment = 'Enterprise DCM project - DEV environment';

show dcm projects in schema ENT_DCM_CTRL_DB.PROJECTS;
