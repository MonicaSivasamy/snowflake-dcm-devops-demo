-- =============================================================================
-- DATABASE-LEVEL ISOLATION - remove Developer A's sandbox     (NOT DCM-managed)
-- Run after the pull request is merged. Work is safe in Git; nothing is lost.
-- =============================================================================
use role DCM_DEMO_ADMIN;

execute dcm project ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_DEV_A purge;   -- drops only objects this project manages
drop database if exists DEV_A_RAW_COMPUTE_DB;
drop database if exists DEV_A_BUSINESS_DB;
drop dcm project if exists ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_DEV_A;
