/*
  Date: 2026-09-30

  grain: one row per device (Type 1 - latest value wins)
  Geo never changes within a device in this sample. Device category changes
  for 4,182 devices and brand for 5,539; they take the value on the device's
  latest event.
*/

with events as (

    select * from {{ ref('stg_ga4__events') }}

),

latest as (

    select
        device_id,
        array_agg(
            struct(continent, sub_continent, country, region, city, device, brand)
            order by time_stamp desc, session_id desc, event_name desc
            limit 1
        )[offset(0)] as last_event

    from events
    group by device_id

)

select
    device_id,
    last_event.continent as continent,
    last_event.sub_continent as sub_continent,
    last_event.country as country,
    last_event.region as region,
    last_event.city as city,
    last_event.device as device,
    last_event.brand as brand

from latest
