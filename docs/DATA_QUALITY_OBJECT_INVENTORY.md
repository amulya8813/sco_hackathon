# Data Quality Object Inventory

## SCO_SOURCE (24 tables)

| Object | Type | PK/BK | Row Count | Existing DQ | Proposed Checks |
|--------|------|-------|-----------|-------------|-----------------|
| COUNTRY | Table | country_id | 50 | Freshness(via _updated_at) | Completeness, Uniqueness |
| COMMODITY | Table | commodity_id | 200 | — | Completeness, Uniqueness(hs_code) |
| COMPLIANCE_LIST | Table | list_entry_id | 500 | — | Completeness |
| SUPPLIER | Table | supplier_id | 1,000 | Completeness(country_id) | Uniqueness(supplier_id), Freshness |
| CUSTOMER | Table | customer_id | 2,000 | — | Completeness(country_id), Uniqueness |
| CARRIER | Table | carrier_id | 50 | — | Completeness |
| PORT | Table | port_id | 80 | — | Completeness(country_id) |
| PART | Table | part_id | 5,000 | Completeness(commodity_id), Uniqueness(part_number) | — |
| WAREHOUSE | Table | warehouse_id | 30 | — | Completeness(country_id) |
| PLANT | Table | plant_id | 150 | RI(supplier_id→SUPPLIER) | Completeness |
| ROUTE | Table | route_id | 200 | — | RI(origin/dest_port_id→PORT) |
| SUPPLIER_CATALOG | Table | (supplier_id,part_id) | 15,000 | — | RI(supplier_id,part_id) |
| PLANT_PART_ASSIGNMENT | Table | assignment_id | 3,000 | — | RI(plant_id,part_id) |
| CARRIER_ROUTE_SERVICE | Table | service_id | 500 | — | RI(carrier_id,route_id) |
| SUPPLIER_COMPLIANCE_MATCH | Table | (supplier_id,list_entry_id) | 150 | — | RI |
| CUSTOMER_COMPLIANCE_MATCH | Table | (customer_id,list_entry_id) | 80 | — | RI |
| COMMODITY_RESTRICTION | Table | restriction_id | 100 | — | RI(commodity_id,country_id) |
| SUPPLIER_RISK_ASSESSMENT | Table | assessment_id | 4,000 | Freshness | Validity(score 0-100) |
| ESG_SCORE | Table | esg_id | 3,000 | Freshness | Validity(scores 0-100) |
| PURCHASE_ORDER | Table | po_id | 50,000 | Completeness, Uniqueness, Freshness, RI | — |
| ORDER_LINE_ITEM | Table | line_item_id | 196,666 | Completeness, Uniqueness, Freshness, RI | — |
| SHIPMENT | Table | shipment_id | 94,535 | Completeness, Uniqueness, Freshness, RI | — |
| SHIPMENT_LINE_ITEM | Table | shipment_line_id | 179,205 | RI | — |
| INVENTORY_POSITION | Table | (part_id,warehouse_id,snapshot_date) | 397,080 | Completeness, Uniqueness, Freshness, RI | — |

## SCO_SILVER (18 dynamic tables)

