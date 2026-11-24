-- =============================================================================
-- PLATFORM SETUP 02 - control plane for the project           (NOT DCM-managed)
-- The dedicated Snowflake "folder" for this project:
--   ENT_DCM_CTRL_DB.PROJECTS   DCM project objects (one per target in manifest.yml)
--   ENT_DCM_CTRL_DB.GIT        Git repository object (Snowflake's copy of GitHub)
--   ENT_DCM_CTRL_DB.OPS        operational procedures (database refresh)
-- The control plane holds no business data and is never cloned or refreshed.
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

create database if not exists ENT_DCM_CTRL_DB
    comment = 'Enterprise DCM project: control plane (DCM project objects, Git repo, ops procedures)';
create schema if not exists ENT_DCM_CTRL_DB.PROJECTS comment = 'DCM project objects - one per environment / developer sandbox';
create schema if not exists ENT_DCM_CTRL_DB.GIT      comment = 'Git repository objects';
create schema if not exists ENT_DCM_CTRL_DB.OPS      comment = 'Operational procedures (refresh / cloning) - separate from DCM deployments';
