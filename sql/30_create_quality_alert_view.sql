--------------------------------------------------------------------------------
-- Supply Chain Ontology — Data Quality: Alert Bridge View
-- 30_create_quality_alert_view.sql
--
-- Bridges DQ_CHECK_RESULT to the existing ALERT_EVENT workflow.
-- Failed, alert-eligible checks appear as candidates for Jira tickets.
--------------------------------------------------------------------------------

USE SCHEMA SCO_HACKATHON.SCO_GOVERNANCE;

CREATE OR REPLACE VIEW V_DQ_ALERT_CANDIDATES AS
SELECT
    QUALITY_CHECK_ID,
    CHECK_NAME,
    QUALITY_DIMENSION,
    LAYER_NAME,
    OBJECT_NAME,
    COLUMN_NAME,
    METRIC_NAME,
    OBSERVED_VALUE,
    EXPECTED_CONDITION,
    SEVERITY,
    EVALUATED_AT,
    DETAILS,
    REMEDIATION_GUIDANCE,
    SOURCE_OBJECT,
    -- Dedup key for Jira integration
    'DQ:' || QUALITY_DIMENSION || ':' || CHECK_NAME AS DEDUP_KEY,
    -- Alert type mapping
    'DQ_' || UPPER(REPLACE(QUALITY_DIMENSION, ' ', '_')) || '_FAILURE' AS ALERT_TYPE
FROM DQ_CHECK_RESULT
WHERE NOT PASSED_FLAG
  AND ALERT_ELIGIBLE_FLAG = TRUE
  AND STATUS = 'ACTIVE';
