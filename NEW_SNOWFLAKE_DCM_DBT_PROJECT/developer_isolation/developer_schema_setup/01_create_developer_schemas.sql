-- =============================================================================
-- SCHEMA-LEVEL ISOLATION - Developer B                (NOT DCM-managed)
-- Private schemas inside the shared DEV databases:
--     DCMDBT_DEV_RAW_COMPUTE_DB.RAW_DEV_B / COMPUTE_DEV_B / GOVERNANCE_DEV_B
--     DCMDBT_DEV_BUSINESS_DB.BUSINESS_READY_DEV_B / GOVERNANCE_DEV_B
-- DCM target DEV_B and dbt target dev_b both use schema_suffix = '_DEV_B'.
-- Only RAW is cloned (data); DCM + dbt build everything else.
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

create schema if not exists DCMDBT_DEV_RAW_COMPUTE_DB.RAW_DEV_B clone DCMDBT_DEV_RAW_COMPUTE_DB.RAW;

create dcm project if not exists ENT_DCMDBT_CTRL_DB.PROJECTS.DCM_DEV_B
    comment = 'Developer B sandbox (schema-level isolation) - infrastructure';
