# Data Quality Framework — SCO Hackathon 2026

## Overview

An end-to-end data quality framework for the SCO supply-chain analytics solution, validating entities, relationships, governed metrics, graph integrity, pipeline health, and semantic consistency. Integrates with the existing Streamlit dashboard and Jira MCP alerting workflow.

## Architecture

```
SCO_SOURCE / SILVER / GOLD (data objects)
    ↓ System DMFs (FRESHNESS, NULL_COUNT, DUPLICATE_COUNT, ROW_COUNT)
    ↓ SQL validation checks (validity, reconciliation, graph, pipeline)
SCO_GOVERNANCE.DQ_CHECK_RESULT (centralized results — 80 checks)
    ↓ Quality score views (V_DQ_QUALITY_SCORE, V_DQ_OVERALL_SCORE)
    ↓ Alert bridge (V_DQ_ALERT_CANDIDATES)
SCO_MONITORING.ALERT_EVENT (existing Jira workflow)
```

## Quality Dimensions (9)

| Dimension | Layer(s) | Checks | Pass | Fail |
|-----------|----------|--------|------|------|
| Completeness | SOURCE | 9 | 9 | 0 |
| Uniqueness | SOURCE | 9 | 9 | 0 |
| Referential Integrity | SOURCE | 7 | 7 | 0 |
| Business Rules | SOURCE | 11 | 11 | 0 |
| Freshness | SOURCE | 6 | 0 | 6 |
| Validity | GOLD | 8 | 8 | 0 |
| Reconciliation | GOLD | 4 | 4 | 0 |
| Graph Quality | GRAPH | 5 | 5 | 0 |
| Pipeline Health | GOLD/SILVER | 5+ | 5+ | 0 |
| **TOTAL** | | **80** | **74** | **6** |

## Overall Pass Rate: 92.5% (74/80 active checks)

All 6 failures are freshness checks — expected with synthetic data that was loaded once and not refreshed. All business-logic, validity, reconciliation, and graph integrity checks pass.

## Key Validations

### Governed Metric Reconciliation (all PASS)
- **OTD**: Row-level recalc matches stored `ON_TIME_DELIVERY_RATE_PCT` within 0.01
- **Fill Rate**: Row-level recalc matches stored `FILL_RATE_PCT` within 0.01
- **DOI**: `QUANTITY_ON_HAND / AVG_DAILY_DEMAND` matches `DAYS_OF_INVENTORY` within 0.01
- **Landed Cost**: Component sum equals stored total within 0.01
- **OTD formula**: Confirmed ratio-of-sums, NOT average-of-percentages

### Graph Integrity (all PASS)
- 0 orphan source edges, 0 orphan target edges
- All 13 node types valid, all node IDs match `TYPE:id` format
- Polymorphic shipment origins: 0 UNKNOWN targets

### Persona Consistency
- All 3 persona OTD queries (Planning, Procurement, Logistics) return identical values
- Fill Rate: Planning and Logistics return identical values
- Semantic View formula confirmed as ratio-of-sums

## Integration Points

- **Streamlit**: Existing `Alerts & Data Quality` page reads from `V_DQ_SCORECARD` which feeds `DQ_CHECK_RESULT`
- **Jira MCP**: `V_DQ_ALERT_CANDIDATES` produces failed checks for existing alert pipeline
- **Knowledge Graph**: Graph quality checks validate node/edge integrity

## Known Limitations

1. **Freshness failures**: Synthetic data loaded once; freshness SLAs designed for live environments
2. **DMF attachments**: Proposed in `26_attach_system_dmfs.sql` but not executed (dry-run mode)
3. **Semantic View reconciliation**: Cannot execute Cortex Analyst queries from SQL; formula confirmed via DDL inspection
4. **Pipeline tasks**: All suspended; pipeline health checks pass as "configured but not running"
5. **Custom DMFs**: Created in `27_create_custom_dmfs.sql` but not yet attached to tables
