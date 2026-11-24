-- =============================================================================
-- SECURITY / MASKING POLICIES - assignments (DCM-managed)
-- Policies are attached to the DCM-owned COMPUTE table; every dbt view built on it
-- (e.g. BUSINESS_DB.BUSINESS_READY.CUSTOMER_PROFILE) inherits the masking.
-- RAW is protected by grants only (RAW_READER), so that the dbt load
-- always reads real values.
-- =============================================================================

attach masking policy {{ raw_compute_db }}.GOVERNANCE{{ schema_suffix }}.MASK_EMAIL
    to table {{ raw_compute_db }}.COMPUTE{{ schema_suffix }}.CUSTOMER column EMAIL;

attach masking policy {{ raw_compute_db }}.GOVERNANCE{{ schema_suffix }}.MASK_PHONE
    to table {{ raw_compute_db }}.COMPUTE{{ schema_suffix }}.CUSTOMER column PHONE;
