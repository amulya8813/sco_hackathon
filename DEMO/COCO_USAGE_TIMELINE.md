# CoCo Usage Timeline

## Chronological Evidence

| # | Phase | CoCo Action | Files Generated | Key Evidence |
|---|-------|-------------|-----------------|-------------|
| 1 | Source Design | Schema inspection, DDL generation | sql/01_create_source_tables.sql | 24 tables, 1,058 lines of DDL |
| 2 | Validation | Source layer verification queries | sql/02_validate_source_layer.sql | PK, FK, column-type validation |
| 3 | Synthetic Data | Deterministic data generation | sql/03_generate_synthetic_data.sql | ~1M rows across 24 tables, HASH()-based determinism |
| 4 | Data Validation | Post-load row count verification | sql/04_validate_synthetic_data.sql | All target counts matched |
| 5 | Bronze Layer | Mirror-table creation | sql/05_bronze_layer.sql | 24 BRZ_ dynamic tables |
| 6 | Silver Layer | Conformed entity creation | sql/06_silver_layer.sql | 18 SLV_ dynamic tables, DQ score column |
| 7 | Gold Layer | Governed metric views | sql/07_gold_layer.sql | 11 Gold objects, KPI_BUSINESS_GLOSSARY |
| 8 | UDFs & Tasks | SQL functions, streams, task graph | sql/08_udfs_streams_tasks.sql | 6 UDFs, 5 streams, 4 tasks |
| 9 | DMF Framework | Initial DQ attachment design | sql/09_data_quality_dmfs.sql | DMF attachments, governance views, alert |
| 10 | Semantic View | Cortex Analyst integration | semantic_views/sv_supply_chain.sql | Multi-fact star model, ratio-of-sums |
| 11 | Streamlit App | 7-page application | streamlit-v2/ (8 files) | Executive Overview through Knowledge Graph |
| 12 | Knowledge Graph | 40 views in SCO_GRAPH | sql/10-14 (5 files) | 166K nodes, 932K edges, 0 orphans |
| 13 | Jira MCP | Alert integration | sql/15-19, scripts/, config/ | 1,816 alerts, dry-run handler |
| 14 | Data Quality FW | Comprehensive DQ framework | sql/25-33, tests/ (9+3 files) | 80 checks, 74 pass, 4/4 metric reconcile |
| 15 | Demo Prep | Validated demo materials | DEMO/ (13 files) | 3-min script, all queries validated |

## Key Defects Found and Fixed by CoCo

| # | Issue | CoCo Action | Fix |
|---|-------|-------------|-----|
| 1 | FRESHNESS + TIMESTAMP_NTZ incompatibility | Identified during DMF attachment | Used FRESHNESS ON (pk_column) fallback |
| 2 | SNAPSHOT_DATE vs MONTH_START_DATE in DOI KPI | Error in executive_overview.py | Added .replace("MONTH_START_DATE", "SNAPSHOT_DATE") |
| 3 | cortex_analyst_app.py in snowflake.yml but missing from streamlit-v2 | Detected during file review | Removed ghost reference from artifacts |
| 4 | st.metric(border=True) compatibility | Identified as potential runtime issue | Documented; works on SPCS runtime |
| 5 | OTD detection window vs synthetic data range | Detection queries used rolling 3-month from current date (Sep 2026) but data ends Dec 2025 | Adjusted to use actual data window |

## CoCo Tools Used

- `snowflake_sql_execute` — Schema creation, validation, query execution
- `write` / `edit` — File generation and modification
- `read` / `glob` — Codebase discovery
- `task` (Explore agent) — Parallel file reading
- `bash` — MCP discovery, file system operations
- `skill` — Python file workflows, SQL authoring

## Total Artifacts Generated

| Category | Count |
|----------|-------|
| SQL scripts | 28 |
| Streamlit pages | 7 |
| Test suites | 6 |
| Documentation | 18 |
| Config files | 1 |
| Python scripts | 1 |
| Demo materials | 13 |
| **Total files** | **74** |

## Database Objects Created

| Schema | Objects |
|--------|---------|
| SCO_SOURCE | 24 tables |
| SCO_BRONZE | 24 dynamic tables |
| SCO_SILVER | 18 dynamic tables, 5 streams |
| SCO_GOLD | 11 tables, 1 semantic view, 4 tasks |
| SCO_GRAPH | 40 views |
| SCO_GOVERNANCE | 10 views/tables, 5 custom DMFs |
| SCO_MONITORING | 5 tables/views |
| **Total** | **~142 objects** |
