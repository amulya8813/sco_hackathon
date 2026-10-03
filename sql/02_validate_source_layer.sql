--------------------------------------------------------------------------------
-- Supply Chain Ontology — Source Layer Post-Creation Validation
-- 02_validate_source_layer.sql
--
-- Prompt source: prompts_for_DDLandDataPopulation.txt, Prompt 3
--   "Validate the newly created SCO_SOURCE source layer. Perform metadata-only
--    validation. Do not query or use any internal datasets. Do not insert data."
--
-- Scope: METADATA ONLY. Reads INFORMATION_SCHEMA of the project database plus
--        row counts of the project's own tables. Touches no other database.
--        Inserts nothing. Modifies nothing.
--
-- Run AFTER 01_create_source_tables.sql, BEFORE 03_generate_synthetic_data.sql.
-- Every query returns a PASS/FAIL column so results can be screenshotted as-is.
--------------------------------------------------------------------------------

SET sco_role      = 'ACCOUNTADMIN';
SET sco_warehouse = 'COMPUTE_WH';
SET sco_database  = 'SCO_HACKATHON';

USE ROLE      IDENTIFIER($sco_role);
USE WAREHOUSE IDENTIFIER($sco_warehouse);
USE DATABASE  IDENTIFIER($sco_database);
USE SCHEMA    SCO_SOURCE;

SELECT CURRENT_ROLE()      AS active_role,
       CURRENT_WAREHOUSE() AS active_warehouse,
       CURRENT_DATABASE()  AS active_database,
       CURRENT_SCHEMA()    AS active_schema;


-- =============================================================================
-- Expected-shape reference. Column counts are derived from the approved
-- Supply_Chain_Source_Layer_Design.md / 01_create_source_tables.sql.
-- =============================================================================
CREATE OR REPLACE TEMPORARY VIEW V_EXPECTED_TABLES AS
SELECT * FROM VALUES
    ('COUNTRY',                    22, 1, 0,  2),
    ('COMMODITY',                  21, 1, 0,  1),
    ('COMPLIANCE_LIST',            21, 1, 1,  0),
    ('SUPPLIER',                   29, 1, 1,  2),
    ('CUSTOMER',                   26, 1, 1,  0),
    ('CARRIER',                    20, 1, 1,  0),
    ('PORT',                       21, 1, 1,  1),
    ('PART',                       27, 1, 1,  2),
    ('WAREHOUSE',                  21, 1, 1,  0),
    ('PLANT',                      23, 1, 2,  0),
    ('ROUTE',                      23, 1, 4,  0),
    ('SUPPLIER_CATALOG',           21, 1, 2,  0),
    ('PLANT_PART_ASSIGNMENT',      17, 1, 2,  0),
    ('CARRIER_ROUTE_SERVICE',      17, 1, 2,  0),
    ('SUPPLIER_COMPLIANCE_MATCH',  19, 1, 2,  0),
    ('CUSTOMER_COMPLIANCE_MATCH',  20, 1, 2,  0),
    ('COMMODITY_RESTRICTION',      17, 1, 2,  0),
    ('SUPPLIER_RISK_ASSESSMENT',   21, 1, 1,  0),
    ('ESG_SCORE',                  23, 1, 2,  0),
    ('PURCHASE_ORDER',             23, 1, 2,  1),
    ('ORDER_LINE_ITEM',            27, 1, 3,  1),
    ('SHIPMENT',                   36, 1, 12, 0),
    ('SHIPMENT_LINE_ITEM',         16, 1, 2,  0),
    ('INVENTORY_POSITION',         20, 1, 2,  0)
AS t(table_name, expected_columns, expected_pk, expected_fk, expected_uq);


