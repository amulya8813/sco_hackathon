# Prompts — Knowledge Graph Phase

## Prompt 1: Discovery & Schema Inspection

Inspected all 24 SCO_SOURCE tables, 18 SCO_SILVER dynamic tables, and 11 SCO_GOLD objects via `INFORMATION_SCHEMA.COLUMNS` queries. Built a complete inventory of entity IDs, FK relationships, and join keys. Identified that no `SLV_DIM_PORT` exists (ports embedded in `SLV_DIM_ROUTE`), and that `SLV_FACT_SHIPMENT` has polymorphic origin/destination columns.

## Prompt 2: Graph Design & Node Creation

Designed 13 node types mapped 1:1 to Silver dimension/fact tables. Each node view provides: stable `NODE_ID`, `NODE_LABEL`, `NODE_TYPE`, `DATA_QUALITY_SCORE`, `IS_ACTIVE`, and entity-specific business attributes. Port nodes derived from route dimension. Order nodes deduplicated from fact order lines.

## Prompt 3: Edge Creation

Derived 25 edge types strictly from FK relationships in Silver tables. No relationships were inferred from column-name similarity. Handled polymorphic edges: `SHIPMENT_ORIGINATES_FROM` resolves via `ORIGIN_TYPE`; `ENTITY_HAS_ESG_SCORE` links both suppliers and plants.

## Prompt 4: Validation & Demo Queries

Created comprehensive validation: orphan edge checks (0 violations), duplicate edge detection, polymorphic resolution verification, node/edge type inventory. 10 demo traversal queries covering all required scenarios. Adjusted risk threshold (40 vs 75) based on actual data distribution.

## Prompt 5: Streamlit Integration

Added `knowledge_graph.py` page to the Streamlit app with: graph summary metrics, entity explorer with 1-hop neighborhood, multi-hop supplier-to-customer risk trace, and carrier performance visualization. Updated `snowflake.yml` artifacts.

## Key Design Decisions

1. **Relational fallback** — No native graph objects in account; used views.
2. **Silver preferred** — All nodes from conformed Silver dimensions.
3. **Port derivation** — Union of origin/destination ports from `SLV_DIM_ROUTE`.
4. **Self-referential edges** — Risk/ESG/compliance as enrichment edges on supplier/plant nodes.
5. **Polymorphic dispatch** — `CASE WHEN ORIGIN_TYPE` for shipment origins.
6. **Latest-only for risk/ESG** — `QUALIFY ROW_NUMBER()` to avoid historical explosion.
7. **No physical tables** — All graph objects are views for zero storage cost.
