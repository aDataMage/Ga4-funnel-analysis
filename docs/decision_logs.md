# Decision log

Every modelling decision and why, in date order. Anything a future reader
would ask "why is it like this?" about belongs here.

<!-- Pattern:

## [Layer: Staging / Intermediate / Marts]

### Date: YYYY-MM-DD

  Decision: [one line] <br>

- [what was done]
- [why - the reason a future reader needs]
- [what was deliberately not done, and why]

  Output view/table: model_name `models\layer\model_name.sql`

-->

## Staging

### Date: 2026-09-29

  Decision: lower-case all string columns in the staging layer <br>

- Downstream filters, joins and group-bys never have to worry about casing
- Booleans are left as they land: `lower()` on a BOOL fails static analysis

### Date: 2026-09-29

  Decision: build stg_ga4__events as an incremental table, partitioned by event_date, with the date range set by project vars (superseded below: partitioning dropped) <br>

- `insert_overwrite` on day partitions of `event_date`; the vars `ga4_start_date` / `ga4_end_date` (YYYYMMDD, defaults 20201101-20210131) filter `_TABLE_SUFFIX`, so a run reads only those daily shards and replaces only those partitions
- The source is 92 daily shards and 4,295,584 events with nested arrays; reprocessing a window shouldn't rescan all of it
- A constant `_TABLE_SUFFIX` filter limits the shards BigQuery scans; a filter that looks up `max(event_date)` from the existing table (the usual `is_incremental()` pattern) is a subquery, which BigQuery can't use to prune wildcard shards
- This departs from the staging-is-a-view convention: a view would re-read the nested source on every downstream query

  Output view/table: stg_ga4__events `models\staging\stg_ga4__events.sql`

### Date: 2026-09-29

  Decision: extract event_params with scalar subqueries through a macro, never a FROM-clause unnest <br>

- `ga4_event_param(key, value_type)` in `macros/ga4_event_param.sql` returns one value from `event_params` by key, reading the `string` / `int` / `float` / `double` field
- A `FROM events, UNNEST(event_params)` join returns one row per param: 4,295,584 events became 46,095,652 rows
- No event repeats a key, so the scalar subquery can't return more than one row
- Some keys store values in more than one field (`session_engaged` string and int, `value` / `tax` int and double, `transaction_id` string and int); the macro reads one field, so those need care when they're used

  Output view/table: stg_ga4__events `models\staging\stg_ga4__events.sql`

### Date: 2026-09-29

  Decision: drop empty columns, constants and export artefacts from stg_ga4__events <br>

- Profiled over all 4,295,584 events (2020-11-01 to 2021-01-31)
- Empty on every row: `app_info.*`, `device.advertising_id`, `device.mobile_os_hardware_model`, `device.time_zone_offset_seconds`, `device.vendor_id`, `ecommerce.refund_value(_in_usd)`, `ecommerce.shipping_value(_in_usd)`, `event_dimensions.hostname`, `event_previous_timestamp`, `event_server_timestamp_offset`, `user_id`, `privacy_info.ads_storage`, `privacy_info.analytics_storage`
- One value on every row: `platform` ('WEB'), `stream_id`, `device.is_limited_ad_tracking` ('No'), `privacy_info.uses_transient_token` ('No'), `geo.metro` ('(not set)'), `user_ltv.currency` ('USD')
- Export artefact: `event_bundle_sequence_id` (a batching counter, not an attribute of the event)
- Populated but not selected in this model, so still available in the source for later models: `device.language`, `device.mobile_model_name`, `device.operating_system(_version)`, `device.web_info.browser(_version)`, `ecommerce.*` (purchase revenue, tax, transaction_id, item counts), `event_value_in_usd`, `user_ltv.revenue`, `items`, `user_properties` (134 events), and the event_params other than page_title, page_location and ga_session_id
- Not dropped: `device.mobile_marketing_name` is '<Other>' on every row but was kept as specified; open question (resolved below: dropped)

  Output view/table: stg_ga4__events `models\staging\stg_ga4__events.sql`

### Date: 2026-09-29

  Decision: parse event_date to DATE and NULL city's '(not set)' <br>

