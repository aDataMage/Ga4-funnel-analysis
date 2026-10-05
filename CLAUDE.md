# Project conventions

Scaffolded from `telco_churn` (a finished portfolio project). These are the
conventions that project settled on — follow them unless told otherwise.

## Stack

- **Warehouse:** BigQuery. **Transformation:** dbt on the Fusion engine (2.x),
  run as `dbt` (installed at `~/.local/bin/dbt.exe`). **Checks:** Python in a
  project venv (`requirements.txt`) for ad-hoc profiling queries. **Delivery:**
  an Excel dashboard over Power Query (`reports/`), Markdown (writing).
- Credentials live in `~/.dbt/profiles.yml` and `.env` — never in the repo.
  `load_dotenv()` only finds `.env` from inside the repo; scripts elsewhere
  must pass its path.

## dbt

- **Staging:** one view per source table, `stg_<source>__<table>`. Rename to
  snake_case, lower-case every string column (booleans stay as they land —
  `lower()` on a BOOL fails static analysis). A dated header comment records
  the grain, what was dropped and why.
- **One YAML per model**, same name as the model. Every column described.
  Generic tests use `data_tests:` with parameters under `arguments:` (Fusion
  syntax).
- **Marts** are tables: `fct_` (one row per entity), `dim_`, `rpt_`
  (pre-aggregated for a specific deliverable). Every band carries a `*_sort`
  column. Outcome flags are integers so `SUM` counts and `AVG` is the rate.
- **Exposures** declare every dashboard (`models/marts/_exposures.yml`), with
  its live `url` once published.
- **Parity test:** `tests/assert_dashboard_parity.sql` checks the dashboard's
  headline numbers against the marts (severity warn). Add a check whenever a
  number goes into a title, tile or note.
- **Every modelling decision** goes in `docs/decision_logs.md`, in its pattern.
- Watch for placeholder strings where you'd expect NULL (e.g. `'none'`):
  `IFNULL` handling silently drops those rows.

## Analysis

- **Every figure states its base** — which customers it counts.
- **Every rate and gap has an interval** (Wilson, Newcombe). The SQL macro in
  `macros/confidence_intervals.sql` matches statsmodels exactly.
- **Test the obvious explanation before accepting it**: ask "if this were the
  cause, what would have to be true?", then check it against its confounder.
- **Association, not cause.** Say so wherever it matters; recommendations come
  with the test that would show whether they work.
- **Flag thin cells** (n < 100) and never let a small-n figure carry a claim
  without its interval.

## Writing

- Dashboards and write-ups follow the **SIGNAL framework**
  (`docs/reference/signal_framework.md`): an explainer dashboard uses S, G and
  N; a memo puts the bottom line and the asks first.
- Titles are sentences with a verb. Invent nothing on the evidence side — no
  made-up quotes, numbers or mechanisms.
- **When asked to add material to existing writing, integrate it — keep the
  existing headline, structure and wording.** Ask before reframing.
- Public-facing pages (README, portfolio) are written for **recruiters and
  employers**: the finding and the proof of skill first, engineering detail
  collapsed.

## Charts and brand

- This project's dashboard palette (Excel theme `GA4 Funnel`, validated on its
  background): base `#FAF7F2`, one accent **`#4B3621`** for the series that
  matters, de-emphasis grey **`#56687D`**, text `#1F1A14`, `#E2DACE` for
  borders and gridlines only, never text. The accent fails on a dark base
  (1.5 : 1), so keep backgrounds light.
- Validate any new colour pairing before shipping it.
- Excel, Power BI Service and Tableau Public can't render the brand fonts:
  Georgia for titles, Segoe UI for text.

## Environment gotchas

- Git Bash heredocs mangle backslash escapes — write scripts containing `\n`,
  `\$` or `\\` with a file-writing tool, not `cat <<EOF`.
- Matplotlib reads two `$` in one string as mathtext — escape as `\$`.
- The project is on the **BigQuery sandbox**: tables and partitions expire 60
  days after creation (partitioned tables on 2020-21 dates lose every
  partition on write), and DML is blocked (no snapshots, no MERGE).
- A dropped connection to the BigQuery Storage API surfaces in dbt as "requires
  the BigQuery Read Session User role". Check DNS / network before IAM.
- Excel: the Google BigQuery ODBC driver ignores a key file path saved in a
  DSN; pass the full connection string instead.
