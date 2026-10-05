/*
  Date: 2026-09-30

  grain: one row per calendar day, ga4_start_date to ga4_end_date (the vars
  that set the event range)
  Built with BigQuery's generate_date_array, not dbt_utils.date_spine - the
  spine macro runs a warehouse query at compile time.
  Every band carries a *_sort column so BI tools order it by calendar, not
  alphabetically.
*/

with days as (

    select date_day
    from unnest(generate_date_array(
        parse_date('%Y%m%d', '{{ var("ga4_start_date") }}'),
        parse_date('%Y%m%d', '{{ var("ga4_end_date") }}')
    )) as date_day

)

select
    date_day,
    extract(year from date_day) as year,
    extract(quarter from date_day) as quarter,
    format_date('%Y-%m', date_day) as year_month,
    format_date('%B', date_day) as month_name,
    extract(month from date_day) as month_sort,
    extract(isoweek from date_day) as iso_week,
    format_date('%A', date_day) as day_name,
    extract(dayofweek from date_day) - 1 + if(extract(dayofweek from date_day) = 1, 7, 0) as day_sort,
    if(extract(dayofweek from date_day) in (1, 7), 1, 0) as is_weekend

from days
