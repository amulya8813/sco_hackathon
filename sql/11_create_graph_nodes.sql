--------------------------------------------------------------------------------
-- Supply Chain Ontology — Knowledge Graph: Node Views
-- 11_create_graph_nodes.sql
--
-- 13 node types, each a view in SCO_GRAPH sourced from SCO_SILVER.
-- Every node has: NODE_ID, NODE_LABEL, NODE_TYPE, ENTITY_ID, DESCRIPTION,
--                 SOURCE_TABLE, DATA_QUALITY_SCORE, IS_ACTIVE
-- plus entity-specific business attributes.
--------------------------------------------------------------------------------

USE SCHEMA SCO_HACKATHON.SCO_GRAPH;

-- ═══════════════════════════════════════════════════════════════════════
-- 1. SUPPLIER
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW V_NODE_SUPPLIER AS
SELECT
    'SUPPLIER:' || SUPPLIER_ID           AS NODE_ID,
    SUPPLIER_NAME                        AS NODE_LABEL,
    'SUPPLIER'                           AS NODE_TYPE,
    SUPPLIER_ID                          AS ENTITY_ID,
    'External organization providing parts/materials under contract' AS DESCRIPTION,
    'SCO_SILVER.SLV_DIM_SUPPLIER'        AS SOURCE_TABLE,
    _DQ_SCORE                            AS DATA_QUALITY_SCORE,
    IFF(SUPPLIER_STATUS = 'ACTIVE', TRUE, FALSE) AS IS_ACTIVE,
    COUNTRY_ID, COUNTRY_NAME, SUPPLIER_TIER, OVERALL_RISK_SCORE,
    INDUSTRY_DESCRIPTION, OVERALL_ESG_SCORE, RISK_CATEGORY
FROM SCO_HACKATHON.SCO_SILVER.SLV_DIM_SUPPLIER;

-- ═══════════════════════════════════════════════════════════════════════
-- 2. PART
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW V_NODE_PART AS
SELECT
    'PART:' || PART_ID                   AS NODE_ID,
    PART_NAME                            AS NODE_LABEL,
    'PART'                               AS NODE_TYPE,
    PART_ID                              AS ENTITY_ID,
    'Distinct item/SKU that can be ordered, shipped, and inventoried' AS DESCRIPTION,
    'SCO_SILVER.SLV_DIM_PART'            AS SOURCE_TABLE,
    _DQ_SCORE                            AS DATA_QUALITY_SCORE,
    IFF(LIFECYCLE_STATUS = 'ACTIVE', TRUE, FALSE) AS IS_ACTIVE,
    PART_NUMBER, PART_CATEGORY, COMMODITY_ID, HS_CODE,
    STANDARD_COST_USD, UNIT_WEIGHT_KG, ESG_RISK_FLAG, EXPORT_CONTROL_FLAG
FROM SCO_HACKATHON.SCO_SILVER.SLV_DIM_PART;

-- ═══════════════════════════════════════════════════════════════════════
-- 3. PLANT
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW V_NODE_PLANT AS
SELECT
    'PLANT:' || PLANT_ID                 AS NODE_ID,
    PLANT_NAME                           AS NODE_LABEL,
    'PLANT'                              AS NODE_TYPE,
    PLANT_ID                             AS ENTITY_ID,
    'Manufacturing/assembly facility where parts are produced' AS DESCRIPTION,
    'SCO_SILVER.SLV_DIM_PLANT'           AS SOURCE_TABLE,
    _DQ_SCORE                            AS DATA_QUALITY_SCORE,
    IFF(OPERATIONAL_STATUS = 'OPERATIONAL', TRUE, FALSE) AS IS_ACTIVE,
    SUPPLIER_ID, SUPPLIER_NAME, COUNTRY_ID, COUNTRY_NAME,
    PLANT_TYPE, CAPACITY_UNITS_PER_DAY
FROM SCO_HACKATHON.SCO_SILVER.SLV_DIM_PLANT;

