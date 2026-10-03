# Knowledge Graph Design — SCO Hackathon 2026

## Overview

A governed supply-chain knowledge graph implemented as relational node and edge views in `SCO_HACKATHON.SCO_GRAPH`, sourced from conformed Silver-layer dynamic tables in `SCO_SILVER`. The graph supports supply-chain traceability, impact analysis, multi-hop traversal, risk propagation, and governed conversational analytics.

## Architecture

```
SCO_SOURCE (24 tables)
    ↓ Bronze mirror
SCO_BRONZE
    ↓ Conformed dimensions & facts
SCO_SILVER (18 dynamic tables)
    ↓ Knowledge graph views
SCO_GRAPH (13 node views + 25 edge views + 2 union views)
    ↓ Governed metrics
SCO_GOLD (11 metric/scorecard tables)
```

## Implementation Approach

**Relational fallback** — No Snowflake-native graph objects were available in the account. The graph is implemented as:

- **Node views** (`V_NODE_*`): One view per entity type, projecting stable IDs, labels, DQ scores, and business attributes from Silver dimensions.
- **Edge views** (`V_EDGE_*`): One view per relationship type, derived strictly from FK joins in Silver fact/bridge tables.
- **Union views** (`V_ALL_NODES`, `V_ALL_EDGES`): Graph-wide query surfaces.
- **Multi-hop traversal**: Recursive CTEs and multi-join queries in `14_graph_demo_queries.sql`.

## Design Principles

1. **No invented relationships** — Every edge maps to an explicit FK in Silver.
2. **SCO_SILVER preferred** — Conformed, DQ-scored entities; Gold used only for metric linkage.
3. **Polymorphic handling** — `SLV_FACT_SHIPMENT.ORIGIN_TYPE` resolves to SUPPLIER, PLANT, or WAREHOUSE.
4. **ESG polymorphism** — ESG scores link to both suppliers and plants via `SLV_FACT_ESG`.
5. **Stable identifiers** — `NODE_ID = 'TYPE:' || ENTITY_ID` enables deterministic graph traversal.
6. **Source lineage** — Every node and edge carries `SOURCE_TABLE`.
7. **DQ integration** — Node views expose `DATA_QUALITY_SCORE` from Silver `_DQ_SCORE`.

## Graph Summary

| Metric | Count |
|---|---|
| Node types | 13 |
| Total nodes | 166,530 |
| Edge types | 25 |
| Total edges | ~937,000 |
| Orphan edges | 0 |
| Invalid node types | 0 |
| Polymorphic unknowns | 0 |

## Object Dependency Order

```
1. SCO_GRAPH schema (10_create_graph_schema.sql)
2. Node views (11_create_graph_nodes.sql) — depend on SCO_SILVER dims
3. Edge views (12_create_graph_edges.sql) — depend on SCO_SILVER facts + node views
4. Union views (V_ALL_NODES, V_ALL_EDGES) — depend on all node/edge views
5. Validation (13_graph_validation.sql) — depend on union views
6. Demo queries (14_graph_demo_queries.sql) — depend on node + edge views
```

## Demo Scenarios Supported

1. **Supplier disruption** — Trace affected parts, orders, shipments, customers
2. **Shipment delay** — Late shipments → affected customers
3. **Port congestion** — Congested ports → routes → shipments
4. **Inventory shortage** — Below-reorder positions → open order exposure
5. **ESG violation** — Flagged suppliers → connected parts and customers
6. **Demand spike** — Stockout risk across warehouse positions
7. **Risk propagation** — High-risk supplier → multi-hop to customer exposure
8. **Carrier performance** — Graph-derived on-time rates
9. **Complete order lineage** — Full chain from supplier to customer
10. **Compliance exposure** — Sanctions-matched suppliers → supply chain impact
