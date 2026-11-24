-- =============================================================================
-- SECURITY / GRANTS - database and schema level (DCM-managed)
-- DCM keeps these grants in sync: a grant removed from this file is revoked
-- on the next DEPLOY.
-- =============================================================================
{% if owns_databases %}

-- RAW_COMPUTE_DB
grant usage on database {{ raw_compute_db }}         to database role {{ raw_compute_db }}.RAW_READER;
grant usage on schema   {{ raw_compute_db }}.RAW     to database role {{ raw_compute_db }}.RAW_READER;

grant usage on database {{ raw_compute_db }}         to database role {{ raw_compute_db }}.COMPUTE_READER;
grant usage on schema   {{ raw_compute_db }}.COMPUTE to database role {{ raw_compute_db }}.COMPUTE_READER;

-- BUSINESS_DB
grant usage on database {{ business_db }}                to database role {{ business_db }}.BUSINESS_READER;
grant usage on schema   {{ business_db }}.BUSINESS_READY to database role {{ business_db }}.BUSINESS_READER;

{% endif %}