-- =============================================================================
-- CHECK 1 — Exactly the 24 designed tables exist in SCO_SOURCE
-- =============================================================================
WITH actual AS (
    SELECT TABLE_NAME
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_CATALOG = CURRENT_DATABASE()
      AND TABLE_SCHEMA  = 'SCO_SOURCE'
      AND TABLE_TYPE    = 'BASE TABLE'
)
SELECT 'CHECK 1: Table inventory'                                   AS check_name,
       (SELECT COUNT(*) FROM V_EXPECTED_TABLES)                     AS expected_count,
       (SELECT COUNT(*) FROM actual)                                AS actual_count,
       (SELECT COUNT(*) FROM V_EXPECTED_TABLES e
         WHERE NOT EXISTS (SELECT 1 FROM actual a
                            WHERE a.TABLE_NAME = e.table_name))     AS missing_tables,
       (SELECT COUNT(*) FROM actual a
         WHERE NOT EXISTS (SELECT 1 FROM V_EXPECTED_TABLES e
                            WHERE e.table_name = a.TABLE_NAME))     AS extra_tables,
       IFF((SELECT COUNT(*) FROM actual) = 24
           AND NOT EXISTS (SELECT 1 FROM V_EXPECTED_TABLES e
                            WHERE NOT EXISTS (SELECT 1 FROM actual a
                                               WHERE a.TABLE_NAME = e.table_name))
           AND NOT EXISTS (SELECT 1 FROM actual a
                            WHERE NOT EXISTS (SELECT 1 FROM V_EXPECTED_TABLES e
                                               WHERE e.table_name = a.TABLE_NAME)),
           'PASS', 'FAIL')                                          AS status;

-- CHECK 1b — Name the specific missing / extra tables (empty result = clean)
SELECT e.table_name AS table_name, 'MISSING' AS issue
FROM V_EXPECTED_TABLES e
LEFT JOIN INFORMATION_SCHEMA.TABLES t
       ON t.TABLE_NAME = e.table_name
      AND t.TABLE_SCHEMA = 'SCO_SOURCE'
      AND t.TABLE_CATALOG = CURRENT_DATABASE()
WHERE t.TABLE_NAME IS NULL
UNION ALL
SELECT t.TABLE_NAME, 'UNEXPECTED'
FROM INFORMATION_SCHEMA.TABLES t
LEFT JOIN V_EXPECTED_TABLES e ON e.table_name = t.TABLE_NAME
WHERE t.TABLE_SCHEMA = 'SCO_SOURCE'
  AND t.TABLE_CATALOG = CURRENT_DATABASE()
  AND t.TABLE_TYPE = 'BASE TABLE'
  AND e.table_name IS NULL;


-- =============================================================================
-- CHECK 2 — Column count per table matches the approved design
-- =============================================================================
WITH actual AS (
    SELECT TABLE_NAME, COUNT(*) AS col_count
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_CATALOG = CURRENT_DATABASE()
      AND TABLE_SCHEMA  = 'SCO_SOURCE'
    GROUP BY TABLE_NAME
)
SELECT e.table_name,
       e.expected_columns,
       COALESCE(a.col_count, 0)                              AS actual_columns,
       COALESCE(a.col_count, 0) - e.expected_columns         AS delta,
       IFF(a.col_count = e.expected_columns, 'PASS', 'FAIL') AS status
FROM V_EXPECTED_TABLES e
LEFT JOIN actual a ON a.TABLE_NAME = e.table_name
ORDER BY status DESC, e.table_name;


-- =============================================================================
-- CHECK 3 — NOT NULL definitions and DEFAULT values present
-- =============================================================================
-- 3a. Every table must have the four NOT NULL audit columns.
SELECT TABLE_NAME,
       COUNT_IF(COLUMN_NAME IN ('_LOADED_AT','_UPDATED_AT','_IS_DELETED','_BATCH_ID','_VERSION','_SOURCE_SYSTEM')
                AND IS_NULLABLE = 'NO')                                     AS not_null_audit_cols,
       IFF(COUNT_IF(COLUMN_NAME IN ('_LOADED_AT','_UPDATED_AT','_IS_DELETED','_BATCH_ID','_VERSION','_SOURCE_SYSTEM')
                    AND IS_NULLABLE = 'NO') = 6, 'PASS', 'FAIL')            AS status
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_CATALOG = CURRENT_DATABASE() AND TABLE_SCHEMA = 'SCO_SOURCE'
GROUP BY TABLE_NAME
ORDER BY status DESC, TABLE_NAME;

-- 3b. Default values registered on the audit/lineage/metadata columns.
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_CATALOG = CURRENT_DATABASE()
  AND TABLE_SCHEMA  = 'SCO_SOURCE'
  AND COLUMN_NAME IN ('_LOADED_AT','_UPDATED_AT','_IS_DELETED','_BATCH_ID',
                      '_SOURCE_SYSTEM','_CONFIDENCE_LEVEL','_VERSION')
