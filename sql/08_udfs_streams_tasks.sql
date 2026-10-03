--------------------------------------------------------------------------------
-- Supply Chain Ontology — SQL UDFs, Streams, and Task Graph
-- 08_udfs_streams_tasks.sql
--------------------------------------------------------------------------------

SET sco_role='ACCOUNTADMIN';
SET sco_warehouse='COMPUTE_WH';
SET sco_database='SCO_HACKATHON';

USE ROLE IDENTIFIER($sco_role);
USE WAREHOUSE IDENTIFIER($sco_warehouse);
USE DATABASE IDENTIFIER($sco_database);

CREATE SCHEMA IF NOT EXISTS SCO_SILVER;
USE SCHEMA SCO_SILVER;

-- =============================================================================
-- Reusable governed SQL functions
-- =============================================================================

CREATE OR REPLACE FUNCTION FN_IS_ON_TIME(actual_receipt DATE, promised DATE)
RETURNS BOOLEAN
LANGUAGE SQL
COMMENT = 'Returns whether actual customer receipt occurred on or before the promised delivery date; NULL when either date is absent.'
AS
$$
    IFF(actual_receipt IS NULL OR promised IS NULL, NULL, actual_receipt <= promised)
$$;

CREATE OR REPLACE FUNCTION FN_DAYS_LATE(actual DATE, promised DATE)
RETURNS NUMBER
LANGUAGE SQL
COMMENT = 'Returns non-negative calendar days late; NULL when either date is absent.'
AS
$$
    IFF(actual IS NULL OR promised IS NULL, NULL, GREATEST(DATEDIFF('day', promised, actual), 0))
$$;

CREATE OR REPLACE FUNCTION FN_LANDED_COST_PER_UNIT(
    supply_cost NUMBER,
    freight NUMBER,
    insurance NUMBER,
    duties NUMBER,
    handling NUMBER,
    units NUMBER
)
RETURNS NUMBER
LANGUAGE SQL
COMMENT = 'Returns governed landed cost per unit: supply cost plus allocated freight, insurance, duties, and handling.'
AS
$$
    IFF(
        units IS NULL OR units = 0,
        NULL,
        supply_cost
          + COALESCE(freight, 0) / units
          + COALESCE(insurance, 0) / units
          + COALESCE(duties, 0) / units
          + COALESCE(handling, 0) / units
    )
$$;

CREATE OR REPLACE FUNCTION FN_DOI(on_hand NUMBER, avg_daily_demand NUMBER)
RETURNS NUMBER
LANGUAGE SQL
COMMENT = 'Returns governed days of inventory and returns NULL for absent or zero average daily demand.'
AS
$$
    IFF(avg_daily_demand IS NULL OR avg_daily_demand = 0, NULL, on_hand / avg_daily_demand)
$$;

CREATE OR REPLACE FUNCTION FN_RISK_BAND(score NUMBER)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Maps a 0-100 risk score to Low, Medium, High, or Critical bands.'
AS
$$
    CASE
        WHEN score IS NULL THEN NULL
        WHEN score < 25 THEN 'Low'
        WHEN score < 50 THEN 'Medium'
        WHEN score < 75 THEN 'High'
        ELSE 'Critical'
    END
$$;

CREATE OR REPLACE FUNCTION FN_FILL_RATE_PCT(shipped NUMBER, ordered NUMBER)
RETURNS NUMBER
LANGUAGE SQL
COMMENT = 'Returns unit fill rate percentage capped at 100 percent and NULL for absent or zero ordered units.'
AS
$$
    IFF(
        ordered IS NULL OR ordered = 0,
        NULL,
        100 * LEAST(COALESCE(shipped, 0), ordered) / ordered
    )
$$;

-- =============================================================================
-- High-churn source change streams
-- =============================================================================

CREATE OR REPLACE STREAM STR_PURCHASE_ORDER
  ON TABLE SCO_HACKATHON.SCO_SOURCE.PURCHASE_ORDER
  SHOW_INITIAL_ROWS = FALSE
  COMMENT = 'CDC stream for purchase-order operational audit.';

CREATE OR REPLACE STREAM STR_ORDER_LINE_ITEM
  ON TABLE SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM
  SHOW_INITIAL_ROWS = FALSE
  COMMENT = 'CDC stream for order-line operational audit.';

CREATE OR REPLACE STREAM STR_SHIPMENT
  ON TABLE SCO_HACKATHON.SCO_SOURCE.SHIPMENT
  SHOW_INITIAL_ROWS = FALSE
  COMMENT = 'CDC stream for shipment operational audit.';

