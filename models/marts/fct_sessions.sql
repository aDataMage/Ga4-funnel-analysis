/*
  Date: 2026-09-30

  grain: one row per session (30-minute inactivity sessions from
  int_events__sessionised); session_id is that model's session_key
  ga_session_id: GA4's own session id on the session's first event.
  4,697 of 355,592 sessions contain more than one GA4 id - ga_session_count
  keeps that visible
  session_date: event_date of the first event (property time zone), so it
  joins dim_date the same way fct_events does
  traffic_source_key: the source / medium / campaign on the session's first
  event, keyed to dim_traffic_source (same hash as fct_events)
  funnel: the reached_* flags from int_sessions__funnel_steps - 1 if the
  session contains the step's event at all (not in sequence)
*/

{%- set funnel_steps = [
    'session_start',
    'view_item',
    'add_to_cart',
    'begin_checkout',
    'add_shipping_info',
    'add_payment_info',
    'purchase'
] %}

with events as (

    select * from {{ ref('int_events__sessionised') }}

),

funnel as (

    select * from {{ ref('int_sessions__funnel_steps') }}

),

sessions as (

    select
        session_key,
        array_agg(session_id order by time_stamp, session_id, event_name limit 1)[offset(0)] as ga_session_id,
        count(distinct session_id) as ga_session_count,
        array_agg(event_date order by time_stamp, session_id, event_name limit 1)[offset(0)] as session_date,
        array_agg(
            struct(medium, traffic_source, source_name)
            order by time_stamp, session_id, event_name
            limit 1
        )[offset(0)] as first_traffic,
        min(time_stamp) as session_start,
        max(time_stamp) as session_end,
        count(*) as event_count,
        device_id

    from events
    group by session_key, device_id

)

select
    sessions.session_key as session_id,
    sessions.ga_session_id,
    sessions.ga_session_count,
    sessions.session_date,
    sessions.session_start,
    sessions.session_end,
    sessions.event_count,
    sessions.device_id,
    {{ dbt_utils.generate_surrogate_key(['sessions.first_traffic.medium', 'sessions.first_traffic.traffic_source', 'sessions.first_traffic.source_name']) }} as traffic_source_key,
    {% for step in funnel_steps -%}
    funnel.reached_{{ step }}{{ ',' if not loop.last }}
    {% endfor %}

from sessions
inner join funnel
    on sessions.session_key = funnel.session_key
