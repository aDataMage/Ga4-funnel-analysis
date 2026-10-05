/*
  Date: 2026-09-30

  grain: one row per source / medium / campaign combination seen in the events
  traffic_source_key hashes the three columns; NULLs hash to a fixed token, so
  combinations with NULL parts (direct traffic, '(data deleted)') get a key too.
  The same hash is built in fct_events and int_devices__traffic_attribution.
*/

with events as (

    select * from {{ ref('stg_ga4__events') }}

),

combinations as (

    select distinct
        medium,
        traffic_source,
        source_name

    from events

)

select
    {{ dbt_utils.generate_surrogate_key(['medium', 'traffic_source', 'source_name']) }} as traffic_source_key,
    medium,
    traffic_source,
    source_name

from combinations