ORDER BY TABLE_NAME, COLUMN_NAME;

-- 3c. Any column whose default is missing where the design requires one.
SELECT TABLE_NAME, COLUMN_NAME, 'DEFAULT MISSING' AS issue
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_CATALOG = CURRENT_DATABASE()
  AND TABLE_SCHEMA  = 'SCO_SOURCE'
  AND COLUMN_NAME IN ('_LOADED_AT','_UPDATED_AT','_IS_DELETED','_BATCH_ID',
                      '_SOURCE_SYSTEM','_CONFIDENCE_LEVEL','_VERSION')
  AND COLUMN_DEFAULT IS NULL
ORDER BY TABLE_NAME, COLUMN_NAME;


-- =============================================================================
-- CHECK 4 — Primary key, unique, and foreign key metadata
-- =============================================================================
-- 4a. Constraint counts per table vs. design.
WITH tc AS (
    SELECT TABLE_NAME, CONSTRAINT_TYPE, COUNT(*) AS n
    FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = 'SCO_SOURCE' AND CONSTRAINT_CATALOG = CURRENT_DATABASE()
    GROUP BY TABLE_NAME, CONSTRAINT_TYPE
),
pivoted AS (
    SELECT TABLE_NAME,
           SUM(IFF(CONSTRAINT_TYPE = 'PRIMARY KEY', n, 0)) AS pk_n,
           SUM(IFF(CONSTRAINT_TYPE = 'FOREIGN KEY', n, 0)) AS fk_n,
           SUM(IFF(CONSTRAINT_TYPE = 'UNIQUE',      n, 0)) AS uq_n
    FROM tc GROUP BY TABLE_NAME
)
SELECT e.table_name,
       e.expected_pk, COALESCE(p.pk_n, 0) AS actual_pk,
       e.expected_fk, COALESCE(p.fk_n, 0) AS actual_fk,
       e.expected_uq, COALESCE(p.uq_n, 0) AS actual_uq,
       IFF(COALESCE(p.pk_n,0) = e.expected_pk, 'PASS', 'FAIL') AS pk_status,
       IFF(COALESCE(p.fk_n,0) = e.expected_fk, 'PASS', 'FAIL') AS fk_status,
       IFF(COALESCE(p.uq_n,0) = e.expected_uq, 'PASS', 'FAIL') AS uq_status
FROM V_EXPECTED_TABLES e
LEFT JOIN pivoted p ON p.TABLE_NAME = e.table_name
ORDER BY pk_status, fk_status, uq_status, e.table_name;

-- 4b. Totals: expect 24 PK / 49 FK / 10 UNIQUE = 83 named constraints.
SELECT CONSTRAINT_TYPE,
       COUNT(*) AS constraint_count,
       CASE CONSTRAINT_TYPE
            WHEN 'PRIMARY KEY' THEN IFF(COUNT(*) = 24, 'PASS', 'FAIL')
            WHEN 'FOREIGN KEY' THEN IFF(COUNT(*) = 49, 'PASS', 'FAIL')
            WHEN 'UNIQUE'      THEN IFF(COUNT(*) = 10, 'PASS', 'FAIL')
            ELSE 'INFO'
       END AS status
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE TABLE_SCHEMA = 'SCO_SOURCE' AND CONSTRAINT_CATALOG = CURRENT_DATABASE()
GROUP BY CONSTRAINT_TYPE
ORDER BY CONSTRAINT_TYPE;

-- ---------------------------------------------------------------------------
-- Column-level key metadata.
--
-- Snowflake has no KEY_COLUMN_USAGE view, and REFERENTIAL_CONSTRAINTS carries
-- constraint names only. Column detail comes from SHOW + RESULT_SCAN.
--
-- RUN EACH SHOW/SELECT PAIR ONE AT A TIME. LAST_QUERY_ID() resolves to the
-- immediately preceding statement, so a bulk "run all" scans the wrong result.
-- ---------------------------------------------------------------------------

-- 4c. Primary key column membership, including composite key ordering.
SHOW PRIMARY KEYS IN SCHEMA SCO_SOURCE;

SELECT "table_name"       AS table_name,
       "constraint_name"  AS constraint_name,
       "column_name"      AS column_name,
       "key_sequence"     AS key_position
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
ORDER BY table_name, constraint_name, key_position;

