/*
  Date: 2026-09-30

  grain: one row per item per event (the GA4 items array, unnested)
  event_id matches fct_events.event_id: the same hash over device_id, GA4
  session id, time_stamp and event_name
  item_index: the item's position in the event's array (0-based), which makes
  the row unique within the event
  cleaned: strings go through ga4_clean_string, and '' / 'not available in demo
  dataset' become NULL too - the export's other placeholders for "no value"
  dropped: item_category2-5, coupon, affiliation, location_id, promotion_id,
  creative_slot ('(not set)' on every row); item_refund(_in_usd) (empty);
  item_list_name ('(not set)' or 'not available in demo dataset' on every row)
*/

with events as (

    select * from {{ ref('stg_ga4__events') }}
    where array_length(items) > 0

),

unnested as (

    select
        {{ dbt_utils.generate_surrogate_key(['device_id', 'session_id', 'time_stamp', 'event_name']) }} as event_id,
        event_date,
        event_name,
        item_index,
        item

    from events,
        unnest(items) as item with offset as item_index

)

{%- set item_strings = [
    'item_id', 'item_name', 'item_brand', 'item_variant', 'item_category',
    'item_list_id', 'item_list_index', 'promotion_name', 'creative_name'
] %}

select
    {{ dbt_utils.generate_surrogate_key(['event_id', 'item_index']) }} as event_item_id,
    event_id,
    event_date,
    event_name,
    item_index,
    {% for col in item_strings -%}
    nullif(nullif({{ ga4_clean_string('item.' ~ col) }}, ''), 'not available in demo dataset') as {{ col }},
    {% endfor -%}
    item.price as price,
    item.price_in_usd as price_in_usd,
    item.quantity as quantity,
    item.item_revenue as item_revenue,
    item.item_revenue_in_usd as item_revenue_in_usd

from unnested
