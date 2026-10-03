# Test Jira Payloads — Dry-Run Validation

## Test Scenario 1: New Stockout Alert → Jira Create

**Alert:**
```
ALERT_ID: 1
ALERT_TYPE: INVENTORY_SHORTAGE
SEVERITY: CRITICAL
ENTITY_TYPE: PART
ENTITY_ID: Part_00042
OBSERVED_VALUE: 0
THRESHOLD_VALUE: 0
DEDUP_KEY: STOCKOUT:42:5
```

**Expected Jira Payload:**
```json
{
  "project": {"key": "SCO"},
  "summary": "[SCO-CRITICAL] INVENTORY_SHORTAGE: Part_00042",
  "issuetype": {"name": "Task"},
  "priority": {"name": "Highest"},
  "labels": ["sco-hackathon", "coco-generated", "supply-chain", "critical", "business"],
  "description": "h2. Supply Chain Alert — INVENTORY_SHORTAGE\n\n*Severity:* CRITICAL\n*Affected Entity:* PART — Part_00042\n..."
}
```

**Expected MCP Tool:** `jira.create_issue`
**Expected Response Handling:** On 201 → update ALERT_EVENT set JIRA_SYNC_STATUS='CREATED', JIRA_ISSUE_KEY=response.key

---

## Test Scenario 2: Repeated Stockout → No Duplicate

**Precondition:** Alert with DEDUP_KEY `STOCKOUT:42:5` already OPEN.
**Action:** Run 16_detect_business_alerts.sql again.
**Expected:** 0 new rows inserted (NOT EXISTS clause prevents duplicate).

---

## Test Scenario 3: DQ Check Failure → Jira Create

**Alert:**
```
ALERT_TYPE: DQ_CHECK_FAILURE
SEVERITY: HIGH
ENTITY_ID: Completeness.ORDER_LINE_ITEM.quantity_ordered
DEDUP_KEY: DQ_FAIL:Completeness:ORDER_LINE_ITEM.quantity_ordered
```

**Expected Payload:**
```json
{
  "project": {"key": "SCO"},
  "summary": "[SCO-HIGH] DQ_CHECK_FAILURE: Completeness.ORDER_LINE_ITEM.quantity_ordered",
  "issuetype": {"name": "Bug"},
  "priority": {"name": "High"},
  "labels": ["sco-hackathon", "coco-generated", "supply-chain", "high", "data_quality"]
}
```

---

## Test Scenario 4: Condition Resolves → Alert Auto-Resolved

**Precondition:** OPEN stockout alert for DEDUP_KEY `STOCKOUT:42:5`.
**Action:** Inventory recovers (stockout_flag goes FALSE). Run 18_alert_deduplication.sql.
**Expected:** Alert STATUS updated to 'RESOLVED', RESOLVED_AT set.
**Jira Action:** Handler should call `jira.update_issue` to add resolution comment (not auto-close).

---

## Test Scenario 5: MCP Unavailable → Alert Retained

**Precondition:** Jira MCP not configured.
**Action:** Run jira_alert_handler.py in live mode.
**Expected:** JIRA_SYNC_STATUS remains 'PENDING' or set to 'FAILED' with error message.
**Expected Log:** JIRA_SYNC_LOG entry with RESPONSE_STATUS='FAILED', DRY_RUN=FALSE.

---

## Test Scenario 6: Severity Change → Update Existing Issue

**Precondition:** OPEN alert with JIRA_ISSUE_KEY='SCO-123'.
**Action:** New detection finds same condition at higher severity.
**Expected:** Existing alert SEVERITY updated. Handler calls `jira.update_issue` on SCO-123.

---

## Test Scenario 7: Sensitive Data Check

**Action:** Inspect all ALERT_MESSAGE values.
**Expected:** No email addresses (except @example.com), no credentials, no row-level PII.
**Validation Query:**
```sql
SELECT ALERT_ID FROM ALERT_EVENT
WHERE ALERT_MESSAGE LIKE '%@%.%' AND ALERT_MESSAGE NOT LIKE '%@example.com%';
-- Should return 0 rows
```

---

## Test Scenario 8: Dry-Run vs Live Separation

**Dry-Run (default):**
- Payload logged to JIRA_SYNC_LOG with DRY_RUN=TRUE
- No MCP call made
- JIRA_SYNC_STATUS set to 'SKIPPED'

**Live (--live flag):**
- MCP call attempted
- On success: JIRA_SYNC_STATUS='CREATED', issue key stored
- On failure: JIRA_SYNC_STATUS='FAILED', error logged
