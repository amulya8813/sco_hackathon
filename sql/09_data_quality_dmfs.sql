--------------------------------------------------------------------------------
-- Supply Chain Ontology — Data Quality Monitoring (DMFs)
-- 09_data_quality_dmfs.sql
--
-- Implements the "Data Quality — DMFs (Freshness, Completeness, Quality
-- Checks)" row of the reference architecture.
--
-- EDITION REQUIREMENT ----------------------------------------------------
-- Data Metric Functions require Snowflake ENTERPRISE EDITION. On Standard
-- Edition, PART A and PART B will fail with:
--   "Data Quality Monitoring requires Enterprise Edition."
-- If that happens, SKIP to PART D, which reproduces every one of the same
-- checks as plain views that run on any edition. The demo does not depend on
-- Enterprise Edition.
--
-- Run AFTER: 07_gold_layer.sql
--------------------------------------------------------------------------------

SET sco_role      = 'ACCOUNTADMIN';
SET sco_warehouse = 'COMPUTE_WH';
SET sco_database  = 'SCO_HACKATHON';

USE ROLE      IDENTIFIER($sco_role);
USE WAREHOUSE IDENTIFIER($sco_warehouse);
USE DATABASE  IDENTIFIER($sco_database);

CREATE SCHEMA IF NOT EXISTS SCO_GOVERNANCE
  COMMENT = 'Data quality metric functions, quality results, and monitoring views for the Supply Chain Ontology.';
USE SCHEMA SCO_GOVERNANCE;


-- =============================================================================
-- PART A — CUSTOM DATA METRIC FUNCTIONS
--
-- DMF expressions must be DETERMINISTIC: CURRENT_DATE() / CURRENT_TIMESTAMP()
-- are not permitted inside the expression body. Freshness is therefore
-- expressed against the table's own maximum timestamp rather than "now", and
-- wall-clock freshness is evaluated in PART D instead.
-- =============================================================================

-- A1. Completeness — count NULLs in a column that the design declares mandatory.
CREATE OR REPLACE DATA METRIC FUNCTION DMF_NULL_COUNT(
    arg_t TABLE(arg_c VARIANT)
)
RETURNS NUMBER
COMMENT = 'Completeness: number of NULL values in the monitored column. Target = 0.'
AS
$$
  SELECT COUNT(*) FROM arg_t WHERE arg_c IS NULL
$$;

-- A2. Uniqueness — count of duplicate values in a column declared UNIQUE or PK.
--     Snowflake does not enforce those constraints, so this is the real check.
CREATE OR REPLACE DATA METRIC FUNCTION DMF_DUPLICATE_COUNT(
    arg_t TABLE(arg_c VARIANT)
)
RETURNS NUMBER
COMMENT = 'Uniqueness: number of surplus rows beyond one per distinct value. Target = 0.'
AS
$$
  SELECT COUNT(*) - COUNT(DISTINCT arg_c) FROM arg_t WHERE arg_c IS NOT NULL
$$;

-- A3. Validity — count of non-positive quantities where the business requires > 0.
CREATE OR REPLACE DATA METRIC FUNCTION DMF_NON_POSITIVE_COUNT(
    arg_t TABLE(arg_c NUMBER)
)
RETURNS NUMBER
COMMENT = 'Validity: number of rows where a must-be-positive measure is zero or negative. Target = 0.'
AS
$$
  SELECT COUNT(*) FROM arg_t WHERE arg_c <= 0
$$;

-- A4. Range validity — scores that fall outside the governed 0–100 band.
CREATE OR REPLACE DATA METRIC FUNCTION DMF_OUT_OF_RANGE_SCORE_COUNT(
    arg_t TABLE(arg_c NUMBER)
)
RETURNS NUMBER
COMMENT = 'Validity: number of score values outside the governed 0-100 range. Target = 0.'
AS
$$
  SELECT COUNT(*) FROM arg_t WHERE arg_c < 0 OR arg_c > 100
