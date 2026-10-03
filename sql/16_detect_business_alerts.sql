--------------------------------------------------------------------------------
-- Supply Chain Ontology — Business Alert Detection Queries
-- 16_detect_business_alerts.sql
--
-- Each query inserts into ALERT_EVENT only if no OPEN alert exists for
-- the same DEDUP_KEY (idempotent — safe to re-run).
--------------------------------------------------------------------------------

USE SCHEMA SCO_HACKATHON.SCO_MONITORING;

-- ═══════════════════════════════════════════════════════════════════════
-- B1. OTD Below Governed Threshold (95%)
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO ALERT_EVENT (ALERT_TYPE, ALERT_CATEGORY, SEVERITY, ENTITY_TYPE, ENTITY_ID,
    METRIC_NAME, OBSERVED_VALUE, THRESHOLD_VALUE, ALERT_MESSAGE, SOURCE_OBJECT, DEDUP_KEY)
SELECT
    'OTD_BELOW_THRESHOLD', 'BUSINESS', 'CRITICAL',
    'SUPPLIER', SUPPLIER_NAME,
    'OTD_RATE',
    ROUND(SUM(LINES_ON_TIME)/NULLIF(SUM(LINES_DUE),0)*100, 2),
    95.0,
    'On-Time Delivery rate for supplier ' || SUPPLIER_NAME || ' is ' ||
        ROUND(SUM(LINES_ON_TIME)/NULLIF(SUM(LINES_DUE),0)*100, 2) || '% — below governed threshold of 95%',
    'SCO_GOLD.GLD_METRIC_OTD',
    'OTD_BELOW:' || SUPPLIER_NAME || ':' || DATE_TRUNC('month', CURRENT_DATE())
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD
WHERE MONTH_START_DATE >= DATEADD('month', -3, CURRENT_DATE())
GROUP BY SUPPLIER_NAME
HAVING SUM(LINES_ON_TIME)/NULLIF(SUM(LINES_DUE),0)*100 < 95
   AND NOT EXISTS (
       SELECT 1 FROM ALERT_EVENT ae
       WHERE ae.DEDUP_KEY = 'OTD_BELOW:' || SUPPLIER_NAME || ':' || DATE_TRUNC('month', CURRENT_DATE())
         AND ae.STATUS = 'OPEN'
   );

-- ═══════════════════════════════════════════════════════════════════════
-- B2. Fill Rate Below Governed Threshold (92%)
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO ALERT_EVENT (ALERT_TYPE, ALERT_CATEGORY, SEVERITY, ENTITY_TYPE, ENTITY_ID,
    METRIC_NAME, OBSERVED_VALUE, THRESHOLD_VALUE, ALERT_MESSAGE, SOURCE_OBJECT, DEDUP_KEY)
SELECT
    'FILL_RATE_BELOW_THRESHOLD', 'BUSINESS', 'HIGH',
    'WAREHOUSE', WAREHOUSE_NAME,
    'FILL_RATE',
    ROUND(SUM(UNITS_FULFILLED)/NULLIF(SUM(UNITS_ORDERED),0)*100, 2),
    92.0,
    'Fill Rate for warehouse ' || WAREHOUSE_NAME || ' is ' ||
        ROUND(SUM(UNITS_FULFILLED)/NULLIF(SUM(UNITS_ORDERED),0)*100, 2) || '% — below governed threshold of 92%',
    'SCO_GOLD.GLD_METRIC_FILL_RATE',
    'FILL_BELOW:' || WAREHOUSE_NAME || ':' || DATE_TRUNC('month', CURRENT_DATE())
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_FILL_RATE
WHERE MONTH_START_DATE >= DATEADD('month', -3, CURRENT_DATE())
GROUP BY WAREHOUSE_NAME
HAVING SUM(UNITS_FULFILLED)/NULLIF(SUM(UNITS_ORDERED),0)*100 < 92
   AND NOT EXISTS (
       SELECT 1 FROM ALERT_EVENT ae
       WHERE ae.DEDUP_KEY = 'FILL_BELOW:' || WAREHOUSE_NAME || ':' || DATE_TRUNC('month', CURRENT_DATE())
         AND ae.STATUS = 'OPEN'
   );

-- ═══════════════════════════════════════════════════════════════════════
-- B3. DOI Outside Accepted Range (15-45 days)
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO ALERT_EVENT (ALERT_TYPE, ALERT_CATEGORY, SEVERITY, ENTITY_TYPE, ENTITY_ID,
    METRIC_NAME, OBSERVED_VALUE, THRESHOLD_VALUE, ALERT_MESSAGE, SOURCE_OBJECT, DEDUP_KEY)
SELECT
    'DOI_OUTSIDE_RANGE', 'BUSINESS', 'HIGH',
    'PART', PART_NAME,
    'DOI_DAYS',
    ROUND(DAYS_OF_INVENTORY, 1),
    15.0,
    'Days of Inventory for ' || PART_NAME || ' at ' || WAREHOUSE_NAME || ' is ' ||
        ROUND(DAYS_OF_INVENTORY, 1) || ' days — outside governed range of 15-45',
    'SCO_GOLD.GLD_INVENTORY_HEALTH',
    'DOI_RANGE:' || PART_ID || ':' || WAREHOUSE_ID
