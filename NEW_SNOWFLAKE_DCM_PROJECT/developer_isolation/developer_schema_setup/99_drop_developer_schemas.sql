-- =============================================================================
-- SCHEMA-LEVEL ISOLATION - remove Developer B's sandbox       (NOT DCM-managed)
-- =============================================================================
use role DCM_DEMO_ADMIN;

execute dcm project ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_DEV_B purge;   -- drops the *_DEV_B schemas it manages
drop schema if exists DEV_RAW_COMPUTE_DB.RAW_DEV_B;                 -- the cloned RAW schema
drop dcm project if exists ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_DEV_B;
