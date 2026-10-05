{{ config(severity='warn') }}

/*
  Date: 2026-10-05

  The marts must reproduce the headline numbers the Excel dashboard states in
  its titles, tiles and notes. Any row returned is a figure that has drifted
  from the dashboard - either the data changed (update the dashboard text) or
  a model changed (fix the model).

  Severity is warn, not error: a data refresh should flag the dashboard as
  stale, not block the build.
*/

with funnel as (

    select * from {{ ref('rpt_funnel') }}

),

weekly as (

    select * from {{ ref('rpt_funnel_weekly') }}

),

product as (

    select * from {{ ref('rpt_product_funnel') }}

),

checks as (

    -- page 1: tiles and step table
    select 'p1 sessions' as check_name, cast(segment_sessions as float64) as actual, 355592.0 as expected, 0.0 as tolerance
    from funnel where segment_type = 'overall' and step = 'sessions'

    union all
    select 'p1 purchasing sessions', sessions_reached, 4843, 0
    from funnel where segment_type = 'overall' and step = 'purchase'

    union all
    select 'p1 session conversion rate', reach_rate, 0.0136, 0.0001
    from funnel where segment_type = 'overall' and step = 'purchase'

    union all
    select 'p1 sessions never viewing a product', 1 - reach_rate, 0.785, 0.001
    from funnel where segment_type = 'overall' and step = 'view_item'

    union all
    select 'p1 view -> cart conversion', step_conversion, 0.197, 0.001
    from funnel where segment_type = 'overall' and step = 'add_to_cart'

    union all
    select 'p1 checkouts without add_to_cart', skipped_prev_share, 0.462, 0.001
    from funnel where segment_type = 'overall' and step = 'begin_checkout'

    -- page 2: title and note
    union all
    select 'p2 referral gap at purchase', gap_vs_rest, 0.0039, 0.0001
    from funnel where segment_type = 'channel' and segment_value = 'referral' and step = 'purchase'

    union all
    select 'p2 unknown channel conversion', reach_rate, 0.032, 0.001
    from funnel where segment_type = 'channel' and segment_value = 'unknown' and step = 'purchase'

    -- page 3: title, annotations and product chart title
    union all
    select 'p3 weekly peak (7 Dec)', session_conversion_rate, 0.0201, 0.0001
    from weekly where week_start = date '2020-12-07'

    union all
    select 'p3 weekly low (4 Jan)', session_conversion_rate, 0.0056, 0.0001
    from weekly where week_start = date '2021-01-04'

    union all
    select "p3 men's / unisex apparel view -> purchase", view_to_purchase_rate, 0.0505, 0.0001
    from product where item_category = "home/apparel/men's / unisex/"

    union all
    select "p3 men's / unisex apparel share of item revenue",
        item_revenue_in_usd / (select sum(item_revenue_in_usd) from product), 0.35, 0.005
    from product where item_category = "home/apparel/men's / unisex/"

)

select *
from checks
where abs(actual - expected) > tolerance
