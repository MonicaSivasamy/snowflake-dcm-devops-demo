-- =============================================================================
-- DATABASE-LEVEL ISOLATION - deploy Developer A's feature branch   (runs DCM)
-- Same SQL files as everybody else; target DEV_A maps them to DEV_A_* databases.
-- CLI equivalent (from the local working copy):
--     snow dcm plan   --target DEV_A --from NEW_SNOWFLAKE_DCM_PROJECT/dcm_project
--     snow dcm deploy --target DEV_A --from NEW_SNOWFLAKE_DCM_PROJECT/dcm_project
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

alter git repository ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO fetch;

execute dcm project ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_DEV_A
    plan using configuration DEV_A
    from '@ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO/branches/"feature/dev-a-country-codes"/NEW_SNOWFLAKE_DCM_PROJECT/dcm_project';

execute dcm project ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_DEV_A
    deploy as "dev-a-country-codes"           -- alias: no slashes allowed
    using configuration DEV_A
    from '@ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO/branches/"feature/dev-a-country-codes"/NEW_SNOWFLAKE_DCM_PROJECT/dcm_project';

-- !! Never CALL a cloned procedure before the first DEPLOY: until DCM
--    re-points it, the clone's code still targets the SOURCE database.
-- rebuild COMPUTE with the new logic and look at the result (sandbox only)
call SBX_DEV_A_RAW_COMPUTE_DB.COMPUTE.SP_LOAD_CUSTOMER();
select CUSTOMER_ID, COUNTRY from SBX_DEV_A_RAW_COMPUTE_DB.COMPUTE.CUSTOMER order by 1;
