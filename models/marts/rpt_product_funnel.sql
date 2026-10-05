/*
  Date: 2026-10-02

  grain: one row per product category - the dashboard's product funnel (page 3)
  linking: purchase events use a different category taxonomy ('apparel') from
  view / cart events ('home/apparel/men's / unisex/'), and item_ids don't
  match across events (4 of 809 purchased ids appear in views). item_name does
  (387 of 395 purchased names appear in views), so products are linked by
  item_name, and each product takes the category it most often carries on
  view_item events (ties alphabetical). Items with no name ('(not set)') can't
  be linked and are left out
  base: sessions that viewed at least one product of the category
  view_to_cart_rate / view_to_purchase_rate: of those sessions, the share that
  also carted / bought a product of the same category - true proportions, with
  Wilson 95% intervals
  revenue and units: purchase events of the category's products, all sessions
  thin cells: is_thin_cell where fewer than 100 sessions viewed the category
*/

with items as (

    select * from {{ ref('fct_event_items') }}
    where item_name is not null

),

events as (

    select event_id, session_id from {{ ref('fct_events') }}

),

product_category as (

    select
        item_name,
        array_agg(item_category order by n desc, item_category limit 1)[offset(0)] as item_category

    from (
        select item_name, item_category, count(*) as n
        from items
        where event_name = 'view_item'
            and item_category is not null
        group by 1, 2
    )
    group by 1

),

session_category as (

    select
        events.session_id,
        coalesce(product_category.item_category, 'unknown') as item_category,
        max(if(items.event_name = 'view_item', 1, 0)) as viewed,
        max(if(items.event_name = 'add_to_cart', 1, 0)) as carted,
        max(if(items.event_name = 'purchase', 1, 0)) as purchased,
        sum(if(items.event_name = 'purchase', items.quantity, 0)) as units_purchased,
        sum(if(items.event_name = 'purchase', items.item_revenue_in_usd, 0)) as item_revenue_in_usd

    from items
    inner join events
        on items.event_id = events.event_id
    left join product_category
        on items.item_name = product_category.item_name
    group by 1, 2

),

categories as (

    select
        item_category,
        sum(viewed) as sessions_viewed,
        sum(viewed * carted) as sessions_viewed_and_carted,
        sum(viewed * purchased) as sessions_viewed_and_purchased,
        sum(purchased) as sessions_purchased,
        sum(units_purchased) as units_purchased,
        sum(item_revenue_in_usd) as item_revenue_in_usd

    from session_category
    group by 1

)

select
    item_category,
    case
        when item_category = 'unknown' then 999
        else row_number() over (order by sessions_viewed desc, item_category)
    end as category_sort,
    sessions_viewed,
    sessions_viewed_and_carted,
    sessions_viewed_and_purchased,
    sessions_purchased,
    units_purchased,
    item_revenue_in_usd,
    safe_divide(sessions_viewed_and_carted, sessions_viewed) as view_to_cart_rate,
    {{ wilson_bound('sessions_viewed_and_carted', 'nullif(sessions_viewed, 0)', 'lower') }} as view_to_cart_rate_lower,
    {{ wilson_bound('sessions_viewed_and_carted', 'nullif(sessions_viewed, 0)', 'upper') }} as view_to_cart_rate_upper,
    safe_divide(sessions_viewed_and_purchased, sessions_viewed) as view_to_purchase_rate,
    {{ wilson_bound('sessions_viewed_and_purchased', 'nullif(sessions_viewed, 0)', 'lower') }} as view_to_purchase_rate_lower,
    {{ wilson_bound('sessions_viewed_and_purchased', 'nullif(sessions_viewed, 0)', 'upper') }} as view_to_purchase_rate_upper,
    if(sessions_viewed < 100, 1, 0) as is_thin_cell

from categories
