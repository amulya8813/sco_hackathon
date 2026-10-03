# Final Technical Validation

## Object Existence Verification

| Object | Verified | Row Count |
|--------|----------|-----------|
| SCO_GOLD.GLD_METRIC_OTD | YES | 108,288 |
| SCO_GOLD.GLD_METRIC_FILL_RATE | YES | 2,845 |
| SCO_GOLD.GLD_METRIC_DOI | YES | 529,440 |
| SCO_GOLD.GLD_METRIC_LANDED_COST | YES | 114,400 |
| SCO_GOLD.GLD_METRIC_DEFINITIONS | YES | 4 |
| SCO_GOLD.SV_SUPPLY_CHAIN | YES | Semantic View |
| SCO_GRAPH.V_ALL_NODES | YES | 166,530 |
| SCO_GRAPH.V_ALL_EDGES | YES | 932,013 |
| SCO_GOVERNANCE.DQ_CHECK_RESULT | YES | 80 |
| SCO_MONITORING.ALERT_EVENT | YES | 1,816 |

## Demo Query Validation

| Query | Expected | Actual | Status |
|-------|----------|--------|--------|
| OTD ratio-of-sums (2025) | 82.45% | 82.45% | PASS |
| OTD wrong avg method | 82.55% | 82.55% | PASS (proves governance) |
| Persona Planning | 82.45% | 82.45% | PASS |
| Persona Procurement | 82.45% | 82.45% | PASS |
| Persona Logistics | 82.45% | 82.45% | PASS |
| Graph: Supplier 1 parts | 15 | 15 | PASS |
| Graph: Supplier 1 customers | 356 | 356 | PASS |
| Carrier worst on-time | 18.8% | 18.8% | PASS |
| DQ checks passed | 74 | 74 | PASS |
| DQ checks failed | 6 | 6 | PASS (all freshness) |
| Metric reconciliation | 4/4 | 4/4 | PASS |
| Graph quality | 5/5 | 5/5 | PASS |
| Open alerts | 1,816 | 1,816 | PASS |

## Streamlit Pages

| Page | Loads | Key Feature |
|------|-------|-------------|
| Executive Overview | YES | 4 KPI cards with period comparison |
| Governed Metrics | YES | Metric definitions, trend charts, breakdowns |
| Ask Analyst | YES | Cortex Analyst chat via SV_SUPPLY_CHAIN |
| Forecasting | DO NOT SHOW | Out of scope |
| Alerts & Data Quality | YES | DQ scorecard, freshness, pipeline audit |
| Ontology Explorer | YES | Entity relationships, row counts |
| Knowledge Graph | YES | Graph summary, risk trace, carrier performance |

## Formula Verification

OTD stored in GLD_METRIC_OTD:
- Column: ON_TIME_DELIVERY_RATE_PCT
- Verified: = LINES_ON_TIME / LINES_DUE * 100 for every row where LINES_DUE > 0
- Row-level mismatch count: 0

Semantic View SV_SUPPLY_CHAIN OTD metric:
- Definition: `SUM(otd.LINES_ON_TIME) / NULLIF(SUM(otd.LINES_DUE), 0) * 100`
- Matches governed formula: YES

Streamlit executive_overview.py OTD:
- Line 79: `SUM(LINES_ON_TIME) / NULLIF(SUM(LINES_DUE), 0) * 100`
- Matches governed formula: YES

## Cortex ML Forecasting Exclusion Confirmed
- NOT mentioned in demo script
- NOT shown in click path
- NOT included in architecture
- NOT referenced in any demo SQL
- NOT part of judging criteria mapping
- Streamlit Forecasting page marked DO NOT SHOW
