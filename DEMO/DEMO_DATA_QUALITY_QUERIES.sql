--------------------------------------------------------------------------------
-- Demo Data Quality Queries — Validated
-- DEMO/DEMO_DATA_QUALITY_QUERIES.sql
--------------------------------------------------------------------------------

-- ═══════════════════════════════════════════════════════════════════════
-- 1. OVERALL DQ SUMMARY — for demo narration
-- ═══════════════════════════════════════════════════════════════════════
SELECT QUALITY_DIMENSION,
    COUNT(*) AS TOTAL, COUNT_IF(PASSED_FLAG) AS PASSED, COUNT_IF(NOT PASSED_FLAG) AS FAILED
FROM SCO_HACKATHON.SCO_GOVERNANCE.DQ_CHECK_RESULT
GROUP BY QUALITY_DIMENSION ORDER BY QUALITY_DIMENSION;

-- ═══════════════════════════════════════════════════════════════════════
-- 2. METRIC RECONCILIATION — All 4 metrics pass
-- ═══════════════════════════════════════════════════════════════════════
SELECT CHECK_NAME, PASSED_FLAG, OBSERVED_VALUE, DETAILS
FROM SCO_HACKATHON.SCO_GOVERNANCE.DQ_CHECK_RESULT
WHERE QUALITY_DIMENSION IN ('Metric Reconciliation', 'RECONCILIATION')
ORDER BY CHECK_NAME;

-- ═══════════════════════════════════════════════════════════════════════
-- 3. GRAPH QUALITY CHECKS — All pass
-- ═══════════════════════════════════════════════════════════════════════
SELECT CHECK_NAME, PASSED_FLAG, OBSERVED_VALUE, DETAILS
FROM SCO_HACKATHON.SCO_GOVERNANCE.DQ_CHECK_RESULT
WHERE QUALITY_DIMENSION IN ('Graph Quality', 'GRAPH')
ORDER BY CHECK_NAME;

-- ═══════════════════════════════════════════════════════════════════════
-- 4. FAILED CHECKS — Only freshness (expected)
-- ═══════════════════════════════════════════════════════════════════════
SELECT CHECK_NAME, QUALITY_DIMENSION, SEVERITY, DETAILS
FROM SCO_HACKATHON.SCO_GOVERNANCE.DQ_CHECK_RESULT
WHERE PASSED_FLAG = FALSE
ORDER BY CHECK_NAME;

-- ═══════════════════════════════════════════════════════════════════════
-- 5. ALERT EVENTS SUMMARY — Show monitoring in action
-- ═══════════════════════════════════════════════════════════════════════
SELECT ALERT_CATEGORY, ALERT_TYPE, SEVERITY, STATUS, COUNT(*) AS CNT
FROM SCO_HACKATHON.SCO_MONITORING.ALERT_EVENT
WHERE STATUS = 'OPEN'
GROUP BY ALL ORDER BY CNT DESC;
