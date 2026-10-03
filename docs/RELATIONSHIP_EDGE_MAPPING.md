# Relationship-Edge Mapping — SCO Knowledge Graph

## Dimensional Edges (entity-to-entity, from Silver dimensions)

| # | Edge Type | Source → Target | Cardinality | Source Table | Join Keys | Edge Count |
|---|-----------|-----------------|-------------|-------------|-----------|------------|
| 1 | `SUPPLIER_SUPPLIES_PART` | Supplier → Part | M:N | `SLV_BRIDGE_SUPPLIER_PART` | supplier_id, part_id | 15,000 |
| 2 | `SUPPLIER_LOCATED_IN_COUNTRY` | Supplier → Country | N:1 | `SLV_DIM_SUPPLIER` | country_id | 1,000 |
| 3 | `PLANT_OWNED_BY_SUPPLIER` | Plant → Supplier | N:1 | `SLV_DIM_PLANT` | supplier_id | 150 |
| 4 | `PLANT_LOCATED_IN_COUNTRY` | Plant → Country | N:1 | `SLV_DIM_PLANT` | country_id | 150 |
| 5 | `WAREHOUSE_LOCATED_IN_COUNTRY` | Warehouse → Country | N:1 | `SLV_DIM_WAREHOUSE` | country_id | 30 |
| 6 | `CUSTOMER_LOCATED_IN_COUNTRY` | Customer → Country | N:1 | `SLV_DIM_CUSTOMER` | country_id | 2,000 |
| 7 | `CARRIER_LOCATED_IN_COUNTRY` | Carrier → Country | N:1 | `SLV_DIM_CARRIER` | country_id | 50 |
| 8 | `PART_CLASSIFIED_AS_COMMODITY` | Part → Commodity | N:1 | `SLV_DIM_PART` | commodity_id | 5,000 |
| 9 | `ROUTE_ORIGINATES_AT_PORT` | Route → Port | N:1 | `SLV_DIM_ROUTE` | origin_port_id | 200 |
| 10 | `ROUTE_TERMINATES_AT_PORT` | Route → Port | N:1 | `SLV_DIM_ROUTE` | destination_port_id | 200 |
| 11 | `PORT_LOCATED_IN_COUNTRY` | Port → Country | N:1 | `SLV_DIM_ROUTE` (derived) | country_id | 79 |

## Transactional Edges (from Silver facts)

| # | Edge Type | Source → Target | Cardinality | Source Table | Join Keys | Edge Count |
|---|-----------|-----------------|-------------|-------------|-----------|------------|
| 12 | `ORDER_PLACED_BY_CUSTOMER` | Order → Customer | N:1 | `SLV_FACT_ORDER_LINE` | customer_id | 50,000 |
| 13 | `ORDER_SUPPLIED_BY_SUPPLIER` | Order → Supplier | N:1 | `SLV_FACT_ORDER_LINE` | line_supplier_id | 50,000 |
| 14 | `ORDER_CONTAINS_PART` | Order → Part | M:N | `SLV_FACT_ORDER_LINE` | part_id | 167,028 |
| 15 | `SHIPMENT_FOLLOWS_ROUTE` | Shipment → Route | N:1 | `SLV_FACT_SHIPMENT` | route_id | 94,535 |
| 16 | `SHIPMENT_TRANSPORTED_BY_CARRIER` | Shipment → Carrier | N:1 | `SLV_FACT_SHIPMENT` | carrier_id | 94,535 |
| 17 | `SHIPMENT_DELIVERS_TO_CUSTOMER` | Shipment → Customer | N:1 | `SLV_FACT_SHIPMENT` | destination_customer_id | 66,216 |
| 18 | `SHIPMENT_ORIGINATES_FROM` | Shipment → Supplier/Plant/Warehouse | N:1 | `SLV_FACT_SHIPMENT` | origin_type + origin_*_id | 94,535 |
| 19 | `SHIPMENT_FULFILLS_ORDER` | Shipment → Order | M:N | `SLV_FACT_SHIPMENT_LINE` | order_id | 94,535 |
| 20 | `SHIPMENT_CONTAINS_PART` | Shipment → Part | M:N | `SLV_FACT_SHIPMENT_LINE` | part_id | 169,273 |
| 21 | `INVENTORY_FOR_PART` | Inventory → Part | N:1 | `SLV_FACT_INVENTORY` | part_id | 13,236 |
| 22 | `INVENTORY_STORED_AT_WAREHOUSE` | Inventory → Warehouse | N:1 | `SLV_FACT_INVENTORY` | warehouse_id | 13,236 |

## Risk/ESG/Compliance Edges (self-referential enrichment)

| # | Edge Type | Source → Target | Cardinality | Source Table | Join Keys | Edge Count |
|---|-----------|-----------------|-------------|-------------|-----------|------------|
| 23 | `SUPPLIER_HAS_RISK_ASSESSMENT` | Supplier → Supplier | 1:N (latest) | `SLV_FACT_SUPPLIER_RISK` | supplier_id | 500 |
| 24 | `SUPPLIER_HAS_COMPLIANCE_MATCH` | Supplier → Supplier | 1:N | `SLV_FACT_SUPPLIER_COMPLIANCE` | supplier_id, list_entry_id | 150 |
| 25 | `ENTITY_HAS_ESG_SCORE` | Supplier/Plant → self | 1:N (latest) | `SLV_FACT_ESG` | supplier_id, plant_id | 375 |

## Polymorphic Relationships

### SHIPMENT_ORIGINATES_FROM
Resolved via `SLV_FACT_SHIPMENT.ORIGIN_TYPE`:
- SUPPLIER → 90,670 edges
- PLANT → 2,575 edges
- WAREHOUSE → 1,290 edges
- UNKNOWN → 0 (all resolved)

### ENTITY_HAS_ESG_SCORE
- Supplier ESG → via `supplier_id` (latest scoring period)
- Plant ESG → via `plant_id` (latest scoring period)

## Validation Results

- Orphan source edges: **0**
- Orphan target edges: **0**
- Duplicate edges: **0**
- Invalid node types: **0**
- Polymorphic unknowns: **0**
