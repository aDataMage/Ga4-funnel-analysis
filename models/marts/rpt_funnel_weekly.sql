/*
  Date: 2026-10-02

  grain: one row per ISO week (Monday start) - the dashboard's trend (page 3)
  base: 30-minute sessions by session_date; presence-based funnel steps
  session_conversion_rate: purchasing sessions / sessions, Wilson 95% interval
  is_partial_week: 1 where the week has fewer than 7 days of data - the
  sample starts on Sunday 2020-11-01, so its first week has one day
*/

with sessions as (

    select * from {{ ref('fct_sessions') }}

),

weekly as (

    select
        date_trunc(session_date, isoweek) as week_start,
        count(distinct session_date) as days_in_week,
        count(*) as sessions,
        sum(reached_view_item) as sessions_with_view_item,
        sum(reached_add_to_cart) as sessions_with_add_to_cart,
        sum(reached_begin_checkout) as sessions_with_begin_checkout,
        sum(reached_purchase) as sessions_with_purchase

    from sessions
    group by 1

)

select
    week_start,
    format_date('%d %b', week_start) as week_label,
    row_number() over (order by week_start) as week_sort,
    days_in_week,
    if(days_in_week < 7, 1, 0) as is_partial_week,
    sessions,
    sessions_with_view_item,
    sessions_with_add_to_cart,
    sessions_with_begin_checkout,
    sessions_with_purchase,
    safe_divide(sessions_with_purchase, sessions) as session_conversion_rate,
    {{ wilson_bound('sessions_with_purchase', 'nullif(sessions, 0)', 'lower') }} as session_conversion_rate_lower,
    {{ wilson_bound('sessions_with_purchase', 'nullif(sessions, 0)', 'upper') }} as session_conversion_rate_upper

from weekly
