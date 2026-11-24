{#- =============================================================================
    GOVERNANCE hooks. The POLICIES and DATABASE ROLES are defined by DCM
    (dcm_project/sources/definitions/security/). dbt only ATTACHES them to the
    objects it (re)creates, because a CREATE OR REPLACE drops attachments.
    Order in dbt_project.yml: policy first, then the grant.
============================================================================= -#}

{% macro env_cfg(key) -%}
    {{ return(var('environments')[target.name][key]) }}
{%- endmacro %}

{#- Row access policy from <this database>.GOVERNANCE<suffix> -#}
{% macro attach_row_access_policy(policy_name, column_name) -%}
    alter view {{ this }} add row access policy
        {{ this.database }}.GOVERNANCE{{ env_cfg('schema_suffix') }}.{{ policy_name }}
        on ({{ column_name }})
{%- endmacro %}

{#- SELECT to a DCM-managed database role of this database.
    Schema-level sandboxes (owns_databases = false) have no own roles: skipped. -#}
{% macro grant_select_to_database_role(role_name) -%}
    {%- if env_cfg('owns_databases') -%}
    grant select on view {{ this }} to database role {{ this.database }}.{{ role_name }}
    {%- else -%}
    select 'no grant in schema-level sandbox'
    {%- endif -%}
{%- endmacro %}
