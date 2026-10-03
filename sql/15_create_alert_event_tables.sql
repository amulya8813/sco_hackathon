--------------------------------------------------------------------------------
-- Supply Chain Ontology — Monitoring & Alerting: Alert Event Table
-- 15_create_alert_event_tables.sql
--------------------------------------------------------------------------------

USE DATABASE SCO_HACKATHON;
CREATE SCHEMA IF NOT EXISTS SCO_MONITORING
  COMMENT = 'Governed alert events, Jira integration state, and monitoring orchestration';
USE SCHEMA SCO_MONITORING;

-- ═══════════════════════════════════════════════════════════════════════
-- Core alert event table
-- ═══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS ALERT_EVENT (
    ALERT_ID            NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    ALERT_TYPE          VARCHAR(100)   NOT NULL,
    ALERT_CATEGORY      VARCHAR(30)    NOT NULL,  -- BUSINESS | DATA_QUALITY
    SEVERITY            VARCHAR(20)    NOT NULL,  -- CRITICAL | HIGH | MEDIUM | LOW
    ENTITY_TYPE         VARCHAR(50),              -- SUPPLIER | PART | WAREHOUSE | ROUTE | ...
    ENTITY_ID           VARCHAR(200),
    METRIC_NAME         VARCHAR(100),
    OBSERVED_VALUE      NUMBER(18,4),
    THRESHOLD_VALUE     NUMBER(18,4),
    FORECAST_VALUE      NUMBER(18,4),
    ALERT_MESSAGE       VARCHAR(4000)  NOT NULL,
    DETECTED_AT         TIMESTAMP_NTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    SOURCE_OBJECT       VARCHAR(500),
    SOURCE_QUERY_ID     VARCHAR(200),
    -- Alert state
    STATUS              VARCHAR(30)    NOT NULL DEFAULT 'OPEN',  -- OPEN | ACKNOWLEDGED | RESOLVED | SUPPRESSED
    RESOLVED_AT         TIMESTAMP_NTZ,
    -- Jira integration
    JIRA_ISSUE_KEY      VARCHAR(50),
    JIRA_ISSUE_URL      VARCHAR(1000),
    JIRA_SYNC_STATUS    VARCHAR(30)    DEFAULT 'PENDING', -- PENDING | CREATED | UPDATED | FAILED | SKIPPED
    JIRA_LAST_SYNC_AT   TIMESTAMP_NTZ,
    JIRA_ERROR_MESSAGE  VARCHAR(4000),
    -- Deduplication
    DEDUP_KEY           VARCHAR(500)   NOT NULL,
    -- Audit
    CREATED_AT          TIMESTAMP_NTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT          TIMESTAMP_NTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_ALERT_EVENT PRIMARY KEY (ALERT_ID)
)
COMMENT = 'Governed alert events for business and data-quality exceptions with Jira MCP sync state';

-- ═══════════════════════════════════════════════════════════════════════
-- Jira sync log — every MCP request/response (no secrets)
-- ═══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS JIRA_SYNC_LOG (
    LOG_ID              NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    ALERT_ID            NUMBER NOT NULL,
    SYNC_ACTION         VARCHAR(30)  NOT NULL,  -- CREATE | UPDATE | RESOLVE | RETRY
    REQUEST_PAYLOAD     VARIANT,                -- sanitized payload (no tokens)
    RESPONSE_STATUS     VARCHAR(30),
    RESPONSE_CODE       NUMBER,
    RESPONSE_MESSAGE    VARCHAR(4000),
    JIRA_ISSUE_KEY      VARCHAR(50),
    DRY_RUN             BOOLEAN      NOT NULL DEFAULT TRUE,
    EXECUTED_AT         TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_JIRA_SYNC_LOG PRIMARY KEY (LOG_ID)
)
COMMENT = 'Audit log for Jira MCP sync operations — no secrets stored';

-- ═══════════════════════════════════════════════════════════════════════
-- Alert thresholds — governed reference for detection queries
-- ═══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS ALERT_THRESHOLD (
    METRIC_NAME         VARCHAR(100) NOT NULL,
    ALERT_TYPE          VARCHAR(100) NOT NULL,
    SEVERITY            VARCHAR(20)  NOT NULL,
    THRESHOLD_OPERATOR  VARCHAR(10)  NOT NULL,  -- LT | GT | OUTSIDE
    THRESHOLD_VALUE     NUMBER(18,4) NOT NULL,
    THRESHOLD_UPPER     NUMBER(18,4),           -- for OUTSIDE range
    IS_ACTIVE           BOOLEAN      NOT NULL DEFAULT TRUE,
    CREATED_AT          TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_ALERT_THRESHOLD PRIMARY KEY (METRIC_NAME, ALERT_TYPE)
)
COMMENT = 'Governed thresholds for alert detection — derived from GLD_METRIC_DEFINITIONS';

-- Seed thresholds from governed metric definitions
INSERT INTO ALERT_THRESHOLD (METRIC_NAME, ALERT_TYPE, SEVERITY, THRESHOLD_OPERATOR, THRESHOLD_VALUE, THRESHOLD_UPPER) VALUES
    ('OTD_RATE',        'OTD_BELOW_THRESHOLD',        'CRITICAL', 'LT', 95.0,  NULL),
    ('FILL_RATE',       'FILL_RATE_BELOW_THRESHOLD',   'HIGH',     'LT', 92.0,  NULL),
    ('DOI_DAYS',        'DOI_OUTSIDE_RANGE',           'HIGH',     'OUTSIDE', 15.0, 45.0),
    ('LANDED_COST_USD', 'LANDED_COST_ANOMALY',         'MEDIUM',   'GT', 0,     NULL),
    ('RISK_SCORE',      'SUPPLIER_RISK_EVENT',          'HIGH',     'GT', 40.0,  NULL),
    ('STOCKOUT_FLAG',   'INVENTORY_SHORTAGE',           'CRITICAL', 'GT', 0,     NULL),
    ('ON_TIME_ARR_PCT', 'SHIPMENT_DELAY_RISK',          'HIGH',     'LT', 50.0,  NULL);