$$;

-- A5. Staleness — age in days between the newest and oldest audit timestamp.
--     Deterministic (no reference to "now"), so it is DMF-legal.
CREATE OR REPLACE DATA METRIC FUNCTION DMF_LOAD_SPAN_DAYS(
    arg_t TABLE(arg_c TIMESTAMP_NTZ)
)
RETURNS NUMBER
COMMENT = 'Freshness: span in days between the earliest and latest load timestamp in the table.'
AS
$$
  SELECT COALESCE(DATEDIFF(day, MIN(arg_c), MAX(arg_c)), 0) FROM arg_t
$$;

-- A6. Referential integrity — child key values with no matching parent.
CREATE OR REPLACE DATA METRIC FUNCTION DMF_ORPHAN_COUNT(
    arg_child TABLE(arg_fk NUMBER),
    arg_parent TABLE(arg_pk NUMBER)
)
RETURNS NUMBER
COMMENT = 'Referential integrity: child rows whose foreign key has no matching parent. Target = 0.'
AS
$$
  SELECT COUNT(*) FROM arg_child
  WHERE arg_fk IS NOT NULL
    AND arg_fk NOT IN (SELECT arg_pk FROM arg_parent WHERE arg_pk IS NOT NULL)
$$;

-- A7. Temporal ordering — rows where an end date precedes its start date.
CREATE OR REPLACE DATA METRIC FUNCTION DMF_DATE_ORDER_VIOLATIONS(
    arg_t TABLE(arg_start DATE, arg_end DATE)
)
RETURNS NUMBER
COMMENT = 'Consistency: rows where the later date precedes the earlier date. Target = 0.'
AS
$$
  SELECT COUNT(*) FROM arg_t
  WHERE arg_start IS NOT NULL AND arg_end IS NOT NULL AND arg_end < arg_start
$$;


-- =============================================================================
-- PART B — ATTACH DMFs TO TABLES
--
-- A schedule must be set on a table BEFORE any DMF is associated with it.
-- TRIGGER_ON_CHANGES re-evaluates whenever the table's data changes; the
-- source tables are batch-loaded, so a 60-minute cadence is used instead to
-- align with the dynamic tables' TARGET_LAG.
-- =============================================================================

ALTER TABLE SCO_HACKATHON.SCO_SOURCE.PURCHASE_ORDER
  SET DATA_METRIC_SCHEDULE = '60 MINUTE';
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM
  SET DATA_METRIC_SCHEDULE = '60 MINUTE';
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.SHIPMENT
  SET DATA_METRIC_SCHEDULE = '60 MINUTE';
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.SHIPMENT_LINE_ITEM
  SET DATA_METRIC_SCHEDULE = '60 MINUTE';
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.INVENTORY_POSITION
  SET DATA_METRIC_SCHEDULE = '60 MINUTE';
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.SUPPLIER
  SET DATA_METRIC_SCHEDULE = '1440 MINUTE';
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.PART
  SET DATA_METRIC_SCHEDULE = '1440 MINUTE';
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.SUPPLIER_RISK_ASSESSMENT
  SET DATA_METRIC_SCHEDULE = '1440 MINUTE';
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.ESG_SCORE
  SET DATA_METRIC_SCHEDULE = '1440 MINUTE';

-- ---------------------------------------------------------------------------
-- Built-in system DMFs (row count, null count, duplicate count, freshness).
--
-- FRESHNESS must use ON (). Its column overload accepts only DATE,
-- TIMESTAMP_LTZ and TIMESTAMP_TZ; every audit timestamp here is TIMESTAMP_NTZ,
-- which resolves to no overload ("Function 'FRESHNESS$V1' does not exist").
-- ON () measures time since the last DML, the intended signal anyway.
-- ---------------------------------------------------------------------------
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.PURCHASE_ORDER
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ();
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.PURCHASE_ORDER
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (order_date);
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.PURCHASE_ORDER
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT ON (order_id);
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.PURCHASE_ORDER
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS ON ();

