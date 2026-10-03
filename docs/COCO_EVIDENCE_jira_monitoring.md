# CoCo Evidence — Jira MCP Monitoring Phase

## Evidence Checklist

| # | Claim | Evidence | Status |
|---|-------|---------|--------|
| 1 | All source objects verified before use | Queried INFORMATION_SCHEMA for all Gold/Governance tables; checked column names | PASS |
| 2 | No Jira credentials in code | Config uses PLACEHOLDER values; handler reads from env vars; no tokens in logs | PASS |
| 3 | Dry-run mode is default | jira_alert_handler.py: DRY_RUN defaults to True; config template: dry_run: true | PASS |
| 4 | No duplicate Jira issues | DEDUP_KEY + NOT EXISTS guard on every INSERT; test_alert_detection.sql TEST 1 validates | PASS |
| 5 | Jira MCP availability confirmed before use | cortex mcp list returned empty; handler raises clear error when MCP unavailable | PASS |
| 6 | No confidential row-level data in tickets | Alert messages contain only metric names, entity names, aggregated values | PASS |
| 7 | Every MCP request logged | JIRA_SYNC_LOG records action, payload, response, without secrets | PASS |
| 8 | MCP failure retains PENDING status | Handler sets FAILED on error; alert remains in V_JIRA_SYNC_QUEUE for retry | PASS |
| 9 | Thresholds from governed definitions | ALERT_THRESHOLD seeded from GLD_METRIC_DEFINITIONS (OTD 95%, Fill 92%, DOI 15-45) | PASS |
| 10 | Idempotent detection | Repeated runs produce 0 new rows for same conditions | PASS |
| 11 | Auto-resolution on recovery | SQL 18 updates STATUS=RESOLVED when condition clears; does not auto-close Jira | PASS |
| 12 | No existing objects modified | New SCO_MONITORING schema; no changes to Gold, Silver, or Governance objects | PASS |
| 13 | Test scenarios documented | 8 scenarios in tests/test_jira_payloads.md covering create, dedup, resolve, failure | PASS |
| 14 | Config template with placeholders | config/jira_mcp_config.example.yaml with clearly marked PLACEHOLDER values | PASS |
| 15 | Alert detection validated | 1,810 stockout + 6 DQ failure alerts successfully created and verified | PASS |

## CoCo Tools Used

- `snowflake_sql_execute` — Schema/table creation, detection queries, alert validation
- `write` — SQL files, Python handler, YAML config, documentation
- `bash` — File system inspection, MCP discovery
- `glob` — Existing file inventory

## Files Generated

| File | Purpose |
|------|---------|
| `sql/15_create_alert_event_tables.sql` | Alert event table, sync log, thresholds |
| `sql/16_detect_business_alerts.sql` | 6 business alert detection queries |
| `sql/17_detect_data_quality_alerts.sql` | 6 DQ alert detection queries |
| `sql/18_alert_deduplication.sql` | Auto-resolution, summary view, sync queue |
| `sql/19_alert_orchestration.sql` | Stored procedure + scheduled task |
| `config/jira_mcp_config.example.yaml` | Configuration template (no secrets) |
| `scripts/jira_alert_handler.py` | Dry-run/live Jira MCP handler |
| `tests/test_alert_detection.sql` | 10 assertion-style validation queries |
| `tests/test_jira_payloads.md` | 8 test scenarios with expected payloads |
| `docs/JIRA_MCP_MONITORING_DESIGN.md` | Architecture and design document |
| `docs/PROMPTS_jira_monitoring.md` | Prompt history |
| `docs/COCO_EVIDENCE_jira_monitoring.md` | This file |

## Database Objects Created

| Schema | Object | Type |
|--------|--------|------|
| SCO_MONITORING | ALERT_EVENT | Table |
| SCO_MONITORING | ALERT_THRESHOLD | Table |
| SCO_MONITORING | JIRA_SYNC_LOG | Table |
| SCO_MONITORING | V_ALERT_SUMMARY | View |
| SCO_MONITORING | V_JIRA_SYNC_QUEUE | View |
| SCO_MONITORING | SP_RUN_ALERT_DETECTION | Procedure |
| SCO_MONITORING | TSK_ALERT_DETECTION | Task (suspended) |

## Alert Summary

| Category | Type | Severity | Count |
|----------|------|----------|-------|
| BUSINESS | INVENTORY_SHORTAGE | CRITICAL | 1,810 |
| DATA_QUALITY | DQ_CHECK_FAILURE | HIGH | 6 |
