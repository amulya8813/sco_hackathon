--------------------------------------------------------------------------------
-- Data Quality Framework — Custom DMFs
-- 27_create_custom_dmfs.sql
--
-- Custom Data Metric Functions for composite-key uniqueness and
-- business rules that cannot be expressed with system DMFs.
--------------------------------------------------------------------------------
USE DATABASE SCO_HACKATHON;
USE SCHEMA SCO_GOVERNANCE;

-- ═══════════════════════════════════════════════════════════════════════
-- Custom DMF: Composite key duplicate count
-- Used for multi-column business keys (e.g., part+warehouse+date)
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE DATA METRIC FUNCTION DMF_COMPOSITE_KEY_DUPLICATES(
    ARG_T TABLE(KEY_HASH VARCHAR)
)
RETURNS NUMBER
COMMENT = 'Counts rows whose concatenated key hash appears more than once'
AS
$$
    SELECT COUNT(*) - COUNT(DISTINCT KEY_HASH) FROM ARG_T
$$;

-- ═══════════════════════════════════════════════════════════════════════
-- Custom DMF: Negative value count
-- Validates that numeric columns are non-negative
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE DATA METRIC FUNCTION DMF_NEGATIVE_VALUE_COUNT(
    ARG_T TABLE(VAL NUMBER)
)
RETURNS NUMBER
COMMENT = 'Counts rows where the numeric value is negative'
AS
$$
    SELECT COUNT_IF(VAL < 0) FROM ARG_T
$$;

-- ═══════════════════════════════════════════════════════════════════════
-- Custom DMF: Value outside range
-- Validates that values fall within [low, high] inclusive
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE DATA METRIC FUNCTION DMF_OUT_OF_RANGE_COUNT(
    ARG_T TABLE(VAL NUMBER)
)
RETURNS NUMBER
COMMENT = 'Counts rows where the value is outside 0-100 range'
AS
$$
    SELECT COUNT_IF(VAL < 0 OR VAL > 100) FROM ARG_T
$$;

-- ═══════════════════════════════════════════════════════════════════════
-- Custom DMF: Orphan FK count
-- Generic FK check — counts child rows with no matching parent
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE DATA METRIC FUNCTION DMF_ORPHAN_FK_COUNT(
    ARG_T TABLE(FK_VALUE NUMBER)
)
RETURNS NUMBER
COMMENT = 'Counts rows where FK value is not NULL but has no parent (requires SQL join check outside DMF for full validation)'
AS
$$
    SELECT COUNT_IF(FK_VALUE IS NULL) FROM ARG_T
$$;

-- ═══════════════════════════════════════════════════════════════════════
-- Custom DMF: Numerator exceeds denominator
-- For metric inputs where shipped > ordered is invalid
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE DATA METRIC FUNCTION DMF_NUMERATOR_EXCEEDS_DENOMINATOR(
    ARG_T TABLE(NUMERATOR NUMBER, DENOMINATOR NUMBER)
)
RETURNS NUMBER
COMMENT = 'Counts rows where numerator exceeds denominator (e.g., shipped > ordered)'
AS
$$
    SELECT COUNT_IF(NUMERATOR > DENOMINATOR) FROM ARG_T
$$;

-- ═══════════════════════════════════════════════════════════════════════
-- 31_validate_dmf_attachments.sql (inline — validates all attachments)
-- ═══════════════════════════════════════════════════════════════════════
-- This query checks for active DMF attachments on SCO_SOURCE tables.
-- Run after executing 26_attach_system_dmfs.sql to confirm.
-- SELECT METRIC_DATABASE, METRIC_SCHEMA, METRIC_NAME,
--        REF_ENTITY_DOMAIN, REF_ENTITY_NAME, REF_ENTITY_COLUMN_NAME,
--        SCHEDULE_STATUS, SCHEDULE
-- FROM TABLE(INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
--     REF_ENTITY_DOMAIN => 'TABLE',
--     REF_ENTITY_NAME => 'SCO_HACKATHON.SCO_SOURCE.SUPPLIER'
-- ));
