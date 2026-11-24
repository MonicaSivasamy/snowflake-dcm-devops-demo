-- =============================================================================
-- PLATFORM SETUP 02 - control plane for the project   (NOT DCM- or dbt-managed)
-- The dedicated Snowflake "folder" for this project:
--   ENT_DBT_CTRL_DB.PROJECTS   DCM project objects (DCM_<ENV>) and
--                              dbt project objects (DBT_<ENV>)
--   ENT_DBT_CTRL_DB.GIT        Git repository object (Snowflake's copy of GitHub)
--   ENT_DBT_CTRL_DB.OPS        operational procedures (database refresh)
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

create database if not exists ENT_DBT_CTRL_DB
    comment = 'Enterprise dbt + DCM project: control plane (DCM + dbt project objects, Git repo, ops)';
create schema if not exists ENT_DBT_CTRL_DB.PROJECTS comment = 'DCM_<ENV> and DBT_<ENV> project objects';
create schema if not exists ENT_DBT_CTRL_DB.GIT      comment = 'Git repository objects';
create schema if not exists ENT_DBT_CTRL_DB.OPS      comment = 'Operational procedures (refresh / cloning)';