ALTER TABLE SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ();
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT ON (line_item_id);
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (promised_delivery_date);
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (quantity_ordered);
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS ON ();

ALTER TABLE SCO_HACKATHON.SCO_SOURCE.SHIPMENT
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ();
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.SHIPMENT
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT ON (shipment_id);
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.SHIPMENT
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (freight_cost_usd);
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.SHIPMENT
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS ON ();

ALTER TABLE SCO_HACKATHON.SCO_SOURCE.INVENTORY_POSITION
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ();
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.INVENTORY_POSITION
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (quantity_on_hand);
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.INVENTORY_POSITION
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS ON ();

ALTER TABLE SCO_HACKATHON.SCO_SOURCE.SUPPLIER
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ();
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.SUPPLIER
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT ON (supplier_id);
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.SUPPLIER
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (country_id);

ALTER TABLE SCO_HACKATHON.SCO_SOURCE.PART
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT ON (part_number);
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.PART
  ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (commodity_id);

-- ---------------------------------------------------------------------------
-- Custom DMFs from PART A.
-- ---------------------------------------------------------------------------
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM
  ADD DATA METRIC FUNCTION SCO_GOVERNANCE.DMF_NON_POSITIVE_COUNT ON (quantity_ordered);
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM
  ADD DATA METRIC FUNCTION SCO_GOVERNANCE.DMF_DATE_ORDER_VIOLATIONS
      ON (promised_ship_date, promised_delivery_date);
ALTER TABLE SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM
  ADD DATA METRIC FUNCTION SCO_GOVERNANCE.DMF_DATE_ORDER_VIOLATIONS
      ON (actual_ship_date, actual_receipt_date);

ALTER TABLE SCO_HACKATHON.SCO_SOURCE.SHIPMENT
  ADD DATA METRIC FUNCTION SCO_GOVERNANCE.DMF_DATE_ORDER_VIOLATIONS
      ON (ship_date, actual_arrival_date);

ALTER TABLE SCO_HACKATHON.SCO_SOURCE.SUPPLIER_RISK_ASSESSMENT
  ADD DATA METRIC FUNCTION SCO_GOVERNANCE.DMF_OUT_OF_RANGE_SCORE_COUNT ON (overall_risk_score);

ALTER TABLE SCO_HACKATHON.SCO_SOURCE.ESG_SCORE
  ADD DATA METRIC FUNCTION SCO_GOVERNANCE.DMF_OUT_OF_RANGE_SCORE_COUNT ON (overall_esg_score);

ALTER TABLE SCO_HACKATHON.SCO_SOURCE.INVENTORY_POSITION
  ADD DATA METRIC FUNCTION SCO_GOVERNANCE.DMF_LOAD_SPAN_DAYS ON (_loaded_at);


-- =============================================================================
-- PART C — INSPECT DMF RESULTS
-- Results land in SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS after the
-- first scheduled evaluation. Allow one schedule interval before querying.
-- =============================================================================

SELECT metric_name, table_name, argument_names, value, measurement_time
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE table_database = 'SCO_HACKATHON'
  AND table_schema   = 'SCO_SOURCE'
ORDER BY measurement_time DESC, table_name, metric_name;

-- Which DMFs are attached to which columns.
SELECT metric_name, ref_entity_name, ref_arguments, schedule, schedule_status
FROM TABLE(INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
    REF_ENTITY_NAME  => 'SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM',
    REF_ENTITY_DOMAIN => 'TABLE'));


-- =============================================================================
-- PART D — EDITION-INDEPENDENT QUALITY MONITORING
--
-- Reproduces every check above as ordinary views. Works on Standard Edition
-- and runs on demand rather than on a schedule, so the Streamlit quality
-- dashboard and the Snowflake Alerts can both read from one place regardless
-- of edition.
-- =============================================================================