- `event_date` lands as a 'YYYYMMDD' string; parsed to DATE so it can be the partition column
- `geo.city` = '(not set)' on 1,795,444 events (41.8%); set to NULL so counts of cities don't treat it as a city
- Not done: other placeholders stay as they land (lower-cased): '(not set)' in continent, sub_continent (10,917 each), country (32,208) and region (403,316); '<other>' in brand (329,271) and marketing_name (all rows); '(none)', '(direct)', '<other>', '(data deleted)' in the traffic_source fields. Filters that assume NULL will miss these rows (superseded below: all placeholders now cleaned)

  Output view/table: stg_ga4__events `models\staging\stg_ga4__events.sql`

### Date: 2026-09-29

  Decision: keep traffic_source fields, documented as first-touch acquisition <br>

- `traffic_source.medium` / `.source` / `.name` in the GA4 export describe what first acquired the device, not the source of each session or event
- Named `medium`, `traffic_source`, `source_name`; the YAML says they are first-touch so they aren't read as session attribution
- Session-level source lives in event_params (`source`, `medium`, `campaign`), not extracted yet

  Output view/table: stg_ga4__events `models\staging\stg_ga4__events.sql`

### Date: 2026-09-29

  Decision: clean every string dimension with ga4_clean_string - placeholders to NULL, brackets unwrapped (amended 2026-10-05: '(none)' now becomes 'direct') <br>

- `ga4_clean_string(column)` in `macros/ga4_clean_string.sql` lower-cases, turns '(not set)', '(none)' and '(data deleted)' into NULL, and unwraps a value wrapped end to end in `()` or `<>` ('(direct)' -> 'direct', '<Other>' -> 'other', '(organic)' -> 'organic', '(referral)' -> 'referral')
- Applied to page_title, page_location, device, brand, the geo fields, the traffic_source fields and transaction_id; the only wrapped values found across these (all 4,295,584 events) were in brand, the geo fields, the traffic_source fields and transaction_id
- NULLed: city 1,795,444, region 403,316, country 32,208, continent and sub_continent 10,917 each, transaction_id 741,523; medium 1,303,601 ('(none)' 989,684 + '(data deleted)' 313,917); traffic_source 308,695 and source_name 306,045 ('(data deleted)')
- A placeholder is not a value: left as text, it counts as a city, a country or a transaction, and IFNULL / IS NULL handling silently misses it
- Side effect: medium NULL now covers both direct traffic ('(none)') and deleted data; traffic_source = 'direct' tells them apart
- Not done: the `items` array is passed through raw, placeholders and casing included - it is cleaned where it is unnested

  Output view/table: stg_ga4__events `models\staging\stg_ga4__events.sql`

### Date: 2026-09-29

  Decision: drop device.mobile_marketing_name <br>

- '<Other>' on every one of the 4,295,584 events: no information, and after cleaning it would be the constant 'other'

  Output view/table: stg_ga4__events `models\staging\stg_ga4__events.sql`

### Date: 2026-09-29

  Decision: flatten ecommerce to columns; keep items as an array in stg_ga4__events <br>

- `ecommerce` is a struct (one value per event), so flattening it keeps the one-row-per-event grain: transaction_id, purchase_revenue(_in_usd), tax_value(_in_usd), total_item_quantity, unique_items
- `ecommerce.refund_value(_in_usd)` and `ecommerce.shipping_value(_in_usd)` stay dropped - empty on every row
- `items` is an array: unnesting it here would make the grain one row per item and repeat each event's counts and revenue per item. It stays an array (populated on 512,346 events, 11.9%) and is unnested downstream

  Output view/table: stg_ga4__events `models\staging\stg_ga4__events.sql`

### Date: 2026-09-29

  Decision: add event_key, a surrogate key on device_id, session_id, time_stamp and event_name (superseded 2026-09-30: removed from staging) <br>

- GA4 exports no event id; downstream models (the unnested items, dedupes) need one to join back to the event
- The four-column combination is unique across all 4,295,584 events (checked against the raw source before building); a `unique` test keeps checking it
- Built with `dbt_utils.generate_surrogate_key`, on the cleaned columns

  Output view/table: stg_ga4__events `models\staging\stg_ga4__events.sql`

