/*
  Date: 2026-10-02

  grain: one row per segment x funnel step - the dashboard's funnel table
  (pages 1 and 2). segment_type is overall, device_category, continent or
  channel; steps run sessions -> view_item -> add_to_cart -> begin_checkout ->
  add_shipping_info -> add_payment_info -> purchase
  base: 30-minute sessions (fct_sessions); a session reaches a step if it
  contains the event at all (presence, not sequence)
  reach_rate: sessions reaching the step / all sessions in the segment
  step_conversion: of sessions that reached the previous step, the share that
  also reached this one - a true proportion even where steps are skipped
  skipped_prev_share: share of sessions reaching this step that never reached
  the previous one (46% at begin_checkout: the add_to_cart caveat)
  gap_vs_rest: the segment's reach rate minus the rest of sessions' - rest, not
  overall, so the two groups are independent for the Newcombe interval
  intervals: Wilson / Newcombe 95%, macros/confidence_intervals.sql
  thin cells: is_thin_segment (segment n < 100), is_thin_step (previous-step n < 100)
  channel: the session's first-event medium; 'direct' where source is direct,
  'unknown' where medium is NULL for any other reason ('(data deleted)')
*/

{%- set steps = [
    {'name': 'sessions', 'flag': '1', 'prev': '1'},
    {'name': 'view_item', 'flag': 'reached_view_item', 'prev': '1'},
    {'name': 'add_to_cart', 'flag': 'reached_add_to_cart', 'prev': 'reached_view_item'},
    {'name': 'begin_checkout', 'flag': 'reached_begin_checkout', 'prev': 'reached_add_to_cart'},
    {'name': 'add_shipping_info', 'flag': 'reached_add_shipping_info', 'prev': 'reached_begin_checkout'},
    {'name': 'add_payment_info', 'flag': 'reached_add_payment_info', 'prev': 'reached_add_shipping_info'},
    {'name': 'purchase', 'flag': 'reached_purchase', 'prev': 'reached_add_payment_info'}
] %}

{%- set segment_types = ['device_category', 'continent', 'channel'] %}

with sessions as (

    select
        fct_sessions.*,
        dim_devices.device as device_category,
        dim_devices.continent,
        case
            when dim_traffic_source.traffic_source = 'direct' then 'direct'
            when dim_traffic_source.medium is null then 'unknown'
            else dim_traffic_source.medium
        end as channel

    from {{ ref('fct_sessions') }} as fct_sessions
    left join {{ ref('dim_devices') }} as dim_devices
        on fct_sessions.device_id = dim_devices.device_id
    left join {{ ref('dim_traffic_source') }} as dim_traffic_source
        on fct_sessions.traffic_source_key = dim_traffic_source.traffic_source_key

),

segmented as (

    select 'overall' as segment_type, 'all sessions' as segment_value, sessions.* from sessions
    {% for seg in segment_types %}
    union all
    select '{{ seg }}' as segment_type, coalesce({{ seg }}, 'unknown') as segment_value, sessions.* from sessions
    {% endfor %}

),

steps as (

    {% for step in steps %}
    select
        segment_type,
        segment_value,
        '{{ step.name }}' as step,
        {{ loop.index }} as step_sort,
        count(*) as segment_sessions,
        sum({{ step.flag }}) as sessions_reached,
        sum({{ step.prev }}) as prev_step_sessions,
        sum({{ step.prev }} * {{ step.flag }}) as reached_from_prev

    from segmented
    group by segment_type, segment_value
    {% if not loop.last %}union all{% endif %}
    {% endfor %}

),

with_rest as (

    select
        steps.*,
        overall.segment_sessions - steps.segment_sessions as rest_sessions,
        overall.sessions_reached - steps.sessions_reached as rest_reached

    from steps
    inner join steps as overall
        on overall.segment_type = 'overall'
        and overall.step = steps.step

),

sorted as (

    select
        *,
        case
            when segment_type = 'overall' then 0
            when segment_value = 'unknown' then 99
            else dense_rank() over (
                partition by segment_type, step
                order by segment_sessions desc
            )
        end as segment_sort,
        case segment_type
            when 'overall' then 1
            when 'device_category' then 2
            when 'continent' then 3
            when 'channel' then 4
        end as segment_type_sort

    from with_rest

)

select
    segment_type,
    segment_type_sort,
    segment_value,
    segment_sort,
    step,
    step_sort,
    segment_sessions,
    sessions_reached,
    prev_step_sessions,
    reached_from_prev,

    safe_divide(sessions_reached, segment_sessions) as reach_rate,
    {{ wilson_bound('sessions_reached', 'nullif(segment_sessions, 0)', 'lower') }} as reach_rate_lower,
    {{ wilson_bound('sessions_reached', 'nullif(segment_sessions, 0)', 'upper') }} as reach_rate_upper,

    safe_divide(reached_from_prev, prev_step_sessions) as step_conversion,
    {{ wilson_bound('reached_from_prev', 'nullif(prev_step_sessions, 0)', 'lower') }} as step_conversion_lower,
    {{ wilson_bound('reached_from_prev', 'nullif(prev_step_sessions, 0)', 'upper') }} as step_conversion_upper,

    safe_divide(sessions_reached - reached_from_prev, sessions_reached) as skipped_prev_share,

    safe_divide(sessions_reached, segment_sessions)
        - safe_divide(rest_reached, rest_sessions) as gap_vs_rest,
    {{ newcombe_bound('sessions_reached', 'nullif(segment_sessions, 0)', 'rest_reached', 'nullif(rest_sessions, 0)', 'lower') }} as gap_vs_rest_lower,
    {{ newcombe_bound('sessions_reached', 'nullif(segment_sessions, 0)', 'rest_reached', 'nullif(rest_sessions, 0)', 'upper') }} as gap_vs_rest_upper,

    if(segment_sessions < 100, 1, 0) as is_thin_segment,
    if(prev_step_sessions < 100, 1, 0) as is_thin_step

from sorted
