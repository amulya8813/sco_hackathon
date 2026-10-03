--------------------------------------------------------------------------------
-- Supply Chain Ontology — Knowledge Graph: Demo Traversal Queries
-- 14_graph_demo_queries.sql
--
-- 10 governed graph queries demonstrating:
--   multi-hop traversal, risk propagation, impact analysis,
--   traceability, and conversational analytics scenarios.
--------------------------------------------------------------------------------

USE SCHEMA SCO_HACKATHON.SCO_GRAPH;

-- ═══════════════════════════════════════════════════════════════════════
-- QUERY 1: Supplier-to-Customer Traceability
-- "Trace the complete path from a specific supplier to all customers
--  receiving parts from that supplier, through orders and shipments."
-- ═══════════════════════════════════════════════════════════════════════
-- Hop path: SUPPLIER → (supplies) PART → (in order) ORDER → (fulfilled by) SHIPMENT → (delivers to) CUSTOMER
SELECT
    s.NODE_LABEL  AS SUPPLIER,
    p.NODE_LABEL  AS PART,
    o.NODE_LABEL  AS ORDER_NUMBER,
    sh.NODE_LABEL AS SHIPMENT_REF,
    c.NODE_LABEL  AS CUSTOMER
FROM V_EDGE_SUPPLIER_SUPPLIES_PART sp
JOIN V_NODE_SUPPLIER s  ON s.NODE_ID = sp.SOURCE_NODE_ID
JOIN V_NODE_PART p      ON p.NODE_ID = sp.TARGET_NODE_ID
JOIN V_EDGE_ORDER_CONTAINS_PART oc ON oc.TARGET_NODE_ID = p.NODE_ID
JOIN V_NODE_ORDER o     ON o.NODE_ID = oc.SOURCE_NODE_ID
JOIN V_EDGE_SHIPMENT_FULFILLS_ORDER sfo ON sfo.TARGET_NODE_ID = o.NODE_ID
JOIN V_NODE_SHIPMENT sh ON sh.NODE_ID = sfo.SOURCE_NODE_ID
JOIN V_EDGE_SHIPMENT_DELIVERS_TO_CUSTOMER sdc ON sdc.SOURCE_NODE_ID = sh.NODE_ID
JOIN V_NODE_CUSTOMER c  ON c.NODE_ID = sdc.TARGET_NODE_ID
WHERE s.ENTITY_ID = 1  -- Supplier_0001
LIMIT 50;


-- ═══════════════════════════════════════════════════════════════════════
-- QUERY 2: Supplier Disruption — All Affected Parts
-- "If Supplier 42 is disrupted, which parts are affected?"
-- ═══════════════════════════════════════════════════════════════════════
SELECT
    s.NODE_LABEL  AS DISRUPTED_SUPPLIER,
    sp.SOLE_SOURCE_FLAG,
    p.NODE_LABEL  AS AFFECTED_PART,
    p.PART_CATEGORY
FROM V_EDGE_SUPPLIER_SUPPLIES_PART sp
JOIN V_NODE_SUPPLIER s ON s.NODE_ID = sp.SOURCE_NODE_ID
JOIN V_NODE_PART p     ON p.NODE_ID = sp.TARGET_NODE_ID
WHERE s.ENTITY_ID = 42
ORDER BY sp.SOLE_SOURCE_FLAG DESC, p.PART_CATEGORY;


