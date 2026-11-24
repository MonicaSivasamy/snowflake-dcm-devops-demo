{#- Schema = the folder's schema (COMPUTE / BUSINESS_READY) + the target's
    schema_suffix ('' or '_DEV_B'). Replaces dbt's default <target>_<schema>. -#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set base = custom_schema_name if custom_schema_name else target.schema -%}
    {{ (base ~ var('environments')[target.name]['schema_suffix']) | upper }}
{%- endmacro %}