-- ═══════════════════════════════════════════════════════════════════════
-- 4. WAREHOUSE
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW V_NODE_WAREHOUSE AS
SELECT
    'WAREHOUSE:' || WAREHOUSE_ID         AS NODE_ID,
    WAREHOUSE_NAME                       AS NODE_LABEL,
    'WAREHOUSE'                          AS NODE_TYPE,
    WAREHOUSE_ID                         AS ENTITY_ID,
    'Storage facility for inventory, from which orders are fulfilled' AS DESCRIPTION,
    'SCO_SILVER.SLV_DIM_WAREHOUSE'       AS SOURCE_TABLE,
    _DQ_SCORE                            AS DATA_QUALITY_SCORE,
    IFF(OPERATIONAL_STATUS = 'OPERATIONAL', TRUE, FALSE) AS IS_ACTIVE,
    COUNTRY_ID, COUNTRY_NAME, WAREHOUSE_TYPE, CAPACITY_SQFT
FROM SCO_HACKATHON.SCO_SILVER.SLV_DIM_WAREHOUSE;

-- ═══════════════════════════════════════════════════════════════════════
-- 5. CUSTOMER
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW V_NODE_CUSTOMER AS
SELECT
    'CUSTOMER:' || CUSTOMER_ID           AS NODE_ID,
    CUSTOMER_NAME                        AS NODE_LABEL,
    'CUSTOMER'                           AS NODE_TYPE,
    CUSTOMER_ID                          AS ENTITY_ID,
    'Organization that places demand for parts from the supply chain' AS DESCRIPTION,
    'SCO_SILVER.SLV_DIM_CUSTOMER'        AS SOURCE_TABLE,
    _DQ_SCORE                            AS DATA_QUALITY_SCORE,
    TRUE                                 AS IS_ACTIVE,
    COUNTRY_ID, COUNTRY_NAME, CUSTOMER_REGION, SERVICE_LEVEL_TIER,
    CUSTOMER_TYPE, MARKET_SEGMENT
FROM SCO_HACKATHON.SCO_SILVER.SLV_DIM_CUSTOMER;

-- ═══════════════════════════════════════════════════════════════════════
-- 6. CARRIER
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW V_NODE_CARRIER AS
SELECT
    'CARRIER:' || CARRIER_ID             AS NODE_ID,
    CARRIER_NAME                         AS NODE_LABEL,
    'CARRIER'                            AS NODE_TYPE,
    CARRIER_ID                           AS ENTITY_ID,
    'Logistics provider responsible for transporting shipments' AS DESCRIPTION,
    'SCO_SILVER.SLV_DIM_CARRIER'         AS SOURCE_TABLE,
    _DQ_SCORE                            AS DATA_QUALITY_SCORE,
    IFF(CONTRACT_STATUS = 'ACTIVE', TRUE, FALSE) AS IS_ACTIVE,
    COUNTRY_ID, COUNTRY_NAME, PRIMARY_MODE, ON_TIME_RATE_PCT, DAMAGE_RATE_PCT
FROM SCO_HACKATHON.SCO_SILVER.SLV_DIM_CARRIER;

-- ═══════════════════════════════════════════════════════════════════════
-- 7. ROUTE
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW V_NODE_ROUTE AS
SELECT
    'ROUTE:' || ROUTE_ID                 AS NODE_ID,
    ROUTE_NAME                           AS NODE_LABEL,
    'ROUTE'                              AS NODE_TYPE,
    ROUTE_ID                             AS ENTITY_ID,
    'Defined logistics lane between origin and destination ports' AS DESCRIPTION,
    'SCO_SILVER.SLV_DIM_ROUTE'           AS SOURCE_TABLE,
    _DQ_SCORE                            AS DATA_QUALITY_SCORE,
    TRUE                                 AS IS_ACTIVE,
    ORIGIN_PORT_ID, ORIGIN_PORT_NAME, DESTINATION_PORT_ID, DESTINATION_PORT_NAME,
    PRIMARY_MODE, AVG_TRANSIT_DAYS, AVG_COST_PER_KG_USD, RELIABILITY_PCT