-- ═══════════════════════════════════════════════════════════════════════
-- QUERY 3: Plants and Orders Affected by Unavailable Part
-- "Part 100 is out of stock — which plants produce it and which
--  open orders need it?"
-- ═══════════════════════════════════════════════════════════════════════
WITH affected_part AS (
    SELECT NODE_ID, NODE_LABEL FROM V_NODE_PART WHERE ENTITY_ID = 100
)
SELECT 'PLANT' AS IMPACT_TYPE, pl.NODE_LABEL AS IMPACTED_ENTITY, NULL AS ORDER_STATUS
FROM affected_part ap
JOIN V_EDGE_SUPPLIER_SUPPLIES_PART sp ON sp.TARGET_NODE_ID = ap.NODE_ID
JOIN V_EDGE_PLANT_OWNED_BY_SUPPLIER pos ON pos.TARGET_NODE_ID = sp.SOURCE_NODE_ID
JOIN V_NODE_PLANT pl ON pl.NODE_ID = pos.SOURCE_NODE_ID
UNION ALL
SELECT 'ORDER', o.NODE_LABEL, o.ORDER_STATUS
FROM affected_part ap
JOIN V_EDGE_ORDER_CONTAINS_PART oc ON oc.TARGET_NODE_ID = ap.NODE_ID
JOIN V_NODE_ORDER o ON o.NODE_ID = oc.SOURCE_NODE_ID
WHERE o.ORDER_STATUS NOT IN ('DELIVERED','CANCELLED')
LIMIT 50;


-- ═══════════════════════════════════════════════════════════════════════
-- QUERY 4: Shipments Through a Congested Port
-- "Show all shipments passing through ports with CONGESTED status."
-- ═══════════════════════════════════════════════════════════════════════
SELECT
    pt.NODE_LABEL AS CONGESTED_PORT,
    pt.AVG_DWELL_DAYS,
    r.NODE_LABEL  AS ROUTE,
    sh.NODE_LABEL AS SHIPMENT_REF,
    sh.SHIP_DATE,
    sh.SHIPMENT_STATUS
FROM V_NODE_PORT pt
JOIN V_EDGE_ROUTE_ORIGINATES_AT_PORT rop ON rop.TARGET_NODE_ID = pt.NODE_ID
JOIN V_NODE_ROUTE r ON r.NODE_ID = rop.SOURCE_NODE_ID
JOIN V_EDGE_SHIPMENT_FOLLOWS_ROUTE sfr ON sfr.TARGET_NODE_ID = r.NODE_ID
JOIN V_NODE_SHIPMENT sh ON sh.NODE_ID = sfr.SOURCE_NODE_ID
WHERE pt.CONGESTION_STATUS = 'CONGESTED'
LIMIT 50;


-- ═══════════════════════════════════════════════════════════════════════
-- QUERY 5: Customers Affected by Delayed Shipments
-- "Which customers have shipments that arrived late?"
-- ═══════════════════════════════════════════════════════════════════════
SELECT
    c.NODE_LABEL  AS CUSTOMER,
    c.CUSTOMER_REGION,
    COUNT(*)      AS LATE_SHIPMENT_COUNT
FROM V_NODE_SHIPMENT sh
JOIN V_EDGE_SHIPMENT_DELIVERS_TO_CUSTOMER sdc ON sdc.SOURCE_NODE_ID = sh.NODE_ID
JOIN V_NODE_CUSTOMER c ON c.NODE_ID = sdc.TARGET_NODE_ID
WHERE sh.ON_TIME_ARRIVAL_FLAG = FALSE
GROUP BY c.NODE_LABEL, c.CUSTOMER_REGION
ORDER BY LATE_SHIPMENT_COUNT DESC
LIMIT 20;


-- ═══════════════════════════════════════════════════════════════════════
-- QUERY 6: Inventory Exposure from Demand Spike
-- "Which parts at which warehouses are below reorder and have
--  high open-order volume?"
-- ═══════════════════════════════════════════════════════════════════════
SELECT
    inv.NODE_LABEL AS INVENTORY_POSITION,
    inv.QUANTITY_ON_HAND,
    inv.QUANTITY_AVAILABLE,
    inv.STOCKOUT_FLAG,
    COUNT(oc.SOURCE_NODE_ID) AS OPEN_ORDER_COUNT
