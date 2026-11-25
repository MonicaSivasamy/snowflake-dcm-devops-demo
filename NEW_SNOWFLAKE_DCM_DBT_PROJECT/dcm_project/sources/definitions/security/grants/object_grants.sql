-- =============================================================================
-- SECURITY / GRANTS - object permissions (DCM-managed)
-- Only for objects DCM creates. Objects built by dbt get their grants from
-- dbt post-hooks (dbt_project/macros/governance/), always AFTER their policies
-- are attached, so they are never readable unprotected.
-- =============================================================================
{% if owns_databases %}

-- RAW landing table (DCM): read-only
grant select on table {{ raw_compute_db }}.RAW.CUSTOMER_SRC to database role {{ raw_compute_db }}.RAW_READER;

-- COMPUTE views built by dbt: future grant (COMPUTE is a managed access schema).
-- Tables are NOT covered on purpose: COMPUTE.CUSTOMER holds PII and is granted
-- by dbt only after the masking policies are attached.
grant select on future views in schema {{ raw_compute_db }}.COMPUTE to database role {{ raw_compute_db }}.COMPUTE_READER;

-- ORCHESTRATION: granting OPERATE on the dbt task needs EXECUTE TASK on the
-- account for the owner role (platform_setup/01). Once granted, add:
-- grant operate, monitor on task {{ raw_compute_db }}.COMPUTE.RUN_DBT_BUILD to database role {{ raw_compute_db }}.COMPUTE_ENGINEER;

{% endif %}