FROM SCO_HACKATHON.SCO_SILVER.SLV_DIM_ROUTE;

-- ═══════════════════════════════════════════════════════════════════════
-- 8. PORT (derived from Route dimension — origin + destination ports)
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW V_NODE_PORT AS
WITH all_ports AS (
    SELECT DISTINCT
        ORIGIN_PORT_ID       AS PORT_ID,
        ORIGIN_PORT_NAME     AS PORT_NAME,
        ORIGIN_PORT_UN_LOCODE AS UN_LOCODE,
        ORIGIN_COUNTRY_ID    AS COUNTRY_ID,
        ORIGIN_COUNTRY_NAME  AS COUNTRY_NAME,
        ORIGIN_PORT_CONGESTION_STATUS AS CONGESTION_STATUS,
        ORIGIN_PORT_AVG_DWELL_DAYS    AS AVG_DWELL_DAYS
    FROM SCO_HACKATHON.SCO_SILVER.SLV_DIM_ROUTE
    WHERE ORIGIN_PORT_ID IS NOT NULL
    UNION
    SELECT DISTINCT
        DESTINATION_PORT_ID,
        DESTINATION_PORT_NAME,
        DESTINATION_PORT_UN_LOCODE,
        DESTINATION_COUNTRY_ID,
        DESTINATION_COUNTRY_NAME,
        DESTINATION_PORT_CONGESTION_STATUS,
        DESTINATION_PORT_AVG_DWELL_DAYS
    FROM SCO_HACKATHON.SCO_SILVER.SLV_DIM_ROUTE
    WHERE DESTINATION_PORT_ID IS NOT NULL
)
SELECT
    'PORT:' || PORT_ID                   AS NODE_ID,
    PORT_NAME                            AS NODE_LABEL,
    'PORT'                               AS NODE_TYPE,
    PORT_ID                              AS ENTITY_ID,
    'Seaport, airport, or inland port for cargo movement' AS DESCRIPTION,
    'SCO_SILVER.SLV_DIM_ROUTE (derived)' AS SOURCE_TABLE,
    NULL                                 AS DATA_QUALITY_SCORE,
    TRUE                                 AS IS_ACTIVE,
    COUNTRY_ID, COUNTRY_NAME, UN_LOCODE, CONGESTION_STATUS, AVG_DWELL_DAYS
FROM all_ports;

-- ═══════════════════════════════════════════════════════════════════════
-- 9. COUNTRY
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW V_NODE_COUNTRY AS
SELECT
    'COUNTRY:' || COUNTRY_ID             AS NODE_ID,
    COUNTRY_NAME                         AS NODE_LABEL,
    'COUNTRY'                            AS NODE_TYPE,
    COUNTRY_ID                           AS ENTITY_ID,
    'Geographic entity with ISO codes and risk/sanctions attributes' AS DESCRIPTION,
    'SCO_SILVER.SLV_DIM_COUNTRY'         AS SOURCE_TABLE,
    _DQ_SCORE                            AS DATA_QUALITY_SCORE,
    TRUE                                 AS IS_ACTIVE,
    ISO_ALPHA2, ISO_ALPHA3, REGION_NAME, SUB_REGION,
    SANCTIONS_STATUS, RISK_RATING
FROM SCO_HACKATHON.SCO_SILVER.SLV_DIM_COUNTRY;

-- ═══════════════════════════════════════════════════════════════════════
-- 10. COMMODITY
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW V_NODE_COMMODITY AS
SELECT
    'COMMODITY:' || COMMODITY_ID         AS NODE_ID,
    COMMODITY_DESCRIPTION                AS NODE_LABEL,
    'COMMODITY'                          AS NODE_TYPE,
    COMMODITY_ID                         AS ENTITY_ID,
    'HS classification for traded goods with duty/compliance attributes' AS DESCRIPTION,
    'SCO_SILVER.SLV_DIM_COMMODITY'       AS SOURCE_TABLE,
    _DQ_SCORE                            AS DATA_QUALITY_SCORE,
    TRUE                                 AS IS_ACTIVE,
    HS_CODE, HS_SECTION, HS_CHAPTER, ESG_RISK_FLAG, EXPORT_CONTROL_FLAG
