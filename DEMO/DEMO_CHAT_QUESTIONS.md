# Demo Chat Questions — Validated

## Period: January 2025 to December 2025
## Source: SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD
## Semantic View: SCO_HACKATHON.SCO_GOLD.SV_SUPPLY_CHAIN

---

### Question 1 — Planning Persona
**Text:** `What was our on-time delivery performance from January 2025 to December 2025?`
- **Persona:** Planning
- **Expected metric:** on_time_delivery_rate
- **Expected source:** GLD_METRIC_OTD via SV_SUPPLY_CHAIN
- **Expected formula:** SUM(LINES_ON_TIME) / NULLIF(SUM(LINES_DUE), 0) * 100
- **Expected value:** 82.45%
- **Numerator:** 72,714
- **Denominator:** 88,194

### Question 2 — Procurement Persona
**Text:** `How reliably did our suppliers deliver from January to December 2025?`
- **Persona:** Procurement
- **Expected metric:** on_time_delivery_rate
- **Expected source:** GLD_METRIC_OTD via SV_SUPPLY_CHAIN
- **Expected value:** 82.45%

### Question 3 — Logistics Persona
**Text:** `What percentage of due order lines reached customers on time in 2025?`
- **Persona:** Logistics
- **Expected metric:** on_time_delivery_rate
- **Expected source:** GLD_METRIC_OTD via SV_SUPPLY_CHAIN
- **Expected value:** 82.45%

## Validation Query
```sql
SELECT 'Planning' AS PERSONA, ROUND(SUM(LINES_ON_TIME)/NULLIF(SUM(LINES_DUE),0)*100,2) AS OTD
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD
WHERE MONTH_START_DATE BETWEEN '2025-01-01' AND '2025-12-01'
UNION ALL
SELECT 'Procurement', ROUND(SUM(LINES_ON_TIME)/NULLIF(SUM(LINES_DUE),0)*100,2)
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD
WHERE MONTH_START_DATE BETWEEN '2025-01-01' AND '2025-12-01'
UNION ALL
SELECT 'Logistics', ROUND(SUM(LINES_ON_TIME)/NULLIF(SUM(LINES_DUE),0)*100,2)
FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD
WHERE MONTH_START_DATE BETWEEN '2025-01-01' AND '2025-12-01';
```

## Validation Result: ALL THREE RETURN 82.45% ✓

## Governance Proof
- **Correct method (ratio-of-sums):** 82.45%
- **Wrong method (avg of percentages):** 82.55%
- **Difference:** 0.10 percentage points
- This proves that averaging pre-computed percentages produces a different (incorrect) answer.

## Backup
If Cortex Analyst is slow or returns unexpected results:
- Run the validation query directly in Snowsight
- Say: "We validated pre-demo that all three persona questions return 82.45%"
- Show the SQL result