CREATE OR REPLACE VIEW V_DQ_COMPLETENESS
  COMMENT = 'Completeness: NULL counts on mandatory business columns across the source layer.'
AS
SELECT 'ORDER_LINE_ITEM' AS table_name, 'promised_delivery_date' AS column_name,
       COUNT_IF(promised_delivery_date IS NULL) AS null_rows, COUNT(*) AS total_rows,
       ROUND(100.0 * COUNT_IF(promised_delivery_date IS NULL) / NULLIF(COUNT(*),0), 4) AS null_pct
FROM SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM
UNION ALL
SELECT 'ORDER_LINE_ITEM', 'quantity_ordered',
       COUNT_IF(quantity_ordered IS NULL), COUNT(*),
       ROUND(100.0 * COUNT_IF(quantity_ordered IS NULL) / NULLIF(COUNT(*),0), 4)
FROM SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM
UNION ALL
SELECT 'PURCHASE_ORDER', 'order_date',
       COUNT_IF(order_date IS NULL), COUNT(*),
       ROUND(100.0 * COUNT_IF(order_date IS NULL) / NULLIF(COUNT(*),0), 4)
FROM SCO_HACKATHON.SCO_SOURCE.PURCHASE_ORDER
UNION ALL
SELECT 'PURCHASE_ORDER', 'total_value_usd',
       COUNT_IF(total_value_usd IS NULL), COUNT(*),
       ROUND(100.0 * COUNT_IF(total_value_usd IS NULL) / NULLIF(COUNT(*),0), 4)
FROM SCO_HACKATHON.SCO_SOURCE.PURCHASE_ORDER
UNION ALL
SELECT 'SHIPMENT', 'freight_cost_usd',
       COUNT_IF(freight_cost_usd IS NULL), COUNT(*),
       ROUND(100.0 * COUNT_IF(freight_cost_usd IS NULL) / NULLIF(COUNT(*),0), 4)
FROM SCO_HACKATHON.SCO_SOURCE.SHIPMENT
UNION ALL
SELECT 'SHIPMENT', 'carrier_id',
       COUNT_IF(carrier_id IS NULL), COUNT(*),
       ROUND(100.0 * COUNT_IF(carrier_id IS NULL) / NULLIF(COUNT(*),0), 4)
FROM SCO_HACKATHON.SCO_SOURCE.SHIPMENT
UNION ALL
SELECT 'INVENTORY_POSITION', 'quantity_on_hand',
       COUNT_IF(quantity_on_hand IS NULL), COUNT(*),
       ROUND(100.0 * COUNT_IF(quantity_on_hand IS NULL) / NULLIF(COUNT(*),0), 4)
FROM SCO_HACKATHON.SCO_SOURCE.INVENTORY_POSITION
UNION ALL
SELECT 'SUPPLIER', 'country_id',
       COUNT_IF(country_id IS NULL), COUNT(*),
       ROUND(100.0 * COUNT_IF(country_id IS NULL) / NULLIF(COUNT(*),0), 4)
FROM SCO_HACKATHON.SCO_SOURCE.SUPPLIER
UNION ALL
SELECT 'PART', 'commodity_id',
       COUNT_IF(commodity_id IS NULL), COUNT(*),
       ROUND(100.0 * COUNT_IF(commodity_id IS NULL) / NULLIF(COUNT(*),0), 4)
FROM SCO_HACKATHON.SCO_SOURCE.PART;


CREATE OR REPLACE VIEW V_DQ_UNIQUENESS
  COMMENT = 'Uniqueness: duplicate counts on every declared primary and unique key. Snowflake does not enforce these constraints.'
AS
SELECT 'PURCHASE_ORDER' AS table_name, 'order_id (PK)' AS key_name,
       COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_rows
