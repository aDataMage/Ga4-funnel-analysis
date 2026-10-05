/*
  Date: 2026-09-30

  grain: one row per event (as stg_ga4__events), with its session attached
  sessions: a device's events split wherever more than 30 minutes (1,800
  seconds) pass between consecutive events; session_num counts a device's
  sessions from 1 in time order
  session_key: surrogate key on device_id + session_num
  order: events with the same timestamp are ordered by session_id then
  event_name, so session numbering is the same on every run
  GA4's own session_id is kept alongside but not used for sessionising
*/

with events as (

    select * from {{ ref('stg_ga4__events') }}

),

gaps as (

    select
        *,
        timestamp_diff(
            time_stamp,
            lag(time_stamp) over (partition by device_id order by time_stamp, session_id, event_name),
            second
        ) as secs_since_prev

    from events

),

flagged as (

    select
        *,
        if(secs_since_prev is null or secs_since_prev > 1800, 1, 0) as is_new_session

    from gaps

),

sessions as (

    select
        *,
        sum(is_new_session) over (
            partition by device_id
            order by time_stamp, session_id, event_name
            rows between unbounded preceding and current row
        ) as session_num

    from flagged

)

select
    {{ dbt_utils.generate_surrogate_key(['device_id', 'session_num']) }} as session_key,
    * except (secs_since_prev),
    div(secs_since_prev, 60) as mins_since_prev

from sessions
