# Demo Backup Plan

## Failure Scenario 1: Streamlit App Won't Load

**Fallback:**
- Run DEMO_SQL_QUERIES.sql directly in Snowsight SQL worksheet
- Show OTD = 82.45% via direct query
- Show graph summary via DEMO_GRAPH_QUERIES.sql
- Show DQ results via DEMO_DATA_QUALITY_QUERIES.sql

**Dialogue:** "The Streamlit app is our primary interface, but the governed data is accessible directly. Let me show you the same results through SQL."

## Failure Scenario 2: Cortex Analyst Timeout or Wrong Answer

**Fallback:**
- Skip live chat input
- Show pre-validated persona consistency query (DEMO_SQL_QUERIES.sql #3)
- All three return 82.45%

**Dialogue:** "We validated before the demo that all three persona questions — Planning, Procurement, and Logistics — return 82.45% against the governed semantic view."

## Failure Scenario 3: Knowledge Graph Query Slow

**Fallback:**
- Pre-run DEMO_GRAPH_QUERIES.sql #2 and keep results visible
- Supplier 1 → 15 parts → 585 orders → 984 shipments → 356 customers

**Dialogue:** "The multi-hop trace shows that a single supplier disruption can cascade to 356 customers through 984 shipments."

## Failure Scenario 4: Data Quality Results Missing

**Fallback:**
- Run DEMO_DATA_QUALITY_QUERIES.sql #1 live
- Show: 74 passed, 6 freshness failures (expected)

**Dialogue:** "We ran 80 quality checks across 10 dimensions. All passed except 6 freshness checks — expected because this is demo data."

## Failure Scenario 5: Jira MCP Not Configured

**Fallback:**
- Show DEMO_JIRA_DRY_RUN.md with the JSON payload
- Show ALERT_EVENT table with 1,816 open alerts

**Dialogue:** "The Jira integration works in dry-run mode. Here is the exact ticket payload that would be created, including deduplication to prevent duplicates."

## Failure Scenario 6: Network/Permission Issue

**Fallback:**
- Use screenshots from pre-validation
- Present from the PowerPoint deck
- Reference validation report: docs/DATA_QUALITY_VALIDATION_REPORT.md

## Statements to AVOID in All Scenarios
- Do NOT mention Cortex ML Forecasting
- Do NOT claim live Jira tickets were created (unless verified)
- Do NOT claim 100% pass rate (6 checks fail as expected)
- Do NOT claim real-time data (synthetic demo data)
- Do NOT show the Forecasting page in Streamlit
