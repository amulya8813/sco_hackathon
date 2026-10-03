--------------------------------------------------------------------------------
-- Supply Chain Ontology — Data Quality Alert Detection Queries
-- 17_detect_data_quality_alerts.sql
--------------------------------------------------------------------------------

USE SCHEMA SCO_HACKATHON.SCO_MONITORING;

-- ═══════════════════════════════════════════════════════════════════════
-- DQ1. Failing DQ checks from V_DQ_SCORECARD
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO ALERT_EVENT (ALERT_TYPE, ALERT_CATEGORY, SEVERITY, ENTITY_TYPE, ENTITY_ID,
    METRIC_NAME, OBSERVED_VALUE, THRESHOLD_VALUE, ALERT_MESSAGE, SOURCE_OBJECT, DEDUP_KEY)
SELECT
    'DQ_CHECK_FAILURE', 'DATA_QUALITY', 'HIGH',
    'TABLE', DQ_DIMENSION || '.' || CHECK_NAME,
    CHECK_NAME,
    VIOLATION_COUNT, 0,
    'DQ check ' || CHECK_NAME || ' in dimension ' || DQ_DIMENSION ||
        ' FAILED with ' || VIOLATION_COUNT || ' violations',
    'SCO_GOVERNANCE.V_DQ_SCORECARD',
    'DQ_FAIL:' || DQ_DIMENSION || ':' || CHECK_NAME
FROM SCO_HACKATHON.SCO_GOVERNANCE.V_DQ_SCORECARD
WHERE STATUS = 'FAIL'
  AND NOT EXISTS (
      SELECT 1 FROM ALERT_EVENT ae
      WHERE ae.DEDUP_KEY = 'DQ_FAIL:' || DQ_DIMENSION || ':' || CHECK_NAME
        AND ae.STATUS = 'OPEN'
  );

-- ═══════════════════════════════════════════════════════════════════════
-- DQ2. Stale source tables (freshness > 24 hours)
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO ALERT_EVENT (ALERT_TYPE, ALERT_CATEGORY, SEVERITY, ENTITY_TYPE, ENTITY_ID,
    METRIC_NAME, OBSERVED_VALUE, THRESHOLD_VALUE, ALERT_MESSAGE, SOURCE_OBJECT, DEDUP_KEY)
SELECT
    'STALE_SOURCE_TABLE', 'DATA_QUALITY', 'MEDIUM',
    'TABLE', TABLE_NAME,
    'FRESHNESS_HOURS',
    ROUND(HOURS_STALE, 1),
    SLA_HOURS,
    'Table ' || TABLE_NAME || ' is stale: ' || ROUND(HOURS_STALE, 1) ||
        ' hours since last update (SLA: ' || SLA_HOURS || ' hours)',
    'SCO_GOVERNANCE.V_DQ_FRESHNESS',
    'STALE:' || TABLE_NAME
FROM SCO_HACKATHON.SCO_GOVERNANCE.V_DQ_FRESHNESS
WHERE STATUS = 'STALE'
  AND NOT EXISTS (
      SELECT 1 FROM ALERT_EVENT ae
      WHERE ae.DEDUP_KEY = 'STALE:' || TABLE_NAME
        AND ae.STATUS = 'OPEN'
  );

-- ═══════════════════════════════════════════════════════════════════════
-- DQ3. Completeness violations (NULL in required columns)
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO ALERT_EVENT (ALERT_TYPE, ALERT_CATEGORY, SEVERITY, ENTITY_TYPE, ENTITY_ID,
    METRIC_NAME, OBSERVED_VALUE, THRESHOLD_VALUE, ALERT_MESSAGE, SOURCE_OBJECT, DEDUP_KEY)
SELECT
    'COMPLETENESS_VIOLATION', 'DATA_QUALITY', 'MEDIUM',
    'TABLE', TABLE_NAME || '.' || COLUMN_NAME,
    'NULL_PCT',
    NULL_PCT, 0,
    'Column ' || TABLE_NAME || '.' || COLUMN_NAME || ' has ' || NULL_ROWS ||
        ' NULL rows (' || NULL_PCT || '%) out of ' || TOTAL_ROWS,
    'SCO_GOVERNANCE.V_DQ_COMPLETENESS',
    'NULLS:' || TABLE_NAME || ':' || COLUMN_NAME