FROM SCO_HACKATHON.SCO_SILVER.SLV_DIM_COMMODITY;

-- ═══════════════════════════════════════════════════════════════════════
-- 11. ORDER (from SLV_FACT_ORDER_LINE, one row per order)
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW V_NODE_ORDER AS
SELECT DISTINCT
    'ORDER:' || ORDER_ID                 AS NODE_ID,
    ORDER_NUMBER                         AS NODE_LABEL,
    'ORDER'                              AS NODE_TYPE,
    ORDER_ID                             AS ENTITY_ID,
    'Customer order comprising one or more line items for parts delivery' AS DESCRIPTION,
    'SCO_SILVER.SLV_FACT_ORDER_LINE'     AS SOURCE_TABLE,
    NULL                                 AS DATA_QUALITY_SCORE,
    TRUE                                 AS IS_ACTIVE,
    CUSTOMER_ID, ORDER_DATE, ORDER_STATUS, ORDER_PRIORITY,
    ORDER_TOTAL_VALUE_USD
FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_ORDER_LINE
QUALIFY ROW_NUMBER() OVER (PARTITION BY ORDER_ID ORDER BY LINE_ITEM_ID) = 1;

-- ═══════════════════════════════════════════════════════════════════════
-- 12. SHIPMENT (from SLV_FACT_SHIPMENT)
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW V_NODE_SHIPMENT AS
SELECT
    'SHIPMENT:' || SHIPMENT_ID           AS NODE_ID,
    SHIPMENT_REFERENCE                   AS NODE_LABEL,
    'SHIPMENT'                           AS NODE_TYPE,
    SHIPMENT_ID                          AS ENTITY_ID,
    'Physical transport event moving goods from origin to destination' AS DESCRIPTION,
    'SCO_SILVER.SLV_FACT_SHIPMENT'       AS SOURCE_TABLE,
    _DQ_SCORE                            AS DATA_QUALITY_SCORE,
    TRUE                                 AS IS_ACTIVE,
    CARRIER_ID, ROUTE_ID, SHIP_DATE, SHIPMENT_STATUS,
    TOTAL_WEIGHT_KG, FREIGHT_COST_USD, ON_TIME_ARRIVAL_FLAG
FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_SHIPMENT;

-- ═══════════════════════════════════════════════════════════════════════
-- 13. INVENTORY_POSITION (latest snapshot per part-warehouse)
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW V_NODE_INVENTORY AS
SELECT
    'INVENTORY:' || PART_ID || ':' || WAREHOUSE_ID AS NODE_ID,
    PART_NAME || ' @ ' || WAREHOUSE_NAME           AS NODE_LABEL,
    'INVENTORY'                                    AS NODE_TYPE,
    PART_ID * 10000 + WAREHOUSE_ID                 AS ENTITY_ID,
    'Inventory position for a part at a specific warehouse' AS DESCRIPTION,
    'SCO_SILVER.SLV_FACT_INVENTORY'                AS SOURCE_TABLE,
    _DQ_SCORE                                      AS DATA_QUALITY_SCORE,
    TRUE                                           AS IS_ACTIVE,
    PART_ID, WAREHOUSE_ID, SNAPSHOT_DATE,
    QUANTITY_ON_HAND, QUANTITY_AVAILABLE,
    STOCKOUT_FLAG, BELOW_REORDER_FLAG
FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_INVENTORY
QUALIFY ROW_NUMBER() OVER (PARTITION BY PART_ID, WAREHOUSE_ID ORDER BY SNAPSHOT_DATE DESC) = 1;
