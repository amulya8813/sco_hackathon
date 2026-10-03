--------------------------------------------------------------------------------
-- Supply Chain Ontology — Data Quality: Metric Reconciliation Tests
-- tests/test_metric_reconciliation.sql
--------------------------------------------------------------------------------

-- TEST 1: OTD uses ratio-of-sums, not average-of-percentages
-- The two should differ — proving ratio-of-sums is the implemented formula
WITH comparison AS (
    SELECT
        ROUND(SUM(LINES_ON_TIME) / NULLIF(SUM(LINES_DUE), 0) * 100, 4) AS RATIO_OF_SUMS,
        ROUND(AVG(ON_TIME_DELIVERY_RATE_PCT), 4) AS AVG_OF_PCT
    FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD
)
SELECT 'FAIL: OTD ratio-of-sums equals avg-of-pct (formula not distinguishable)' AS TEST
FROM comparison
WHERE ABS(RATIO_OF_SUMS - AVG_OF_PCT) < 0.001 AND RATIO_OF_SUMS <> AVG_OF_PCT;

-- TEST 2: OTD row-level recalc matches stored value
SELECT 'FAIL: OTD row mismatch' AS TEST, COUNT(*) AS MISMATCHED_ROWS
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD
WHERE ABS(ON_TIME_DELIVERY_RATE_PCT - ROUND(LINES_ON_TIME * 100.0 / NULLIF(LINES_DUE, 0), 4)) > 0.01
HAVING COUNT(*) > 0;

-- TEST 3: Fill Rate recalc matches
SELECT 'FAIL: Fill Rate row mismatch' AS TEST, COUNT(*) AS MISMATCHED_ROWS
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_FILL_RATE
WHERE ABS(FILL_RATE_PCT - ROUND(UNITS_FULFILLED * 100.0 / NULLIF(UNITS_ORDERED, 0), 4)) > 0.01
HAVING COUNT(*) > 0;

-- TEST 4: DOI recalc matches
SELECT 'FAIL: DOI row mismatch' AS TEST, COUNT(*) AS MISMATCHED_ROWS
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_DOI
WHERE AGGREGATION_LEVEL = 'PART_WAREHOUSE'
  AND DAYS_OF_INVENTORY IS NOT NULL
  AND ABS(DAYS_OF_INVENTORY - ROUND(QUANTITY_ON_HAND / NULLIF(AVG_DAILY_DEMAND, 0), 4)) > 0.01
HAVING COUNT(*) > 0;

-- TEST 5: Landed Cost component sum
SELECT 'FAIL: Landed Cost component mismatch' AS TEST, COUNT(*) AS MISMATCHED_ROWS
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_LANDED_COST
WHERE ABS(LANDED_COST_PER_UNIT_USD - (PURCHASE_COST_PER_UNIT_USD + FREIGHT_COST_PER_UNIT_USD +
    INSURANCE_COST_PER_UNIT_USD + DUTIES_COST_PER_UNIT_USD + HANDLING_COST_PER_UNIT_USD)) > 0.01
HAVING COUNT(*) > 0;

-- TEST 6: Zero-denominator OTD handling
SELECT 'FAIL: non-null OTD when lines_due=0' AS TEST, COUNT(*) AS VIOLATIONS
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD
WHERE LINES_DUE = 0 AND ON_TIME_DELIVERY_RATE_PCT IS NOT NULL
HAVING COUNT(*) > 0;