### Date: 2026-09-29

  Decision: drop partitioning - build stg_ga4__events as a plain table, rebuilt in full each run <br>

- The first build of the incremental, event_date-partitioned table finished with 0 rows
- Cause: the `dbt_dev` dataset has a 60-day default partition expiration (`default_partition_expiration_ms` = 5,184,000,000). Partition age is measured from the partition's date, and every event_date in this sample (2020-11-01 to 2021-01-31) is years past 60 days, so BigQuery drops each partition as it is written
- The dataset's default table expiration is also 60 days. That is the BigQuery sandbox's limit (a project without billing), and the sandbox doesn't allow a longer expiration, so the setting can't be changed for now
- An unpartitioned table has no partitions to expire. Its table expiration counts from when the table was created, and each full rebuild recreates it
- Cost of the change: every run rescans all the shards in the var range, and the vars now set the whole range the table holds - overriding them replaces the table with that window, not just those days
- Not done: an incremental `merge` on event_key without partitioning - it would still rescan the shards in range each run, so it saves little on a static sample

  **When billing is added - restore partitioning:**
  1. Remove the dataset's partition expiration: `bq update --default_partition_expiration 0 focus-appliance-507309-h8:dbt_dev` (and `--default_table_expiration 0` if tables should persist)
  2. Set the model config back to `materialized='incremental'`, `incremental_strategy='insert_overwrite'`, `partition_by={'field': 'event_date', 'data_type': 'date', 'granularity': 'day'}`
  3. Run `dbt build -s stg_ga4__events --full-refresh` once - an unpartitioned table can't be replaced in place by a partitioned one
  4. Mark this entry superseded and revert the header comment, the YAML description and the vars comment in `dbt_project.yml`

  Output view/table: stg_ga4__events `models\staging\stg_ga4__events.sql`

### Date: 2026-09-30

  Decision: remove event_key from stg_ga4__events <br>

- Staging stays a clean, renamed copy of the source; keys are built where they're used, starting with session_key in the intermediate layer
- The `unique` and `not_null` tests on event_key went with it. device_id, session_id, time_stamp and event_name are still unique together across all 4,295,584 events, but nothing tests that any more

  Output view/table: stg_ga4__events `models\staging\stg_ga4__events.sql`

## Intermediate

### Date: 2026-09-30

  Decision: sessionise events by a 30-minute inactivity gap per device, at event grain <br>

- `int_events__sessionised` keeps one row per event and adds `is_new_session`, `session_num`, `mins_since_prev` and `session_key`
- A device's event starts a new session when more than 1,800 seconds have passed since its previous event, or when it is the device's first event; `session_num` is the running sum of those starts
- The gap is measured in seconds, not whole minutes: `timestamp_diff(..., minute)` truncates, so a 30m 59s gap would count as 30 and not split the session. `mins_since_prev` is reported in whole minutes for reading only
- Events with the same timestamp are ordered by session_id, then event_name. Those four columns are unique together, so the order - and so `session_num` - is the same on every run
- Event grain, not session grain: the session rollup (start, end, event count, duration) is built from this model downstream, and event-level models can still see each event's session
- GA4's own `session_id` (ga_session_id) is carried through but not used, so this model's sessions follow one explicit rule
- Materialised as a view, the intermediate-layer default

  Output view/table: int_events__sessionised `models\intermediate\int_events__sessionised.sql`

### Date: 2026-09-30

  Decision: key sessions with session_key, a surrogate key on device_id and session_num <br>

- `dbt_utils.generate_surrogate_key(['device_id', 'session_num'])`: one value per session, repeated on each of its events
- `session_num` is only unique within a device, so the key needs both columns
- Tested `not_null`; it can't be tested `unique` here because the model is at event grain - that test belongs on the session-grain model

  Output view/table: int_events__sessionised `models\intermediate\int_events__sessionised.sql`

### Date: 2026-09-30

  Decision: flag GA4 ecommerce funnel steps per session, by presence, not sequence <br>

