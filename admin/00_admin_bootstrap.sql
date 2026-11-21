-- =============================================================================
-- DCM DevOps Demo - one-time administrative bootstrap
-- Run ONCE in a Snowsight worksheet as ACCOUNTADMIN.
-- Everything here is idempotent (IF NOT EXISTS) and tagged with COMMENT 'DCM_DEMO'.
-- It does NOT touch any existing database, role, user or warehouse.
-- =============================================================================
USE ROLE ACCOUNTADMIN;

-- 1. Dedicated demo role --------------------------------------------------------
CREATE ROLE IF NOT EXISTS DCM_DEMO_ADMIN COMMENT = 'DCM_DEMO: owns every object created by the DCM DevOps demo';
GRANT ROLE DCM_DEMO_ADMIN TO USER MSIVASAMY;   -- so you can open the Streamlit app and inspect objects
GRANT ROLE DCM_DEMO_ADMIN TO ROLE SYSADMIN;    -- keeps the standard role hierarchy

-- 2. Dedicated demo warehouse ----------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS DCM_DEMO_WH
  WAREHOUSE_SIZE = XSMALL AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE
  COMMENT = 'DCM_DEMO';
GRANT USAGE, OPERATE ON WAREHOUSE DCM_DEMO_WH TO ROLE DCM_DEMO_ADMIN;

-- 3. Account-level privileges the demo role needs ---------------------------------
GRANT CREATE DATABASE    ON ACCOUNT TO ROLE DCM_DEMO_ADMIN;  -- demo databases (ANALYTICS_DB, DEV_A_*, ...)
GRANT CREATE INTEGRATION ON ACCOUNT TO ROLE DCM_DEMO_ADMIN;  -- API integration for the GitHub repo
GRANT EXECUTE DATA METRIC FUNCTION ON ACCOUNT TO ROLE DCM_DEMO_ADMIN;  -- DCM data quality expectations
GRANT DATABASE ROLE SNOWFLAKE.DATA_METRIC_USER TO ROLE DCM_DEMO_ADMIN;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE DCM_DEMO_ADMIN;  -- Streamlit app runs DCM PLAN/DEPLOY through a task:
                                                      -- DCM rejects Jinja templating under owner's rights (Streamlit in Snowflake)

-- 4. Dedicated service user for automation (used by the Claude cloud session) ----
CREATE USER IF NOT EXISTS DCM_DEMO_SVC
  TYPE = SERVICE
  DEFAULT_ROLE = DCM_DEMO_ADMIN
  DEFAULT_WAREHOUSE = DCM_DEMO_WH
  COMMENT = 'DCM_DEMO: service user for the DCM DevOps demo automation';
GRANT ROLE DCM_DEMO_ADMIN TO USER DCM_DEMO_SVC;

-- 5. Authentication policy: PAT only, and no network policy required -------------
--    (the cloud session has no fixed egress IP). Scoped to DCM_DEMO_SVC only;
--    your own user MSIVASAMY is not changed.
CREATE DATABASE IF NOT EXISTS DCM_DEMO_SECURITY_DB COMMENT = 'DCM_DEMO: holds the demo authentication policy';
CREATE SCHEMA   IF NOT EXISTS DCM_DEMO_SECURITY_DB.POLICIES COMMENT = 'DCM_DEMO';
CREATE AUTHENTICATION POLICY IF NOT EXISTS DCM_DEMO_SECURITY_DB.POLICIES.DCM_DEMO_SVC_AUTH
  AUTHENTICATION_METHODS = ('PROGRAMMATIC_ACCESS_TOKEN')
  PAT_POLICY = (NETWORK_POLICY_EVALUATION = ENFORCED_NOT_REQUIRED)
  COMMENT = 'DCM_DEMO: PAT-only login for DCM_DEMO_SVC without fixed IP';
ALTER USER DCM_DEMO_SVC SET AUTHENTICATION POLICY DCM_DEMO_SECURITY_DB.POLICIES.DCM_DEMO_SVC_AUTH;

-- 6. Token restricted to the demo role, expires in 30 days -----------------------
--    Copy the TOKEN_SECRET value from the result. It is shown only once.
ALTER USER DCM_DEMO_SVC ADD PROGRAMMATIC ACCESS TOKEN DCM_DEMO_PAT
  ROLE_RESTRICTION = 'DCM_DEMO_ADMIN'
  DAYS_TO_EXPIRY = 30
  COMMENT = 'DCM_DEMO';

-- Verify
SHOW GRANTS TO ROLE DCM_DEMO_ADMIN;
SHOW USER PROGRAMMATIC ACCESS TOKENS FOR USER DCM_DEMO_SVC;

-- -----------------------------------------------------------------------------
-- To revoke later:
--   ALTER USER DCM_DEMO_SVC REMOVE PROGRAMMATIC ACCESS TOKEN DCM_DEMO_PAT;
--   DROP USER DCM_DEMO_SVC;
-- -----------------------------------------------------------------------------
