-- =============================================================================
-- CLEANUP - removes ONLY objects created by this prototype.
-- Every statement names one object explicitly. No wildcard / pattern drops.
-- Review before running. Irreversible.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- PART 1 - run as DCM_DEMO_ADMIN (owner of everything below)
-- ---------------------------------------------------------------------------
USE ROLE DCM_DEMO_ADMIN;

-- 1a. Show what will be removed (must all be owned by DCM_DEMO_ADMIN, comment 'DCM_DEMO...')
SHOW DATABASES LIKE '%ANALYTICS_DB';
SHOW DATABASES LIKE '%BUSINESS_DB';
SHOW DCM PROJECTS IN SCHEMA DCM_DEMO_CTRL_DB.PROJECTS;

-- 1b. Streamlit app
DROP STREAMLIT IF EXISTS DCM_DEMO_CTRL_DB.APP.DCM_DEVOPS_DEMO;

-- 1c. Demo databases (shared DEV, developer sandboxes, UAT, PROD - PROD is never deployed by the demo)
DROP DATABASE IF EXISTS ANALYTICS_DB;
DROP DATABASE IF EXISTS BUSINESS_DB;
DROP DATABASE IF EXISTS DEV_A_ANALYTICS_DB;
DROP DATABASE IF EXISTS DEV_A_BUSINESS_DB;
DROP DATABASE IF EXISTS DEV_B_ANALYTICS_DB;
DROP DATABASE IF EXISTS DEV_B_BUSINESS_DB;
DROP DATABASE IF EXISTS UAT_ANALYTICS_DB;
DROP DATABASE IF EXISTS UAT_BUSINESS_DB;
DROP DATABASE IF EXISTS PROD_ANALYTICS_DB;
DROP DATABASE IF EXISTS PROD_BUSINESS_DB;

-- 1d. DCM project objects (dropping a project does not drop objects; those were dropped above)
DROP DCM PROJECT IF EXISTS DCM_DEMO_CTRL_DB.PROJECTS.DCM_SHARED_DEV;
DROP DCM PROJECT IF EXISTS DCM_DEMO_CTRL_DB.PROJECTS.DCM_DEV_A;
DROP DCM PROJECT IF EXISTS DCM_DEMO_CTRL_DB.PROJECTS.DCM_DEV_B;
DROP DCM PROJECT IF EXISTS DCM_DEMO_CTRL_DB.PROJECTS.DCM_UAT;
DROP DCM PROJECT IF EXISTS DCM_DEMO_CTRL_DB.PROJECTS.DCM_PROD;

-- 1e. Control database (Git repository object, audit log, app stage) and Git API integration
DROP DATABASE IF EXISTS DCM_DEMO_CTRL_DB;
DROP INTEGRATION IF EXISTS DCM_DEMO_GIT_API;

-- ---------------------------------------------------------------------------
-- PART 2 - run as ACCOUNTADMIN (objects from admin/00_admin_bootstrap.sql)
-- ---------------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;
ALTER USER IF EXISTS DCM_DEMO_SVC REMOVE PROGRAMMATIC ACCESS TOKEN DCM_DEMO_PAT;
ALTER USER IF EXISTS DCM_DEMO_SVC UNSET AUTHENTICATION POLICY;
DROP USER IF EXISTS DCM_DEMO_SVC;
DROP AUTHENTICATION POLICY IF EXISTS DCM_DEMO_SECURITY_DB.POLICIES.DCM_DEMO_SVC_AUTH;
DROP DATABASE IF EXISTS DCM_DEMO_SECURITY_DB;
DROP WAREHOUSE IF EXISTS DCM_DEMO_WH;
DROP ROLE IF EXISTS DCM_DEMO_ADMIN;