-- 4c-ii. Composite PK arity vs. the approved design.
SHOW PRIMARY KEYS IN SCHEMA SCO_SOURCE;

WITH pk AS (
    SELECT "table_name" AS table_name, COUNT(*) AS pk_columns
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
    GROUP BY "table_name"
),
expected AS (
    SELECT * FROM VALUES
      ('SUPPLIER_CATALOG',2),('PLANT_PART_ASSIGNMENT',2),('CARRIER_ROUTE_SERVICE',2),
      ('SUPPLIER_COMPLIANCE_MATCH',2),('CUSTOMER_COMPLIANCE_MATCH',2),
      ('COMMODITY_RESTRICTION',2),('SUPPLIER_RISK_ASSESSMENT',2),
      ('SHIPMENT_LINE_ITEM',2),('INVENTORY_POSITION',3)
    AS e(table_name, expected_pk_columns)
)
SELECT e.table_name, e.expected_pk_columns, COALESCE(pk.pk_columns,0) AS actual_pk_columns,
       IFF(pk.pk_columns = e.expected_pk_columns,'PASS','FAIL') AS status
FROM expected e
LEFT JOIN pk ON pk.table_name = e.table_name
ORDER BY status, e.table_name;

-- 4d. Every foreign key resolves to a real parent table and column.
SHOW IMPORTED KEYS IN SCHEMA SCO_SOURCE;

SELECT "fk_table_name"      AS child_table,
       "fk_column_name"     AS child_column,
       "pk_table_name"      AS parent_table,
       "pk_column_name"     AS parent_column,
       "fk_name"            AS constraint_name,
       IFF("pk_table_name" IS NOT NULL,'PASS','FAIL') AS status
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
ORDER BY child_table, constraint_name;

-- 4d-ii. Foreign key total (expect 49).
SHOW IMPORTED KEYS IN SCHEMA SCO_SOURCE;

SELECT COUNT(*) AS foreign_key_columns,
       IFF(COUNT(*) = 49,'PASS','FAIL') AS status
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- 4e. FK / parent-key data type compatibility.
SHOW IMPORTED KEYS IN SCHEMA SCO_SOURCE;

WITH fk AS (
    SELECT "fk_table_name"  AS child_table,  "fk_column_name" AS child_column,
           "pk_table_name"  AS parent_table, "pk_column_name" AS parent_column,
           "fk_name"        AS constraint_name
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
)
SELECT fk.constraint_name, fk.child_table, fk.child_column,
       fk.parent_table, fk.parent_column,
       cc.DATA_TYPE AS child_type,  cc.NUMERIC_PRECISION AS child_precision,
       cp.DATA_TYPE AS parent_type, cp.NUMERIC_PRECISION AS parent_precision,
       IFF(cc.DATA_TYPE = cp.DATA_TYPE
           AND COALESCE(cc.NUMERIC_PRECISION,0) = COALESCE(cp.NUMERIC_PRECISION,0),
           'PASS','FAIL') AS status
FROM fk
JOIN INFORMATION_SCHEMA.COLUMNS cc
  ON cc.TABLE_SCHEMA = 'SCO_SOURCE'
 AND cc.TABLE_NAME   = fk.child_table
 AND cc.COLUMN_NAME  = fk.child_column
JOIN INFORMATION_SCHEMA.COLUMNS cp
  ON cp.TABLE_SCHEMA = 'SCO_SOURCE'
 AND cp.TABLE_NAME   = fk.parent_table
 AND cp.COLUMN_NAME  = fk.parent_column
ORDER BY status, fk.child_table;


