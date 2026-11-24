-- =============================================================================
-- SECURITY / GRANTS - table and view permissions (DCM-managed)
-- =============================================================================
{% if owns_databases %}

-- RAW layer: read-only
grant select on table {{ raw_compute_db }}.RAW.CUSTOMER_SRC          to database role {{ raw_compute_db }}.RAW_READER;
grant select on view  {{ raw_compute_db }}.RAW.V_CUSTOMER_SRC_LATEST to database role {{ raw_compute_db }}.RAW_READER;

-- COMPUTE layer: read
grant select on table {{ raw_compute_db }}.COMPUTE.CUSTOMER                 to database role {{ raw_compute_db }}.COMPUTE_READER;
-- views built by dbt: future grant (COMPUTE is a managed access schema)
grant select on future views in schema {{ raw_compute_db }}.COMPUTE          to database role {{ raw_compute_db }}.COMPUTE_READER;

-- COMPUTE layer: engineering (write)
grant insert, update, delete, truncate on table {{ raw_compute_db }}.COMPUTE.CUSTOMER to database role {{ raw_compute_db }}.COMPUTE_ENGINEER;

-- BUSINESS_READY: SELECT on the dbt-built views is granted by dbt right AFTER
-- the row access policy is attached (dbt_project/macros/governance/), so a
-- view is never readable without its policy. No future grant here on purpose.

{% endif %}
