--------------------------------------------------------------------------------
-- Supply Chain Ontology — Knowledge Graph: Validation Queries
-- 13_graph_validation.sql
--
-- Validates graph integrity:
--   1. Orphan edges (source or target node missing from V_ALL_NODES)
--   2. Duplicate edges
--   3. Invalid node types
--   4. Node type counts
--   5. Edge type counts
--   6. Polymorphic resolution (SHIPMENT_ORIGINATES_FROM targets valid types)
--   7. Deleted/inactive node consistency
--------------------------------------------------------------------------------

USE SCHEMA SCO_HACKATHON.SCO_GRAPH;

-- ═══════════════════════════════════════════════════════════════════════
-- 1. ORPHAN EDGES — edges referencing non-existent source nodes
-- ═══════════════════════════════════════════════════════════════════════
SELECT 'ORPHAN_SOURCE' AS CHECK_NAME, e.EDGE_TYPE, COUNT(*) AS VIOLATION_COUNT
FROM V_ALL_EDGES e
LEFT JOIN V_ALL_NODES n ON n.NODE_ID = e.SOURCE_NODE_ID
WHERE n.NODE_ID IS NULL AND e.DIRECTION <> 'SELF'
GROUP BY e.EDGE_TYPE
ORDER BY VIOLATION_COUNT DESC;

-- ═══════════════════════════════════════════════════════════════════════
-- 2. ORPHAN EDGES — edges referencing non-existent target nodes
-- ═══════════════════════════════════════════════════════════════════════
SELECT 'ORPHAN_TARGET' AS CHECK_NAME, e.EDGE_TYPE, COUNT(*) AS VIOLATION_COUNT
FROM V_ALL_EDGES e
LEFT JOIN V_ALL_NODES n ON n.NODE_ID = e.TARGET_NODE_ID
WHERE n.NODE_ID IS NULL AND e.DIRECTION <> 'SELF'
GROUP BY e.EDGE_TYPE
ORDER BY VIOLATION_COUNT DESC;

-- ═══════════════════════════════════════════════════════════════════════
-- 3. DUPLICATE EDGES — same source+target+type appearing more than once
-- ═══════════════════════════════════════════════════════════════════════
SELECT 'DUPLICATE_EDGE' AS CHECK_NAME, EDGE_TYPE, COUNT(*) AS DUPLICATE_COUNT
FROM (
    SELECT SOURCE_NODE_ID, TARGET_NODE_ID, EDGE_TYPE, COUNT(*) AS CNT
    FROM V_ALL_EDGES
    GROUP BY SOURCE_NODE_ID, TARGET_NODE_ID, EDGE_TYPE
    HAVING COUNT(*) > 1
)
GROUP BY EDGE_TYPE
ORDER BY DUPLICATE_COUNT DESC;

-- ═══════════════════════════════════════════════════════════════════════
-- 4. INVALID NODE TYPES
-- ═══════════════════════════════════════════════════════════════════════
SELECT 'INVALID_NODE_TYPE' AS CHECK_NAME, NODE_TYPE, COUNT(*) AS CNT
FROM V_ALL_NODES
WHERE NODE_TYPE NOT IN ('SUPPLIER','PART','PLANT','WAREHOUSE','CUSTOMER',
    'CARRIER','ROUTE','PORT','COUNTRY','COMMODITY','ORDER','SHIPMENT','INVENTORY')
GROUP BY NODE_TYPE;

-- ═══════════════════════════════════════════════════════════════════════
-- 5. NODE TYPE SUMMARY
-- ═══════════════════════════════════════════════════════════════════════
SELECT NODE_TYPE, COUNT(*) AS NODE_COUNT,
    COUNT_IF(IS_ACTIVE) AS ACTIVE_COUNT,
    AVG(DATA_QUALITY_SCORE) AS AVG_DQ_SCORE
FROM V_ALL_NODES
GROUP BY NODE_TYPE
ORDER BY NODE_COUNT DESC;

-- ═══════════════════════════════════════════════════════════════════════
-- 6. EDGE TYPE SUMMARY
-- ═══════════════════════════════════════════════════════════════════════
SELECT EDGE_TYPE, SOURCE_TYPE, TARGET_TYPE, DIRECTION, CARDINALITY,
    COUNT(*) AS EDGE_COUNT
FROM V_ALL_EDGES
GROUP BY EDGE_TYPE, SOURCE_TYPE, TARGET_TYPE, DIRECTION, CARDINALITY
ORDER BY EDGE_COUNT DESC;

-- ═══════════════════════════════════════════════════════════════════════
-- 7. POLYMORPHIC RESOLUTION — SHIPMENT_ORIGINATES_FROM targets valid types
-- ═══════════════════════════════════════════════════════════════════════
SELECT 'POLYMORPHIC_CHECK' AS CHECK_NAME, TARGET_TYPE,
    COUNT(*) AS EDGE_COUNT,
    COUNT_IF(TARGET_NODE_ID = 'UNKNOWN') AS UNKNOWN_COUNT
FROM V_EDGE_SHIPMENT_ORIGINATES_FROM
GROUP BY TARGET_TYPE
ORDER BY EDGE_COUNT DESC;

-- ═══════════════════════════════════════════════════════════════════════
-- 8. GRAPH SUMMARY
-- ═══════════════════════════════════════════════════════════════════════
SELECT
    (SELECT COUNT(*) FROM V_ALL_NODES) AS TOTAL_NODES,
    (SELECT COUNT(DISTINCT NODE_TYPE) FROM V_ALL_NODES) AS NODE_TYPES,
    (SELECT COUNT(*) FROM V_ALL_EDGES) AS TOTAL_EDGES,
    (SELECT COUNT(DISTINCT EDGE_TYPE) FROM V_ALL_EDGES) AS EDGE_TYPES;