FROM SCO_HACKATHON.SCO_GOLD.GLD_INVENTORY_HEALTH
WHERE (DAYS_OF_INVENTORY < 15 OR DAYS_OF_INVENTORY > 45)
  AND DAYS_OF_INVENTORY IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM ALERT_EVENT ae
      WHERE ae.DEDUP_KEY = 'DOI_RANGE:' || PART_ID || ':' || WAREHOUSE_ID
        AND ae.STATUS = 'OPEN'
  );

-- ═══════════════════════════════════════════════════════════════════════
-- B4. Supplier Risk Event (risk score >= 40)
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO ALERT_EVENT (ALERT_TYPE, ALERT_CATEGORY, SEVERITY, ENTITY_TYPE, ENTITY_ID,
    METRIC_NAME, OBSERVED_VALUE, THRESHOLD_VALUE, ALERT_MESSAGE, SOURCE_OBJECT, DEDUP_KEY)
SELECT
    'SUPPLIER_RISK_EVENT', 'BUSINESS',
    CASE WHEN RISK_SCORE >= 75 THEN 'CRITICAL' WHEN RISK_SCORE >= 50 THEN 'HIGH' ELSE 'MEDIUM' END,
    'SUPPLIER', SUPPLIER_NAME,
    'RISK_SCORE',
    RISK_SCORE, 40.0,
    'Supplier ' || SUPPLIER_NAME || ' risk score is ' || RISK_SCORE ||
        ' (sanctions matches: ' || SANCTIONS_MATCH_COUNT || ', spend at risk: $' || ROUND(SPEND_AT_RISK_USD, 0) || ')',
    'SCO_GOLD.GLD_RISK_EXPOSURE',
    'RISK:' || SUPPLIER_ID || ':' || MONTH_START_DATE
FROM SCO_HACKATHON.SCO_GOLD.GLD_RISK_EXPOSURE
WHERE RISK_SCORE >= 40
  AND MONTH_START_DATE >= DATEADD('month', -3, CURRENT_DATE())
  AND NOT EXISTS (
      SELECT 1 FROM ALERT_EVENT ae
      WHERE ae.DEDUP_KEY = 'RISK:' || SUPPLIER_ID || ':' || MONTH_START_DATE
        AND ae.STATUS = 'OPEN'
  );

-- ═══════════════════════════════════════════════════════════════════════
-- B5. Inventory Shortage (stockout positions)
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO ALERT_EVENT (ALERT_TYPE, ALERT_CATEGORY, SEVERITY, ENTITY_TYPE, ENTITY_ID,
    METRIC_NAME, OBSERVED_VALUE, THRESHOLD_VALUE, ALERT_MESSAGE, SOURCE_OBJECT, DEDUP_KEY)
SELECT
    'INVENTORY_SHORTAGE', 'BUSINESS', 'CRITICAL',
    'PART', PART_NAME,
    'STOCKOUT_FLAG',
    0, 0,
    'Stockout: ' || PART_NAME || ' at ' || WAREHOUSE_NAME ||
        ' — quantity on hand: ' || QUANTITY_ON_HAND || ', available: ' || QUANTITY_AVAILABLE,
    'SCO_GOLD.GLD_INVENTORY_HEALTH',
    'STOCKOUT:' || PART_ID || ':' || WAREHOUSE_ID
FROM SCO_HACKATHON.SCO_GOLD.GLD_INVENTORY_HEALTH
WHERE STOCKOUT_FLAG = TRUE
  AND NOT EXISTS (
      SELECT 1 FROM ALERT_EVENT ae
      WHERE ae.DEDUP_KEY = 'STOCKOUT:' || PART_ID || ':' || WAREHOUSE_ID
        AND ae.STATUS = 'OPEN'
  );

-- ═══════════════════════════════════════════════════════════════════════
-- B6. Shipment Delay Risk (carrier on-time < 50%)
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO ALERT_EVENT (ALERT_TYPE, ALERT_CATEGORY, SEVERITY, ENTITY_TYPE, ENTITY_ID,
    METRIC_NAME, OBSERVED_VALUE, THRESHOLD_VALUE, ALERT_MESSAGE, SOURCE_OBJECT, DEDUP_KEY)
SELECT
    'SHIPMENT_DELAY_RISK', 'BUSINESS', 'HIGH',
    'CARRIER', CARRIER_NAME,
    'ON_TIME_ARR_PCT',
    ON_TIME_ARRIVAL_RATE_PCT, 50.0,
    'Carrier ' || CARRIER_NAME || ' on route ' || ROUTE_NAME || ' has on-time rate of ' ||
        ON_TIME_ARRIVAL_RATE_PCT || '% — high delay risk',
    'SCO_GOLD.GLD_SHIPMENT_PERFORMANCE',
    'DELAY:' || CARRIER_ID || ':' || ROUTE_ID || ':' || MONTH_START_DATE
FROM SCO_HACKATHON.SCO_GOLD.GLD_SHIPMENT_PERFORMANCE
WHERE ON_TIME_ARRIVAL_RATE_PCT < 50
  AND MONTH_START_DATE >= DATEADD('month', -3, CURRENT_DATE())
  AND NOT EXISTS (
      SELECT 1 FROM ALERT_EVENT ae
      WHERE ae.DEDUP_KEY = 'DELAY:' || CARRIER_ID || ':' || ROUTE_ID || ':' || MONTH_START_DATE
        AND ae.STATUS = 'OPEN'
  );