FROM V_NODE_INVENTORY inv
JOIN V_EDGE_INVENTORY_FOR_PART ifp ON ifp.SOURCE_NODE_ID = inv.NODE_ID
JOIN V_EDGE_ORDER_CONTAINS_PART oc ON oc.TARGET_NODE_ID = ifp.TARGET_NODE_ID
JOIN V_NODE_ORDER o ON o.NODE_ID = oc.SOURCE_NODE_ID AND o.ORDER_STATUS NOT IN ('DELIVERED','CANCELLED')
WHERE inv.BELOW_REORDER_FLAG = TRUE
GROUP BY inv.NODE_LABEL, inv.QUANTITY_ON_HAND, inv.QUANTITY_AVAILABLE, inv.STOCKOUT_FLAG
ORDER BY OPEN_ORDER_COUNT DESC
LIMIT 20;


-- ═══════════════════════════════════════════════════════════════════════
-- QUERY 7: Risk Propagation — Supplier → Part → Order → Customer
-- "For high-risk suppliers, trace which customers are exposed."
-- ═══════════════════════════════════════════════════════════════════════
WITH high_risk_suppliers AS (
    SELECT NODE_ID, NODE_LABEL, OVERALL_RISK_SCORE, RISK_CATEGORY
    FROM V_NODE_SUPPLIER
    WHERE OVERALL_RISK_SCORE >= 40
)
SELECT
    hrs.NODE_LABEL AS HIGH_RISK_SUPPLIER,
    hrs.RISK_CATEGORY,
    hrs.OVERALL_RISK_SCORE,
    p.NODE_LABEL   AS PART,
    c.NODE_LABEL   AS EXPOSED_CUSTOMER,
    c.SERVICE_LEVEL_TIER
FROM high_risk_suppliers hrs
JOIN V_EDGE_SUPPLIER_SUPPLIES_PART sp ON sp.SOURCE_NODE_ID = hrs.NODE_ID
JOIN V_NODE_PART p ON p.NODE_ID = sp.TARGET_NODE_ID
JOIN V_EDGE_ORDER_CONTAINS_PART oc ON oc.TARGET_NODE_ID = p.NODE_ID
JOIN V_EDGE_ORDER_PLACED_BY_CUSTOMER opc ON opc.SOURCE_NODE_ID = oc.SOURCE_NODE_ID
JOIN V_NODE_CUSTOMER c ON c.NODE_ID = opc.TARGET_NODE_ID
LIMIT 100;


-- ═══════════════════════════════════════════════════════════════════════
-- QUERY 8: ESG Violations — Suppliers/Plants with Controversy
-- "Find suppliers and plants flagged for ESG controversy, and the parts
--  and customers connected to them."
-- ═══════════════════════════════════════════════════════════════════════
SELECT
    s.NODE_LABEL  AS SUPPLIER,
    esg.OVERALL_ESG_SCORE,
    esg.FORCED_LABOR_RISK,
    esg.CONTROVERSY_FLAG,
    COUNT(DISTINCT sp.TARGET_NODE_ID) AS PARTS_AFFECTED
FROM V_EDGE_ENTITY_HAS_ESG_SCORE esg
JOIN V_NODE_SUPPLIER s ON s.NODE_ID = esg.SOURCE_NODE_ID
LEFT JOIN V_EDGE_SUPPLIER_SUPPLIES_PART sp ON sp.SOURCE_NODE_ID = s.NODE_ID
WHERE esg.SOURCE_TYPE = 'SUPPLIER'
  AND (esg.CONTROVERSY_FLAG = TRUE OR esg.FORCED_LABOR_RISK = 'HIGH')
GROUP BY s.NODE_LABEL, esg.OVERALL_ESG_SCORE, esg.FORCED_LABOR_RISK, esg.CONTROVERSY_FLAG
ORDER BY PARTS_AFFECTED DESC
LIMIT 20;


-- ═══════════════════════════════════════════════════════════════════════
-- QUERY 9: Carrier Performance via Linked Shipments
-- "Rank carriers by on-time rate using actual shipment data."
-- ═══════════════════════════════════════════════════════════════════════
SELECT
    car.NODE_LABEL AS CARRIER,
    car.PRIMARY_MODE,
    COUNT(*)       AS TOTAL_SHIPMENTS,
    COUNT_IF(sh.ON_TIME_ARRIVAL_FLAG) AS ON_TIME_COUNT,
    ROUND(100.0 * COUNT_IF(sh.ON_TIME_ARRIVAL_FLAG) / NULLIF(COUNT(*), 0), 1) AS ON_TIME_PCT
