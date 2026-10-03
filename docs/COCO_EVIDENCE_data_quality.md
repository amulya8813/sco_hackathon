# CoCo Evidence — Data Quality Phase

## Evidence Checklist

| # | Claim | Evidence | Status |
|---|-------|---------|--------|
| 1 | All tables/columns verified before use | Queried INFORMATION_SCHEMA.COLUMNS for every referenced table; adjusted names | PASS |
| 2 | No invented thresholds | OTD 95%, Fill Rate 92%, DOI 15-45 from GLD_METRIC_DEFINITIONS | PASS |
| 3 | No invented relationships | All RI checks match existing V_DQ_REFERENTIAL_INTEGRITY definitions | PASS |
| 4 | Existing 42 checks preserved | Imported from V_DQ_SCORECARD into DQ_CHECK_RESULT without modification | PASS |
| 5 | OTD uses ratio-of-sums | Reconciliation R01: SUM(on_time)/NULLIF(SUM(due),0)*100 — confirmed by difference test | PASS |
| 6 | OTD never averages pre-computed percentages | R05 confirms ratio-of-sums ≠ AVG(stored %) | PASS |
| 7 | All 4 metrics reconciled | OTD, Fill Rate, DOI, Landed Cost — all within 0.01 tolerance | PASS |
| 8 | Graph integrity validated | 0 orphan edges, 13 types, 0 UNKNOWN polymorphic targets | PASS |
| 9 | Persona consistency validated | 3 OTD personas return identical value; 2 Fill Rate personas identical | PASS |
| 10 | DMF freshness uses approved fallback | FRESHNESS ON () — DML-based, not TIMESTAMP_NTZ column | PASS |
| 11 | No duplicate DMF attachments | Checked DATA_METRIC_FUNCTION_REFERENCES: 0 existing attachments | PASS |
| 12 | Quality score excludes blocked checks | V_DQ_QUALITY_SCORE denominator = ACTIVE checks only | PASS |
| 13 | Alert bridge to existing Jira workflow | V_DQ_ALERT_CANDIDATES produces failed, eligible checks for ALERT_EVENT | PASS |
| 14 | No existing objects modified | All new objects in SCO_GOVERNANCE; existing views untouched | PASS |
| 15 | Dry-run mode: DMFs not attached | 26_attach_system_dmfs.sql written but not executed | PASS |
| 16 | Critical failures displayed separately | V_DQ_OVERALL_SCORE has CRITICAL_FAILURES column | PASS |
| 17 | 80 checks across 9 dimensions | 74 pass, 6 fail (freshness expected), 0 blocked | PASS |
| 18 | Semantic View formula confirmed | DDL inspection: SUM(LINES_ON_TIME)/NULLIF(SUM(LINES_DUE),0)*100 | PASS |

## CoCo Tools Used

- `snowflake_sql_execute` — Discovery, table creation, check execution, validation
- `write` — SQL files, test files, documentation
- `read` / `glob` — Existing file and codebase inventory

## Files Generated

| File | Purpose |
|------|---------|
| `sql/25_create_quality_result_objects.sql` | Centralized result table + score views |
| `sql/26_attach_system_dmfs.sql` | System DMF proposals (dry-run) |
| `sql/27_create_custom_dmfs.sql` | Custom DMF functions |
| `sql/28_run_business_quality_checks.sql` | Import existing + Gold validity checks |
| `sql/29_reconcile_governed_metrics.sql` | 4 metric reconciliation checks |
| `sql/30_create_quality_alert_view.sql` | Alert bridge for Jira integration |
| `sql/31_validate_dmf_attachments.sql` | Pre-attachment duplicate check |
| `sql/32_validate_graph_quality.sql` | 5 graph integrity checks |
| `sql/33_validate_pipeline_health.sql` | Stream/task/audit validation |
| `tests/test_data_quality_framework.sql` | 9 framework assertion tests |
| `tests/test_metric_reconciliation.sql` | 6 metric reconciliation tests |
| `tests/test_persona_consistency.sql` | 3 persona consistency tests |
| `docs/DATA_QUALITY_FRAMEWORK.md` | Framework design document |
| `docs/DATA_QUALITY_OBJECT_INVENTORY.md` | Object inventory |
| `docs/DATA_QUALITY_RULE_CATALOG.md` | Rule catalog |
| `docs/DATA_QUALITY_VALIDATION_REPORT.md` | Validation results |
| `docs/PROMPTS_data_quality.md` | Prompt history |
| `docs/COCO_EVIDENCE_data_quality.md` | This file |

## Database Objects Created

| Schema | Object | Type |
|--------|--------|------|
| SCO_GOVERNANCE | DQ_CHECK_RESULT | Table |
| SCO_GOVERNANCE | V_DQ_QUALITY_SCORE | View |
| SCO_GOVERNANCE | V_DQ_OVERALL_SCORE | View |
| SCO_GOVERNANCE | V_DQ_ALERT_CANDIDATES | View |

## Execution Order

1. `25_create_quality_result_objects.sql` — table + views
2. `31_validate_dmf_attachments.sql` — check existing DMFs
3. `26_attach_system_dmfs.sql` — attach DMFs (after approval)
4. `27_create_custom_dmfs.sql` — create custom functions
5. `28_run_business_quality_checks.sql` — populate results
6. `29_reconcile_governed_metrics.sql` — reconciliation checks
7. `32_validate_graph_quality.sql` — graph checks
8. `33_validate_pipeline_health.sql` — pipeline checks
9. `30_create_quality_alert_view.sql` — alert bridge

## Required Privileges

- ACCOUNTADMIN or role with:
  - SELECT on all SCO_* schemas
  - CREATE TABLE/VIEW on SCO_GOVERNANCE
  - APPLY DATA METRIC FUNCTION (for DMF attachment)
  - USAGE on SNOWFLAKE.CORE schema (for system DMFs)