- `int_sessions__funnel_steps`: one row per session_key, with an integer flag per step - session_start, view_item, add_to_cart, begin_checkout, add_shipping_info, add_payment_info, purchase - plus session_start / session_end timestamps and event_count
- These are GA4's standard ecommerce events, and every step is in the sample (GA4 sessions containing each, from 354,857 with session_start down to 4,848 with purchase)
- A flag is 1 if the session contains the event anywhere. Steps aren't forced into order: GA4 doesn't guarantee every step fires, so a sequence rule would drop sessions whose tagging skipped a step. A session can therefore have a later step at 1 and an earlier one at 0
- Flags are integers: SUM counts sessions reaching a step, AVG is the rate
- `reached_session_start` flags GA4's session_start event. These sessions are cut by the 30-minute rule, not by GA4, so not every one contains it
- Not done: the discovery events (view_item_list, select_item, view_search_results, view_promotion, select_promotion) - out of this funnel's scope
- Unique `session_key` tested here - the session-grain model the sessionising decision left it for

  Output view/table: int_sessions__funnel_steps `models\intermediate\int_sessions__funnel_steps.sql`

### Date: 2026-09-30

  Decision: attribute sessions to the device's first touch, from GA4's traffic_source fields <br>

- `first_touch`, `first_touch_medium`, `first_touch_source`, `first_touch_source_name` come from the staging columns `first_touch`, `medium`, `traffic_source`, `source_name`
- GA4 exports traffic_source as the channel that first acquired the device, so every session of a device gets that device's first-touch channel - including repeat sessions that arrived some other way
- Read from the session's first event (same order as the sessionising), so the value is well defined even if a device's traffic_source ever varied between events
- Checked 2026-09-30: it does vary - 42,263 of 270,154 devices (16%) carry more than one source / medium / campaign combination across their events, so "every session of a device gets the same channel" above doesn't hold in this sample; each session takes the combination on its own first event
- Not done: session-level attribution (the channel each session arrived through). That lives in event_params `source`, `medium` and `campaign`, which aren't extracted into staging yet
- Inherited from staging: NULL medium covers both direct traffic ('(none)') and '(data deleted)'; first_touch_source = 'direct' tells them apart

  Output view/table: int_sessions__funnel_steps `models\intermediate\int_sessions__funnel_steps.sql`

### Date: 2026-09-30

  Decision: take each device's current traffic attribution from its latest event, as the input to the SCD2 snapshot (disabled 2026-10-05 with the snapshot) <br>

- `int_devices__traffic_attribution`: one row per device with the source / medium / campaign on its latest event, and its `traffic_source_key`
- A snapshot records the state of a table each time it runs, so its input must be one row per device holding the current value; "latest event" is the current value
- The within-sample history (42,263 devices change combination across their events) is not reconstructed here - see the SCD2 entry under Snapshots

  Output view/table: int_devices__traffic_attribution `models\intermediate\int_devices__traffic_attribution.sql`

## Snapshots

### Date: 2026-09-30

  Decision: build SCD Type 2 attribution history with a dbt snapshot (check strategy) - it demonstrates the pattern, not a live need (disabled 2026-10-05, see below) <br>

- `snap_device_traffic_attribution` snapshots `int_devices__traffic_attribution`: `unique_key: device_id`, `strategy: check` on `traffic_source_key`. When a device's key changes between runs, the old row is closed (`valid_to` set) and a new version opens
- dbt's meta columns are renamed to the Type 2 vocabulary: `valid_from`, `valid_to`, `attribution_version_key` (surrogate key per version, dbt_scd_id), `snapshot_updated_at`; `dim_device_traffic_attribution` adds `is_current`
- **Honest scope:** the GA4 sample is static (2020-11-01 to 2021-01-31). A snapshot stamps versions with the *run* time, so every device gets exactly one version dated at the first run, and the attribution changes inside the sample never appear as versions. This shows the Type 2 mechanics; it doesn't solve a live problem on this data. It would on a live GA4 export, where each run sees newer events
- Not done: reconstructing history from event time (valid_from = first event showing a value). That's a derived table, not a snapshot, and it wasn't asked for
- In the BigQuery sandbox, tables expire 60 days after creation, and a snapshot table is never recreated - so its history would be lost after 60 days. Another reason it is a demonstration until billing is added

  Output view/table: snap_device_traffic_attribution `snapshots\snap_device_traffic_attribution.yml`

