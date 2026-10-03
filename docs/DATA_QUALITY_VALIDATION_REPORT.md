# Data Quality Validation Report

## Execution Summary

| Metric | Value |
|--------|-------|
| Total checks executed | 80 |
| Passed | 74 |
| Failed | 6 |
| Blocked | 0 |
| Unsupported | 0 |
| Overall pass rate | 92.5% |
| Critical failures | 0 |
| Quality dimensions | 9 |
| Layers covered | SOURCE, GOLD, GRAPH, SILVER |

## Results by Dimension

### Completeness (9/9 PASS)
All mandatory business columns validated: supplier_name, country_id, order_date, po_id, part_id, quantity_ordered, carrier_id, freight_cost_usd, commodity_id, quantity_on_hand. Zero NULLs found.

### Uniqueness (9/9 PASS)
All PKs and unique keys validated: supplier_id, po_id, order_number, line_item_id, shipment_id, part_number, hs_code, iso_alpha3, inventory composite key. Zero duplicates found.

### Referential Integrity (7/7 PASS)
All FK relationships validated: ORDER_LINE_ITEM→PURCHASE_ORDER, ORDER_LINE_ITEM→PART, SHIPMENT_LINE_ITEM→SHIPMENT, SHIPMENT_LINE_ITEM→ORDER_LINE_ITEM, INVENTORY→PART, PURCHASE_ORDER→SUPPLIER, PLANT→SUPPLIER. Zero orphans found.

### Business Rules (11/11 PASS)
All validity rules pass: non-positive quantities (0), shipped>ordered (0), receipt before ship (0), cancelled order with shipment (0), inventory balance check (0), negative inventory (0), risk score range (0), ESG score range (0), ESG parent check (0), shipment origin check (0), catalog coverage (0).

### Freshness (0/6 PASS — expected)
All 6 source tables show STALE (357+ hours) because synthetic data was loaded once on 2026-09-14. This is expected behavior — freshness SLAs are designed for live pipelines.

### Validity — Gold Layer (8/8 PASS)
- OTD rate in 0-100%: PASS (0 violations)
- Fill rate in 0-100%: PASS (0 violations)
- DOI non-negative: PASS (0 violations)
- Landed cost non-negative: PASS (0 violations)
- Lines on-time <= lines due: PASS (0 violations)
- Units fulfilled <= ordered: PASS (0 violations)
- Risk score 0-100: PASS (0 violations)
- ESG score 0-100: PASS (0 violations)

### Reconciliation — Gold Layer (4/4 PASS)
- **OTD recalc vs stored**: PASS — `SUM(on_time)/NULLIF(SUM(due),0)*100` matches `ON_TIME_DELIVERY_RATE_PCT` within 0.01 for all 108,288 rows
- **Fill Rate recalc vs stored**: PASS — matches within 0.01 for all 2,845 rows
- **DOI recalc vs stored**: PASS — `qty_on_hand/NULLIF(avg_daily_demand,0)` matches within 0.01
- **Landed Cost component sum**: PASS — purchase+freight+insurance+duties+handling = total within 0.01

### Graph Quality (5/5 PASS)
- No orphan source edges: PASS (0)
- No orphan target edges: PASS (0)
- 13 valid node types: PASS
- Polymorphic resolution: PASS (0 UNKNOWN)
- Node ID format: PASS (all match TYPE:id)

### Pipeline Health (5+/5+ PASS)
- 4 tasks exist and configured (suspended — expected for hackathon)
- Pipeline audit table accessible

## Persona Consistency
- OTD: 3 personas (Planning, Procurement, Logistics) return identical governed value
- Fill Rate: 2 personas return identical governed value
- Semantic View confirmed using ratio-of-sums formula (DDL inspection)
