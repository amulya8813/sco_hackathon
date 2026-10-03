# Prompts — Jira MCP Monitoring Phase

## Prompt 1: Discovery

Inspected all monitoring-relevant objects:
- 6 governance views in SCO_GOVERNANCE (V_DQ_SCORECARD, V_DQ_FRESHNESS, V_DQ_COMPLETENESS, V_DQ_REFERENTIAL_INTEGRITY, V_DQ_BUSINESS_RULES, V_DQ_UNIQUENESS)
- 4 Gold metric tables (GLD_METRIC_OTD, GLD_METRIC_FILL_RATE, GLD_METRIC_DOI, GLD_METRIC_LANDED_COST)
- 3 Gold operational tables (GLD_RISK_EXPOSURE, GLD_INVENTORY_HEALTH, GLD_SHIPMENT_PERFORMANCE)
- 4 existing tasks (TSK_SCO_ROOT + 3 children, all suspended)
- 1 existing alert (ALRT_DATA_QUALITY_FAILURE, suspended)
- GLD_METRIC_DEFINITIONS with governed thresholds (OTD 95%, Fill Rate 92%, DOI 15-45 days)
- Current metric values: OTD 74.7%, Fill Rate 85.0%, DOI 7.0 days (all below thresholds)
- No Jira MCP configured (cortex mcp list returned empty)

## Prompt 2: Alert Table & Threshold Design

Created SCO_MONITORING schema with ALERT_EVENT, ALERT_THRESHOLD, JIRA_SYNC_LOG tables. Seeded thresholds from GLD_METRIC_DEFINITIONS. Designed DEDUP_KEY strategy for idempotent detection.

## Prompt 3: Business Alert Detection (SQL 16)

Created 6 business alert detection queries with dedup guards. Discovered that synthetic data ends at 2025-12-31, requiring the detection window to reference that period rather than a rolling 3-month window from current date.

## Prompt 4: Data Quality Alert Detection (SQL 17)

Created 6 DQ detection queries sourcing from governance views. Successfully detected 6 DQ check failures and 1,810 stockout positions on first run.

## Prompt 5: Orchestration & State Management (SQL 18-19)

Created auto-resolution queries for recovered conditions, alert summary view, Jira sync queue view, stored procedure SP_RUN_ALERT_DETECTION, and scheduled task TSK_ALERT_DETECTION.

## Prompt 6: Jira Handler & Documentation

Created jira_alert_handler.py with dry-run/live mode, config template, test scenarios, and all documentation.

## Key Design Decisions

1. **Dry-run first** — All Jira operations default to dry-run mode
2. **Config template** — No secrets in code; YAML placeholder file
3. **Idempotent detection** — DEDUP_KEY + NOT EXISTS prevents duplicates
4. **Auto-resolution** — Cleared conditions flip to RESOLVED; no auto-close of Jira
5. **Audit trail** — Every MCP attempt logged without secrets
6. **Synthetic data window** — Detection queries adapted for 2024-2025 data range
7. **Severity-based priority** — CRITICAL→Highest, HIGH→High, etc.
