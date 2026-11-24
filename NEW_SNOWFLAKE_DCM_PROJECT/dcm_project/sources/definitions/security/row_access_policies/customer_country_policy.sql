-- =============================================================================
-- SECURITY / ROW ACCESS POLICIES - definition (DCM-managed)
-- Sessions holding database role ALL_COUNTRIES_READER see every customer;
-- everybody else sees home-market (US) customers only.
-- =============================================================================

define row access policy {{ business_db }}.GOVERNANCE{{ schema_suffix }}.CUSTOMER_COUNTRY_RAP
    as (country varchar) returns boolean ->
        is_database_role_in_session('ALL_COUNTRIES_READER')   -- resolved in this database
        or country = 'US'
    comment = 'All countries for ALL_COUNTRIES_READER, US only for everybody else';
