-- =============================================================================
-- DATABASE-LEVEL ISOLATION - Developer A                      (NOT DCM-managed)
-- Developer A gets PRIVATE COPIES of both databases (zero-copy clones of DEV):
--     DEV_RAW_COMPUTE_DB  --clone-->  DEV_A_RAW_COMPUTE_DB
--     DEV_BUSINESS_DB     --clone-->  DEV_A_BUSINESS_DB
-- and a private DCM project object ENT_DCM_DEV_A (manifest target DEV_A).
-- Nothing Developer A deploys can touch shared DEV, QA, PROD or Developer B.
--
-- Run once when the developer is onboarded (or to start over).
-- Next step: 02_deploy_feature_branch.sql  (DCM re-points the cloned objects
-- to DEV_A_* names and takes ownership of them).
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

set DEV_ID = 'DEV_A';
set SRC_ENV = 'DEV';            -- clone from shared DEV (never PROD: PII)

set SRC_RC  = $SRC_ENV || '_RAW_COMPUTE_DB';
set SRC_BIZ = $SRC_ENV || '_BUSINESS_DB';
set DEV_RC  = $DEV_ID  || '_RAW_COMPUTE_DB';
set DEV_BIZ = $DEV_ID  || '_BUSINESS_DB';

-- zero-copy clones: instant, no storage cost until data changes
create database if not exists identifier($DEV_RC)  clone identifier($SRC_RC);
create database if not exists identifier($DEV_BIZ) clone identifier($SRC_BIZ);

-- the developer's own DCM project object (= own deployment history)
create dcm project if not exists ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_DEV_A
    comment = 'Developer A sandbox (database-level isolation)';

-- optional: give the developer's personal role access
-- grant ownership ... / grant database role DEV_A_RAW_COMPUTE_DB.COMPUTE_ENGINEER to role <DEV_A_ROLE>;
