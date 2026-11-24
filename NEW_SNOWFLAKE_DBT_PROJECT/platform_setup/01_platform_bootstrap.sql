-- =============================================================================
-- PLATFORM SETUP 01 - one-time account bootstrap      (NOT DCM- or dbt-managed)
-- Run once as ACCOUNTADMIN. Gives the DCM deployment role exactly what it needs.
--
-- Deployment role : DCM_DEMO_ADMIN  (the account's existing automation role and
--                   service user DCM_DEMO_SVC; in your organization use a
--                   dedicated role such as DCM_DEPLOYER)
-- Warehouse       : DCM_DEMO_WH
-- Idempotent: safe to re-run.
-- =============================================================================
use role accountadmin;

create role if not exists DCM_DEMO_ADMIN comment = 'DCM deployment role (owns DCM-managed objects)';
grant role DCM_DEMO_ADMIN to role SYSADMIN;

create warehouse if not exists DCM_DEMO_WH
    warehouse_size = XSMALL auto_suspend = 60 auto_resume = true initially_suspended = true;
grant usage, operate on warehouse DCM_DEMO_WH to role DCM_DEMO_ADMIN;

grant create database    on account to role DCM_DEMO_ADMIN;   -- DCM creates <ENV>_RAW_COMPUTE_DB / <ENV>_BUSINESS_DB
grant create integration on account to role DCM_DEMO_ADMIN;   -- API integration for the Git repository

-- Optional: only if DCM should also own ACCOUNT roles (DEFINE ROLE ...).
-- This project keeps account roles with the security team instead
-- (platform_setup/04_account_roles.sql), so the grant stays commented out.
-- grant create role on account to role DCM_DEMO_ADMIN;
