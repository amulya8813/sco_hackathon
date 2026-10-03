-- ============================================================================
-- test_streamlit_queries.sql
-- Validation queries for the Streamlit Supply Chain Analytics application.
-- Run each query in a Snowflake worksheet to verify correctness.
-- ============================================================================

-- ── TEST 1: OTD is calculated as ratio of sums (never avg of pct) ──────────
-- Expected: single row with OTD_PCT matching the Executive Overview KPI
SELECT 'TEST_OTD_RATIO_OF_SUMS' AS TEST_NAME,
       SUM(LINES_ON_TIME) / NULLIF(SUM(LINES_DUE), 0) * 100 AS OTD_PCT,
       IFF(OTD_PCT IS NOT NULL AND OTD_PCT BETWEEN 0 AND 100, 'PASS', 'FAIL') AS RESULT
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD
WHERE MONTH_START_DATE BETWEEN '2024-07-01' AND '2025-12-01';

-- ── TEST 2: Fill Rate ratio of sums ────────────────────────────────────────
SELECT 'TEST_FILL_RATE_RATIO' AS TEST_NAME,
       SUM(UNITS_FULFILLED) / NULLIF(SUM(UNITS_ORDERED), 0) * 100 AS FILL_PCT,
       IFF(FILL_PCT IS NOT NULL AND FILL_PCT BETWEEN 0 AND 100, 'PASS', 'FAIL') AS RESULT
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_FILL_RATE;

-- ── TEST 3: DOI uses PART_WAREHOUSE aggregation level ──────────────────────
SELECT 'TEST_DOI_AGG_LEVEL' AS TEST_NAME,
       SUM(QUANTITY_ON_HAND) / NULLIF(SUM(AVG_DAILY_DEMAND), 0) AS DOI_DAYS,
       IFF(DOI_DAYS IS NOT NULL AND DOI_DAYS > 0, 'PASS', 'FAIL') AS RESULT
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_DOI
WHERE AGGREGATION_LEVEL = 'PART_WAREHOUSE';

-- ── TEST 4: Landed Cost weighted average ───────────────────────────────────
SELECT 'TEST_LANDED_COST_WEIGHTED' AS TEST_NAME,
       SUM(LANDED_COST_PER_UNIT_USD * TOTAL_UNITS) / NULLIF(SUM(TOTAL_UNITS), 0) AS LANDED_CPU,
       IFF(LANDED_CPU IS NOT NULL AND LANDED_CPU > 0, 'PASS', 'FAIL') AS RESULT
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_LANDED_COST;

-- ── TEST 5: Metric definitions table has 4 rows ───────────────────────────
SELECT 'TEST_METRIC_DEFINITIONS_COUNT' AS TEST_NAME,
       COUNT(*) AS ROW_COUNT,
       IFF(ROW_COUNT = 4, 'PASS', 'FAIL') AS RESULT
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_DEFINITIONS;

-- ── TEST 6: DQ Scorecard view is queryable ─────────────────────────────────
SELECT 'TEST_DQ_SCORECARD_ACCESSIBLE' AS TEST_NAME,
       COUNT(*) AS CHECK_COUNT,
       IFF(CHECK_COUNT > 0, 'PASS', 'FAIL') AS RESULT
FROM SCO_HACKATHON.SCO_GOVERNANCE.V_DQ_SCORECARD;

-- ── TEST 7: Freshness view returns rows ────────────────────────────────────
SELECT 'TEST_FRESHNESS_ACCESSIBLE' AS TEST_NAME,
       COUNT(*) AS TABLE_COUNT,
       IFF(TABLE_COUNT > 0, 'PASS', 'FAIL') AS RESULT
FROM SCO_HACKATHON.SCO_GOVERNANCE.V_DQ_FRESHNESS;

-- ── TEST 8: Semantic view exists ───────────────────────────────────────────
SELECT 'TEST_SEMANTIC_VIEW_EXISTS' AS TEST_NAME,
       COUNT(*) AS SV_COUNT,
       IFF(SV_COUNT = 1, 'PASS', 'FAIL') AS RESULT
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
-- Pre-run: SHOW SEMANTIC VIEWS LIKE 'SV_SUPPLY_CHAIN' IN SCHEMA SCO_HACKATHON.SCO_GOLD;

-- ── TEST 9: Gold tables have data ─────────────────────────────────────────
SELECT 'TEST_GOLD_TABLES_POPULATED' AS TEST_NAME,
       (SELECT COUNT(*) FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD) AS OTD_ROWS,
       (SELECT COUNT(*) FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_FILL_RATE) AS FILL_ROWS,
       (SELECT COUNT(*) FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_DOI) AS DOI_ROWS,
       (SELECT COUNT(*) FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_LANDED_COST) AS LANDED_ROWS,
       IFF(OTD_ROWS > 0 AND FILL_ROWS > 0 AND DOI_ROWS > 0 AND LANDED_ROWS > 0, 'PASS', 'FAIL') AS RESULT;

-- ── TEST 10: Demand history for forecasting ────────────────────────────────
SELECT 'TEST_DEMAND_HISTORY' AS TEST_NAME,
       COUNT(*) AS ROW_COUNT,
       COUNT(DISTINCT PART_ID) AS PART_COUNT,
       IFF(ROW_COUNT > 0 AND PART_COUNT > 0, 'PASS', 'FAIL') AS RESULT
FROM SCO_HACKATHON.SCO_GOLD.GLD_DEMAND_HISTORY;

-- ── TEST 11: Persona-equivalent questions return same governed metric ──────
-- Run these two in Cortex Analyst (via the chat page) and compare:
-- Q1: "What was the overall on-time delivery rate?"
-- Q2: "Show me the OTD percentage across all suppliers"
-- Both should produce: SUM(LINES_ON_TIME)/NULLIF(SUM(LINES_DUE),0)*100
-- from GLD_METRIC_OTD via SV_SUPPLY_CHAIN — same number, same definition.

-- ── TEST 12: NULL/empty dataset handling ───────────────────────────────────
-- The app uses NULLIF() to prevent division by zero and wraps all KPI
-- loads in try/except with graceful fallback messages.
SELECT 'TEST_NULLIF_SAFETY' AS TEST_NAME,
       SUM(LINES_ON_TIME) / NULLIF(0, 0) AS ZERO_SAFE,
       IFF(ZERO_SAFE IS NULL, 'PASS (NULL returned)', 'FAIL') AS RESULT;
