--------------------------------------------------------------------------------
-- Supply Chain Ontology — Alert Detection Tests
-- tests/test_alert_detection.sql
--
-- Assertion-style: each query returns 0 rows if passing.
--------------------------------------------------------------------------------

-- TEST 1: No duplicate OPEN alerts for same DEDUP_KEY
SELECT 'FAIL: duplicate open alerts' AS TEST, DEDUP_KEY, COUNT(*) AS DUPES
FROM SCO_HACKATHON.SCO_MONITORING.ALERT_EVENT
WHERE STATUS = 'OPEN'
GROUP BY DEDUP_KEY
HAVING COUNT(*) > 1;

-- TEST 2: All alerts have required fields populated
SELECT 'FAIL: missing required fields' AS TEST, ALERT_ID
FROM SCO_HACKATHON.SCO_MONITORING.ALERT_EVENT
WHERE ALERT_TYPE IS NULL OR ALERT_CATEGORY IS NULL OR SEVERITY IS NULL
   OR ALERT_MESSAGE IS NULL OR DEDUP_KEY IS NULL;

-- TEST 3: All severities are valid enum values
SELECT 'FAIL: invalid severity' AS TEST, ALERT_ID, SEVERITY
FROM SCO_HACKATHON.SCO_MONITORING.ALERT_EVENT
WHERE SEVERITY NOT IN ('CRITICAL','HIGH','MEDIUM','LOW');

-- TEST 4: All categories are valid
SELECT 'FAIL: invalid category' AS TEST, ALERT_ID, ALERT_CATEGORY
FROM SCO_HACKATHON.SCO_MONITORING.ALERT_EVENT
WHERE ALERT_CATEGORY NOT IN ('BUSINESS','DATA_QUALITY');

-- TEST 5: All statuses are valid
SELECT 'FAIL: invalid status' AS TEST, ALERT_ID, STATUS
FROM SCO_HACKATHON.SCO_MONITORING.ALERT_EVENT
WHERE STATUS NOT IN ('OPEN','ACKNOWLEDGED','RESOLVED','SUPPRESSED');

-- TEST 6: Resolved alerts have RESOLVED_AT set
SELECT 'FAIL: resolved without timestamp' AS TEST, ALERT_ID
FROM SCO_HACKATHON.SCO_MONITORING.ALERT_EVENT
WHERE STATUS = 'RESOLVED' AND RESOLVED_AT IS NULL;

-- TEST 7: JIRA_SYNC_STATUS is valid
SELECT 'FAIL: invalid jira sync status' AS TEST, ALERT_ID, JIRA_SYNC_STATUS
FROM SCO_HACKATHON.SCO_MONITORING.ALERT_EVENT
WHERE JIRA_SYNC_STATUS NOT IN ('PENDING','CREATED','UPDATED','FAILED','SKIPPED');

-- TEST 8: Idempotency — running detection twice produces no new rows
-- (Run 16_detect_business_alerts.sql twice and compare counts)
-- Manual verification: run detection, note count, run again, count should be same.

-- TEST 9: Sync log has no secrets (check for common patterns)
SELECT 'FAIL: potential secret in log' AS TEST, LOG_ID
FROM SCO_HACKATHON.SCO_MONITORING.JIRA_SYNC_LOG
WHERE REQUEST_PAYLOAD::VARCHAR LIKE '%token%'
   OR REQUEST_PAYLOAD::VARCHAR LIKE '%password%'
   OR REQUEST_PAYLOAD::VARCHAR LIKE '%secret%'
   OR REQUEST_PAYLOAD::VARCHAR LIKE '%Bearer%';

-- TEST 10: Alert message does not contain row-level PII
SELECT 'FAIL: alert contains email' AS TEST, ALERT_ID
FROM SCO_HACKATHON.SCO_MONITORING.ALERT_EVENT
WHERE ALERT_MESSAGE LIKE '%@%.%' AND ALERT_MESSAGE NOT LIKE '%@example.com%';
