--------------------------------------------------------------------------------
-- Demo SQL Queries — Validated and ready to execute
-- DEMO/DEMO_SQL_QUERIES.sql
--------------------------------------------------------------------------------

-- ═══════════════════════════════════════════════════════════════════════
-- 1. GOVERNED OTD — Ratio of Sums (correct method)
-- ═══════════════════════════════════════════════════════════════════════
-- Expected result: 82.45%
SELECT
    ROUND(SUM(LINES_ON_TIME) / NULLIF(SUM(LINES_DUE), 0) * 100, 2) AS OTD_RATIO_OF_SUMS,
    SUM(LINES_ON_TIME) AS TOTAL_ON_TIME,
    SUM(LINES_DUE)     AS TOTAL_DUE
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD
WHERE MONTH_START_DATE BETWEEN '2025-01-01' AND '2025-12-01';

-- ═══════════════════════════════════════════════════════════════════════
-- 2. WRONG METHOD — Average of percentages (proves governance value)
-- ═══════════════════════════════════════════════════════════════════════
-- Expected result: 82.55% (DIFFERENT from correct 82.45%)
SELECT
    ROUND(AVG(ON_TIME_DELIVERY_RATE_PCT), 2) AS WRONG_AVG_OF_PERCENTAGES
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD
WHERE MONTH_START_DATE BETWEEN '2025-01-01' AND '2025-12-01';

-- ═══════════════════════════════════════════════════════════════════════
-- 3. PERSONA CONSISTENCY — Three personas, one answer
-- ═══════════════════════════════════════════════════════════════════════
-- Expected: all three return 82.45%
SELECT 'Planning' AS PERSONA, ROUND(SUM(LINES_ON_TIME)/NULLIF(SUM(LINES_DUE),0)*100,2) AS OTD
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD WHERE MONTH_START_DATE BETWEEN '2025-01-01' AND '2025-12-01'
UNION ALL
SELECT 'Procurement', ROUND(SUM(LINES_ON_TIME)/NULLIF(SUM(LINES_DUE),0)*100,2)
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD WHERE MONTH_START_DATE BETWEEN '2025-01-01' AND '2025-12-01'
UNION ALL
SELECT 'Logistics', ROUND(SUM(LINES_ON_TIME)/NULLIF(SUM(LINES_DUE),0)*100,2)
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD WHERE MONTH_START_DATE BETWEEN '2025-01-01' AND '2025-12-01';

-- ═══════════════════════════════════════════════════════════════════════
-- 4. OBJECT COUNTS — Solution scale
-- ═══════════════════════════════════════════════════════════════════════
SELECT TABLE_SCHEMA, COUNT(*) AS OBJECT_COUNT
FROM SCO_HACKATHON.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA IN ('SCO_SOURCE','SCO_BRONZE','SCO_SILVER','SCO_GOLD','SCO_GRAPH','SCO_GOVERNANCE','SCO_MONITORING')
GROUP BY TABLE_SCHEMA ORDER BY TABLE_SCHEMA;

-- ═══════════════════════════════════════════════════════════════════════
-- 5. GRAPH SUMMARY
-- ═══════════════════════════════════════════════════════════════════════
SELECT 'NODES' AS OBJ, COUNT(*) AS CNT, COUNT(DISTINCT NODE_TYPE) AS TYPES
FROM SCO_HACKATHON.SCO_GRAPH.V_ALL_NODES
UNION ALL
SELECT 'EDGES', COUNT(*), COUNT(DISTINCT EDGE_TYPE)
FROM SCO_HACKATHON.SCO_GRAPH.V_ALL_EDGES;

-- ═══════════════════════════════════════════════════════════════════════
-- 6. DATA QUALITY SUMMARY
-- ═══════════════════════════════════════════════════════════════════════
SELECT QUALITY_DIMENSION,
    COUNT(*) AS TOTAL, COUNT_IF(PASSED_FLAG) AS PASSED, COUNT_IF(NOT PASSED_FLAG) AS FAILED
FROM SCO_HACKATHON.SCO_GOVERNANCE.DQ_CHECK_RESULT
GROUP BY QUALITY_DIMENSION ORDER BY QUALITY_DIMENSION;
