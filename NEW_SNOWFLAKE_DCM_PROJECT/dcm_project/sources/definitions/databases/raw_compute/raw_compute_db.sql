-- =============================================================================
-- Logical database: RAW_COMPUTE_DB   (physical name: {{ raw_compute_db }})
-- Holds the RAW layer (data as received) and the COMPUTE layer (cleansing).
-- GOVERNANCE holds the masking policies that protect this database.
-- =============================================================================
{% if owns_databases %}
define database {{ raw_compute_db }}
    data_retention_time_in_days = {{ data_retention_days }}
    comment = 'RAW + COMPUTE layers. Managed by DCM - do not change manually.';
{% endif %}

define schema {{ raw_compute_db }}.RAW{{ schema_suffix }}
    comment = 'RAW layer: source data as received';

define schema {{ raw_compute_db }}.COMPUTE{{ schema_suffix }}
    comment = 'COMPUTE layer: cleansing and transformation';

define schema {{ raw_compute_db }}.GOVERNANCE{{ schema_suffix }}
    comment = 'Masking policies for RAW_COMPUTE_DB';
