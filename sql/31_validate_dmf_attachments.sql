--------------------------------------------------------------------------------
-- Supply Chain Ontology — Data Quality: DMF Attachment Validation
-- 31_validate_dmf_attachments.sql
--
-- Checks for existing DMF attachments before proposing new ones.
-- Run BEFORE executing 26_attach_system_dmfs.sql.
--------------------------------------------------------------------------------

-- Check existing DMF attachments on critical source tables
SELECT * FROM TABLE(SCO_HACKATHON.INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
    REF_ENTITY_DOMAIN => 'TABLE',
    REF_ENTITY_NAME => 'SCO_HACKATHON.SCO_SOURCE.PURCHASE_ORDER'));

SELECT * FROM TABLE(SCO_HACKATHON.INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
    REF_ENTITY_DOMAIN => 'TABLE',
    REF_ENTITY_NAME => 'SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM'));

SELECT * FROM TABLE(SCO_HACKATHON.INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
    REF_ENTITY_DOMAIN => 'TABLE',
    REF_ENTITY_NAME => 'SCO_HACKATHON.SCO_SOURCE.SHIPMENT'));

SELECT * FROM TABLE(SCO_HACKATHON.INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
    REF_ENTITY_DOMAIN => 'TABLE',
    REF_ENTITY_NAME => 'SCO_HACKATHON.SCO_SOURCE.SUPPLIER'));

SELECT * FROM TABLE(SCO_HACKATHON.INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
    REF_ENTITY_DOMAIN => 'TABLE',
    REF_ENTITY_NAME => 'SCO_HACKATHON.SCO_SOURCE.INVENTORY_POSITION'));

-- Summarize: if any rows returned above, those DMFs are already attached.
-- Do NOT re-attach them (will produce "already attached" errors).
-- Only attach DMFs listed in 26_attach_system_dmfs.sql that do NOT appear above.