FROM SCO_HACKATHON.SCO_SOURCE.PURCHASE_ORDER
UNION ALL
SELECT 'PURCHASE_ORDER', 'order_number (UQ)', COUNT(*) - COUNT(DISTINCT order_number)
FROM SCO_HACKATHON.SCO_SOURCE.PURCHASE_ORDER
UNION ALL
SELECT 'ORDER_LINE_ITEM', 'line_item_id (PK)', COUNT(*) - COUNT(DISTINCT line_item_id)
FROM SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM
UNION ALL
SELECT 'SHIPMENT', 'shipment_id (PK)', COUNT(*) - COUNT(DISTINCT shipment_id)
FROM SCO_HACKATHON.SCO_SOURCE.SHIPMENT
UNION ALL
SELECT 'SUPPLIER', 'supplier_id (PK)', COUNT(*) - COUNT(DISTINCT supplier_id)
FROM SCO_HACKATHON.SCO_SOURCE.SUPPLIER
UNION ALL
SELECT 'PART', 'part_number (UQ)', COUNT(*) - COUNT(DISTINCT part_number)
FROM SCO_HACKATHON.SCO_SOURCE.PART
UNION ALL
SELECT 'COMMODITY', 'hs_code (UQ)', COUNT(*) - COUNT(DISTINCT hs_code)
FROM SCO_HACKATHON.SCO_SOURCE.COMMODITY
UNION ALL
SELECT 'COUNTRY', 'iso_alpha3 (UQ)', COUNT(*) - COUNT(DISTINCT iso_alpha3)
FROM SCO_HACKATHON.SCO_SOURCE.COUNTRY
UNION ALL
SELECT 'INVENTORY_POSITION', 'part+warehouse+date (PK)',
       COUNT(*) - COUNT(DISTINCT part_id || '-' || warehouse_id || '-' || snapshot_date)
FROM SCO_HACKATHON.SCO_SOURCE.INVENTORY_POSITION;


CREATE OR REPLACE VIEW V_DQ_FRESHNESS
  COMMENT = 'Freshness: hours since the most recent update on each high-churn source table, measured against wall-clock time.'
AS
SELECT 'PURCHASE_ORDER' AS table_name,
       MAX(_updated_at) AS last_updated_at,
       DATEDIFF(hour, MAX(_updated_at), CURRENT_TIMESTAMP()) AS hours_stale,
       24 AS sla_hours,
       IFF(DATEDIFF(hour, MAX(_updated_at), CURRENT_TIMESTAMP()) <= 24,'FRESH','STALE') AS status
FROM SCO_HACKATHON.SCO_SOURCE.PURCHASE_ORDER
UNION ALL
SELECT 'ORDER_LINE_ITEM', MAX(_updated_at),
       DATEDIFF(hour, MAX(_updated_at), CURRENT_TIMESTAMP()), 24,
       IFF(DATEDIFF(hour, MAX(_updated_at), CURRENT_TIMESTAMP()) <= 24,'FRESH','STALE')
FROM SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM
UNION ALL
SELECT 'SHIPMENT', MAX(_updated_at),
       DATEDIFF(hour, MAX(_updated_at), CURRENT_TIMESTAMP()), 24,
       IFF(DATEDIFF(hour, MAX(_updated_at), CURRENT_TIMESTAMP()) <= 24,'FRESH','STALE')
FROM SCO_HACKATHON.SCO_SOURCE.SHIPMENT
UNION ALL
SELECT 'INVENTORY_POSITION', MAX(_updated_at),
       DATEDIFF(hour, MAX(_updated_at), CURRENT_TIMESTAMP()), 24,
       IFF(DATEDIFF(hour, MAX(_updated_at), CURRENT_TIMESTAMP()) <= 24,'FRESH','STALE')
FROM SCO_HACKATHON.SCO_SOURCE.INVENTORY_POSITION
UNION ALL
SELECT 'SUPPLIER_RISK_ASSESSMENT', MAX(_updated_at),
       DATEDIFF(hour, MAX(_updated_at), CURRENT_TIMESTAMP()), 168,
       IFF(DATEDIFF(hour, MAX(_updated_at), CURRENT_TIMESTAMP()) <= 168,'FRESH','STALE')