-- =============================================================================
-- CHECK 5 — Missing or extra columns vs. Supply_Chain_Source_Layer_Design.md
-- (spot-checked on the business-critical metric-driving tables)
-- =============================================================================
CREATE OR REPLACE TEMPORARY VIEW V_EXPECTED_KEY_COLUMNS AS
SELECT * FROM VALUES
    ('ORDER_LINE_ITEM','QUANTITY_ORDERED'), ('ORDER_LINE_ITEM','UNIT_PRICE_USD'),
    ('ORDER_LINE_ITEM','PROMISED_DELIVERY_DATE'), ('ORDER_LINE_ITEM','ACTUAL_RECEIPT_DATE'),
    ('ORDER_LINE_ITEM','PROMISED_SHIP_DATE'), ('ORDER_LINE_ITEM','ACTUAL_SHIP_DATE'),
    ('ORDER_LINE_ITEM','LINE_STATUS'),
    ('SHIPMENT_LINE_ITEM','QUANTITY_SHIPPED'),
    ('INVENTORY_POSITION','QUANTITY_ON_HAND'), ('INVENTORY_POSITION','QUANTITY_AVAILABLE'),
    ('INVENTORY_POSITION','QUANTITY_RESERVED'), ('INVENTORY_POSITION','SNAPSHOT_DATE'),
    ('INVENTORY_POSITION','SAFETY_STOCK_LEVEL'), ('INVENTORY_POSITION','REORDER_POINT'),
    ('SHIPMENT','FREIGHT_COST_USD'), ('SHIPMENT','INSURANCE_COST_USD'),
    ('SHIPMENT','DUTIES_USD'), ('SHIPMENT','HANDLING_COST_USD'),
    ('SHIPMENT','SHIP_DATE'), ('SHIPMENT','ACTUAL_ARRIVAL_DATE'),
    ('SHIPMENT','ESTIMATED_ARRIVAL_DATE'), ('SHIPMENT','SHIPMENT_STATUS'),
    ('SUPPLIER_CATALOG','SUPPLY_COST_USD'), ('SUPPLIER_CATALOG','LEAD_TIME_DAYS'),
    ('PURCHASE_ORDER','ORDER_STATUS'), ('PURCHASE_ORDER','ORDER_DATE'),
    ('PART','STANDARD_COST_USD'), ('PART','PART_CATEGORY'),
    ('COMMODITY','HS_CODE'), ('COUNTRY','REGION_NAME')
AS t(table_name, column_name);

SELECT k.table_name, k.column_name,
       IFF(c.COLUMN_NAME IS NOT NULL, 'PASS', 'FAIL — MISSING') AS status,
       c.DATA_TYPE
FROM V_EXPECTED_KEY_COLUMNS k
LEFT JOIN INFORMATION_SCHEMA.COLUMNS c
       ON c.TABLE_SCHEMA = 'SCO_SOURCE'
      AND c.TABLE_NAME   = k.table_name
      AND c.COLUMN_NAME  = k.column_name
ORDER BY status, k.table_name, k.column_name;


-- =============================================================================
-- CHECK 6 — All audit, lineage, and metadata columns exist on all 24 tables
-- =============================================================================
WITH required AS (
    SELECT * FROM VALUES
        ('_LOADED_AT','AUDIT'), ('_UPDATED_AT','AUDIT'),
        ('_IS_DELETED','AUDIT'), ('_BATCH_ID','AUDIT'),
        ('_SOURCE_SYSTEM','LINEAGE'), ('_SOURCE_TABLE','LINEAGE'),
        ('_SOURCE_KEY','LINEAGE'), ('_SOURCE_UPDATED_AT','LINEAGE'),
        ('_DATA_QUALITY_SCORE','METADATA'), ('_CONFIDENCE_LEVEL','METADATA'),
        ('_VERSION','METADATA')
    AS r(column_name, column_class)
),
matrix AS (
    SELECT e.table_name, r.column_name, r.column_class,
           IFF(c.COLUMN_NAME IS NOT NULL, 1, 0) AS present
    FROM V_EXPECTED_TABLES e
    CROSS JOIN required r
    LEFT JOIN INFORMATION_SCHEMA.COLUMNS c
           ON c.TABLE_SCHEMA = 'SCO_SOURCE'
          AND c.TABLE_NAME   = e.table_name
          AND c.COLUMN_NAME  = r.column_name
)
SELECT table_name,
       SUM(IFF(column_class = 'AUDIT',    present, 0)) AS audit_cols_present,
       SUM(IFF(column_class = 'LINEAGE',  present, 0)) AS lineage_cols_present,
       SUM(IFF(column_class = 'METADATA', present, 0)) AS metadata_cols_present,
       SUM(present)                                    AS total_present,
       IFF(SUM(present) = 11, 'PASS', 'FAIL')          AS status
FROM matrix
GROUP BY table_name
ORDER BY status DESC, table_name;

