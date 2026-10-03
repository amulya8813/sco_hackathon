# Entity-Node Mapping — SCO Knowledge Graph

| # | Entity | Node View | Source Table | Node ID Pattern | Key Attributes | Row Count |
|---|--------|-----------|-------------|-----------------|----------------|-----------|
| 1 | Supplier | `V_NODE_SUPPLIER` | `SLV_DIM_SUPPLIER` | `SUPPLIER:{id}` | name, country, tier, risk_score, esg_score, risk_category | 1,000 |
| 2 | Part | `V_NODE_PART` | `SLV_DIM_PART` | `PART:{id}` | number, category, commodity_id, hs_code, cost, weight | 5,000 |
| 3 | Plant | `V_NODE_PLANT` | `SLV_DIM_PLANT` | `PLANT:{id}` | name, supplier_id, country, type, capacity | 150 |
| 4 | Warehouse | `V_NODE_WAREHOUSE` | `SLV_DIM_WAREHOUSE` | `WAREHOUSE:{id}` | name, country, type, capacity | 30 |
| 5 | Customer | `V_NODE_CUSTOMER` | `SLV_DIM_CUSTOMER` | `CUSTOMER:{id}` | name, country, region, service_tier, type | 2,000 |
| 6 | Carrier | `V_NODE_CARRIER` | `SLV_DIM_CARRIER` | `CARRIER:{id}` | name, country, mode, on_time_rate | 50 |
| 7 | Route | `V_NODE_ROUTE` | `SLV_DIM_ROUTE` | `ROUTE:{id}` | name, origin/dest port, mode, transit_days, cost | 200 |
| 8 | Port | `V_NODE_PORT` | `SLV_DIM_ROUTE` (derived) | `PORT:{id}` | name, country, un_locode, congestion_status | 79 |
| 9 | Country | `V_NODE_COUNTRY` | `SLV_DIM_COUNTRY` | `COUNTRY:{id}` | name, iso codes, region, sanctions_status, risk_rating | 50 |
| 10 | Commodity | `V_NODE_COMMODITY` | `SLV_DIM_COMMODITY` | `COMMODITY:{id}` | description, hs_code, esg_risk_flag, export_control | 200 |
| 11 | Order | `V_NODE_ORDER` | `SLV_FACT_ORDER_LINE` | `ORDER:{id}` | number, customer_id, date, status, priority, value | 50,000 |
| 12 | Shipment | `V_NODE_SHIPMENT` | `SLV_FACT_SHIPMENT` | `SHIPMENT:{id}` | reference, carrier, route, date, status, on_time_flag | 94,535 |
| 13 | Inventory | `V_NODE_INVENTORY` | `SLV_FACT_INVENTORY` | `INVENTORY:{part}:{wh}` | part+warehouse, qty_on_hand, stockout_flag | 13,236 |

## Common Node Columns

Every node view provides:
- `NODE_ID` — Stable identifier (`TYPE:entity_id`)
- `NODE_LABEL` — Human-readable business name
- `NODE_TYPE` — Entity classification
- `ENTITY_ID` — Numeric business key
- `DESCRIPTION` — Business definition
- `SOURCE_TABLE` — Silver table providing the data
- `DATA_QUALITY_SCORE` — DQ score from Silver `_DQ_SCORE`
- `IS_ACTIVE` — Active/operational status

## Notes

- **Port** is derived from `SLV_DIM_ROUTE` since no `SLV_DIM_PORT` exists in Silver.
- **Order** is derived from `SLV_FACT_ORDER_LINE` with deduplication via `QUALIFY ROW_NUMBER()`.
- **Inventory** shows the latest snapshot per part-warehouse combination.