FROM V_EDGE_SHIPMENT_TRANSPORTED_BY_CARRIER stc
JOIN V_NODE_SHIPMENT sh ON sh.NODE_ID = stc.SOURCE_NODE_ID
JOIN V_NODE_CARRIER car ON car.NODE_ID = stc.TARGET_NODE_ID
GROUP BY car.NODE_LABEL, car.PRIMARY_MODE
ORDER BY ON_TIME_PCT ASC
LIMIT 20;


-- ═══════════════════════════════════════════════════════════════════════
-- QUERY 10: Complete Order Lineage — Supplier to Customer
-- "For a specific order, show every entity in the chain."
-- ═══════════════════════════════════════════════════════════════════════
WITH target_order AS (
    SELECT NODE_ID, NODE_LABEL, CUSTOMER_ID, ORDER_DATE FROM V_NODE_ORDER WHERE ENTITY_ID = 1
)
SELECT 1 AS HOP, 'CUSTOMER' AS ENTITY_TYPE, c.NODE_LABEL AS ENTITY, NULL AS DETAIL
FROM target_order t
JOIN V_EDGE_ORDER_PLACED_BY_CUSTOMER opc ON opc.SOURCE_NODE_ID = t.NODE_ID
JOIN V_NODE_CUSTOMER c ON c.NODE_ID = opc.TARGET_NODE_ID

UNION ALL
SELECT 2, 'SUPPLIER', s.NODE_LABEL, NULL
FROM target_order t
JOIN V_EDGE_ORDER_SUPPLIED_BY_SUPPLIER oss ON oss.SOURCE_NODE_ID = t.NODE_ID
JOIN V_NODE_SUPPLIER s ON s.NODE_ID = oss.TARGET_NODE_ID

UNION ALL
SELECT 3, 'PART', p.NODE_LABEL, p.PART_CATEGORY
FROM target_order t
JOIN V_EDGE_ORDER_CONTAINS_PART oc ON oc.SOURCE_NODE_ID = t.NODE_ID
JOIN V_NODE_PART p ON p.NODE_ID = oc.TARGET_NODE_ID

UNION ALL
SELECT 4, 'SHIPMENT', sh.NODE_LABEL, sh.SHIPMENT_STATUS
FROM target_order t
JOIN V_EDGE_SHIPMENT_FULFILLS_ORDER sfo ON sfo.TARGET_NODE_ID = t.NODE_ID
JOIN V_NODE_SHIPMENT sh ON sh.NODE_ID = sfo.SOURCE_NODE_ID

UNION ALL
SELECT 5, 'CARRIER', car.NODE_LABEL, car.PRIMARY_MODE
FROM target_order t
JOIN V_EDGE_SHIPMENT_FULFILLS_ORDER sfo ON sfo.TARGET_NODE_ID = t.NODE_ID
JOIN V_EDGE_SHIPMENT_TRANSPORTED_BY_CARRIER stc ON stc.SOURCE_NODE_ID = sfo.SOURCE_NODE_ID
JOIN V_NODE_CARRIER car ON car.NODE_ID = stc.TARGET_NODE_ID

UNION ALL
SELECT 6, 'ROUTE', r.NODE_LABEL, r.PRIMARY_MODE
FROM target_order t
JOIN V_EDGE_SHIPMENT_FULFILLS_ORDER sfo ON sfo.TARGET_NODE_ID = t.NODE_ID
JOIN V_EDGE_SHIPMENT_FOLLOWS_ROUTE sfr ON sfr.SOURCE_NODE_ID = sfo.SOURCE_NODE_ID
JOIN V_NODE_ROUTE r ON r.NODE_ID = sfr.TARGET_NODE_ID

ORDER BY HOP;
