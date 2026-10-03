--------------------------------------------------------------------------------
-- Demo Graph Queries — Validated
-- DEMO/DEMO_GRAPH_QUERIES.sql
--------------------------------------------------------------------------------

-- ═══════════════════════════════════════════════════════════════════════
-- 1. GRAPH SUMMARY (show at start of graph section)
-- Expected: 166,530 nodes / 13 types / 932,013 edges / 25 types
-- ═══════════════════════════════════════════════════════════════════════
SELECT 'NODES' AS OBJ, COUNT(*) AS CNT, COUNT(DISTINCT NODE_TYPE) AS TYPES
FROM SCO_HACKATHON.SCO_GRAPH.V_ALL_NODES
UNION ALL
SELECT 'EDGES', COUNT(*), COUNT(DISTINCT EDGE_TYPE)
FROM SCO_HACKATHON.SCO_GRAPH.V_ALL_EDGES;

-- ═══════════════════════════════════════════════════════════════════════
-- 2. SUPPLIER DISRUPTION IMPACT — Multi-hop trace
-- "If Supplier 1 is disrupted, how many parts/orders/customers are affected?"
-- Expected: 15 parts → 585 orders → 984 shipments → 356 customers
-- ═══════════════════════════════════════════════════════════════════════
SELECT
    s.NODE_LABEL AS SUPPLIER,
    COUNT(DISTINCT sp.TARGET_NODE_ID) AS PARTS_AFFECTED,
    COUNT(DISTINCT oc.SOURCE_NODE_ID) AS ORDERS_AFFECTED,
    COUNT(DISTINCT sfo.SOURCE_NODE_ID) AS SHIPMENTS_AFFECTED,
    COUNT(DISTINCT sdc.TARGET_NODE_ID) AS CUSTOMERS_EXPOSED
FROM SCO_HACKATHON.SCO_GRAPH.V_NODE_SUPPLIER s
JOIN SCO_HACKATHON.SCO_GRAPH.V_EDGE_SUPPLIER_SUPPLIES_PART sp ON sp.SOURCE_NODE_ID = s.NODE_ID
JOIN SCO_HACKATHON.SCO_GRAPH.V_EDGE_ORDER_CONTAINS_PART oc ON oc.TARGET_NODE_ID = sp.TARGET_NODE_ID
JOIN SCO_HACKATHON.SCO_GRAPH.V_EDGE_SHIPMENT_FULFILLS_ORDER sfo ON sfo.TARGET_NODE_ID = oc.SOURCE_NODE_ID
JOIN SCO_HACKATHON.SCO_GRAPH.V_EDGE_SHIPMENT_DELIVERS_TO_CUSTOMER sdc ON sdc.SOURCE_NODE_ID = sfo.SOURCE_NODE_ID
WHERE s.ENTITY_ID = 1
GROUP BY s.NODE_LABEL;

-- ═══════════════════════════════════════════════════════════════════════
-- 3. CARRIER PERFORMANCE — Graph-derived on-time rates
-- Expected: Globalbridge Carrier 6 at 18.8% (worst)
-- ═══════════════════════════════════════════════════════════════════════
SELECT car.NODE_LABEL AS CARRIER, car.PRIMARY_MODE,
    COUNT(*) AS TOTAL_SHIPMENTS,
    COUNT_IF(sh.ON_TIME_ARRIVAL_FLAG) AS ON_TIME,
    ROUND(100.0*COUNT_IF(sh.ON_TIME_ARRIVAL_FLAG)/NULLIF(COUNT(*),0),1) AS ON_TIME_PCT
FROM SCO_HACKATHON.SCO_GRAPH.V_EDGE_SHIPMENT_TRANSPORTED_BY_CARRIER stc
JOIN SCO_HACKATHON.SCO_GRAPH.V_NODE_SHIPMENT sh ON sh.NODE_ID = stc.SOURCE_NODE_ID
JOIN SCO_HACKATHON.SCO_GRAPH.V_NODE_CARRIER car ON car.NODE_ID = stc.TARGET_NODE_ID
GROUP BY car.NODE_LABEL, car.PRIMARY_MODE
ORDER BY ON_TIME_PCT ASC LIMIT 5;

-- ═══════════════════════════════════════════════════════════════════════
-- 4. GRAPH INTEGRITY — No orphan edges (demo proof point)
-- Expected: 0 rows
-- ═══════════════════════════════════════════════════════════════════════
SELECT 'ORPHAN_SOURCE' AS CHECK, COUNT(*) AS VIOLATIONS
FROM SCO_HACKATHON.SCO_GRAPH.V_ALL_EDGES e
LEFT JOIN SCO_HACKATHON.SCO_GRAPH.V_ALL_NODES n ON n.NODE_ID = e.SOURCE_NODE_ID
WHERE n.NODE_ID IS NULL AND e.DIRECTION <> 'SELF'
UNION ALL
SELECT 'ORPHAN_TARGET', COUNT(*)
FROM SCO_HACKATHON.SCO_GRAPH.V_ALL_EDGES e
LEFT JOIN SCO_HACKATHON.SCO_GRAPH.V_ALL_NODES n ON n.NODE_ID = e.TARGET_NODE_ID
WHERE n.NODE_ID IS NULL AND e.DIRECTION <> 'SELF';
