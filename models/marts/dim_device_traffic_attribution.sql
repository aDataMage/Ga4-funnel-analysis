{#- Disabled with snap_device_traffic_attribution: the BigQuery sandbox blocks
    the snapshot's MERGE. Enable all three once the project has billing. -#}
{{ config(enabled=false) }}

/*
  Date: 2026-09-30

  grain: one row per device per attribution version (SCD Type 2)
  Exposes snap_device_traffic_attribution with the Type 2 columns: a
  surrogate key per version, valid_from, valid_to and is_current.
  Demonstrates the pattern: the GA4 sample is static, so each device has one
  version, dated at the first snapshot run (see decision log).
*/

with snapshot as (

    select * from {{ ref('snap_device_traffic_attribution') }}

)

select
    attribution_version_key,
    device_id,
    traffic_source_key,
    medium,
    traffic_source,
    source_name,
    valid_from,
    valid_to,
    if(valid_to is null, 1, 0) as is_current

from snapshot
