# Jira MCP Monitoring & Alerting Design

## Overview

A governed monitoring and alerting workflow that detects supply-chain and data-quality exceptions in Snowflake, manages alert lifecycle with deduplication, and creates/updates Jira issues through MCP in dry-run or live mode.

## Architecture

```
SCO_GOLD / SCO_GOVERNANCE (metric + DQ sources)
    ↓ Detection queries (SQL 16-17)
SCO_MONITORING.ALERT_EVENT (governed alert table)
    ↓ Deduplication + state management (SQL 18)
SCO_MONITORING.V_JIRA_SYNC_QUEUE (pending alerts)
    ↓ Jira handler (scripts/jira_alert_handler.py)
Jira MCP → Create/Update/Resolve issues
    ↓ Audit
SCO_MONITORING.JIRA_SYNC_LOG
```

## Alert Categories

### Business Alerts
| Alert Type | Source | Threshold | Severity |
|---|---|---|---|
| OTD_BELOW_THRESHOLD | GLD_METRIC_OTD | < 95% | CRITICAL |
| FILL_RATE_BELOW_THRESHOLD | GLD_METRIC_FILL_RATE | < 92% | HIGH |
| DOI_OUTSIDE_RANGE | GLD_INVENTORY_HEALTH | < 15 or > 45 days | HIGH |
| SUPPLIER_RISK_EVENT | GLD_RISK_EXPOSURE | score >= 40 | HIGH |
| INVENTORY_SHORTAGE | GLD_INVENTORY_HEALTH | stockout_flag = TRUE | CRITICAL |
| SHIPMENT_DELAY_RISK | GLD_SHIPMENT_PERFORMANCE | on-time < 50% | HIGH |

### Data Quality Alerts
| Alert Type | Source | Condition | Severity |
|---|---|---|---|
| DQ_CHECK_FAILURE | V_DQ_SCORECARD | STATUS = 'FAIL' | HIGH |
| STALE_SOURCE_TABLE | V_DQ_FRESHNESS | STATUS = 'STALE' | MEDIUM |
| COMPLETENESS_VIOLATION | V_DQ_COMPLETENESS | NULL_PCT > 5% | MEDIUM |
| REFERENTIAL_INTEGRITY_VIOLATION | V_DQ_REFERENTIAL_INTEGRITY | ORPHAN_ROWS > 0 | HIGH |
| BUSINESS_RULE_VIOLATION | V_DQ_BUSINESS_RULES | VIOLATION_ROWS > 0 | HIGH |
| TASK_FAILURE | GLD_PIPELINE_AUDIT | STATUS = 'FAIL' | CRITICAL |

## Database Objects

### SCO_MONITORING Schema
| Object | Type | Purpose |
|---|---|---|
| ALERT_EVENT | Table | Core alert lifecycle table |
| ALERT_THRESHOLD | Table | Governed thresholds from metric definitions |
| JIRA_SYNC_LOG | Table | Audit trail for MCP requests (no secrets) |
| V_ALERT_SUMMARY | View | Dashboard-ready alert summary |
| V_JIRA_SYNC_QUEUE | View | Pending alerts for Jira sync |
| SP_RUN_ALERT_DETECTION | Procedure | Full detection cycle |
| TSK_ALERT_DETECTION | Task | Hourly scheduled detection (initially suspended) |

## Deduplication Strategy

- **DEDUP_KEY**: Composite key per alert type (e.g., `OTD_BELOW:{supplier}:{month}`)
- INSERT only when no OPEN alert exists for the same DEDUP_KEY
- Repeated runs are idempotent — same condition produces zero new rows
- Auto-resolution when the underlying condition clears

## Jira Integration

### Dry-Run Mode (default)
- Builds exact ticket payload
- Logs to JIRA_SYNC_LOG with DRY_RUN=TRUE
- Does NOT call MCP
- Shows payload for review

### Live Mode (explicit enable)
- Calls Jira MCP `create_issue` / `update_issue`
- Updates ALERT_EVENT with issue key and URL
- Logs every request/response
- Retries on MCP failure; retains PENDING status

### Ticket Content
- Summary: `[SCO-{SEVERITY}] {ALERT_TYPE}: {ENTITY_ID}`
- Description: business impact, metric values, thresholds, investigation steps
- Labels: `sco-hackathon`, `coco-generated`, severity
- No row-level data; no credentials

## Guardrails
- No duplicate issues for same active condition
- No auto-close without approved rule
- No confidential data in tickets
- MCP unavailability retains PENDING status
- Every MCP call logged without secrets

## Validated Alert Counts (Synthetic Data)
- 1,810 INVENTORY_SHORTAGE (stockout positions)
- 6 DQ_CHECK_FAILURE (from V_DQ_SCORECARD)
- OTD and shipment delay detections use synthetic data window (2024-2025)
