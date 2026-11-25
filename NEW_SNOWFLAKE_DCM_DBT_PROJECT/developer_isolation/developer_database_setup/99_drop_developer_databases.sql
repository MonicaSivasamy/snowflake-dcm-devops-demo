-- =============================================================================
-- DATABASE-LEVEL ISOLATION - remove Developer A's sandbox
-- Everything DCM_DEV_A manages lives in the two sandbox databases, so dropping
-- them removes it all (dbt objects included); then the project objects go.
-- =============================================================================
use role DCM_DEMO_ADMIN;

drop dbt project if exists ENT_DCMDBT_CTRL_DB.PROJECTS.DBT_DEV_A;
drop database if exists SBX_DCMDBT_DEV_A_RAW_COMPUTE_DB;
drop database if exists SBX_DCMDBT_DEV_A_BUSINESS_DB;
drop dcm project if exists ENT_DCMDBT_CTRL_DB.PROJECTS.DCM_DEV_A;
