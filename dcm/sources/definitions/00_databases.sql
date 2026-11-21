-- Databases and schemas for the three-layer architecture.
-- {{ analytics_db }} / {{ business_db }} come from the templating configuration
-- of the target (see manifest.yml), so the same file serves every environment.

define database {{ analytics_db }}
    comment = 'DCM_DEMO: shared analytics database (RAW + COMPUTE)';

define schema {{ analytics_db }}.RAW
    comment = 'DCM_DEMO: source data';

define schema {{ analytics_db }}.COMPUTE
    comment = 'DCM_DEMO: transformation logic';

define database {{ business_db }}
    comment = 'DCM_DEMO: shared business database';

define schema {{ business_db }}.BUSINESS_READY
    comment = 'DCM_DEMO: views consumed by business users';
