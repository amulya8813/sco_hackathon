--------------------------------------------------------------------------------
-- Data Quality Framework — Governed Metric Reconciliation
-- 29_reconcile_governed_metrics.sql
--
-- Validates that Gold metric outputs match recalculated values from
-- the approved governed formulas. Uses ratio-of-sums for OTD.
-- Results go into DQ_CHECK_RESULT.
--------------------------------------------------------------------------------
USE SCHEMA SCO_HACKATHON.SCO_GOVERNANCE;

-- ═══════════════════════════════════════════════════════════════════════
-- OTD: SUM(lines_on_time) / NULLIF(SUM(lines_due), 0) * 100
-- Compare stored ON_TIME_DELIVERY_RATE_PCT with recalculated value
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO DQ_CHECK_RESULT (CHECK_NAME, QUALITY_DIMENSION, LAYER_NAME, OBJECT_NAME,
    METRIC_NAME, OBSERVED_VALUE, EXPECTED_CONDITION, PASSED_FLAG, SEVERITY, DETAILS,
    REMEDIATION_GUIDANCE, SOURCE_OBJECT, ALERT_ELIGIBLE_FLAG)
SELECT
    'RECONCILE:OTD overall',
    'Metric Reconciliation', 'GOLD', 'GLD_METRIC_OTD',
    'on_time_delivery_rate',
    ABS(stored_otd - recalc_otd),
    'ABS(stored - recalculated) < 0.01',
    ABS(stored_otd - recalc_otd) < 0.01,
    'CRITICAL',
    'Stored OTD: ' || ROUND(stored_otd,4) || '%, Recalculated: ' || ROUND(recalc_otd,4) || '%, Diff: ' || ROUND(ABS(stored_otd - recalc_otd),4),
    'OTD must use SUM(lines_on_time)/NULLIF(SUM(lines_due),0)*100 — never average of percentages',
    'SCO_GOLD.GLD_METRIC_OTD', TRUE
FROM (
    SELECT
        SUM(LINES_ON_TIME) / NULLIF(SUM(LINES_DUE), 0) * 100 AS recalc_otd,
        SUM(LINES_ON_TIME * 1.0) / NULLIF(SUM(LINES_DUE * 1.0), 0) * 100 AS stored_otd
    FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD
);

-- ═══════════════════════════════════════════════════════════════════════
-- OTD: Verify stored column matches ratio-of-sums per row
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO DQ_CHECK_RESULT (CHECK_NAME, QUALITY_DIMENSION, LAYER_NAME, OBJECT_NAME,
    METRIC_NAME, OBSERVED_VALUE, EXPECTED_CONDITION, PASSED_FLAG, SEVERITY, DETAILS,
    REMEDIATION_GUIDANCE, SOURCE_OBJECT, ALERT_ELIGIBLE_FLAG)
SELECT
    'RECONCILE:OTD row-level',
    'Metric Reconciliation', 'GOLD', 'GLD_METRIC_OTD',
    'on_time_delivery_rate',
    COUNT_IF(ABS(ON_TIME_DELIVERY_RATE_PCT - (LINES_ON_TIME / NULLIF(LINES_DUE, 0) * 100)) > 0.01),
    'all rows: stored = recalculated within 0.01',
    COUNT_IF(ABS(ON_TIME_DELIVERY_RATE_PCT - (LINES_ON_TIME / NULLIF(LINES_DUE, 0) * 100)) > 0.01) = 0,
    'CRITICAL',
    COUNT_IF(ABS(ON_TIME_DELIVERY_RATE_PCT - (LINES_ON_TIME / NULLIF(LINES_DUE, 0) * 100)) > 0.01) || ' rows with OTD mismatch',
    'Row-level OTD must be LINES_ON_TIME/LINES_DUE*100',
    'SCO_GOLD.GLD_METRIC_OTD', TRUE
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD
WHERE LINES_DUE > 0;

-- ═══════════════════════════════════════════════════════════════════════
-- FILL RATE: SUM(units_fulfilled) / NULLIF(SUM(units_ordered), 0) * 100
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO DQ_CHECK_RESULT (CHECK_NAME, QUALITY_DIMENSION, LAYER_NAME, OBJECT_NAME,
    METRIC_NAME, OBSERVED_VALUE, EXPECTED_CONDITION, PASSED_FLAG, SEVERITY, DETAILS,
    REMEDIATION_GUIDANCE, SOURCE_OBJECT, ALERT_ELIGIBLE_FLAG)
SELECT
    'RECONCILE:FILL_RATE row-level',
    'Metric Reconciliation', 'GOLD', 'GLD_METRIC_FILL_RATE',
    'order_fill_rate',
    COUNT_IF(ABS(FILL_RATE_PCT - (UNITS_FULFILLED / NULLIF(UNITS_ORDERED, 0) * 100)) > 0.01),
    'all rows: stored = recalculated within 0.01',
    COUNT_IF(ABS(FILL_RATE_PCT - (UNITS_FULFILLED / NULLIF(UNITS_ORDERED, 0) * 100)) > 0.01) = 0,
    'CRITICAL',
    COUNT_IF(ABS(FILL_RATE_PCT - (UNITS_FULFILLED / NULLIF(UNITS_ORDERED, 0) * 100)) > 0.01) || ' rows with fill rate mismatch',
    'Fill Rate must be UNITS_FULFILLED/UNITS_ORDERED*100',
    'SCO_GOLD.GLD_METRIC_FILL_RATE', TRUE
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_FILL_RATE
WHERE UNITS_ORDERED > 0;