FROM SCO_HACKATHON.SCO_SOURCE.SUPPLIER_RISK_ASSESSMENT
UNION ALL
SELECT 'ESG_SCORE', MAX(_updated_at),
       DATEDIFF(hour, MAX(_updated_at), CURRENT_TIMESTAMP()), 168,
       IFF(DATEDIFF(hour, MAX(_updated_at), CURRENT_TIMESTAMP()) <= 168,'FRESH','STALE')
FROM SCO_HACKATHON.SCO_SOURCE.ESG_SCORE;


CREATE OR REPLACE VIEW V_DQ_REFERENTIAL_INTEGRITY
  COMMENT = 'Referential integrity: orphan counts on the load-bearing foreign keys. Snowflake does not enforce FK constraints.'
AS
SELECT 'ORDER_LINE_ITEM.order_id -> PURCHASE_ORDER' AS relationship, COUNT(*) AS orphan_rows
FROM SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM c
LEFT JOIN SCO_HACKATHON.SCO_SOURCE.PURCHASE_ORDER p ON p.order_id = c.order_id
WHERE p.order_id IS NULL
UNION ALL
SELECT 'ORDER_LINE_ITEM.part_id -> PART', COUNT(*)
FROM SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM c
LEFT JOIN SCO_HACKATHON.SCO_SOURCE.PART p ON p.part_id = c.part_id
WHERE p.part_id IS NULL
UNION ALL
SELECT 'SHIPMENT_LINE_ITEM.shipment_id -> SHIPMENT', COUNT(*)
FROM SCO_HACKATHON.SCO_SOURCE.SHIPMENT_LINE_ITEM c
LEFT JOIN SCO_HACKATHON.SCO_SOURCE.SHIPMENT p ON p.shipment_id = c.shipment_id
WHERE p.shipment_id IS NULL
UNION ALL
SELECT 'SHIPMENT_LINE_ITEM.line_item_id -> ORDER_LINE_ITEM', COUNT(*)
FROM SCO_HACKATHON.SCO_SOURCE.SHIPMENT_LINE_ITEM c
LEFT JOIN SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM p ON p.line_item_id = c.line_item_id
WHERE p.line_item_id IS NULL
UNION ALL
SELECT 'INVENTORY_POSITION.part_id -> PART', COUNT(*)
FROM SCO_HACKATHON.SCO_SOURCE.INVENTORY_POSITION c
LEFT JOIN SCO_HACKATHON.SCO_SOURCE.PART p ON p.part_id = c.part_id
WHERE p.part_id IS NULL
UNION ALL
SELECT 'PURCHASE_ORDER.supplier_id -> SUPPLIER', COUNT(*)
FROM SCO_HACKATHON.SCO_SOURCE.PURCHASE_ORDER c
LEFT JOIN SCO_HACKATHON.SCO_SOURCE.SUPPLIER p ON p.supplier_id = c.supplier_id
WHERE p.supplier_id IS NULL
UNION ALL
SELECT 'PLANT.supplier_id -> SUPPLIER', COUNT(*)
FROM SCO_HACKATHON.SCO_SOURCE.PLANT c
LEFT JOIN SCO_HACKATHON.SCO_SOURCE.SUPPLIER p ON p.supplier_id = c.supplier_id
WHERE p.supplier_id IS NULL;


CREATE OR REPLACE VIEW V_DQ_BUSINESS_RULES
  COMMENT = 'Validity and consistency: business rules that cannot be expressed as database constraints.'
AS
SELECT 'Non-positive order quantity' AS rule_name,
       (SELECT COUNT(*) FROM SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM
         WHERE quantity_ordered <= 0) AS violation_rows
