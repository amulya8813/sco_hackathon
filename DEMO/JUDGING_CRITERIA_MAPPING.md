# Judging Criteria Mapping

## Real World Relevance

| Evidence | Where Shown |
|----------|-------------|
| Supply-chain OTD is a real metric used by every logistics organization | 0:40 — Governed Metric |
| Different teams calculating the same metric differently is a documented industry problem | 0:00 — Business Problem |
| Ratio-of-sums vs average-of-percentages is a real statistical governance issue | 1:10 — Conversational Analytics (82.45% vs 82.55%) |
| Supplier disruption impact analysis is a core supply-chain risk management use case | 1:50 — Knowledge Graph |
| Data quality monitoring and automated ticketing are standard operational practices | 2:15 — DQ and Jira |

## Technical Execution

| Evidence | Where Shown |
|----------|-------------|
| 24 source tables with synthetic but realistic data (~1M rows) | Architecture |
| Dynamic Tables for Bronze/Silver/Gold transformation | Architecture |
| Semantic View with multi-fact star model | 0:40 — Governed Metric |
| Cortex Analyst for natural-language analytics | 1:10 — Conversational Analytics |
| Knowledge graph with 166K nodes, 932K edges, 25 edge types | 1:50 — Knowledge Graph |
| 80 data quality checks across 10 dimensions | 2:15 — Data Quality |
| System and custom DMFs | 2:15 — Data Quality |
| Jira MCP integration with deduplication | 2:15 — Jira |
| Tasks, streams, stored procedures for orchestration | Architecture |
| CoCo used across full lifecycle: 74 files, ~142 database objects | 2:35 — CoCo Evidence |

## Solution Completeness

| Component | Status | Evidence |
|-----------|--------|----------|
| Source-to-Gold pipeline | PASS | 24 → 24 → 18 → 11 objects across 4 layers |
| Governed metrics (4) | PASS | OTD, Fill Rate, DOI, Landed Cost — all reconciled |
| Semantic View | PASS | SV_SUPPLY_CHAIN with identical formulas |
| Cortex Analyst | PASS | Natural-language questions resolve to governed metrics |
| Persona consistency | PASS | 3 personas, 1 answer (82.45%) |
| Streamlit (7 pages) | PASS | Executive Overview through Knowledge Graph |
| Knowledge graph | PASS | 13 node types, 25 edge types, 0 orphans |
| Data Quality (80 checks) | PASS | 74 pass, 6 expected freshness failures |
| Metric reconciliation | PASS | 4/4 metrics match governed formulas |
| Jira MCP | PASS | Dry-run with deduplication and audit logging |
| CoCo usage | PASS | Full lifecycle from design to demo prep |
| Orchestration | PASS | Tasks, streams, Dynamic Tables |

## What We Did NOT Claim
- No Cortex ML Forecasting
- No live Jira tickets (dry-run only)
- No 100% DQ pass rate (6 expected failures documented)
- No real-time streaming data (synthetic demo dataset)
