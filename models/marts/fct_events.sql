/*
  Date: 2026-09-30

  grain: one row per event, keyed by event_id - hash of device_id, GA4 session
  id, time_stamp and event_name (unique together across all 4,295,584 events);
  fct_event_items builds the same hash to join back
  keys: session_id -> fct_sessions, device_id -> dim_devices,
  traffic_source_key -> dim_traffic_source, event_date -> dim_date
  GA4's own session id is renamed ga_session_id so session_id means the same
  thing here as in fct_sessions
  Device, location and traffic-source text live in the dims, not here. The
  items array is left out - BI tools can't read arrays; it is unnested in
  fct_event_items.
*/

with events as (

    select * from {{ ref('int_events__sessionised') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['device_id', 'session_id', 'time_stamp', 'event_name']) }} as event_id,
    session_key as session_id,
    session_id as ga_session_id,
    device_id,
    {{ dbt_utils.generate_surrogate_key(['medium', 'traffic_source', 'source_name']) }} as traffic_source_key,
    event_date,
    time_stamp,
    event_name,
    page_title,
    page_location,
    transaction_id,
    purchase_revenue,
    purchase_revenue_in_usd,
    tax_value,
    tax_value_in_usd,
    total_item_quantity,
    unique_items

from events