CREATE OR REPLACE STREAM STR_SHIPMENT_LINE_ITEM
  ON TABLE SCO_HACKATHON.SCO_SOURCE.SHIPMENT_LINE_ITEM
  SHOW_INITIAL_ROWS = FALSE
  COMMENT = 'CDC stream for shipment-line operational audit.';

CREATE OR REPLACE STREAM STR_INVENTORY_POSITION
  ON TABLE SCO_HACKATHON.SCO_SOURCE.INVENTORY_POSITION
  SHOW_INITIAL_ROWS = FALSE
  COMMENT = 'CDC stream for inventory-position operational audit.';

-- =============================================================================
-- Gold operational audit and serverless task graph
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS SCO_GOLD;
USE SCHEMA SCO_GOLD;

CREATE TABLE IF NOT EXISTS GLD_PIPELINE_AUDIT (
    audit_id NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    audit_event_ts TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    task_name VARCHAR(200) NOT NULL,
    object_schema VARCHAR(200),
    object_name VARCHAR(200),
    object_type VARCHAR(50),
    audit_event VARCHAR(100) NOT NULL,
    status VARCHAR(30) NOT NULL,
    rows_affected NUMBER,
    details VARIANT,
    CONSTRAINT pk_gld_pipeline_audit PRIMARY KEY (audit_id)
)
COMMENT = 'Operational audit trail for hourly pipeline orchestration, dynamic-table state snapshots, and consumed source-stream changes.';

CREATE OR REPLACE TASK TSK_SCO_ROOT
  USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
  SCHEDULE = 'USING CRON 0 * * * * UTC'
  COMMENT = 'Hourly serverless root task for the Supply Chain Ontology transformation audit graph.'
AS
INSERT INTO SCO_HACKATHON.SCO_GOLD.GLD_PIPELINE_AUDIT (
    task_name,
    object_schema,
    object_name,
    object_type,
    audit_event,
    status,
    rows_affected,
    details
)
SELECT
    'TSK_SCO_ROOT',
    'SCO_GOLD',
    'BRONZE_TO_SILVER_TO_GOLD',
    'PIPELINE',
    'HOURLY_ORCHESTRATION_STARTED',
    'STARTED',
    NULL,
    OBJECT_CONSTRUCT('scheduled_at_utc', CURRENT_TIMESTAMP());

CREATE OR REPLACE TASK TSK_LOG_REFRESH_STATE
  USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
  COMMENT = 'Logs row-count state for the four governed Gold metric dynamic tables after each hourly root run.'
  AFTER TSK_SCO_ROOT
AS
INSERT INTO SCO_HACKATHON.SCO_GOLD.GLD_PIPELINE_AUDIT (
    task_name,
    object_schema,
    object_name,
    object_type,
    audit_event,
    status,
    rows_affected,
    details
)
SELECT
    'TSK_LOG_REFRESH_STATE',
    'SCO_GOLD',
    metric_object_name,
    'DYNAMIC_TABLE',
    'REFRESH_STATE_SNAPSHOT',
    'OBSERVED',
    metric_row_count,
    OBJECT_CONSTRUCT('observed_at_utc', CURRENT_TIMESTAMP())
FROM (
    SELECT 'GLD_METRIC_OTD' AS metric_object_name, COUNT(*) AS metric_row_count
    FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD
    UNION ALL
    SELECT 'GLD_METRIC_FILL_RATE', COUNT(*)
    FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_FILL_RATE
    UNION ALL
    SELECT 'GLD_METRIC_DOI', COUNT(*)
    FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_DOI
    UNION ALL
    SELECT 'GLD_METRIC_LANDED_COST', COUNT(*)
    FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_LANDED_COST
);

CREATE OR REPLACE TASK TSK_AUDIT_SOURCE_STREAMS
  USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
  COMMENT = 'Consumes high-churn source streams and logs insert/delete CDC counts when any stream has data.'
  AFTER TSK_SCO_ROOT
  WHEN SYSTEM$STREAM_HAS_DATA('SCO_HACKATHON.SCO_SILVER.STR_PURCHASE_ORDER')
    OR SYSTEM$STREAM_HAS_DATA('SCO_HACKATHON.SCO_SILVER.STR_ORDER_LINE_ITEM')
    OR SYSTEM$STREAM_HAS_DATA('SCO_HACKATHON.SCO_SILVER.STR_SHIPMENT')
    OR SYSTEM$STREAM_HAS_DATA('SCO_HACKATHON.SCO_SILVER.STR_SHIPMENT_LINE_ITEM')
    OR SYSTEM$STREAM_HAS_DATA('SCO_HACKATHON.SCO_SILVER.STR_INVENTORY_POSITION')
