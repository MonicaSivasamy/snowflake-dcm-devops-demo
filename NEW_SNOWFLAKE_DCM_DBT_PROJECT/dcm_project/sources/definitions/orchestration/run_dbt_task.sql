-- =============================================================================
-- ORCHESTRATION - the task that runs the dbt project (DCM-managed)
-- This is how dbt is "maintained inside DCM": DCM owns and versions the task
-- (what runs, where, with which target); the dbt models themselves live in
-- ../../dbt_project/ and are executed by it.
--
-- Requires EXECUTE TASK on the account for the owner role (platform_setup/01).
--   run now :  execute task {{ raw_compute_db }}.COMPUTE{{ schema_suffix }}.RUN_DBT_BUILD;
--   schedule:  add  schedule = 'USING CRON 0 6 * * * UTC'  and resume the task
-- =============================================================================

define task {{ raw_compute_db }}.COMPUTE{{ schema_suffix }}.RUN_DBT_BUILD
    warehouse = DCM_DEMO_WH
    comment = 'Runs dbt build for this environment (models + tests)'
as
    execute dbt project ENT_DCMDBT_CTRL_DB.PROJECTS.{{ dbt_project }} args = 'build --target {{ dbt_target }}';
