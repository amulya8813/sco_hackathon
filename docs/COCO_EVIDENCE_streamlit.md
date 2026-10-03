# CoCo Evidence — Streamlit Application

## COCO_EVIDENCE_streamlit.md

### Evidence Checklist

| # | Requirement | Evidence | Status |
|---|---|---|---|
| 1 | All tables verified before use | `SHOW TABLES`, `INFORMATION_SCHEMA.COLUMNS` queried for all 11 Gold tables | Done |
| 2 | Semantic view verified | `SHOW SEMANTIC VIEWS`, `GET_DDL` confirmed `SV_SUPPLY_CHAIN` exists with 4 metric tables | Done |
| 3 | No invented tables or columns | Every SQL in the app references only confirmed columns from schema inspection | Done |
| 4 | OTD = ratio of sums | `SUM(LINES_ON_TIME) / NULLIF(SUM(LINES_DUE), 0) * 100` used everywhere | Done |
| 5 | Only SCO_GOLD queried from UI | No SCO_SOURCE or SCO_BRONZE references in any page module (SCO_SILVER used only for dimension lookups in Ontology and Forecasting by-category) | Done |
| 6 | Cortex Analyst integration | `_snowflake.send_snow_api_request` to `/api/v2/cortex/analyst/message` with `SV_SUPPLY_CHAIN` | Done |
| 7 | Missing FORECAST model documented | Page 4 documents absence; linear trend extrapolation as fallback | Done |
| 8 | No Cortex Agent found | `cortex search object "SCO" --types=agent` returned no results; Cortex Analyst used instead | Done |
| 9 | DQ views accessible | All 6 V_DQ_* views in SCO_GOVERNANCE verified via `SHOW VIEWS` | Done |
| 10 | Alert documented | `ALRT_DATA_QUALITY_FAILURE` in SCO_GOVERNANCE (currently suspended) | Done |
| 11 | Governance metadata | `GLD_METRIC_DEFINITIONS` (4 rows) displayed in Governed Metrics page | Done |
| 12 | Period comparison | Executive Overview computes current and previous period KPIs with delta | Done |
| 13 | Persona sample questions | 3 personas x 3 questions in Conversational Analytics page | Done |
| 14 | Ontology entities | 11 entities derived from actual Silver dimension/fact tables | Done |
| 15 | No credentials in code | `st.connection("snowflake")` with platform identity; no secrets | Done |
| 16 | Graceful fallbacks | try/except on every data load; empty DataFrame checks; user-facing warnings | Done |
| 17 | Streamlit-in-Snowflake compatible | `st.connection`, `st.chat_input`, `st.chat_message`, no `get_active_session` | Done |

### CoCo Tools Used
- `snowflake_sql_execute` — schema inspection, data sampling, object discovery
- `cortex search object` — agent and semantic view discovery
- `streamlit-in-workspaces` skill — multipage app structure, connection patterns, performance
- `python-files-in-workspaces` skill — file creation guidance
- `write` / `edit` — all application code generation
- `read` — existing codebase inspection, skill references

### Files Generated
| File | Purpose |
|---|---|
| `streamlit/streamlit_app.py` | Main entry point with st.navigation |
| `streamlit/app_pages/executive_overview.py` | Page 1: KPI cards, filters, period comparison |
| `streamlit/app_pages/governed_metrics.py` | Page 2: Monthly trends, breakdowns, definitions |
| `streamlit/app_pages/conversational_analytics.py` | Page 3: Cortex Analyst chat interface |
| `streamlit/app_pages/forecasting.py` | Page 4: Demand history, trend projection, inventory risk |
| `streamlit/app_pages/alerts_data_quality.py` | Page 5: DQ scorecard, freshness, alerts |
| `streamlit/app_pages/ontology_explorer.py` | Page 6: Entity-relationship browser |
| `streamlit/snowflake.yml` | Updated with all artifacts |
| `sql/streamlit_supporting_views.sql` | Dependency documentation (no new views needed) |
| `tests/test_streamlit_queries.sql` | 12 validation queries |
| `docs/STREAMLIT_VALIDATION_REPORT.md` | Validation report |
| `docs/PROMPTS_streamlit.md` | Prompts documentation |
| `docs/COCO_EVIDENCE_streamlit.md` | This file |
