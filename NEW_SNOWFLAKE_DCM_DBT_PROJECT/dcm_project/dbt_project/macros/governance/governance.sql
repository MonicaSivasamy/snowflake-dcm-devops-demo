{#- =============================================================================
    GOVERNANCE hooks. The POLICIES and DATABASE ROLES are defined by DCM
    (dcm_project/sources/definitions/security/) - versioned and planned there.
    dbt ATTACHES them to the objects it builds, because every rebuild
    (CREATE OR REPLACE) creates a new object without policies or grants.
    Rule: attach policies FIRST, grant SELECT LAST - so an object is never
    readable by anyone but its owner without its policies.
============================================================================= -#}

{% macro env_cfg(key) -%}
    {{ return(var('environments')[target.name][key]) }}
{%- endmacro %}

{#- schema holding the DCM-defined policies of this database -#}
{% macro governance_schema() -%}
    {{ this.database }}.GOVERNANCE{{ env_cfg('schema_suffix') }}
{%- endmacro %}

{#- Masking policy on one column of the table this model builds -#}
{% macro attach_masking_policy(column_name, policy_name) -%}
    alter table {{ this }} modify column {{ column_name }}
        set masking policy {{ governance_schema() }}.{{ policy_name }}
{%- endmacro %}

{#- Row access policy on the view this model builds -#}
{% macro attach_row_access_policy(policy_name, column_name) -%}
    alter view {{ this }} add row access policy
        {{ governance_schema() }}.{{ policy_name }} on ({{ column_name }})
{%- endmacro %}

{#- SELECT to a DCM-managed database role of this database (table or view).
    Schema-level sandboxes (owns_databases = false) have no own roles: skipped. -#}
{% macro grant_select_to_database_role(role_name) -%}
    {%- set object_type = 'view' if config.get('materialized') == 'view' else 'table' -%}
    {%- if env_cfg('owns_databases') -%}
    grant select on {{ object_type }} {{ this }} to database role {{ this.database }}.{{ role_name }}
    {%- else -%}
    select 'no grant in schema-level sandbox'
    {%- endif -%}
{%- endmacro %}
