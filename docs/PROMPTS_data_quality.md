# Prompts — Data Quality Phase

## Prompt 1: Discovery

Inspected all 128 objects across 7 schemas. Queried INFORMATION_SCHEMA for columns, keys, and data types. Verified existing governance views (42 SQL-based checks in V_DQ_SCORECARD). Confirmed no active DMF attachments (DATA_METRIC_FUNCTION_REFERENCES returned 0 rows). Verified 5 streams (all stale), 4 tasks (all suspended), 1 alert (suspended). Confirmed known FRESHNESS constraint with TIMESTAMP_NTZ columns.

## Prompt 2: Quality Result Model

Designed DQ_CHECK_RESULT table with all required fields: check_name, dimension, layer, observed_value, passed_flag, severity, alert_eligible_flag, status. Created quality score views excluding blocked/unsupported from pass-rate denominator.

## Prompt 3: System DMF Proposals

Created 26_attach_system_dmfs.sql with FRESHNESS ON () (DML-based, per known constraint), NULL_COUNT on mandatory columns, DUPLICATE_COUNT on PKs, ROW_COUNT for volume tracking. All as dry-run proposals.

## Prompt 4: Gold Validity + Reconciliation

8 validity checks (range, non-negative, numerator<=denominator). 4 reconciliation checks recalculating each metric from component columns. All 12 pass. OTD confirmed as ratio-of-sums via difference test.

## Prompt 5: Graph Quality

5 graph integrity checks: orphan edges (0), node types (13), polymorphic resolution (0 UNKNOWN), node ID format. All pass.

## Key Design Decisions

1. **Preserve existing governance** — 42 existing checks imported into centralized DQ_CHECK_RESULT
2. **DML-based freshness** — FRESHNESS ON () per known TIMESTAMP_NTZ constraint
3. **No invented thresholds** — only thresholds from GLD_METRIC_DEFINITIONS or explicit requirements
4. **Reconciliation tolerance** — 0.01 as approved for rounding differences
5. **Alert bridge** — V_DQ_ALERT_CANDIDATES connects to existing ALERT_EVENT workflow
6. **Quality score** — excludes blocked/unsupported from denominator
7. **Idempotent execution** — TRUNCATE + INSERT pattern for clean reruns
