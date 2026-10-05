{#- Unpartitioned table: dbt_dev's 60-day partition expiration deletes any
    2020-21 event_date partition on write. Restore incremental insert_overwrite,
    partitioned by event_date, once the project has billing (see decision log). -#}
{{
    config(
        materialized='table'
    )
}}

/*
  Date: 2026-09-29

  grain: one row per event; no surrogate key - device_id, session_id,
  time_stamp and event_name together are unique across all 4,295,584 events
  table, rebuilt in full each run: the vars ga4_start_date and ga4_end_date set
  which daily shards are read, and so the whole date range the table holds.
  Overriding them on the CLI replaces the table with just that window.
  params: event_params are read with scalar subqueries (ga4_event_param), never
  a FROM-clause unnest - that returns one row per param, not per event
  ecommerce: struct flattened to columns; items stays an array, unnested downstream
  dropped: columns empty on every row, constants and export artefacts, plus
  populated fields out of scope for this model (see docs/decision_logs.md)
  renamed: nested fields flattened to snake_case
  strings go through ga4_clean_string: lower-cased, '(not set)' /
  '(data deleted)' become NULL, '(none)' becomes 'direct', '(direct)' /
  '<other>' lose their brackets
*/

with source as (

    select * from {{ source('ga4', 'events') }}
    where _table_suffix between '{{ var("ga4_start_date") }}' and '{{ var("ga4_end_date") }}'

),
renamed as (
    {%- set fields = [
        {'name':'page_title','value':'string'},
        {'name':'page_location','value':'string'}
    ]
    -%}
    {% set cols = [
        {'name':'device','col_name':'device.category'},
        {'name':'brand','col_name':'device.mobile_brand_name'},
        {'name':'continent','col_name':'geo.continent'},
        {'name':'sub_continent','col_name':'geo.sub_continent'},
        {'name':'country','col_name':'geo.country'},
        {'name':'region','col_name':'geo.region'},
        {'name':'city','col_name':'geo.city'},
        {'name':'medium','col_name':'traffic_source.medium'},
        {'name':'traffic_source','col_name':'traffic_source.source'},
        {'name':'source_name','col_name':'traffic_source.name'},
        {'name':'transaction_id','col_name':'ecommerce.transaction_id'},
    ]%}

    select
        parse_date('%Y%m%d', event_date) as event_date,
        timestamp_micros(event_timestamp) as time_stamp,
        lower(event_name) as event_name,
        lower(user_pseudo_id) as device_id,
        {% for item in fields %}
            {{ ga4_clean_string(ga4_event_param(item.name, item.value)) }} as {{ item.name }}{% if not loop.last %},{% endif %}
        {% endfor %},
        cast({{ ga4_event_param('ga_session_id', 'int') }} as string) as session_id,
        timestamp_micros(user_first_touch_timestamp) as first_touch,
        {% for col in cols %}
                    {{ ga4_clean_string(col.col_name) }} as {{ col.name }}{% if not loop.last %},{% endif %}
        {% endfor %},
        ecommerce.purchase_revenue as purchase_revenue,
        ecommerce.purchase_revenue_in_usd as purchase_revenue_in_usd,
        ecommerce.tax_value as tax_value,
        ecommerce.tax_value_in_usd as tax_value_in_usd,
        ecommerce.total_item_quantity as total_item_quantity,
        ecommerce.unique_items as unique_items,
        items

    from source

)

select * from renamed