FROM SCO_HACKATHON.SCO_GOVERNANCE.V_DQ_COMPLETENESS
WHERE NULL_PCT > 5  -- threshold: >5% nulls
  AND NOT EXISTS (
      SELECT 1 FROM ALERT_EVENT ae
      WHERE ae.DEDUP_KEY = 'NULLS:' || TABLE_NAME || ':' || COLUMN_NAME
        AND ae.STATUS = 'OPEN'
  );

-- ═══════════════════════════════════════════════════════════════════════
-- DQ4. Referential integrity violations (orphan rows)
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO ALERT_EVENT (ALERT_TYPE, ALERT_CATEGORY, SEVERITY, ENTITY_TYPE, ENTITY_ID,
    METRIC_NAME, OBSERVED_VALUE, THRESHOLD_VALUE, ALERT_MESSAGE, SOURCE_OBJECT, DEDUP_KEY)
SELECT
    'REFERENTIAL_INTEGRITY_VIOLATION', 'DATA_QUALITY', 'HIGH',
    'TABLE', RELATIONSHIP,
    'ORPHAN_ROWS',
    ORPHAN_ROWS, 0,
    'Referential integrity: ' || RELATIONSHIP || ' has ' || ORPHAN_ROWS || ' orphan rows',
    'SCO_GOVERNANCE.V_DQ_REFERENTIAL_INTEGRITY',
    'RI:' || RELATIONSHIP
FROM SCO_HACKATHON.SCO_GOVERNANCE.V_DQ_REFERENTIAL_INTEGRITY
WHERE ORPHAN_ROWS > 0
  AND NOT EXISTS (
      SELECT 1 FROM ALERT_EVENT ae
      WHERE ae.DEDUP_KEY = 'RI:' || RELATIONSHIP
        AND ae.STATUS = 'OPEN'
  );

-- ═══════════════════════════════════════════════════════════════════════
-- DQ5. Business rule violations
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO ALERT_EVENT (ALERT_TYPE, ALERT_CATEGORY, SEVERITY, ENTITY_TYPE, ENTITY_ID,
    METRIC_NAME, OBSERVED_VALUE, THRESHOLD_VALUE, ALERT_MESSAGE, SOURCE_OBJECT, DEDUP_KEY)
SELECT
    'BUSINESS_RULE_VIOLATION', 'DATA_QUALITY', 'HIGH',
    'TABLE', RULE_NAME,
    'VIOLATION_ROWS',
    VIOLATION_ROWS, 0,
    'Business rule ' || RULE_NAME || ' has ' || VIOLATION_ROWS || ' violations',
    'SCO_GOVERNANCE.V_DQ_BUSINESS_RULES',
    'BR:' || RULE_NAME
FROM SCO_HACKATHON.SCO_GOVERNANCE.V_DQ_BUSINESS_RULES
WHERE VIOLATION_ROWS > 0
  AND NOT EXISTS (
      SELECT 1 FROM ALERT_EVENT ae
      WHERE ae.DEDUP_KEY = 'BR:' || RULE_NAME
        AND ae.STATUS = 'OPEN'
  );

-- ═══════════════════════════════════════════════════════════════════════
-- DQ6. Task failures (from pipeline audit)
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO ALERT_EVENT (ALERT_TYPE, ALERT_CATEGORY, SEVERITY, ENTITY_TYPE, ENTITY_ID,
    METRIC_NAME, OBSERVED_VALUE, THRESHOLD_VALUE, ALERT_MESSAGE, SOURCE_OBJECT, DEDUP_KEY)
SELECT
    'TASK_FAILURE', 'DATA_QUALITY', 'CRITICAL',
    'TASK', TASK_NAME,
    'FAILURE_COUNT',
    1, 0,
    'Task ' || TASK_NAME || ' failed on ' || OBJECT_NAME || ' at ' || AUDIT_EVENT_TS,
    'SCO_GOLD.GLD_PIPELINE_AUDIT',
    'TASK_FAIL:' || TASK_NAME || ':' || DATE_TRUNC('hour', AUDIT_EVENT_TS)
FROM SCO_HACKATHON.SCO_GOLD.GLD_PIPELINE_AUDIT
WHERE STATUS = 'FAIL'
  AND AUDIT_EVENT_TS >= DATEADD('hour', -2, CURRENT_TIMESTAMP())
  AND NOT EXISTS (
      SELECT 1 FROM ALERT_EVENT ae
      WHERE ae.DEDUP_KEY = 'TASK_FAIL:' || TASK_NAME || ':' || DATE_TRUNC('hour', AUDIT_EVENT_TS)
        AND ae.STATUS = 'OPEN'
  );
