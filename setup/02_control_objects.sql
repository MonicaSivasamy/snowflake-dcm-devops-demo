-- =============================================================================
-- Control plane for the demo (run as DCM_DEMO_ADMIN). Idempotent.
--   DCM_DEMO_CTRL_DB.PROJECTS  - DCM project objects (one per deployment target)
--   DCM_DEMO_CTRL_DB.GIT       - API integration + Git repository clone of GitHub
--   DCM_DEMO_CTRL_DB.AUDIT     - execution log written by the CLI runner and the app
--   DCM_DEMO_CTRL_DB.QA        - independent business-rule validation
--   DCM_DEMO_CTRL_DB.APP       - Streamlit in Snowflake application
-- =============================================================================
USE ROLE DCM_DEMO_ADMIN;
USE WAREHOUSE DCM_DEMO_WH;

CREATE DATABASE IF NOT EXISTS DCM_DEMO_CTRL_DB COMMENT = 'DCM_DEMO: control plane (projects, git, audit, QA, app)';
CREATE SCHEMA IF NOT EXISTS DCM_DEMO_CTRL_DB.PROJECTS COMMENT = 'DCM_DEMO';
CREATE SCHEMA IF NOT EXISTS DCM_DEMO_CTRL_DB.GIT      COMMENT = 'DCM_DEMO';
CREATE SCHEMA IF NOT EXISTS DCM_DEMO_CTRL_DB.AUDIT    COMMENT = 'DCM_DEMO';
CREATE SCHEMA IF NOT EXISTS DCM_DEMO_CTRL_DB.QA       COMMENT = 'DCM_DEMO';
CREATE SCHEMA IF NOT EXISTS DCM_DEMO_CTRL_DB.APP      COMMENT = 'DCM_DEMO';

CREATE TABLE IF NOT EXISTS DCM_DEMO_CTRL_DB.AUDIT.EXECUTION_LOG (
    EVENT_ID     NUMBER AUTOINCREMENT,
    EVENT_TS     TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    SOURCE       VARCHAR(30),      -- 'snow CLI', 'git CLI', 'streamlit'
    ACTOR        VARCHAR(50),      -- Developer A / Developer B / Release manager
    SCENARIO     VARCHAR(50),
    OPERATION    VARCHAR(50),      -- PLAN / DEPLOY / VALIDATE / GIT COMMIT ...
    TARGET       VARCHAR(100),
    GIT_BRANCH   VARCHAR(100),
    GIT_COMMIT   VARCHAR(64),
    STATUS       VARCHAR(20),      -- SUCCESS / FAILED
    COMMAND_TEXT VARCHAR,
    OUTPUT       VARIANT,
    ERROR_TEXT   VARCHAR,
    QUERY_ID     VARCHAR(100)
) COMMENT = 'DCM_DEMO: every PLAN/DEPLOY/validation/git step of the demo';

-- File format used to read whole SQL files out of the Git repository stage.
CREATE FILE FORMAT IF NOT EXISTS DCM_DEMO_CTRL_DB.GIT.WHOLE_FILE
  TYPE = CSV FIELD_DELIMITER = NONE RECORD_DELIMITER = NONE ESCAPE_UNENCLOSED_FIELD = NONE
  COMMENT = 'DCM_DEMO: read a text file as a single value';

-- Git integration (public repository - no secret needed)
CREATE API INTEGRATION IF NOT EXISTS DCM_DEMO_GIT_API
  API_PROVIDER = GIT_HTTPS_API
  API_ALLOWED_PREFIXES = ('https://github.com/MonicaSivasamy/')
  ENABLED = TRUE
  COMMENT = 'DCM_DEMO: read-only access to the demo GitHub repository';

CREATE GIT REPOSITORY IF NOT EXISTS DCM_DEMO_CTRL_DB.GIT.DCM_DEMO_REPO
  API_INTEGRATION = DCM_DEMO_GIT_API
  ORIGIN = 'https://github.com/MonicaSivasamy/snowflake-dcm-devops-demo.git'
  COMMENT = 'DCM_DEMO: Snowflake clone of the GitHub repo';
