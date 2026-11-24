-- =============================================================================
-- REFRESH PROCEDURE - install once                              (NOT DCM-managed)
-- ENT_DCMDBT_CTRL_DB.OPS.SP_REFRESH_DATABASE(source_env, target_env, scope, take_backup)
--
--   source_env   DCMDBT_PROD | DCMDBT_QA | DCMDBT_DEV
--   target_env   DCMDBT_QA | DCMDBT_DEV | SBX_DCMDBT_DEV_A ... (any *PROD is refused)
--   scope        'ALL' | 'RAW_COMPUTE_DB' | 'BUSINESS_DB'
--   take_backup  TRUE -> zero-copy backup <target>_BKP_<timestamp> first
--
-- Lives in the control plane, NOT in the DCM project: cloning is an operation
-- on DATA, scheduled by operations, never part of PLAN / DEPLOY.
-- It does not deploy code. After it, run DCM DEPLOY + dbt build for the target
-- (database_cloning/post_refresh/after_refresh.sql).
-- =============================================================================
use role DCM_DEMO_ADMIN;
use warehouse DCM_DEMO_WH;

create or replace procedure ENT_DCMDBT_CTRL_DB.OPS.SP_REFRESH_DATABASE(
    SOURCE_ENV varchar, TARGET_ENV varchar, SCOPE varchar, TAKE_BACKUP boolean)
returns varchar
language sql
comment = 'Clone <SOURCE_ENV>_<DB> over <TARGET_ENV>_<DB>. Never targets PROD. Data only - run DCM DEPLOY + dbt build afterwards.'
execute as caller
as
$$
declare
    dbs    array;
    src    varchar;
    tgt    varchar;
    bkp    varchar;
    msg    varchar default '';
    ts     varchar default to_char(current_timestamp(), 'YYYYMMDD_HH24MISS');
begin
    if (upper(:TARGET_ENV) like '%PROD%') then
        return 'REFUSED: PROD is never a refresh target';
    end if;
    if (upper(:SOURCE_ENV) = upper(:TARGET_ENV)) then
        return 'REFUSED: source and target are the same';
    end if;

    dbs := case upper(:SCOPE)
               when 'ALL'            then array_construct('RAW_COMPUTE_DB', 'BUSINESS_DB')
               when 'RAW_COMPUTE_DB' then array_construct('RAW_COMPUTE_DB')
               when 'BUSINESS_DB'    then array_construct('BUSINESS_DB')
           end;
    if (dbs is null) then
        return 'REFUSED: scope must be ALL, RAW_COMPUTE_DB or BUSINESS_DB';
    end if;

    for i in 0 to array_size(:dbs) - 1 do
        src := upper(:SOURCE_ENV) || '_' || dbs[i]::varchar;
        tgt := upper(:TARGET_ENV) || '_' || dbs[i]::varchar;

        if (:TAKE_BACKUP) then
            bkp := tgt || '_BKP_' || ts;
            begin
                execute immediate 'create database ' || bkp || ' clone ' || tgt;
                msg := msg || 'backup ' || bkp || '; ';
            exception
                when other then msg := msg || 'no backup (' || tgt || ' did not exist); ';
            end;
        end if;

        execute immediate 'create or replace database ' || tgt || ' clone ' || src;
        msg := msg || 'cloned ' || src || ' -> ' || tgt || '; ';
    end for;

    return msg || 'NEXT: run DCM DEPLOY + dbt build for target ' || upper(:TARGET_ENV)
               || ', then platform_setup/04_account_roles.sql';
end;
$$;
