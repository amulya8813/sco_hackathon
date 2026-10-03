--------------------------------------------------------------------------------
-- Supply Chain Ontology — Alert Deduplication & State Management
-- 18_alert_deduplication.sql
--
-- Auto-resolves alerts whose condition has recovered.
-- Does NOT close Jira tickets — only updates ALERT_EVENT status.
--------------------------------------------------------------------------------

USE SCHEMA SCO_HACKATHON.SCO_MONITORING;

-- ═══════════════════════════════════════════════════════════════════════
-- 1. Auto-resolve stockout alerts when inventory recovers
-- ═══════════════════════════════════════════════════════════════════════
UPDATE ALERT_EVENT ae
SET STATUS = 'RESOLVED',
    RESOLVED_AT = CURRENT_TIMESTAMP(),
    UPDATED_AT = CURRENT_TIMESTAMP()
WHERE ae.ALERT_TYPE = 'INVENTORY_SHORTAGE'
  AND ae.STATUS = 'OPEN'
  AND NOT EXISTS (
      SELECT 1 FROM SCO_HACKATHON.SCO_GOLD.GLD_INVENTORY_HEALTH ih
      WHERE ih.STOCKOUT_FLAG = TRUE
        AND ae.DEDUP_KEY = 'STOCKOUT:' || ih.PART_ID || ':' || ih.WAREHOUSE_ID
  );

-- ═══════════════════════════════════════════════════════════════════════
-- 2. Auto-resolve DQ check alerts when they pass again
-- ═══════════════════════════════════════════════════════════════════════
UPDATE ALERT_EVENT ae
SET STATUS = 'RESOLVED',
    RESOLVED_AT = CURRENT_TIMESTAMP(),
    UPDATED_AT = CURRENT_TIMESTAMP()
WHERE ae.ALERT_TYPE = 'DQ_CHECK_FAILURE'
  AND ae.STATUS = 'OPEN'
  AND NOT EXISTS (
      SELECT 1 FROM SCO_HACKATHON.SCO_GOVERNANCE.V_DQ_SCORECARD dq
      WHERE dq.STATUS = 'FAIL'
        AND ae.DEDUP_KEY = 'DQ_FAIL:' || dq.DQ_DIMENSION || ':' || dq.CHECK_NAME
  );

-- ═══════════════════════════════════════════════════════════════════════
-- 3. Auto-resolve stale alerts when freshness recovers
-- ═══════════════════════════════════════════════════════════════════════
UPDATE ALERT_EVENT ae
SET STATUS = 'RESOLVED',
    RESOLVED_AT = CURRENT_TIMESTAMP(),
    UPDATED_AT = CURRENT_TIMESTAMP()
WHERE ae.ALERT_TYPE = 'STALE_SOURCE_TABLE'
  AND ae.STATUS = 'OPEN'
  AND NOT EXISTS (
      SELECT 1 FROM SCO_HACKATHON.SCO_GOVERNANCE.V_DQ_FRESHNESS f
      WHERE f.STATUS = 'STALE'
        AND ae.DEDUP_KEY = 'STALE:' || f.TABLE_NAME
  );

-- ═══════════════════════════════════════════════════════════════════════
-- 4. Alert summary view for monitoring dashboard
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW V_ALERT_SUMMARY AS
SELECT
    ALERT_CATEGORY,
    ALERT_TYPE,
    SEVERITY,
    STATUS,
    COUNT(*)                          AS ALERT_COUNT,
    MIN(DETECTED_AT)                  AS EARLIEST_DETECTION,
    MAX(DETECTED_AT)                  AS LATEST_DETECTION,
    COUNT_IF(JIRA_SYNC_STATUS = 'CREATED')  AS JIRA_CREATED,
    COUNT_IF(JIRA_SYNC_STATUS = 'PENDING')  AS JIRA_PENDING,
    COUNT_IF(JIRA_SYNC_STATUS = 'FAILED')   AS JIRA_FAILED
FROM ALERT_EVENT
GROUP BY ALERT_CATEGORY, ALERT_TYPE, SEVERITY, STATUS;

-- ═══════════════════════════════════════════════════════════════════════
-- 5. Pending Jira sync queue
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW V_JIRA_SYNC_QUEUE AS
SELECT
    ALERT_ID, ALERT_TYPE, ALERT_CATEGORY, SEVERITY,
    ENTITY_TYPE, ENTITY_ID, METRIC_NAME,
    OBSERVED_VALUE, THRESHOLD_VALUE,
    ALERT_MESSAGE, DETECTED_AT,
    SOURCE_OBJECT, DEDUP_KEY,
    STATUS AS ALERT_STATUS,
    JIRA_SYNC_STATUS,
    JIRA_ISSUE_KEY
FROM ALERT_EVENT
WHERE JIRA_SYNC_STATUS IN ('PENDING', 'FAILED')
  AND STATUS = 'OPEN'
ORDER BY
    CASE SEVERITY WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 ELSE 4 END,
    DETECTED_AT;
