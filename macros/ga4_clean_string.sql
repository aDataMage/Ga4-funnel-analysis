{/*
  Clean a GA4 string dimension: lower-case it, turn the export's "no value"
  placeholders into NULL, and unwrap bracketed labels.

    '(not set)', '(none)', '(data deleted)'  -> NULL
    '(direct)' -> 'direct', '<Other>' -> 'other', '(organic)' -> 'organic', ...

  Only a value wrapped end to end in () or <> is unwrapped; brackets inside a
  value are left alone.

  Usage: {{ ga4_clean_string('geo.city') }} as city
*/}

{% macro ga4_clean_string(column) -%}
    case
        when lower({{ column }}) in ('(not set)', '(data deleted)') then null
        when lower({{ column }}) =  '(none)' then 'direct'
        else regexp_replace(lower({{ column }}), r'^[(<](.*)[)>]$', r'\1')
    end
{%- endmacro %}
