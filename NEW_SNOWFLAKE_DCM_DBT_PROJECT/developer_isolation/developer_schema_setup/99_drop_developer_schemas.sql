-- =============================================================================
-- SCHEMA-LEVEL ISOLATION - remove Developer B's sandbox
-- Order: dbt objects first (they hold the row access policy), then DCM purge.
-- =============================================================================
use role DCM_DEMO_ADMIN;

drop dbt project if exists ENT_DCMDBT_CTRL_DB.PROJECTS.DBT_DEV_B;
drop view if exists DCMDBT_DEV_BUSINESS_DB.BUSINESS_READY_DEV_B.CUSTOMER_PROFILE;  -- releases CUSTOMER_COUNTRY_RAP
execute dcm project ENT_DCMDBT_CTRL_DB.PROJECTS.DCM_DEV_B purge;
drop schema if exists DCMDBT_DEV_RAW_COMPUTE_DB.RAW_DEV_B;
drop dcm project if exists ENT_DCMDBT_CTRL_DB.PROJECTS.DCM_DEV_B;
