{/*
  Pull one value out of GA4's event_params array by key.

  value_type picks the field of the value struct GA4 stores it in:
  'string', 'int', 'float' or 'double'. Returns NULL when the event has no
  such key, or when the key's value sits in a different field.

  Keys are unique within an event in this dataset (checked 2026-09-29), so the
  scalar subquery never returns more than one row.

  Usage: {{ ga4_event_param('ga_session_id', 'int') }} as session_id
*/}

{% macro ga4_event_param(key, value_type='string') -%}
    {%- set fields = {
        'string': 'string_value',
        'int': 'int_value',
        'float': 'float_value',
        'double': 'double_value'
    } -%}
    {%- if value_type not in fields -%}
        {{ exceptions.raise_compiler_error(
            "ga4_event_param: value_type must be one of string, int, float, double - got '" ~ value_type ~ "'"
        ) }}
    {%- endif -%}
    (select value.{{ fields[value_type] }} from unnest(event_params) where key = '{{ key }}')
{%- endmacro %}
