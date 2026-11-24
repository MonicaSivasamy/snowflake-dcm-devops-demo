-- COMPUTE: rebuilds COMPUTE.CUSTOMER from the cleansing view.
-- Run after new RAW data arrives:  call <RAW_COMPUTE_DB>.COMPUTE.SP_LOAD_CUSTOMER();
-- DCM deploys the procedure CODE; calling it is an operational step.

define procedure {{ raw_compute_db }}.COMPUTE{{ schema_suffix }}.SP_LOAD_CUSTOMER()
    returns varchar
    language sql
    comment = 'COMPUTE: full reload of COMPUTE.CUSTOMER from V_CUSTOMER_CLEANSED'
as
$$
begin
    insert overwrite into {{ raw_compute_db }}.COMPUTE{{ schema_suffix }}.CUSTOMER
        (CUSTOMER_ID, FIRST_NAME, LAST_NAME, EMAIL, PHONE, COUNTRY, SIGNUP_DATE, PROCESSED_AT)
    select CUSTOMER_ID, FIRST_NAME, LAST_NAME, EMAIL, PHONE, COUNTRY, SIGNUP_DATE,
           current_timestamp()::timestamp_ntz
    from {{ raw_compute_db }}.COMPUTE{{ schema_suffix }}.V_CUSTOMER_CLEANSED;
    return 'COMPUTE.CUSTOMER loaded: ' || sqlrowcount || ' rows';
end;
$$;
