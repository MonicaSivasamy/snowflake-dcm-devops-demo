{#- Logical database (RAW_COMPUTE_DB / BUSINESS_DB) -> physical name of the
    current target, from vars.environments in dbt_project.yml. -#}
{% macro generate_database_name(custom_database_name=none, node=none) -%}
    {%- set env = var('environments')[target.name] -%}
    {%- set logical = (custom_database_name or 'RAW_COMPUTE_DB') | upper -%}
    {%- if logical == 'RAW_COMPUTE_DB' -%}   {{ env['raw_compute_db'] }}
    {%- elif logical == 'BUSINESS_DB' -%}    {{ env['business_db'] }}
    {%- else -%} {{ exceptions.raise_compiler_error('Unknown logical database: ' ~ logical) }}
    {%- endif -%}
{%- endmacro %}
