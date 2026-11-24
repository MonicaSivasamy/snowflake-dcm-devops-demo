-- =============================================================================
-- DATABASE-LEVEL ISOLATION - Developer A              (NOT DCM- or dbt-managed)
--     DBT_DEV_RAW_COMPUTE_DB  --clone-->  SBX_DBT_DEV_A_RAW_COMPUTE_DB
--     DBT_DEV_BUSINESS_DB     --clone-->  SBX_DBT_DEV_A_BUSINESS_DB
-- plus Developer A's own DCM project (DCM_DEV_A, manifest target DEV_A).
-- The dbt project object is created from the feature branch in 02_.
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

set SRC_RC  = 'DBT_DEV_RAW_COMPUTE_DB';
set SRC_BIZ = 'DBT_DEV_BUSINESS_DB';
set DEV_RC  = 'SBX_DBT_DEV_A_RAW_COMPUTE_DB';
set DEV_BIZ = 'SBX_DBT_DEV_A_BUSINESS_DB';

create database if not exists identifier($DEV_RC)  clone identifier($SRC_RC);
create database if not exists identifier($DEV_BIZ) clone identifier($SRC_BIZ);

create dcm project if not exists ENT_DBT_CTRL_DB.PROJECTS.DCM_DEV_A
    comment = 'Developer A sandbox (database-level isolation) - infrastructure';
