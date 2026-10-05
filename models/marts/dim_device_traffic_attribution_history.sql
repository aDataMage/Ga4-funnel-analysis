/*
  Date: 2026-09-30

  grain: one row per device per attribution version, dated by event time
  (SCD Type 2 derived from the events - the snapshot's run-time versions are in
  dim_device_traffic_attribution)
  A version is a run of a device's consecutive events with the same
  source / medium / campaign; a change of combination opens a new one, so
  A -> B -> A is three versions.
  valid_from: the version's first event; valid_to: the next version's first
  event, NULL on the current one
  345,700 versions across 270,154 devices; 42,263 devices have more than one
*/

with events as (

    select
        device_id,
        time_stamp,
        session_id,
        event_name,
        medium,
        traffic_source,
        source_name,
        {{ dbt_utils.generate_surrogate_key(['medium', 'traffic_source', 'source_name']) }} as traffic_source_key

    from {{ ref('stg_ga4__events') }}

),

changes as (

    select
        *,
        if(
            traffic_source_key = lag(traffic_source_key) over (
                partition by device_id order by time_stamp, session_id, event_name
            ),
            0, 1
        ) as is_change

    from events

),

numbered as (

    select
        *,
        sum(is_change) over (
            partition by device_id
            order by time_stamp, session_id, event_name
            rows between unbounded preceding and current row
        ) as version_num

    from changes

),

versions as (

    select
        device_id,
        version_num,
        any_value(traffic_source_key) as traffic_source_key,
        any_value(medium) as medium,
        any_value(traffic_source) as traffic_source,
        any_value(source_name) as source_name,
        min(time_stamp) as valid_from

    from numbered
    group by device_id, version_num
    order by device_id

)

select
    {{ dbt_utils.generate_surrogate_key(['device_id', 'version_num']) }} as attribution_version_key,
    device_id,
    version_num,
    traffic_source_key,
    medium,
    traffic_source,
    source_name,
    valid_from,
    lead(valid_from) over (partition by device_id order by version_num) as valid_to,
    if(lead(valid_from) over (partition by device_id order by version_num) is null, 1, 0) as is_current

from versions
