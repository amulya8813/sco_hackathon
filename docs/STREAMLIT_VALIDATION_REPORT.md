# Streamlit Validation Report

## Application: SCO Supply Chain Analytics
**Date:** 2026-09-28  
**Database:** SCO_HACKATHON  
**Schemas used:** SCO_GOLD (metrics), SCO_GOVERNANCE (DQ), SCO_SILVER (dimensions for ontology/forecasting)

---

## 1. Table & Column Verification

| Gold Table | Status | Notes |
|---|---|---|
| GLD_METRIC_OTD | Verified | MONTH_START_DATE, SUPPLIER_ID, SUPPLIER_NAME, CUSTOMER_REGION, PART_CATEGORY, LINES_DUE, LINES_ON_TIME, LINES_LATE, ON_TIME_DELIVERY_RATE_PCT, AVG_DAYS_LATE |
| GLD_METRIC_FILL_RATE | Verified | MONTH_START_DATE, CUSTOMER_SERVICE_TIER, PART_CATEGORY, WAREHOUSE_ID, WAREHOUSE_NAME, UNITS_FULFILLED, UNITS_ORDERED, FILL_RATE_PCT |
| GLD_METRIC_DOI | Verified | AGGREGATION_LEVEL, SNAPSHOT_DATE, PART_ID, PART_NUMBER, PART_NAME, PART_CATEGORY, WAREHOUSE_ID, WAREHOUSE_NAME, QUANTITY_ON_HAND, TRAILING_30_DAY_DEMAND, AVG_DAILY_DEMAND, DAYS_OF_INVENTORY, OBSOLESCENCE_REVIEW_FLAG |
| GLD_METRIC_LANDED_COST | Verified | MONTH_START_DATE, SUPPLIER_ID, SUPPLIER_NAME, ROUTE_ID, ROUTE_NAME, PART_CATEGORY, TOTAL_UNITS, PURCHASE/FREIGHT/INSURANCE/DUTIES/HANDLING_COST_PER_UNIT_USD, LANDED_COST_PER_UNIT_USD |
| GLD_SUPPLIER_SCORECARD | Verified | SUPPLIER_ID, SUPPLIER_NAME, MONTH_START_DATE, ON_TIME_DELIVERY_RATE_PCT, FILL_RATE_PCT, AVG_LANDED_COST_PER_UNIT_USD, RISK_SCORE, ESG_SCORE, COMPLIANCE_MATCH_COUNT, ORDER_VOLUME, SPEND_USD |
| GLD_INVENTORY_HEALTH | Verified | PART_ID, PART_NUMBER, PART_NAME, PART_CATEGORY, WAREHOUSE_ID, WAREHOUSE_NAME, SNAPSHOT_DATE, QUANTITY_ON_HAND, QUANTITY_AVAILABLE, REORDER_POINT, SAFETY_STOCK_LEVEL, AVG_DAILY_DEMAND, DAYS_OF_INVENTORY, DAYS_OF_COVER, STOCKOUT_FLAG, BELOW_REORDER_FLAG, EXCESS_FLAG, OBSOLESCENCE_REVIEW_FLAG |
| GLD_DEMAND_HISTORY | Verified | PART_ID, MONTH_START_DATE, TOTAL_QUANTITY, ORDER_COUNT |
| GLD_METRIC_DEFINITIONS | Verified | METRIC_NAME, GOVERNED_DEFINITION, FORMULA, GRAIN, UNIT, TARGET_RANGE, OWNING_DOMAIN, REFRESHED_AT |
| GLD_SHIPMENT_PERFORMANCE | Verified | ROUTE_ID, ROUTE_NAME, CARRIER_ID, CARRIER_NAME, MONTH_START_DATE, SHIPMENT_COUNT, ON_TIME_ARRIVAL_RATE_PCT, AVG_TRANSIT_VARIANCE_DAYS, AVG_FREIGHT_COST_PER_KG_USD |
| GLD_RISK_EXPOSURE | Verified | SUPPLIER_ID, SUPPLIER_NAME, MONTH_START_DATE, RISK_SCORE, ESG_SCORE, SANCTIONS_MATCH_COUNT, SPEND_AT_RISK_USD, SOLE_SOURCE_PART_COUNT |
| GLD_PIPELINE_AUDIT | Verified | AUDIT_ID, AUDIT_EVENT_TS, TASK_NAME, OBJECT_SCHEMA, OBJECT_NAME, OBJECT_TYPE, AUDIT_EVENT, STATUS, ROWS_AFFECTED, DETAILS |

## 2. Calculation Verification

| Metric | Formula Used | Correct? |
|---|---|---|
| OTD | `SUM(LINES_ON_TIME) / NULLIF(SUM(LINES_DUE), 0) * 100` | Yes — ratio of sums, never average of percentages |
| Fill Rate | `SUM(UNITS_FULFILLED) / NULLIF(SUM(UNITS_ORDERED), 0) * 100` | Yes |
| DOI | `SUM(QUANTITY_ON_HAND) / NULLIF(SUM(AVG_DAILY_DEMAND), 0)` | Yes — filtered to PART_WAREHOUSE level |
| Landed Cost | `SUM(LANDED_COST_PER_UNIT_USD * TOTAL_UNITS) / NULLIF(SUM(TOTAL_UNITS), 0)` | Yes — quantity-weighted |

## 3. Semantic View Alignment

- Semantic view `SV_SUPPLY_CHAIN` uses identical formulas in its metric definitions
- Cortex Analyst chat queries are routed through this semantic view
- Persona-equivalent questions resolve to the same governed calculation

## 4. NULL / Empty Dataset Safety

- All KPI calculations use `NULLIF()` to prevent division by zero
- All data loads wrapped in try/except with user-facing fallback messages
- Empty DataFrames checked before rendering charts

## 5. Governance Compliance

- All UI metrics sourced exclusively from SCO_GOLD tables
- SCO_SOURCE and SCO_BRONZE are never queried from the Streamlit UI
- Metric definitions displayed from `GLD_METRIC_DEFINITIONS`
- Source table citations shown on every chart

## 6. Security

- No credentials, tokens, or connection strings in code
- Uses `st.connection("snowflake")` with platform-managed identity
- No raw `snowflake.connector` usage
- Respects Snowflake RBAC via the active session

## 7. Missing Dependencies

| Object | Status | Fallback |
|---|---|---|
| Cortex ML FORECAST model | Not found | Linear trend extrapolation shown; page documents the gap |
| Cortex Agent | Not found (no agents in database) | Cortex Analyst via `_snowflake.send_snow_api_request` used instead |
| Jira MCP integration | Not detected | Alert page notes absence; audit trail shown from GLD_PIPELINE_AUDIT |
| Interactive graph component | Not available in SiS | ASCII/text entity-relationship diagram with entity detail browser |
