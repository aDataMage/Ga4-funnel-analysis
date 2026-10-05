/*
  Date: 2026-09-30

  grain: one row per session (session_key), from int_events__sessionised
  funnel: one integer flag per GA4 ecommerce step - 1 if the session contains
  that event at all, in any order, else 0. SUM counts sessions reaching the
  step, AVG is the rate. Steps aren't forced into sequence: GA4 doesn't
  guarantee every step fires, so a session can reach purchase without add_to_cart
  attribution: first touch - the channel that first acquired the device
  (GA4's traffic_source fields), taken from the session's first event
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

sessions as (

    select
        session_key,
        device_id,
        session_num,
        min(time_stamp) as session_start,
        max(time_stamp) as session_end,
        count(*) as event_count,

        array_agg(
            struct(first_touch, medium, traffic_source, source_name)
            order by time_stamp, session_id, event_name
            limit 1
        )[offset(0)] as first_event,

        {% for step in funnel_steps -%}
        max(if(event_name = '{{ step }}', 1, 0)) as reached_{{ step }}{{ ',' if not loop.last }}
        {% endfor %}

    from events
    group by session_key, device_id, session_num

)

select
    session_key,
    device_id,
    session_num,
    session_start,
    session_end,
    event_count,
    first_event.first_touch as first_touch,
    first_event.medium as first_touch_medium,
    first_event.traffic_source as first_touch_source,
    first_event.source_name as first_touch_source_name,
    {% for step in funnel_steps -%}
    reached_{{ step }}{{ ',' if not loop.last }}
    {% endfor %}

from sessions
