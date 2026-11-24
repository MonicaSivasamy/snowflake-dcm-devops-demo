-- =============================================================================
-- SCHEMA-LEVEL ISOLATION - deploy Developer B's branch    (runs DCM, then dbt)
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

alter git repository ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO fetch;

execute dcm project ENT_DCMDBT_CTRL_DB.PROJECTS.DCM_DEV_B
    plan using configuration DEV_B
    from '@ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO/branches/"feature/dcmdbt-dev-b-customer-segment"/NEW_SNOWFLAKE_DCM_DBT_PROJECT/dcm_project';
execute dcm project ENT_DCMDBT_CTRL_DB.PROJECTS.DCM_DEV_B
    deploy                                     -- no alias: sandboxes redeploy often and aliases must be unique
    using configuration DEV_B
    from '@ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO/branches/"feature/dcmdbt-dev-b-customer-segment"/NEW_SNOWFLAKE_DCM_DBT_PROJECT/dcm_project';

-- first run creates the dbt project object; after further pushes run the
-- commented ALTER ... ADD VERSION instead
create dbt project if not exists ENT_DCMDBT_CTRL_DB.PROJECTS.DBT_DEV_B
    from '@ENT_DCMDBT_CTRL_DB.GIT.ENT_DCMDBT_REPO/branches/"feature/dcmdbt-dev-b-customer-segment"/NEW_SNOWFLAKE_DCM_DBT_PROJECT/dcm_project/dbt_project'
    default_target = 'dev_b'
    comment = 'Developer B sandbox - transformations';

-- run dbt (the same command the DCM-managed task RUN_DBT_BUILD contains):
execute dbt project ENT_DCMDBT_CTRL_DB.PROJECTS.DBT_DEV_B args = 'build --target dev_b';
-- once EXECUTE TASK is granted (platform_setup/01) you can run the DCM task instead:
-- execute task DCMDBT_DEV_RAW_COMPUTE_DB.COMPUTE_DEV_B.RUN_DBT_BUILD;

select * from DCMDBT_DEV_BUSINESS_DB.BUSINESS_READY_DEV_B.CUSTOMER_PROFILE order by 1;
