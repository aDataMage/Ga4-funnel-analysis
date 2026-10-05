# Excel funnel dashboard: as built

**Deliverable:** a three-page explainer dashboard in Excel whose job is funnel
analysis: where sessions drop out between landing and purchase, and for whom.
**Files:** `reports/ga4_funnel_dashboard.xlsx` (live, refreshable) and
`reports/ga4_funnel_dashboard.pdf` (export). **Framework:** SIGNAL moves S, G
and N only (an explainer dashboard: structure and framing, not suspense).
**Data:** the `rpt_funnel*` marts through Power Query (dbt exposure
`excel_workbook`). The headline numbers are guarded by
`tests/assert_dashboard_parity.sql`.

| Sheet | SIGNAL move | Job | Source |
| --- | --- | --- | --- |
| `1 Funnel` | Setting | Where conversion stands and where sessions are lost | `rpt_funnel` (overall) |
| `2 Leaks` | Guilty party | Which devices, regions and channels convert above or below the rest, at any step | `rpt_funnel` (segments) |
| `3 Time & Products` | Narrow in | When conversion moved, and which product categories convert | `rpt_funnel_weekly`, `rpt_product_funnel` |

**Base for every number:** 355,592 sessions (30-minute inactivity sessions,
not GA4's own), 1 Nov 2020 – 31 Jan 2021, Google Merchandise Store obfuscated
GA4 sample. A session "reaches" a step if it contains the event at all.

---

## 1. Data

**Connection.** Data → Get Data → From Other Sources → From ODBC → DSN
**(None)** → Advanced options → connection string:

```text
Driver={ODBC Driver for BigQuery};OAuthMechanism=0;KeyFilePath=C:\Users\PC\.gcp\dbt-local.json;Catalog=focus-appliance-507309-h8;DefaultDataset=dbt_dev
```

Credentials: **Default or Custom** → Connect. Use the connection string, not a
DSN: the Google BigQuery ODBC driver ignores a key file path saved in a DSN
("The path to the file can't be empty").

**Loaded as Tables** on hidden sheets:

| Query | Rows | Table | Sheet |
| --- | --- | --- | --- |
| `rpt_funnel` | 112 | `tFunnel` | `d_funnel` |
| `rpt_funnel_weekly` | 14 | `tWeekly` | `d_weekly` |
| `rpt_product_funnel` | 35 | `tProduct` | `d_product` |

Each table has added error-bar columns (Excel error bars want distances, not
bounds), e.g. `reach_err_minus = [@reach_rate]-[@reach_rate_lower]`. They
survive a refresh.

**`calc` sheet (hidden)** turns the tables into chart-ready ranges, all by
formula, so Refresh All updates every page:

| Block | Cells | How |
| --- | --- | --- |
| Overall funnel | `A1:N8` | `XLOOKUP` on segment `overall` x `step_sort`, columns picked by header with `INDEX/MATCH`; `bar_label` text for the funnel bars |
| Headline tiles | `A11:B14` | sessions, purchasing sessions, conversion rate, CI text |
| Step list | `P1:P8` | source of page 2's step selector |
| Segments at the selected step | `R1:AG16` | one `LET/FILTER/SORTBY` spill, `INDEX(..., {1,3,7,...})` to pick columns (Excel 2021 has no `CHOOSECOLS`); `differs` / `within_noise` split for the two bar colours |
| Weekly trend | `AI1:AM14` | `FILTER` drops the one-day first week |
| Top-12 categories | `AO1:AW13` | sorted by `category_sort`; `highlight` / `others` split |

Table column references are made absolute for sideways fills with the range
form `tFunnel[[col]:[col]]`.

---

## 2. Theme

Custom theme `GA4 Funnel` (Page Layout → Colors / Fonts), validated on the
`#FAF7F2` background (WCAG contrast; accent vs grey colour difference ≥ 34
under deutan, protan and tritan simulation).

| Role | Theme slot | Colour | Contrast on `#FAF7F2` |
| --- | --- | --- | --- |
| Background | Background 2 | `#FAF7F2` | n/a |
| Accent: the one thing each chart is about | Accent 1 | `#4B3621` | 10.6 : 1 |
| Everything else; secondary text | Accent 2 / Text 2 | `#56687D` | 5.4 : 1 |
| Titles, body text | Text 1 | `#1F1A14` | 16.2 : 1 |
| Borders and gridlines only | Accent 4 | `#E2DACE` | 1.3 : 1 |
| Labels inside bars | Background 1 | `#FFFFFF` | 11.4 : 1 on accent, 5.7 : 1 on grey |

Fonts: Georgia (headings), Segoe UI (body). Thin cells (n < 100) are labelled
"(thin)" in text; a lighter grey fails 3 : 1 on this background.

---

## 3. Pages

Each page: a verb-sentence title, a scope line, the visuals, and a footer with
base, method and source model.

### `1 Funnel` (Setting)

**Title:** "1.4% of sessions end in a purchase, and most are lost before anyone
views a product."

- **Tiles:** 355,592 sessions; session conversion rate 1.36% (95% CI 1.32% – 1.40%); 4,843 purchasing sessions.
- **Funnel bars:** sessions reaching each step, labelled with count and reach rate. The accent is on "Viewed a product": 78.5% of sessions never get there, the largest loss in the funnel.
- **Step table:** conversion from the previous step, its 95% Wilson interval, and the share that skipped the previous step (46.2% at began checkout).
- **Note:** the add-to-cart step doesn't nest (46% of checkouts and 41% of purchases have no add-to-cart event).

### `2 Leaks` (Guilty party)

**Title:** "Referral sessions convert above the rest; organic, cpc and 'other'
convert below."

- **Step selector** (`C5`, data validation on `calc!P2:P8`) drives the chart, its title and the table.
- **Gap chart:** each segment's rate minus the rest of sessions' rate, with 95% Newcombe whiskers, on a two-level axis (device / continent / channel). Brown where the interval excludes zero, grey where it doesn't.
- **Table:** sessions, rate and CI, gap and CI; rows whose interval excludes zero in bold (conditional format).
- **Note:** the "unknown" channel (source deleted from the export) converts at 3.2% vs 1.3% for the rest; likely an anonymisation artefact, not to be acted on.

### `3 Time & Products` (Narrow in)

**Title:** "Conversion peaked at 2.0% in early December and fell to 0.6% in the
first week of January."

- **Weekly trend:** conversion line (brown) with Wilson whiskers over weekly sessions (grey, right axis); peak 07 Dec 2.01%, low 04 Jan 0.56%. The one-day first week is left out.
- **Product funnel:** view-to-purchase rate for the 12 most-viewed categories with Wilson whiskers. Accent on men's / unisex apparel: 5.0% of viewing sessions buy, 35% of item revenue.
- **Note:** products are matched across steps by name, because categories and item IDs differ between view and purchase events.

---

## 4. Refresh and QA

- **Refresh:** Data → Refresh All. The BigQuery sandbox expires tables 60 days after each `dbt build`; if the refresh errors with "table not found", run `dbt build` first.
- **Parity:** `dbt build` runs `assert_dashboard_parity`, which warns if any number in the titles, tiles or notes above has drifted from the marts.
- **Checked on build:** every rate shows its interval; every band follows its `*_sort` column; one accent per chart; no text in a series colour; page 2 says "Association, not cause".
