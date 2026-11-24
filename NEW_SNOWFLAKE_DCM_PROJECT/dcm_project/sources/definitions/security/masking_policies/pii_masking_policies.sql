-- =============================================================================
-- SECURITY / MASKING POLICIES - definitions (DCM-managed)
-- Unmasked only for sessions holding database role
-- {{ raw_compute_db }}.PII_READER (granted to <ENV>_ENT_PII_ANALYST).
-- Where they are applied: pii_masking_assignments.sql
-- =============================================================================

define masking policy {{ raw_compute_db }}.GOVERNANCE{{ schema_suffix }}.MASK_EMAIL
    as (val varchar) returns varchar ->
    case
        when is_database_role_in_session('{{ raw_compute_db }}.PII_READER') then val
        when val is null then null
        else regexp_replace(val, '^[^@]+', '*****')          -- *****@domain.com
    end
    comment = 'Mask the local part of an e-mail address';

define masking policy {{ raw_compute_db }}.GOVERNANCE{{ schema_suffix }}.MASK_PHONE
    as (val varchar) returns varchar ->
    case
        when is_database_role_in_session('{{ raw_compute_db }}.PII_READER') then val
        when val is null then null
        else '*******' || right(val, 4)                        -- *******1234
    end
    comment = 'Show only the last 4 digits of a phone number';
