-- =============================================================================
-- Logical database: BUSINESS_DB   (physical name: {{ business_db }})
-- Business-ready views for analysts and reporting tools (views built by dbt).
-- GOVERNANCE holds the row access policies that protect this database.
-- =============================================================================
{% if owns_databases %}
define database {{ business_db }}
    data_retention_time_in_days = {{ data_retention_days }}
    comment = 'Business-ready layer. Managed by DCM - do not change manually.';
{% endif %}

define schema {{ business_db }}.BUSINESS_READY{{ schema_suffix }}
    comment = 'Business-ready views (built by dbt)';

define schema {{ business_db }}.GOVERNANCE{{ schema_suffix }}
    comment = 'Row access policies for BUSINESS_DB';
