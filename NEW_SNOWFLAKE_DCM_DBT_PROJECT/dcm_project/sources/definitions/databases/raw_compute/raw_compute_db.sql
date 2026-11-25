-- =============================================================================
-- Logical database: RAW_COMPUTE_DB   (physical name: {{ raw_compute_db }})
-- Holds the RAW layer (data as received) and the COMPUTE layer (cleansing).
-- DCM creates the containers and the RAW landing table; dbt builds every
-- view and table on top of it (RAW.V_CUSTOMER_SRC_LATEST, all of COMPUTE).
-- GOVERNANCE holds the masking policies that protect this database.
-- =============================================================================
{% if owns_databases %}
define database {{ raw_compute_db }}
    data_retention_time_in_days = {{ data_retention_days }}
    comment = 'RAW + COMPUTE layers. Managed by DCM - do not change manually.';
{% endif %}

define schema {{ raw_compute_db }}.RAW{{ schema_suffix }}
    comment = 'RAW layer: source data as received';

-- MANAGED ACCESS: lets the schema owner keep FUTURE GRANTS, so every view dbt
-- (re)creates here is granted automatically (security/grants/).
define schema {{ raw_compute_db }}.COMPUTE{{ schema_suffix }}
    with managed access
    comment = 'COMPUTE layer: cleansing and transformation (objects built by dbt)';

define schema {{ raw_compute_db }}.GOVERNANCE{{ schema_suffix }}
    comment = 'Masking policies for RAW_COMPUTE_DB';