AS
INSERT INTO SCO_HACKATHON.SCO_GOLD.GLD_PIPELINE_AUDIT (
    task_name,
    object_schema,
    object_name,
    object_type,
    audit_event,
    status,
    rows_affected,
    details
)
SELECT
    'TSK_AUDIT_SOURCE_STREAMS',
    'SCO_SILVER',
    stream_name,
    'STREAM',
    'SOURCE_CHANGES_CONSUMED',
    'SUCCESS',
    total_changes,
    OBJECT_CONSTRUCT(
        'insert_actions', insert_actions,
        'delete_actions', delete_actions,
        'observed_at_utc', CURRENT_TIMESTAMP()
    )
FROM (
    SELECT
        'STR_PURCHASE_ORDER' AS stream_name,
        COUNT(*) AS total_changes,
        COUNT_IF(METADATA$ACTION = 'INSERT') AS insert_actions,
        COUNT_IF(METADATA$ACTION = 'DELETE') AS delete_actions
    FROM SCO_HACKATHON.SCO_SILVER.STR_PURCHASE_ORDER
    UNION ALL
    SELECT
        'STR_ORDER_LINE_ITEM',
        COUNT(*),
        COUNT_IF(METADATA$ACTION = 'INSERT'),
        COUNT_IF(METADATA$ACTION = 'DELETE')
    FROM SCO_HACKATHON.SCO_SILVER.STR_ORDER_LINE_ITEM
    UNION ALL
    SELECT
        'STR_SHIPMENT',
        COUNT(*),
        COUNT_IF(METADATA$ACTION = 'INSERT'),
        COUNT_IF(METADATA$ACTION = 'DELETE')
    FROM SCO_HACKATHON.SCO_SILVER.STR_SHIPMENT
    UNION ALL
    SELECT
        'STR_SHIPMENT_LINE_ITEM',
        COUNT(*),
        COUNT_IF(METADATA$ACTION = 'INSERT'),
        COUNT_IF(METADATA$ACTION = 'DELETE')
    FROM SCO_HACKATHON.SCO_SILVER.STR_SHIPMENT_LINE_ITEM
    UNION ALL
    SELECT
        'STR_INVENTORY_POSITION',
        COUNT(*),
        COUNT_IF(METADATA$ACTION = 'INSERT'),
        COUNT_IF(METADATA$ACTION = 'DELETE')
    FROM SCO_HACKATHON.SCO_SILVER.STR_INVENTORY_POSITION
)
WHERE total_changes > 0;

CREATE OR REPLACE TASK TSK_REFRESH_METRIC_DEFINITIONS_TS
  USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
  COMMENT = 'Refreshes the governance-catalog timestamp to attest that metric definitions remain in the hourly orchestration scope.'
  AFTER TSK_SCO_ROOT
AS
UPDATE SCO_HACKATHON.SCO_GOLD.GLD_METRIC_DEFINITIONS
SET refreshed_at = CURRENT_TIMESTAMP();

-- Snowflake requires child tasks to be resumed before their root task.
ALTER TASK TSK_LOG_REFRESH_STATE RESUME;
ALTER TASK TSK_AUDIT_SOURCE_STREAMS RESUME;
ALTER TASK TSK_REFRESH_METRIC_DEFINITIONS_TS RESUME;
ALTER TASK TSK_SCO_ROOT RESUME;

-- To suspend the graph, suspend the root first and then its children:
-- ALTER TASK TSK_SCO_ROOT SUSPEND;
-- ALTER TASK TSK_LOG_REFRESH_STATE SUSPEND;
-- ALTER TASK TSK_AUDIT_SOURCE_STREAMS SUSPEND;
-- ALTER TASK TSK_REFRESH_METRIC_DEFINITIONS_TS SUSPEND;


ALTER TASK SCO_HACKATHON.SCO_GOLD.TSK_SCO_ROOT SUSPEND;
ALTER TASK SCO_HACKATHON.SCO_GOLD.TSK_LOG_REFRESH_STATE SUSPEND;
ALTER TASK SCO_HACKATHON.SCO_GOLD.TSK_AUDIT_SOURCE_STREAMS SUSPEND;
ALTER TASK SCO_HACKATHON.SCO_GOLD.TSK_REFRESH_METRIC_DEFINITIONS_TS SUSPEND;