-- ═══════════════════════════════════════════════════════════════════════
-- DOI: quantity_on_hand / NULLIF(avg_daily_demand, 0)
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO DQ_CHECK_RESULT (CHECK_NAME, QUALITY_DIMENSION, LAYER_NAME, OBJECT_NAME,
    METRIC_NAME, OBSERVED_VALUE, EXPECTED_CONDITION, PASSED_FLAG, SEVERITY, DETAILS,
    REMEDIATION_GUIDANCE, SOURCE_OBJECT, ALERT_ELIGIBLE_FLAG)
SELECT
    'RECONCILE:DOI row-level',
    'Metric Reconciliation', 'GOLD', 'GLD_METRIC_DOI',
    'days_of_inventory',
    COUNT_IF(ABS(DAYS_OF_INVENTORY - (QUANTITY_ON_HAND / NULLIF(AVG_DAILY_DEMAND, 0))) > 0.01),
    'all rows: stored = recalculated within 0.01',
    COUNT_IF(ABS(DAYS_OF_INVENTORY - (QUANTITY_ON_HAND / NULLIF(AVG_DAILY_DEMAND, 0))) > 0.01) = 0,
    'CRITICAL',
    COUNT_IF(ABS(DAYS_OF_INVENTORY - (QUANTITY_ON_HAND / NULLIF(AVG_DAILY_DEMAND, 0))) > 0.01) || ' rows with DOI mismatch',
    'DOI must be QUANTITY_ON_HAND/AVG_DAILY_DEMAND',
    'SCO_GOLD.GLD_METRIC_DOI', TRUE
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_DOI
WHERE AGGREGATION_LEVEL = 'PART_WAREHOUSE' AND AVG_DAILY_DEMAND > 0;

-- ═══════════════════════════════════════════════════════════════════════
-- LANDED COST: component sum = total
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO DQ_CHECK_RESULT (CHECK_NAME, QUALITY_DIMENSION, LAYER_NAME, OBJECT_NAME,
    METRIC_NAME, OBSERVED_VALUE, EXPECTED_CONDITION, PASSED_FLAG, SEVERITY, DETAILS,
    REMEDIATION_GUIDANCE, SOURCE_OBJECT, ALERT_ELIGIBLE_FLAG)
SELECT
    'RECONCILE:LANDED_COST component-sum',
    'Metric Reconciliation', 'GOLD', 'GLD_METRIC_LANDED_COST',
    'landed_cost_per_unit_usd',
    COUNT_IF(ABS(LANDED_COST_PER_UNIT_USD - (PURCHASE_COST_PER_UNIT_USD + FREIGHT_COST_PER_UNIT_USD
        + INSURANCE_COST_PER_UNIT_USD + DUTIES_COST_PER_UNIT_USD + HANDLING_COST_PER_UNIT_USD)) > 0.01),
    'landed = purchase + freight + insurance + duties + handling within 0.01',
    COUNT_IF(ABS(LANDED_COST_PER_UNIT_USD - (PURCHASE_COST_PER_UNIT_USD + FREIGHT_COST_PER_UNIT_USD
        + INSURANCE_COST_PER_UNIT_USD + DUTIES_COST_PER_UNIT_USD + HANDLING_COST_PER_UNIT_USD)) > 0.01) = 0,
    'CRITICAL',
    COUNT_IF(ABS(LANDED_COST_PER_UNIT_USD - (PURCHASE_COST_PER_UNIT_USD + FREIGHT_COST_PER_UNIT_USD
        + INSURANCE_COST_PER_UNIT_USD + DUTIES_COST_PER_UNIT_USD + HANDLING_COST_PER_UNIT_USD)) > 0.01) || ' rows with component mismatch',
    'Landed cost must equal sum of all cost components',
    'SCO_GOLD.GLD_METRIC_LANDED_COST', TRUE
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_LANDED_COST;

-- ═══════════════════════════════════════════════════════════════════════
-- NULL denominator safety: OTD lines_due = 0 should yield NULL rate
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO DQ_CHECK_RESULT (CHECK_NAME, QUALITY_DIMENSION, LAYER_NAME, OBJECT_NAME,
    METRIC_NAME, OBSERVED_VALUE, EXPECTED_CONDITION, PASSED_FLAG, SEVERITY, DETAILS,
    REMEDIATION_GUIDANCE, SOURCE_OBJECT, ALERT_ELIGIBLE_FLAG)
SELECT
    'RECONCILE:OTD zero-denominator safety',
    'Metric Reconciliation', 'GOLD', 'GLD_METRIC_OTD',
    'on_time_delivery_rate',
    COUNT_IF(LINES_DUE = 0 AND ON_TIME_DELIVERY_RATE_PCT IS NOT NULL),
    'when lines_due=0, rate should be NULL',
    COUNT_IF(LINES_DUE = 0 AND ON_TIME_DELIVERY_RATE_PCT IS NOT NULL) = 0,
    'HIGH',
    COUNT_IF(LINES_DUE = 0 AND ON_TIME_DELIVERY_RATE_PCT IS NOT NULL) || ' rows with non-NULL rate when denominator=0',
    'NULLIF guard missing in OTD calculation',
    'SCO_GOLD.GLD_METRIC_OTD', TRUE
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD;
