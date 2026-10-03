# Data Quality Rule Catalog

## Summary

| Dimension | Checks | Passed | Failed | Notes |
|-----------|--------|--------|--------|-------|
| Completeness | 9 | 9 | 0 | All required columns populated |
| Uniqueness | 9 | 9 | 0 | All PKs and business keys unique |
| Referential Integrity | 7 | 7 | 0 | No orphan rows |
| Business Rules | 11 | 11 | 0 | All rules pass |
| Freshness | 6 | 0 | 6 | Expected — synthetic data ~15 days old |
| Validity | 12 | 12 | 0 | All ranges valid |
| Metric Reconciliation | 4 | 4 | 0 | All 4 metrics reconcile |
| Graph Quality | 5 | 5 | 0 | No orphans, all types valid |
| Pipeline Health | 3 | 3 | 0 | All layers populated |
| **Total** | **66** | **60** | **6** | 6 expected freshness failures |

## Rules by Dimension

### A. Freshness (6 checks)
| Rule ID | Check Name | Object | SLA | Status |
|---------|-----------|--------|-----|--------|
| F01 | FRESHNESS:PURCHASE_ORDER | SCO_SOURCE.PURCHASE_ORDER | 24h | FAIL (expected) |
| F02 | FRESHNESS:ORDER_LINE_ITEM | SCO_SOURCE.ORDER_LINE_ITEM | 24h | FAIL (expected) |
| F03 | FRESHNESS:SHIPMENT | SCO_SOURCE.SHIPMENT | 24h | FAIL (expected) |
| F04 | FRESHNESS:INVENTORY_POSITION | SCO_SOURCE.INVENTORY_POSITION | 24h | FAIL (expected) |
| F05 | FRESHNESS:SUPPLIER_RISK_ASSESSMENT | SCO_SOURCE.SUPPLIER_RISK_ASSESSMENT | 168h | FAIL (expected) |
| F06 | FRESHNESS:ESG_SCORE | SCO_SOURCE.ESG_SCORE | 168h | FAIL (expected) |

### B. Completeness (9 checks)
| Rule ID | Check Name | Column | Status |
|---------|-----------|--------|--------|
| C01 | ORDER_LINE_ITEM.promised_delivery_date | promised_delivery_date | PASS |
| C02 | ORDER_LINE_ITEM.quantity_ordered | quantity_ordered | PASS |
| C03 | PURCHASE_ORDER.order_date | order_date | PASS |
| C04 | PURCHASE_ORDER.total_value_usd | total_value_usd | PASS |
| C05 | SHIPMENT.freight_cost_usd | freight_cost_usd | PASS |
| C06 | SHIPMENT.carrier_id | carrier_id | PASS |
| C07 | INVENTORY_POSITION.quantity_on_hand | quantity_on_hand | PASS |
| C08 | SUPPLIER.country_id | country_id | PASS |
| C09 | PART.commodity_id | commodity_id | PASS |

### C. Uniqueness (9 checks)
| Rule ID | Check Name | Key | Status |
|---------|-----------|-----|--------|
| U01 | PURCHASE_ORDER.order_id (PK) | order_id | PASS |
| U02 | PURCHASE_ORDER.order_number (UQ) | order_number | PASS |
| U03 | ORDER_LINE_ITEM.line_item_id (PK) | line_item_id | PASS |
| U04 | SHIPMENT.shipment_id (PK) | shipment_id | PASS |
| U05 | SUPPLIER.supplier_id (PK) | supplier_id | PASS |
| U06 | PART.part_number (UQ) | part_number | PASS |
| U07 | COMMODITY.hs_code (UQ) | hs_code | PASS |
| U08 | COUNTRY.iso_alpha3 (UQ) | iso_alpha3 | PASS |
| U09 | INVENTORY_POSITION.part+warehouse+date (PK) | composite | PASS |

### D. Referential Integrity (7 checks)
| Rule ID | Relationship | Status |
|---------|-------------|--------|
| RI01 | ORDER_LINE_ITEM.order_id → PURCHASE_ORDER | PASS |
| RI02 | ORDER_LINE_ITEM.part_id → PART | PASS |
| RI03 | SHIPMENT_LINE_ITEM.shipment_id → SHIPMENT | PASS |
| RI04 | SHIPMENT_LINE_ITEM.line_item_id → ORDER_LINE_ITEM | PASS |
| RI05 | INVENTORY_POSITION.part_id → PART | PASS |
| RI06 | PURCHASE_ORDER.supplier_id → SUPPLIER | PASS |
| RI07 | PLANT.supplier_id → SUPPLIER | PASS |

### E. Business Rules (11 checks)
| Rule ID | Rule | Status |
|---------|------|--------|
| BR01 | Non-positive order quantity | PASS |
| BR02 | Shipped more than ordered | PASS |
| BR03 | Receipt date before ship date | PASS |
| BR04 | Cancelled order with a shipment | PASS |
| BR05 | Inventory available <> on_hand - reserved | PASS |
| BR06 | Negative inventory on hand | PASS |
| BR07 | Risk score outside 0-100 | PASS |
| BR08 | ESG score outside 0-100 | PASS |
| BR09 | ESG row without exactly one parent | PASS |
| BR10 | Shipment without exactly one origin node | PASS |
| BR11 | Order line not present in supplier catalog | PASS |

### F. Validity (12 checks)
| Rule ID | Check | Object | Status |
|---------|-------|--------|--------|
| V01 | OTD rate in [0,100] | GLD_METRIC_OTD | PASS |
| V02 | Fill rate in [0,100] | GLD_METRIC_FILL_RATE | PASS |
| V03 | Risk score in [0,100] | GLD_RISK_EXPOSURE | PASS |
| V04 | Inventory qty >= 0 | GLD_INVENTORY_HEALTH | PASS |
| V05 | Demand qty >= 0 | GLD_DEMAND_HISTORY | PASS |
| V06 | Shipment on-time rate in [0,100] | GLD_SHIPMENT_PERFORMANCE | PASS |
| V07 | OTD grain uniqueness | GLD_METRIC_OTD | PASS |
| V08 | Fill Rate grain uniqueness | GLD_METRIC_FILL_RATE | PASS |
| V09-V12 | Additional Gold table emptiness checks | Multiple | PASS |

### G. Metric Reconciliation (4 checks)
| Rule ID | Metric | Formula | Status |
|---------|--------|---------|--------|
| MR01 | OTD row-level | LINES_ON_TIME/LINES_DUE*100 = stored | PASS |
| MR02 | Fill Rate row-level | UNITS_FULFILLED/UNITS_ORDERED*100 = stored | PASS |
| MR03 | DOI row-level | QUANTITY_ON_HAND/AVG_DAILY_DEMAND = stored | PASS |
| MR04 | Landed Cost component-sum | Sum of components = total | PASS |

### H. Graph Quality (5 checks)
| Rule ID | Check | Status |
|---------|-------|--------|
| GQ01 | Node ID not NULL | PASS |
| GQ02 | Valid node types (13 approved) | PASS |
| GQ03 | No orphan source edges | PASS |
| GQ04 | No orphan target edges | PASS |
| GQ05 | Polymorphic origin resolved | PASS |

### I. Pipeline Health (3 checks)
| Rule ID | Check | Status |
|---------|-------|--------|
| PH01 | Silver tables >= 18 | PASS |
| PH02 | Gold tables >= 11 | PASS |
| PH03 | Graph views >= 40 | PASS |
