# Demo Asset Checklist

## Pre-Demo Verification (run 30 minutes before)

| # | Asset | How to Verify | Status |
|---|-------|--------------|--------|
| 1 | Streamlit app loads | Open snow:// URL, verify 7 pages in sidebar | ☐ |
| 2 | Executive Overview KPIs load | Navigate to page, verify 4 KPI cards show values | ☐ |
| 3 | Governed Metrics page loads | Expand metric definitions, verify OTD formula visible | ☐ |
| 4 | Ask Analyst page loads | Verify chat input visible, sample questions shown | ☐ |
| 5 | Ontology Explorer loads | Verify entity relationship text and selector | ☐ |
| 6 | Knowledge Graph page loads | Verify summary metrics (166K nodes, 932K edges) | ☐ |
| 7 | Alerts & DQ page loads | Verify scorecard section loads | ☐ |
| 8 | OTD = 82.45% | Run DEMO_SQL_QUERIES.sql #1 | ☐ |
| 9 | Three personas = same value | Run DEMO_SQL_QUERIES.sql #3 | ☐ |
| 10 | Graph trace works | Run DEMO_GRAPH_QUERIES.sql #2 | ☐ |
| 11 | DQ results populated | Run DEMO_DATA_QUALITY_QUERIES.sql #1 | ☐ |
| 12 | Alert events exist | Check ALERT_EVENT table (expect 1,816 rows) | ☐ |
| 13 | Semantic view exists | SHOW SEMANTIC VIEWS IN SCHEMA SCO_HACKATHON.SCO_GOLD | ☐ |
| 14 | COMPUTE_WH is running | ALTER WAREHOUSE COMPUTE_WH RESUME IF SUSPENDED | ☐ |

## Files to Have Open

| # | File/Tab | Purpose |
|---|----------|---------|
| 1 | Streamlit app (browser tab) | Main demo interface |
| 2 | Snowsight SQL worksheet (browser tab) | Backup queries |
| 3 | DEMO_SQL_QUERIES.sql (in worksheet) | Pre-loaded backup |
| 4 | Architecture slide/PDF | For 0:20 section |
| 5 | Timer app | 3-minute countdown |

## Critical Objects to Verify

| Schema | Key Objects |
|--------|------------|
| SCO_GOLD | GLD_METRIC_OTD (108,288 rows), GLD_METRIC_DEFINITIONS (4 rows), SV_SUPPLY_CHAIN |
| SCO_GRAPH | V_ALL_NODES (166,530), V_ALL_EDGES (932,013) |
| SCO_GOVERNANCE | DQ_CHECK_RESULT (80 rows), V_DQ_SCORECARD |
| SCO_MONITORING | ALERT_EVENT (1,816 rows) |

## Do NOT Show
- Streamlit Forecasting page
- Any Cortex ML FORECAST reference
- Live Jira ticket creation
- Raw source data (SCO_SOURCE) for business analytics
