-- =============================================================================
-- SECURITY / ROLE HIERARCHY - inside each database (DCM-managed)
--
--   RAW_COMPUTE_DB:  COMPUTE_ENGINEER --> COMPUTE_READER
--                                     --> RAW_READER
--   BUSINESS_DB:     ALL_COUNTRIES_READER --> BUSINESS_READER
--
-- Account-role hierarchy (ANALYST -> SYSADMIN, ...) and the link
-- "database role -> account role" are in platform_setup/03_account_roles.sql.
-- =============================================================================
{% if owns_databases %}

grant database role {{ raw_compute_db }}.RAW_READER     to database role {{ raw_compute_db }}.COMPUTE_ENGINEER;
grant database role {{ raw_compute_db }}.COMPUTE_READER to database role {{ raw_compute_db }}.COMPUTE_ENGINEER;

grant database role {{ business_db }}.BUSINESS_READER   to database role {{ business_db }}.ALL_COUNTRIES_READER;

{% endif %}
