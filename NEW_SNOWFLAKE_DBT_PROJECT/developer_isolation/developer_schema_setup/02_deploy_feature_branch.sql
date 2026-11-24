-- =============================================================================
-- SCHEMA-LEVEL ISOLATION - deploy Developer B's branch    (runs DCM, then dbt)
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

alter git repository ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO fetch;

execute dcm project ENT_DBT_CTRL_DB.PROJECTS.DCM_DEV_B
    plan using configuration DEV_B
    from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/branches/"feature/dbt-dev-b-customer-segment"/NEW_SNOWFLAKE_DBT_PROJECT/dcm_project';
execute dcm project ENT_DBT_CTRL_DB.PROJECTS.DCM_DEV_B
    deploy                                     -- no alias: sandboxes redeploy often and aliases must be unique
    using configuration DEV_B
    from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/branches/"feature/dbt-dev-b-customer-segment"/NEW_SNOWFLAKE_DBT_PROJECT/dcm_project';

-- first run creates the dbt project object; after further pushes run the
-- commented ALTER ... ADD VERSION instead
create dbt project if not exists ENT_DBT_CTRL_DB.PROJECTS.DBT_DEV_B
    from '@ENT_DBT_CTRL_DB.GIT.ENT_DBT_REPO/branches/"feature/dbt-dev-b-customer-segment"/NEW_SNOWFLAKE_DBT_PROJECT/dbt_project'
    default_target = 'dev_b'
    comment = 'Developer B sandbox - transformations';

execute dbt project ENT_DBT_CTRL_DB.PROJECTS.DBT_DEV_B args = 'build --target dev_b';

select * from DBT_DEV_BUSINESS_DB.BUSINESS_READY_DEV_B.CUSTOMER_PROFILE order by 1;
