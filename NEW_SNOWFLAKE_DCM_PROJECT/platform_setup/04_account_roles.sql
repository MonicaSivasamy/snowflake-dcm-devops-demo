-- =============================================================================
-- PLATFORM SETUP 04 - account roles, hierarchy, link to database roles
--                                                              (NOT DCM-managed)
-- Run as SECURITYADMIN once per environment, AFTER the first DCM DEPLOY of that
-- environment (the database roles must exist) and again after a database
-- refresh (see database_cloning/post_refresh/).
--
-- Why outside DCM: account roles are shared by many projects and are owned by
-- the security team; the DCM deployment role does not hold CREATE ROLE.
-- (DCM does support DEFINE ROLE if your deployment role holds CREATE ROLE.)
--
--   <ENV>_ENT_ANALYST      -> BUSINESS_READER          (masked PII, US rows only)
--   <ENV>_ENT_PII_ANALYST  -> + PII_READER + ALL_COUNTRIES_READER
--   <ENV>_ENT_ENGINEER     -> COMPUTE_ENGINEER (RAW + COMPUTE)
--   hierarchy: ANALYST -> PII_ANALYST -> SYSADMIN,  ENGINEER -> SYSADMIN
-- =============================================================================
use role securityadmin;

set ENV = 'DEV';                                   -- DEV | QA | PROD

set RC_DB        = $ENV || '_RAW_COMPUTE_DB';
set BIZ_DB       = $ENV || '_BUSINESS_DB';
set ANALYST      = $ENV || '_ENT_ANALYST';
set PII_ANALYST  = $ENV || '_ENT_PII_ANALYST';
set ENGINEER     = $ENV || '_ENT_ENGINEER';

-- 1. account roles
create role if not exists identifier($ANALYST)     comment = 'Business analyst: masked PII, home-market rows';
create role if not exists identifier($PII_ANALYST) comment = 'Privileged analyst: unmasked PII, all countries';
create role if not exists identifier($ENGINEER)    comment = 'Data engineer: RAW + COMPUTE';

-- 2. account role hierarchy
grant role identifier($ANALYST)     to role identifier($PII_ANALYST);
grant role identifier($PII_ANALYST) to role SYSADMIN;
grant role identifier($ENGINEER)    to role SYSADMIN;

-- 3. link DCM-managed database roles to account roles
grant database role identifier($BIZ_DB || '.BUSINESS_READER')      to role identifier($ANALYST);
grant database role identifier($RC_DB  || '.PII_READER')           to role identifier($PII_ANALYST);
grant database role identifier($BIZ_DB || '.ALL_COUNTRIES_READER') to role identifier($PII_ANALYST);
grant database role identifier($RC_DB  || '.COMPUTE_ENGINEER')     to role identifier($ENGINEER);

-- 4. compute
grant usage on warehouse DCM_DEMO_WH to role identifier($ANALYST);
grant usage on warehouse DCM_DEMO_WH to role identifier($ENGINEER);

-- 5. people (example)
-- grant role identifier($ANALYST) to user JANE_DOE;