UNION ALL
SELECT 'Shipped more than ordered',
       (SELECT COUNT(*) FROM (
            SELECT sli.line_item_id
            FROM SCO_HACKATHON.SCO_SOURCE.SHIPMENT_LINE_ITEM sli
            JOIN SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM oli
              ON oli.line_item_id = sli.line_item_id
            GROUP BY sli.line_item_id
            HAVING SUM(sli.quantity_shipped) > MAX(oli.quantity_ordered) + 0.01))
UNION ALL
SELECT 'Receipt date before ship date',
       (SELECT COUNT(*) FROM SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM
         WHERE actual_receipt_date < actual_ship_date)
UNION ALL
SELECT 'Cancelled order with a shipment',
       (SELECT COUNT(*) FROM SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM oli
          JOIN SCO_HACKATHON.SCO_SOURCE.PURCHASE_ORDER po ON po.order_id = oli.order_id
         WHERE po.order_status = 'Cancelled' AND oli.actual_ship_date IS NOT NULL)
UNION ALL
SELECT 'Inventory available <> on_hand - reserved',
       (SELECT COUNT(*) FROM SCO_HACKATHON.SCO_SOURCE.INVENTORY_POSITION
         WHERE ABS(quantity_available - (quantity_on_hand - quantity_reserved)) > 0.01)
UNION ALL
SELECT 'Negative inventory on hand',
       (SELECT COUNT(*) FROM SCO_HACKATHON.SCO_SOURCE.INVENTORY_POSITION
         WHERE quantity_on_hand < 0)
UNION ALL
SELECT 'Risk score outside 0-100',
       (SELECT COUNT(*) FROM SCO_HACKATHON.SCO_SOURCE.SUPPLIER_RISK_ASSESSMENT
         WHERE overall_risk_score < 0 OR overall_risk_score > 100)
UNION ALL
SELECT 'ESG score outside 0-100',
       (SELECT COUNT(*) FROM SCO_HACKATHON.SCO_SOURCE.ESG_SCORE
         WHERE overall_esg_score < 0 OR overall_esg_score > 100)
UNION ALL
SELECT 'ESG row without exactly one parent',
       (SELECT COUNT_IF((supplier_id IS NOT NULL AND plant_id IS NOT NULL)
                     OR (supplier_id IS NULL AND plant_id IS NULL))
          FROM SCO_HACKATHON.SCO_SOURCE.ESG_SCORE)
UNION ALL
SELECT 'Shipment without exactly one origin node',
       (SELECT COUNT_IF(  IFF(origin_supplier_id  IS NOT NULL,1,0)
                        + IFF(origin_plant_id     IS NOT NULL,1,0)
                        + IFF(origin_warehouse_id IS NOT NULL,1,0) <> 1)
          FROM SCO_HACKATHON.SCO_SOURCE.SHIPMENT)
UNION ALL
SELECT 'Order line not present in supplier catalog',
       (SELECT COUNT(*) FROM SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM oli
          LEFT JOIN SCO_HACKATHON.SCO_SOURCE.SUPPLIER_CATALOG sc
                 ON sc.supplier_id = oli.supplier_id AND sc.part_id = oli.part_id
         WHERE sc.supplier_id IS NULL);


-- Single pane of glass for the Streamlit quality dashboard and the Alerts.
CREATE OR REPLACE VIEW V_DQ_SCORECARD
  COMMENT = 'Consolidated data quality scorecard across completeness, uniqueness, referential integrity, business rules, and freshness.'
AS
SELECT 'Completeness' AS dq_dimension, table_name || '.' || column_name AS check_name,
       null_rows AS violation_count, IFF(null_rows = 0,'PASS','FAIL') AS status
FROM V_DQ_COMPLETENESS
UNION ALL
SELECT 'Uniqueness', table_name || '.' || key_name, duplicate_rows,
       IFF(duplicate_rows = 0,'PASS','FAIL')
FROM V_DQ_UNIQUENESS
UNION ALL
SELECT 'Referential Integrity', relationship, orphan_rows,
       IFF(orphan_rows = 0,'PASS','FAIL')
