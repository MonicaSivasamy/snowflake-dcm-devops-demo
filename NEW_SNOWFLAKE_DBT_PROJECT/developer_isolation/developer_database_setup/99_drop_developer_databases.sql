-- =============================================================================
-- DATABASE-LEVEL ISOLATION - remove Developer A's sandbox
-- Order: dbt objects first (they hold the row access policy), then DCM purge.
-- =============================================================================
use role DCM_DEMO_ADMIN;

drop dbt project if exists ENT_DBT_CTRL_DB.PROJECTS.DBT_DEV_A;
drop view if exists SBX_DBT_DEV_A_BUSINESS_DB.BUSINESS_READY.CUSTOMER_PROFILE;   -- releases CUSTOMER_COUNTRY_RAP
execute dcm project ENT_DBT_CTRL_DB.PROJECTS.DCM_DEV_A purge;
drop database if exists SBX_DBT_DEV_A_RAW_COMPUTE_DB;
drop database if exists SBX_DBT_DEV_A_BUSINESS_DB;
drop dcm project if exists ENT_DBT_CTRL_DB.PROJECTS.DCM_DEV_A;
