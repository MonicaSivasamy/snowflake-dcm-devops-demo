-- =============================================================================
-- SECURITY / ROW ACCESS POLICIES - assignment (DCM-managed)
-- =============================================================================

attach row access policy {{ business_db }}.GOVERNANCE{{ schema_suffix }}.CUSTOMER_COUNTRY_RAP
    to view {{ business_db }}.BUSINESS_READY{{ schema_suffix }}.CUSTOMER_PROFILE on (COUNTRY);