FROM V_DQ_REFERENTIAL_INTEGRITY
UNION ALL
SELECT 'Business Rules', rule_name, violation_rows,
       IFF(violation_rows = 0,'PASS','FAIL')
FROM V_DQ_BUSINESS_RULES
UNION ALL
SELECT 'Freshness', table_name, hours_stale, IFF(status = 'FRESH','PASS','FAIL')
FROM V_DQ_FRESHNESS;


SELECT dq_dimension,
       COUNT(*)                       AS checks_run,
       COUNT_IF(status = 'PASS')      AS checks_passed,
       COUNT_IF(status = 'FAIL')      AS checks_failed,
       ROUND(100.0 * COUNT_IF(status = 'PASS') / COUNT(*), 2) AS pass_rate_pct
FROM V_DQ_SCORECARD
GROUP BY dq_dimension
ORDER BY checks_failed DESC, dq_dimension;


-- =============================================================================
-- PART E — SNOWFLAKE ALERTS driven by the quality scorecard
-- =============================================================================

CREATE OR REPLACE ALERT ALRT_DATA_QUALITY_FAILURE
  WAREHOUSE = COMPUTE_WH
  SCHEDULE  = '60 MINUTE'
  IF (EXISTS (
      SELECT 1 FROM SCO_HACKATHON.SCO_GOVERNANCE.V_DQ_SCORECARD WHERE status = 'FAIL'
  ))
  THEN
    INSERT INTO SCO_HACKATHON.SCO_GOLD.GLD_PIPELINE_AUDIT
        (task_name, object_schema, object_name, object_type,
         audit_event, status, rows_affected, details)
    SELECT 'ALRT_DATA_QUALITY_FAILURE', 'SCO_GOVERNANCE', 'V_DQ_SCORECARD', 'ALERT',
           'DATA_QUALITY_VIOLATION', 'FAIL',
           (SELECT COUNT(*) FROM SCO_HACKATHON.SCO_GOVERNANCE.V_DQ_SCORECARD WHERE status = 'FAIL'),
           OBJECT_CONSTRUCT('failing_checks',
               (SELECT ARRAY_AGG(check_name)
                  FROM SCO_HACKATHON.SCO_GOVERNANCE.V_DQ_SCORECARD WHERE status = 'FAIL'));

ALTER ALERT ALRT_DATA_QUALITY_FAILURE RESUME;

-- To pause:  ALTER ALERT ALRT_DATA_QUALITY_FAILURE SUSPEND;

-- =============================================================================
-- END
-- =============================================================================

-- suspend
ALTER TASK SCO_HACKATHON.SCO_GOLD.TSK_SCO_ROOT SUSPEND;

--SHOW TASKS IN SCHEMA SCO_HACKATHON.SCO_GOLD;
--SHOW ALERTS IN SCHEMA SCO_HACKATHON.SCO_GOVERNANCE;

--check if semantic view is created
--SHOW SEMANTIC VIEWS IN SCHEMA SCO_HACKATHON.SCO_GOLD;

SELECT * FROM SEMANTIC_VIEW(
    SCO_HACKATHON.SCO_GOLD.SV_SUPPLY_CHAIN
    METRICS on_time_delivery_rate
);

SELECT * FROM SEMANTIC_VIEW(
    SCO_HACKATHON.SCO_GOLD.SV_SUPPLY_CHAIN
    DIMENSIONS delivery_month
    METRICS on_time_delivery_rate
)
ORDER BY delivery_month;

SELECT * FROM SEMANTIC_VIEW(SCO_HACKATHON.SCO_GOLD.SV_SUPPLY_CHAIN
    DIMENSIONS delivery_month METRICS on_time_delivery_rate)
WHERE delivery_month BETWEEN '2024-07-01' AND '2024-12-01'
ORDER BY delivery_month;


SHOW WAREHOUSES LIKE 'COMPUTE_WH'
ALTER WAREHOUSE COMPUTE_WH RESUME;
SELECT 1;