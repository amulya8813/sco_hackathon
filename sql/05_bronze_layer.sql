--------------------------------------------------------------------------------
-- Supply Chain Ontology — Bronze Layer
-- 05_bronze_layer.sql
--
-- Light-touch, deletion-filtered copies of all 24 canonical source tables.
-- Snowflake does not allow CURRENT_TIMESTAMP in a dynamic-table projection, so
-- _bronze_loaded_at is deterministically derived from the source load timestamp.
--------------------------------------------------------------------------------

SET sco_role='ACCOUNTADMIN';
SET sco_warehouse='COMPUTE_WH';
SET sco_database='SCO_HACKATHON';

USE ROLE IDENTIFIER($sco_role);
USE WAREHOUSE IDENTIFIER($sco_warehouse);
USE DATABASE IDENTIFIER($sco_database);

CREATE SCHEMA IF NOT EXISTS SCO_BRONZE;
USE SCHEMA SCO_BRONZE;

-- =============================================================================
-- Reference and master data
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE BRZ_COUNTRY
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.COUNTRY with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.COUNTRY AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_COMMODITY
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.COMMODITY with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.COMMODITY AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_COMPLIANCE_LIST
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.COMPLIANCE_LIST with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.COMPLIANCE_LIST AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_SUPPLIER
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.SUPPLIER with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.SUPPLIER AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_CUSTOMER
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.CUSTOMER with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.CUSTOMER AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_CARRIER
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.CARRIER with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.CARRIER AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_PORT
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.PORT with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.PORT AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_PART
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.PART with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.PART AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_WAREHOUSE
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.WAREHOUSE with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.WAREHOUSE AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_PLANT
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.PLANT with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.PLANT AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_ROUTE
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.ROUTE with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.ROUTE AS s
WHERE s._is_deleted = FALSE;

-- =============================================================================
-- Relationship, compliance, risk, and ESG data
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE BRZ_SUPPLIER_CATALOG
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.SUPPLIER_CATALOG with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.SUPPLIER_CATALOG AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_PLANT_PART_ASSIGNMENT
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.PLANT_PART_ASSIGNMENT with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.PLANT_PART_ASSIGNMENT AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_CARRIER_ROUTE_SERVICE
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.CARRIER_ROUTE_SERVICE with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.CARRIER_ROUTE_SERVICE AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_SUPPLIER_COMPLIANCE_MATCH
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.SUPPLIER_COMPLIANCE_MATCH with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.SUPPLIER_COMPLIANCE_MATCH AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_CUSTOMER_COMPLIANCE_MATCH
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.CUSTOMER_COMPLIANCE_MATCH with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.CUSTOMER_COMPLIANCE_MATCH AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_COMMODITY_RESTRICTION
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.COMMODITY_RESTRICTION with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.COMMODITY_RESTRICTION AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_SUPPLIER_RISK_ASSESSMENT
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.SUPPLIER_RISK_ASSESSMENT with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.SUPPLIER_RISK_ASSESSMENT AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_ESG_SCORE
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.ESG_SCORE with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.ESG_SCORE AS s
WHERE s._is_deleted = FALSE;

-- =============================================================================
-- Transaction and inventory data
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE BRZ_PURCHASE_ORDER
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.PURCHASE_ORDER with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.PURCHASE_ORDER AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_ORDER_LINE_ITEM
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.ORDER_LINE_ITEM with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_SHIPMENT
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.SHIPMENT with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.SHIPMENT AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_SHIPMENT_LINE_ITEM
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.SHIPMENT_LINE_ITEM with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.SHIPMENT_LINE_ITEM AS s
WHERE s._is_deleted = FALSE;

CREATE OR REPLACE DYNAMIC TABLE BRZ_INVENTORY_POSITION
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Deletion-filtered Bronze copy of SCO_SOURCE.INVENTORY_POSITION with source lineage preserved.'
AS
SELECT s.*, s._loaded_at::TIMESTAMP_NTZ AS _bronze_loaded_at
FROM SCO_HACKATHON.SCO_SOURCE.INVENTORY_POSITION AS s
WHERE s._is_deleted = FALSE;