-- 6b. Name any specific missing audit/lineage/metadata column (empty = clean).
WITH required AS (
    SELECT * FROM VALUES
        ('_LOADED_AT'),('_UPDATED_AT'),('_IS_DELETED'),('_BATCH_ID'),
        ('_SOURCE_SYSTEM'),('_SOURCE_TABLE'),('_SOURCE_KEY'),('_SOURCE_UPDATED_AT'),
        ('_DATA_QUALITY_SCORE'),('_CONFIDENCE_LEVEL'),('_VERSION')
    AS r(column_name)
)
SELECT e.table_name, r.column_name, 'MISSING' AS issue
FROM V_EXPECTED_TABLES e
CROSS JOIN required r
LEFT JOIN INFORMATION_SCHEMA.COLUMNS c
       ON c.TABLE_SCHEMA='SCO_SOURCE' AND c.TABLE_NAME=e.table_name AND c.COLUMN_NAME=r.column_name
WHERE c.COLUMN_NAME IS NULL
ORDER BY e.table_name, r.column_name;


-- =============================================================================
-- CHECK 7 — Creation order left no unresolved references
-- (every FK's parent table exists as a base table in the same schema)
-- =============================================================================
SHOW IMPORTED KEYS IN SCHEMA SCO_SOURCE;

WITH fk AS (
    SELECT "fk_table_name" AS child_table,
           "pk_table_name" AS parent_table,
           "pk_column_name" AS parent_column
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
)
SELECT COUNT(*) AS unresolved_parent_references,
       IFF(COUNT(*) = 0, 'PASS', 'FAIL') AS status
FROM fk
LEFT JOIN INFORMATION_SCHEMA.TABLES t
       ON t.TABLE_NAME   = fk.parent_table
      AND t.TABLE_SCHEMA = 'SCO_SOURCE'
      AND t.TABLE_TYPE   = 'BASE TABLE'
LEFT JOIN INFORMATION_SCHEMA.COLUMNS c
       ON c.TABLE_NAME   = fk.parent_table
      AND c.TABLE_SCHEMA = 'SCO_SOURCE'
      AND c.COLUMN_NAME  = fk.parent_column
WHERE t.TABLE_NAME IS NULL OR c.COLUMN_NAME IS NULL;


-- =============================================================================
-- CHECK 8 — All tables are currently empty (no data loaded yet)
-- =============================================================================
SELECT TABLE_NAME,
       ROW_COUNT,
       BYTES,
       IFF(COALESCE(ROW_COUNT, 0) = 0, 'PASS — EMPTY', 'FAIL — CONTAINS DATA') AS status
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_CATALOG = CURRENT_DATABASE()
  AND TABLE_SCHEMA  = 'SCO_SOURCE'
  AND TABLE_TYPE    = 'BASE TABLE'
ORDER BY status, TABLE_NAME;


-- =============================================================================
-- FINAL CONSOLIDATED VALIDATION REPORT
-- One row per table: expected vs. actual columns, PK/FK/audit status, verdict.
-- This is the deliverable table requested by Prompt 3.
-- =============================================================================
WITH col_counts AS (
    SELECT TABLE_NAME, COUNT(*) AS actual_columns
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='SCO_SOURCE' AND TABLE_CATALOG=CURRENT_DATABASE()
    GROUP BY TABLE_NAME
),
cons AS (
    SELECT TABLE_NAME,
           SUM(IFF(CONSTRAINT_TYPE='PRIMARY KEY',1,0)) AS pk_n,
           SUM(IFF(CONSTRAINT_TYPE='FOREIGN KEY',1,0)) AS fk_n
    FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA='SCO_SOURCE' AND CONSTRAINT_CATALOG=CURRENT_DATABASE()
    GROUP BY TABLE_NAME
),
audit AS (
    SELECT TABLE_NAME,
           COUNT_IF(COLUMN_NAME IN ('_LOADED_AT','_UPDATED_AT','_IS_DELETED','_BATCH_ID',
                                    '_SOURCE_SYSTEM','_SOURCE_TABLE','_SOURCE_KEY','_SOURCE_UPDATED_AT',
                                    '_DATA_QUALITY_SCORE','_CONFIDENCE_LEVEL','_VERSION')) AS audit_cols
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='SCO_SOURCE' AND TABLE_CATALOG=CURRENT_DATABASE()
    GROUP BY TABLE_NAME
),
rows_ AS (
    SELECT TABLE_NAME, COALESCE(ROW_COUNT,0) AS row_count
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA='SCO_SOURCE' AND TABLE_CATALOG=CURRENT_DATABASE()
      AND TABLE_TYPE='BASE TABLE'
)
SELECT e.table_name                                              AS "Table Name",
       e.expected_columns                                        AS "Expected Columns",
       COALESCE(c.actual_columns,0)                              AS "Actual Columns",
       IFF(COALESCE(k.pk_n,0)  = e.expected_pk,'PASS','FAIL')    AS "Primary-Key Status",
       IFF(COALESCE(k.fk_n,0)  = e.expected_fk,'PASS','FAIL')    AS "Foreign-Key Status",
       IFF(COALESCE(a.audit_cols,0) = 11,'PASS','FAIL')          AS "Audit-Column Status",
       IFF(COALESCE(r.row_count,0) = 0,'PASS','FAIL')            AS "Empty-Table Status",
       IFF(   COALESCE(c.actual_columns,0) = e.expected_columns
          AND COALESCE(k.pk_n,0)           = e.expected_pk
          AND COALESCE(k.fk_n,0)           = e.expected_fk
          AND COALESCE(a.audit_cols,0)     = 11
          AND COALESCE(r.row_count,0)      = 0,
          'PASS','FAIL')                                         AS "Overall"
FROM V_EXPECTED_TABLES e
LEFT JOIN col_counts c ON c.TABLE_NAME = e.table_name
LEFT JOIN cons       k ON k.TABLE_NAME = e.table_name
LEFT JOIN audit      a ON a.TABLE_NAME = e.table_name
LEFT JOIN rows_      r ON r.TABLE_NAME = e.table_name
ORDER BY "Overall", "Table Name";


-- Single-line overall verdict for the evidence pack.
WITH col_counts AS (
    SELECT TABLE_NAME, COUNT(*) AS actual_columns FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='SCO_SOURCE' AND TABLE_CATALOG=CURRENT_DATABASE() GROUP BY TABLE_NAME
),
cons AS (
    SELECT TABLE_NAME,
           SUM(IFF(CONSTRAINT_TYPE='PRIMARY KEY',1,0)) AS pk_n,
           SUM(IFF(CONSTRAINT_TYPE='FOREIGN KEY',1,0)) AS fk_n
    FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA='SCO_SOURCE' AND CONSTRAINT_CATALOG=CURRENT_DATABASE() GROUP BY TABLE_NAME
),
audit AS (
    SELECT TABLE_NAME,
           COUNT_IF(COLUMN_NAME IN ('_LOADED_AT','_UPDATED_AT','_IS_DELETED','_BATCH_ID',
                                    '_SOURCE_SYSTEM','_SOURCE_TABLE','_SOURCE_KEY','_SOURCE_UPDATED_AT',
                                    '_DATA_QUALITY_SCORE','_CONFIDENCE_LEVEL','_VERSION')) AS audit_cols
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA='SCO_SOURCE' AND TABLE_CATALOG=CURRENT_DATABASE() GROUP BY TABLE_NAME
)
SELECT COUNT(*)                                                        AS tables_evaluated,
       COUNT_IF(c.actual_columns = e.expected_columns)                 AS column_count_pass,
       COUNT_IF(COALESCE(k.pk_n,0) = e.expected_pk)                    AS pk_pass,
       COUNT_IF(COALESCE(k.fk_n,0) = e.expected_fk)                    AS fk_pass,
       COUNT_IF(COALESCE(a.audit_cols,0) = 11)                         AS audit_pass,
       IFF(COUNT(*) = 24
           AND COUNT_IF(c.actual_columns = e.expected_columns) = 24
           AND COUNT_IF(COALESCE(k.pk_n,0) = e.expected_pk)    = 24
           AND COUNT_IF(COALESCE(k.fk_n,0) = e.expected_fk)    = 24
           AND COUNT_IF(COALESCE(a.audit_cols,0) = 11)         = 24,
           'SOURCE LAYER VALIDATION: PASS',
           'SOURCE LAYER VALIDATION: FAIL')                            AS final_verdict
FROM V_EXPECTED_TABLES e
LEFT JOIN col_counts c ON c.TABLE_NAME = e.table_name
LEFT JOIN cons       k ON k.TABLE_NAME = e.table_name
LEFT JOIN audit      a ON a.TABLE_NAME = e.table_name;

-- =============================================================================
-- END — no data was inserted, no objects were modified.
-- =============================================================================
