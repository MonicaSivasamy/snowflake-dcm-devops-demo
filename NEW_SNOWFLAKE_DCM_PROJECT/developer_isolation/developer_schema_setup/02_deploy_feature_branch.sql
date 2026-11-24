-- =============================================================================
-- SCHEMA-LEVEL ISOLATION - deploy Developer B's feature branch     (runs DCM)
-- CLI equivalent:  snow dcm deploy --target DEV_B --from NEW_SNOWFLAKE_DCM_PROJECT/dcm_project
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

alter git repository ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO fetch;

execute dcm project ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_DEV_B
    plan using configuration DEV_B
    from '@ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO/branches/"feature/dev-b-customer-segment"/NEW_SNOWFLAKE_DCM_PROJECT/dcm_project';

execute dcm project ENT_DCM_CTRL_DB.PROJECTS.ENT_DCM_DEV_B
    deploy as "feature/dev-b-customer-segment"
    using configuration DEV_B
    from '@ENT_DCM_CTRL_DB.GIT.ENT_DCM_REPO/branches/"feature/dev-b-customer-segment"/NEW_SNOWFLAKE_DCM_PROJECT/dcm_project';

call DEV_RAW_COMPUTE_DB.COMPUTE_DEV_B.SP_LOAD_CUSTOMER();
select * from DEV_BUSINESS_DB.BUSINESS_READY_DEV_B.CUSTOMER_PROFILE order by 1;