## Marts

### Date: 2026-09-30

  Decision: star schema - fct_events and fct_sessions, with dim_devices, dim_traffic_source, dim_device_traffic_attribution and dim_date <br>

- `fct_sessions`: one row per 30-minute session. `session_id` is the session_key hash, renamed so the name means the same thing in both facts
- `fct_events`: one row per event; foreign keys `session_id` (fct_sessions), `device_id` (dim_devices), `traffic_source_key` (dim_traffic_source), `event_date` (dim_date). GA4's own session id is renamed `ga_session_id` to avoid clashing with `session_id`
- Descriptive device, location and traffic text moves to the dims; facts carry keys and measures
- Every foreign key has a `relationships` test
- Not done: an event primary key (none requested; device_id, ga_session_id, time_stamp and event_name are unique together if one is needed); the `items` array (BI tools can't read arrays - it stays in stg_ga4__events for an item-level model); the funnel flags from int_sessions__funnel_steps (not requested on fct_sessions) - all three added below

  Output view/table: fct_events `models\marts\fct_events.sql`, fct_sessions `models\marts\fct_sessions.sql`

### Date: 2026-09-30

  Decision: fct_sessions.ga_session_id is the first event's GA4 id, with ga_session_count beside it <br>

- The 30-minute sessions and GA4's sessions don't match one to one: 4,697 of 355,592 sessions contain more than one ga_session_id, and 213 GA4 sessions are split across more than one 30-minute session
- One value keeps the column simple for BI; `ga_session_count` keeps the mismatch visible instead of hiding it
- `session_date` is the first event's `event_date` (property time zone), not `date(session_start)` (UTC), so sessions and events join dim_date the same way

  Output view/table: fct_sessions `models\marts\fct_sessions.sql`

### Date: 2026-09-30

  Decision: dim_devices is Type 1 - one row per device, latest event's values <br>

- Location never changes within a device in this sample; device category changes for 4,182 devices and brand for 5,539
- The latest event's value is kept - the device as it was last seen
- Not done: Type 2 history for device attributes - SCD2 is scoped to traffic attribution only

  Output view/table: dim_devices `models\marts\dim_devices.sql`

### Date: 2026-09-30

  Decision: dim_traffic_source is one row per source / medium / campaign combination, keyed by a hash that includes NULLs <br>

- 15 combinations in the sample, including ones with NULL parts (direct traffic, '(data deleted)')
- `traffic_source_key` = `dbt_utils.generate_surrogate_key` over medium, traffic_source, source_name; the macro hashes NULL as a fixed token, so NULL combinations still get a key and join
- The same hash is built in fct_events and int_devices__traffic_attribution, so the keys match without a lookup join

  Output view/table: dim_traffic_source `models\marts\dim_traffic_source.sql`

### Date: 2026-09-30

  Decision: dim_date from generate_date_array over the ga4 date vars, with *_sort columns <br>

- One row per day from `ga4_start_date` to `ga4_end_date`, so it always covers the event range
- `generate_date_array`, not `dbt_utils.date_spine`: the spine macro runs a warehouse query at compile time, which failed on the Storage API permission
- `month_name` / `day_name` carry `month_sort` / `day_sort` (Monday = 1), per the band convention

  Output view/table: dim_date `models\marts\dim_date.sql`

### Date: 2026-09-30

  Decision: give fct_events a primary key, event_id <br>

- `event_id` = `dbt_utils.generate_surrogate_key` over device_id, ga_session_id, time_stamp and event_name - unique together across all 4,295,584 events; `unique` and `not_null` tested
- Built in the mart, not staging: keys are built where they're used. fct_event_items builds the same hash from staging columns to join back

  Output view/table: fct_events `models\marts\fct_events.sql`

### Date: 2026-09-30

  Decision: fct_event_items - one row per item per event, cleaned, with empty and constant item fields dropped <br>

- The `items` array unnested with its offset: 3,982,732 rows from 512,346 events. `event_item_id` = hash(event_id, item_index); `event_id` joins fct_events
- Most rows are impressions, not purchases: view_item events carry 2,748,246 item rows, purchase events 16,003 - filter on event_name
- Strings go through `ga4_clean_string`; in addition, '' (item_brand 2,498, promotion_name 15,524) and 'Not available in demo dataset' (item_list_name 1,703,220, promotion_name 6,751) become NULL - they are the export's placeholders for "no value", handled like '(not set)'
- Dropped, '(not set)' on every row: item_category2-5, coupon, affiliation, location_id, promotion_id, creative_slot. Empty: item_refund, item_refund_in_usd. item_list_name: NULL on every row once its two placeholders are cleaned
- `price` is populated on 96.3% of rows but `price_in_usd` on only 0.4% (15,555, the same rows as item_revenue) - left as landed, and documented so nobody sums price_in_usd expecting full coverage
- `item_list_index` kept as text: it lands as a string, and casting could silently turn unexpected values into NULL

  Output view/table: fct_event_items `models\marts\fct_event_items.sql`

### Date: 2026-09-30

  Decision: add the funnel flags to fct_sessions <br>

- The seven `reached_*` flags from int_sessions__funnel_steps, joined on session_key - so the funnel is read from the mart, not the intermediate model
- Inner join: both models are built from int_events__sessionised with the same session_key, so every session is in both

  Output view/table: fct_sessions `models\marts\fct_sessions.sql`

### Date: 2026-09-30

  Decision: derive SCD Type 2 attribution history from event time, alongside the snapshot <br>

- `dim_device_traffic_attribution_history`: a version is a run of a device's consecutive events with the same source / medium / campaign (gaps and islands). valid_from = the version's first event; valid_to = the next version's first event (exclusive), NULL on the current one; `attribution_version_key` = hash(device_id, version_num); `is_current`
- The snapshot can't show the within-sample history (versions are stamped by run time); this model can. 345,700 versions for 270,154 devices; 42,263 devices change at least once; the most is 36 versions for one device
- A -> B -> A counts as three versions, not two - a return to an earlier channel is a change
- **Honest scope:** GA4 documents traffic_source as the channel that first acquired the device, which shouldn't change at all, let alone 35 times. The changes may be an artefact of the sample's obfuscation. This model shows what the data holds and demonstrates event-time Type 2 mechanics; it isn't evidence of how devices were really acquired
- Kept separate from the snapshot-based `dim_device_traffic_attribution`: one is run-time history (how Type 2 is maintained in production), the other event-time history (what this static sample can show)

  Output view/table: dim_device_traffic_attribution_history `models\marts\dim_device_traffic_attribution_history.sql`

## Semantic layer

### Date: 2026-09-30

  Decision: define traffic, engagement and funnel metrics in the dbt semantic layer, on fct_sessions and fct_events <br>

- Written in the latest semantic layer spec (dbt v2 / v1.12): each semantic model is declared on its model's own YAML with `semantic_model: enabled: true`, entities and dimensions on the columns they come from, simple metrics (`agg` + `expr`, no measures) under the model's `metrics:`, and ratio metrics top-level in the same file. The first draft used the legacy spec (separate `semantic_models:` with measures and `type_params`) and was replaced
- Semantic models: `fct_sessions`, `fct_events`, and dimension-only `dim_devices` and `dim_traffic_source`; `dim_date` is the time spine (day grain)
- Entities make the joins: session, device, traffic_source, event. Session and event metrics can be sliced by device location and category; event metrics also by the event's own source / medium / campaign
- Metrics - traffic and engagement: `sessions`, `devices`, `events`, `events_per_session`, `avg_session_duration_min`. Funnel: `sessions_with_<step>` and `<step>_rate` for each of session_start, view_item, add_to_cart, begin_checkout, add_shipping_info, add_payment_info, and `session_conversion_rate` (purchasing sessions / sessions)
- One base for every session metric: the 30-minute sessions, dated by the first event's `session_date`. Rates are reach rates over all sessions (presence, not sequence), so they can't be multiplied into a step-to-step funnel
- `devices` counts devices (user_pseudo_id), not people - the sample has no user_id
- `events_per_session` and `avg_session_duration_min` are built from session-level measures (event_count, first-to-last minutes), so numerator and denominator share one base and one date; a one-event session counts as 0 minutes
- Not done: traffic source on session metrics - fct_sessions has no traffic_source_key; the SCD2 as-of join through dim_device_traffic_attribution_history (chose the event's own source); revenue and product metrics (not in scope)
- The semantic layer gives point rates only. The confidence intervals the analysis conventions require come from `macros/confidence_intervals.sql` or the notebook, not from these metrics

  Output view/table: semantic models and metrics in `models\marts\fct_sessions.yml`, `fct_events.yml`, `dim_devices.yml`, `dim_traffic_source.yml`; time spine `models\marts\dim_date.yml`

## Reports

### Date: 2026-10-02

  Decision: feed the Excel workbook daily aggregates of the event-level facts, built as `rpt_` models (superseded 2026-10-05: the funnel dashboard reads the `rpt_funnel*` models, and both daily models were removed) <br>

- Excel caps a sheet at 1,048,576 rows; fct_events (4,295,584) and fct_event_items (3,982,732) don't fit
- `rpt_events_daily`: event_date x event_name x device category x continent x the event's traffic source - 86,038 rows. `rpt_event_items_daily`: event_date x event_name x product - 215,068 rows. fct_sessions (355,592) and the dims are loaded as they are
- Aggregated in dbt, not in Power Query, so the numbers are tested and the same for every tool
- Only additive measures (counts, sums), so any pivot adds up. Distinct counts of devices or sessions are left out - they don't add across rows; fct_sessions has them
- Reconciled on build: events sum to 4,295,584, purchase revenue to 362,165 USD, item rows to 3,982,732 - the same as the facts
- Continent, not country: country would make rpt_events_daily 373,661 rows. Device category and continent are each device's latest value (dim_devices)
- Excel reads BigQuery through Power Query over the BigQuery ODBC driver; declared as the `excel_workbook` exposure

  Output view/table: rpt_events_daily `models\marts\rpt_events_daily.sql`, rpt_event_items_daily `models\marts\rpt_event_items_daily.sql`

### Date: 2026-10-02

  Decision: add traffic_source_key to fct_sessions, from the session's first event <br>

- The funnel dashboard splits sessions by channel; fct_sessions had no traffic source
- The session's first event's source / medium / campaign, hashed exactly as in fct_events, so it joins dim_traffic_source; `not_null` and `relationships` tested, and declared as a foreign `traffic_source` entity in the semantic model
- First event, not most frequent: the channel a session arrived through

  Output view/table: fct_sessions `models\marts\fct_sessions.sql`

### Date: 2026-10-02

  Decision: compute the funnel, its rates and their intervals in dbt (rpt_funnel), not in Excel <br>

- One row per segment (overall, device_category, continent, channel) x step (sessions -> view_item -> add_to_cart -> begin_checkout -> add_shipping_info -> add_payment_info -> purchase): 16 segments x 7 steps = 112 rows
- `reach_rate` = sessions reaching the step / segment sessions. `step_conversion` = sessions reaching both the previous step and this one / sessions reaching the previous step - a true proportion even where steps are skipped, so its Wilson interval is valid
- All six steps kept, with the cart step flagged: 46.2% of sessions reaching begin_checkout and 41.1% of purchasing sessions have no add_to_cart. Every other step nests almost perfectly (at most 16 sessions skip). A buy-now path or untracked cart events - the data can't tell which. `skipped_prev_share` carries this per step and segment
- Segment gaps are measured against the rest of sessions, not overall: a segment is part of overall, and Newcombe's interval needs independent groups
- Wilson / Newcombe from `macros/confidence_intervals.sql`; checked against statsmodels (overall purchase reach 0.013244 to 0.014006, identical). Counts pass through `nullif(n, 0)` - the macro divides by n, and overall has no "rest"
- Thin cells flagged: `is_thin_segment` (segment n < 100), `is_thin_step` (previous-step n < 100)
- Channel = first-event medium; 'direct' where the source is direct (medium NULL from '(none)'); 'unknown' where medium is NULL otherwise ('(data deleted)'). 'unknown' converts at 3.2% vs 1.3% for the rest - flagged on the dashboard as a possible obfuscation artefact
- `session_start` left out of the funnel: GA4's session_start follows GA4's sessions, not these

  Output view/table: rpt_funnel `models\marts\rpt_funnel.sql`

### Date: 2026-10-02

  Decision: weekly conversion trend by ISO week, partial week flagged <br>

- `rpt_funnel_weekly`: sessions, step counts and session conversion rate with its Wilson interval per ISO week (Monday start), 14 weeks
- The sample starts on Sunday 2020-11-01, so the first week holds one day (2,592 sessions); `is_partial_week` lets the dashboard drop or label it. The last week (25-31 Jan) is complete

  Output view/table: rpt_funnel_weekly `models\marts\rpt_funnel_weekly.sql`

### Date: 2026-10-02

  Decision: product funnel by category, linking products across steps by item_name <br>

- First build joined steps on item_category and returned 0 purchases for the top categories: purchase events use a different category taxonomy ('apparel', 'campus collection') from view and cart events ('home/apparel/men's / unisex/'), and item_ids don't match either (4 of 809 purchased ids appear in views). item_name does (387 of 395 purchased names appear in views)
- So products are linked by item_name, and each product takes the category it most often carries on view_item events (ties alphabetical) - the view / cart taxonomy
- Base: sessions that viewed a product of the category; `view_to_cart_rate` / `view_to_purchase_rate` = share of those that also carted / bought a product of the same category - true proportions, Wilson intervals
- Item revenue reconciles in full: 362,110 USD across the 35 categories, the same as all purchase item rows
- Unnamed items ('(not set)') can't be linked and are left out; 5 of 35 categories are thin (< 100 viewing sessions)

  Output view/table: rpt_product_funnel `models\marts\rpt_product_funnel.sql`

## Wrap-up

### Date: 2026-10-05

  Decision: ga4_clean_string maps '(none)' to 'direct' instead of NULL <br>

- GA4 exports '(none)' as the medium of direct traffic (989,684 events). As 'direct' it says what it is; NULL now means only '(data deleted)', so a NULL medium no longer mixes direct traffic with deleted data
- '(none)' appears only in traffic_source.medium in this sample, so the change touches no other column, even though the macro runs on every string dimension
- No dashboard number moves: rpt_funnel's channel was already 'direct' wherever the source is direct. dim_traffic_source keys for direct traffic change (the medium is part of the hash); fct_events and fct_sessions build the same hash, so joins hold
- Column descriptions updated from "NULL covers direct ('(none)') and '(data deleted)'" to the new meaning

  Output view/table: macro `macros\ga4_clean_string.sql`; staging stg_ga4__events `models\staging\stg_ga4__events.sql`

### Date: 2026-10-05

  Decision: disable the snapshot chain on the sandbox, keep the code <br>

- snap_device_traffic_attribution, its input int_devices__traffic_attribution and its output dim_device_traffic_attribution are set `enabled: false`: the BigQuery sandbox blocks DML, and after its first run a snapshot updates its table with MERGE ("Billing has not been enabled ... DML queries are not allowed in the free tier")
- Kept, not deleted: the check-strategy snapshot with Type 2 columns renamed (valid_from, valid_to, version key) is the production pattern, and the code shows it. Enable all three once the project has billing
- SCD Type 2 that does build is dim_device_traffic_attribution_history (event-time versions, tested)

  Output view/table: snapshot `snapshots\snap_device_traffic_attribution.yml`

### Date: 2026-10-05

  Decision: guard the dashboard's headline numbers with a dbt parity test <br>

- `tests/assert_dashboard_parity.sql` checks 12 numbers the dashboard states in titles, tiles and notes (sessions, conversion rate, the 78.5% never viewing a product, view to cart 19.7%, 46.2% of checkouts skipping cart, the referral gap, the unknown channel's 3.2%, the weekly peak and low, men's / unisex apparel's 5.0% and 35% of revenue) against the marts, each with a tolerance at the precision the dashboard shows
- Severity warn: a data refresh should flag the dashboard text as stale, not block the build
- Replaces the template's story parity test, which pointed at a deleted example model

  Output view/table: test `tests\assert_dashboard_parity.sql`

