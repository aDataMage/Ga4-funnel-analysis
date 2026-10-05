{#- Disabled with snap_device_traffic_attribution, the only model that reads it:
    the BigQuery sandbox blocks the snapshot's MERGE. Enable once billing is on. -#}
{{ config(enabled=false) }}

/*
  Date: 2026-09-30

  grain: one row per device
  The device's current traffic-source attribution - the source / medium /
  campaign on its latest event - keyed to dim_traffic_source by
  traffic_source_key. This is the state snap_device_traffic_attribution
  snapshots (check strategy) to build SCD Type 2 history.
  42,263 of 270,154 devices carry more than one combination across their
  events; only the latest is kept here - the snapshot records changes between
  runs, not within the sample (see decision log).
*/

with events as (

    select * from {{ ref('stg_ga4__events') }}

),

latest as (

    select
        device_id,
        array_agg(
            struct(medium, traffic_source, source_name, time_stamp)
            order by time_stamp desc, session_id desc, event_name desc
            limit 1
        )[offset(0)] as last_event

    from events
    group by device_id

)

select
    device_id,
    {{ dbt_utils.generate_surrogate_key(['last_event.medium', 'last_event.traffic_source', 'last_event.source_name']) }} as traffic_source_key,
    last_event.medium as medium,
    last_event.traffic_source as traffic_source,
    last_event.source_name as source_name,
    last_event.time_stamp as attributed_at

from latest