| Object | Type | Source | Row Count | Proposed Checks |
|--------|------|--------|-----------|-----------------|
| SLV_DIM_SUPPLIER | DT | BRZ_SUPPLIER | 1,000 | Uniqueness(supplier_id), Completeness |
| SLV_DIM_PART | DT | BRZ_PART | 5,000 | Uniqueness(part_id) |
| SLV_DIM_CUSTOMER | DT | BRZ_CUSTOMER | 2,000 | Uniqueness(customer_id) |
| SLV_DIM_PLANT | DT | BRZ_PLANT | 150 | RI(supplier_id→SLV_DIM_SUPPLIER) |
| SLV_DIM_WAREHOUSE | DT | BRZ_WAREHOUSE | 30 | Uniqueness(warehouse_id) |
| SLV_DIM_CARRIER | DT | BRZ_CARRIER | 50 | Uniqueness(carrier_id) |
| SLV_DIM_ROUTE | DT | BRZ_ROUTE | 200 | Uniqueness(route_id) |
| SLV_DIM_COUNTRY | DT | BRZ_COUNTRY | 50 | Uniqueness(country_id) |
| SLV_DIM_COMMODITY | DT | BRZ_COMMODITY | 200 | Uniqueness(commodity_id) |
| SLV_DIM_DATE | DT | GENERATOR | 731 | Uniqueness(date_day) |
| SLV_BRIDGE_SUPPLIER_PART | DT | BRZ_SUPPLIER_CATALOG | 15,000 | RI, Uniqueness |
| SLV_FACT_ORDER_LINE | DT | BRZ_ORDER_LINE_ITEM | 196,666 | RI, Validity |
| SLV_FACT_SHIPMENT | DT | BRZ_SHIPMENT | 94,535 | RI, Validity |
| SLV_FACT_SHIPMENT_LINE | DT | BRZ_SHIPMENT_LINE_ITEM | 179,205 | RI |
| SLV_FACT_INVENTORY | DT | BRZ_INVENTORY_POSITION | 397,080 | Validity |
| SLV_FACT_ESG | DT | BRZ_ESG_SCORE | 3,000 | Validity(scores), Polymorphic |
| SLV_FACT_SUPPLIER_COMPLIANCE | DT | BRZ_SUPPLIER_COMPLIANCE_MATCH | 150 | RI |
| SLV_FACT_SUPPLIER_RISK | DT | BRZ_SUPPLIER_RISK_ASSESSMENT | 4,000 | Validity(score) |

## SCO_GOLD (11 tables)

| Object | Type | Row Count | Streamlit Dep | Proposed Checks |
|--------|------|-----------|---------------|-----------------|
| GLD_METRIC_OTD | Table | 108,288 | Yes | Metric reconciliation, Grain uniqueness |
| GLD_METRIC_FILL_RATE | Table | 2,845 | Yes | Metric reconciliation, Grain uniqueness |
| GLD_METRIC_DOI | Table | 529,440 | Yes | Metric reconciliation, Grain uniqueness |
| GLD_METRIC_LANDED_COST | Table | 114,400 | Yes | Metric reconciliation, Grain uniqueness |
| GLD_INVENTORY_HEALTH | Table | 13,236 | Yes | Validity, Completeness |
| GLD_RISK_EXPOSURE | Table | 15,976 | Yes | Validity(risk_score 0-100) |
| GLD_SHIPMENT_PERFORMANCE | Table | 11,701 | Yes | Validity(on_time_rate 0-100) |
| GLD_SUPPLIER_SCORECARD | Table | 22,515 | Yes | Validity, Completeness |
| GLD_DEMAND_HISTORY | Table | 58,993 | Yes | Validity(quantity >= 0) |
| GLD_METRIC_DEFINITIONS | Table | 4 | Yes | Completeness(all cols required) |
| GLD_PIPELINE_AUDIT | Table | 0 | Yes | — |

## SCO_GRAPH (40 views)

| Object | Type | Row Count | Proposed Checks |
|--------|------|-----------|-----------------|
| V_ALL_NODES | View | 166,530 | Node ID format, No NULL types |
| V_ALL_EDGES | View | 932,013 | Orphan source/target, No invalid types |
| 13 V_NODE_* | Views | varies | Uniqueness(NODE_ID), Source lineage |
| 25 V_EDGE_* | Views | varies | Polymorphic resolution |

## SCO_GOVERNANCE (existing checks: 42)

| Dimension | Checks | Passed | Failed |
|-----------|--------|--------|--------|
| Completeness | 9 | 9 | 0 |
| Uniqueness | 9 | 9 | 0 |
| Referential Integrity | 7 | 7 | 0 |
| Business Rules | 11 | 11 | 0 |
| Freshness | 6 | 0 | 6 (expected — synthetic data is ~9 months old) |
| **Total** | **42** | **36** | **6** |

## SCO_MONITORING (5 objects, 1,816 alerts)

| Object | Type | Purpose |
|--------|------|---------|
| ALERT_EVENT | Table | Alert lifecycle |
| ALERT_THRESHOLD | Table | Governed thresholds |
| JIRA_SYNC_LOG | Table | MCP audit |
| V_ALERT_SUMMARY | View | Dashboard summary |
| V_JIRA_SYNC_QUEUE | View | Pending Jira sync |
