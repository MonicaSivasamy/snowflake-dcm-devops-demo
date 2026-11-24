-- =============================================================================
-- SECURITY / ROW ACCESS POLICIES - definition (DCM-managed)
-- Sessions holding {{ business_db }}.ALL_COUNTRIES_READER see every customer;
-- everybody else sees home-market (US) customers only.
-- =============================================================================

define row access policy {{ business_db }}.GOVERNANCE{{ schema_suffix }}.CUSTOMER_COUNTRY_RAP
    as (country varchar) returns boolean ->
        is_database_role_in_session('{{ business_db }}.ALL_COUNTRIES_READER')
        or country = 'US'
    comment = 'All countries for ALL_COUNTRIES_READER, US only for everybody else';
