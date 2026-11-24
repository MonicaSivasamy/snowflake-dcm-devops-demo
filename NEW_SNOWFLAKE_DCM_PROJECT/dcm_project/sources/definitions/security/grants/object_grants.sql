-- =============================================================================
-- SECURITY / GRANTS - table, view and procedure permissions (DCM-managed)
-- =============================================================================
{% if owns_databases %}

-- RAW layer: read-only
grant select on table {{ raw_compute_db }}.RAW.CUSTOMER_SRC          to database role {{ raw_compute_db }}.RAW_READER;
grant select on view  {{ raw_compute_db }}.RAW.V_CUSTOMER_SRC_LATEST to database role {{ raw_compute_db }}.RAW_READER;

-- COMPUTE layer: read
grant select on table {{ raw_compute_db }}.COMPUTE.CUSTOMER            to database role {{ raw_compute_db }}.COMPUTE_READER;
grant select on view  {{ raw_compute_db }}.COMPUTE.V_CUSTOMER_CLEANSED to database role {{ raw_compute_db }}.COMPUTE_READER;

-- COMPUTE layer: engineering (write + run the load)
grant insert, update, delete, truncate on table {{ raw_compute_db }}.COMPUTE.CUSTOMER to database role {{ raw_compute_db }}.COMPUTE_ENGINEER;
grant usage on procedure {{ raw_compute_db }}.COMPUTE.SP_LOAD_CUSTOMER()              to database role {{ raw_compute_db }}.COMPUTE_ENGINEER;

-- BUSINESS_READY: read
grant select on view {{ business_db }}.BUSINESS_READY.CUSTOMER_PROFILE to database role {{ business_db }}.BUSINESS_READER;

{% endif %}
