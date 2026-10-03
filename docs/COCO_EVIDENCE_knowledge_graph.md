# CoCo Evidence — Knowledge Graph Phase

## Evidence Checklist

| # | Claim | Evidence | Status |
|---|-------|---------|--------|
| 1 | All tables/columns verified before use | Queried `INFORMATION_SCHEMA.COLUMNS` for every Silver table; adjusted column names (e.g., `SUPPLIER_STATUS` not `IS_ACTIVE`) | PASS |
| 2 | No invented tables or columns | Every node view references verified Silver columns; Port derived from existing route data | PASS |
| 3 | No inferred relationships | Every edge maps to an explicit FK join in Silver fact/bridge tables | PASS |
| 4 | Bridge tables identified | `SLV_BRIDGE_SUPPLIER_PART` (M:N supplier-part), `SLV_FACT_SHIPMENT_LINE` (M:N shipment-order) | PASS |
| 5 | Polymorphic relationships handled | `ORIGIN_TYPE` dispatch for shipment origins (SUPPLIER/PLANT/WAREHOUSE); ESG links to both supplier and plant | PASS |
| 6 | SCO_SILVER as preferred source | All 13 node types source from Silver dimensions/facts | PASS |
| 7 | SCO_GOLD for metrics only | Gold tables not used in graph views; metrics linked via semantic view | PASS |
| 8 | Zero orphan edges | Validation query confirmed 0 orphan source + 0 orphan target | PASS |
| 9 | Zero duplicate edges | Validated via GROUP BY/HAVING COUNT > 1 | PASS |
| 10 | Zero invalid node types | All nodes in approved 13-type set | PASS |
| 11 | Polymorphic unknowns = 0 | All 94,535 shipment origins resolve to valid entity types | PASS |
| 12 | Source lineage preserved | Every node/edge view includes `SOURCE_TABLE` column | PASS |
| 13 | DQ scores propagated | Node views expose `DATA_QUALITY_SCORE` from Silver `_DQ_SCORE` | PASS |
| 14 | No existing objects modified | Only created new views in new SCO_GRAPH schema | PASS |
| 15 | Views not tables | All graph objects are views (zero storage cost) | PASS |
| 16 | Demo queries validated | Queries 1-10 tested; adjusted risk threshold based on actual data | PASS |
| 17 | Streamlit page integrated | `knowledge_graph.py` added to nav + `snowflake.yml` artifacts | PASS |

## CoCo Tools Used

- `snowflake_sql_execute` — Schema inspection, view creation, validation queries
- `write` / `edit` — SQL files, documentation, Streamlit page
- `read` / `glob` — Existing codebase discovery
- `task` (Explore agent) — Parallel reading of SQL and markdown files

## Files Generated

| File | Purpose |
|------|---------|
| `sql/10_create_graph_schema.sql` | Schema DDL |
| `sql/11_create_graph_nodes.sql` | 13 node view DDLs |
| `sql/12_create_graph_edges.sql` | 25 edge view DDLs (to be written from executed SQL) |
| `sql/13_graph_validation.sql` | 8 validation queries |
| `sql/14_graph_demo_queries.sql` | 10 demo traversal queries |
| `streamlit-v2/app_pages/knowledge_graph.py` | Interactive graph explorer page |
| `docs/KNOWLEDGE_GRAPH_DESIGN.md` | Graph design document |
| `docs/ENTITY_NODE_MAPPING.md` | Node type mapping reference |
| `docs/RELATIONSHIP_EDGE_MAPPING.md` | Edge type mapping reference |
| `docs/PROMPTS_knowledge_graph.md` | Prompt history |
| `docs/COCO_EVIDENCE_knowledge_graph.md` | This file |

## Graph Summary

- **166,530 nodes** across 13 types
- **~937,000 edges** across 25 types
- **0 validation failures**
- **40 views** in SCO_GRAPH schema (13 node + 25 edge + 2 union)
