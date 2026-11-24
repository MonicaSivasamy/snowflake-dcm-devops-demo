-- =============================================================================
-- SECURITY / ROLES - database roles (DCM-managed)
-- Database roles live INSIDE a database, so they are cloned, versioned and
-- deployed together with it. Account roles (people-facing roles such as
-- <ENV>_ENT_ANALYST) are created by the security team outside DCM:
--   platform_setup/03_account_roles.sql
-- Schema-level sandboxes (owns_databases = false) reuse the roles of the
-- database owner and skip this file.
-- =============================================================================
{% if owns_databases %}

-- RAW_COMPUTE_DB --------------------------------------------------------------
define database role {{ raw_compute_db }}.RAW_READER
    comment = 'Read the RAW layer';
define database role {{ raw_compute_db }}.COMPUTE_READER
    comment = 'Read the COMPUTE layer (PII masked)';
define database role {{ raw_compute_db }}.COMPUTE_ENGINEER
    comment = 'Run COMPUTE loads, write COMPUTE tables';
define database role {{ raw_compute_db }}.PII_READER
    comment = 'Marker role: sees unmasked EMAIL / PHONE (checked by masking policies)';

-- BUSINESS_DB -----------------------------------------------------------------
define database role {{ business_db }}.BUSINESS_READER
    comment = 'Read BUSINESS_READY views';
define database role {{ business_db }}.ALL_COUNTRIES_READER
    comment = 'Marker role: sees customers of all countries (checked by row access policy)';

{% endif %}
