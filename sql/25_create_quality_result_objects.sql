--------------------------------------------------------------------------------
-- Data Quality Framework — Centralized Quality Result Objects
-- 25_create_quality_result_objects.sql
--------------------------------------------------------------------------------
USE DATABASE SCO_HACKATHON;
USE SCHEMA SCO_GOVERNANCE;

-- ═══════════════════════════════════════════════════════════════════════
-- Centralized quality-check result table
-- ═══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS DQ_CHECK_RESULT (
    QUALITY_CHECK_ID    NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    CHECK_NAME          VARCHAR(200)   NOT NULL,
    QUALITY_DIMENSION   VARCHAR(50)    NOT NULL,
    LAYER_NAME          VARCHAR(30)    NOT NULL,
    OBJECT_NAME         VARCHAR(200)   NOT NULL,
    COLUMN_NAME         VARCHAR(200),
    METRIC_NAME         VARCHAR(100),
    OBSERVED_VALUE      NUMBER(18,4),
    EXPECTED_CONDITION  VARCHAR(500),
    PASSED_FLAG         BOOLEAN        NOT NULL,
    SEVERITY            VARCHAR(20)    NOT NULL DEFAULT 'MEDIUM',
    EVALUATED_AT        TIMESTAMP_NTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    QUERY_ID            VARCHAR(200),
    DETAILS             VARCHAR(4000),
    REMEDIATION_GUIDANCE VARCHAR(2000),
    SOURCE_OBJECT       VARCHAR(500),
    ALERT_ELIGIBLE_FLAG BOOLEAN        NOT NULL DEFAULT FALSE,
    STATUS              VARCHAR(30)    NOT NULL DEFAULT 'ACTIVE',
    CREATED_AT          TIMESTAMP_NTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT          TIMESTAMP_NTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_DQ_CHECK_RESULT PRIMARY KEY (QUALITY_CHECK_ID)
)
COMMENT = 'Centralized data-quality check results across all dimensions and layers';

-- ═══════════════════════════════════════════════════════════════════════
-- Quality score summary view
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW V_DQ_SCORE_SUMMARY AS
SELECT
    QUALITY_DIMENSION,
    LAYER_NAME,
    COUNT(*)                          AS TOTAL_CHECKS,
    COUNT_IF(PASSED_FLAG)             AS PASSED,
    COUNT_IF(NOT PASSED_FLAG)         AS FAILED,
    COUNT_IF(STATUS = 'BLOCKED')      AS BLOCKED,
    ROUND(100.0 * COUNT_IF(PASSED_FLAG)
        / NULLIF(COUNT_IF(STATUS = 'ACTIVE'), 0), 1) AS PASS_RATE_PCT,
    MAX(EVALUATED_AT)                 AS LAST_EVALUATED
FROM DQ_CHECK_RESULT
WHERE STATUS IN ('ACTIVE', 'BLOCKED')
GROUP BY QUALITY_DIMENSION, LAYER_NAME;

-- ═══════════════════════════════════════════════════════════════════════
-- Failed checks eligible for alerting
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW V_DQ_ALERT_CANDIDATES AS
SELECT
    QUALITY_CHECK_ID,
    CHECK_NAME,
    QUALITY_DIMENSION,
    SEVERITY,
    LAYER_NAME,
    OBJECT_NAME,
    COLUMN_NAME,
    OBSERVED_VALUE,
    EXPECTED_CONDITION,
    DETAILS,
    EVALUATED_AT
FROM DQ_CHECK_RESULT
WHERE PASSED_FLAG = FALSE
  AND ALERT_ELIGIBLE_FLAG = TRUE
  AND STATUS = 'ACTIVE';
