-- DDL script to create the 24 canonical source tables for the Supply Chain Ontology hackathon project.
-- Co-authored with CoCo
--------------------------------------------------------------------------------
-- Supply Chain Ontology — Canonical Source Layer DDL
-- 01_create_source_tables.sql
--
-- Purpose: Creates database, schema, and all 24 source-layer tables in
--          dependency order for the Supply Chain Ontology & Governed
--          Conversational Analytics hackathon.
--
-- Corrections Applied:
--   - _batch_id DEFAULT 'SYNTHETIC_INIT' (DDL Readiness Finding #1)
--   - ESG_SCORE: polymorphic replaced with explicit supplier_id + plant_id FKs
--   - SHIPMENT: polymorphic origin/destination replaced with explicit FKs
--
-- Usage:
--   1. Adjust the three SET statements below if your role/warehouse/db differ.
--   2. Execute the entire script in a single session.
--   3. Rerunnable: uses CREATE TABLE IF NOT EXISTS (no data loss on rerun).
--------------------------------------------------------------------------------

-- =============================================================================
-- CONFIGURATION  (edit these three SET statements only)
-- =============================================================================
SET sco_role      = 'ACCOUNTADMIN';
SET sco_warehouse = 'COMPUTE_WH';
SET sco_database  = 'SCO_HACKATHON';

USE ROLE      IDENTIFIER($sco_role);
USE WAREHOUSE IDENTIFIER($sco_warehouse);
CREATE DATABASE IF NOT EXISTS IDENTIFIER($sco_database);
USE DATABASE  IDENTIFIER($sco_database);

-- -----------------------------------------------------------------------------
-- SAFETY GUARD: abort if the active database is not the hackathon project DB.
-- Satisfies safety rule 6 ("Stop execution if the configured database does not
-- match the hackathon project database").
-- -----------------------------------------------------------------------------
EXECUTE IMMEDIATE $$
DECLARE
  wrong_database EXCEPTION (-20001,
    'GUARD FAILED: the active database is not the configured hackathon project database. Execution halted.');
BEGIN
  IF (UPPER(CURRENT_DATABASE()) <> UPPER(GETVARIABLE('SCO_DATABASE'))) THEN
    RAISE wrong_database;
  END IF;
  RETURN 'GUARD PASS: active database = ' || CURRENT_DATABASE();
END;
$$;

-- Context echo (safety rule 1: confirm role/warehouse/database before execution)
SELECT CURRENT_ROLE()      AS active_role,
       CURRENT_WAREHOUSE() AS active_warehouse,
       CURRENT_DATABASE()  AS active_database,
       CURRENT_SCHEMA()    AS active_schema_before_create;

CREATE SCHEMA IF NOT EXISTS SCO_SOURCE
  COMMENT = 'Supply Chain Ontology — Canonical Source Layer. Contains 24 governed entity and relationship tables.';
USE SCHEMA    SCO_SOURCE;

SELECT CURRENT_ROLE() AS active_role, CURRENT_WAREHOUSE() AS active_warehouse,
       CURRENT_DATABASE() AS active_database, CURRENT_SCHEMA() AS active_schema;


-- =============================================================================
-- BATCH 1: Root Reference Tables (no foreign key dependencies)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. COUNTRY
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS COUNTRY (
    country_id              INTEGER         NOT NULL,
    country_name            VARCHAR(100)    NOT NULL    COMMENT 'Official short name',
    iso_alpha2              CHAR(2)         NOT NULL    COMMENT 'ISO 3166-1 alpha-2 code',
    iso_alpha3              CHAR(3)         NOT NULL    COMMENT 'ISO 3166-1 alpha-3 code',
    iso_numeric             CHAR(3)                     COMMENT 'ISO 3166-1 numeric code',
    region_name             VARCHAR(50)     NOT NULL    COMMENT 'Geographic region (Americas, EMEA, Asia-Pacific, South Asia, Africa)',
    sub_region              VARCHAR(50)                 COMMENT 'Sub-region (e.g., Southeast Asia, Western Europe)',
    sanctions_status        VARCHAR(20)     NOT NULL    DEFAULT 'None' COMMENT 'None, Partial, or Comprehensive',
    trade_bloc              VARCHAR(50)                 COMMENT 'Primary trade agreement (EU, USMCA, ASEAN, RCEP)',
    currency_code           CHAR(3)         NOT NULL    COMMENT 'National currency ISO 4217 code',
    risk_rating             NUMBER(5,2)                 COMMENT 'Composite country risk score (0.00–100.00)',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'VERIFIED',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_country        PRIMARY KEY (country_id),
    CONSTRAINT uq_country_alpha2 UNIQUE (iso_alpha2),
    CONSTRAINT uq_country_alpha3 UNIQUE (iso_alpha3)
)
COMMENT = 'Reference table of sovereign nations defining geographic, trade, and regulatory context for all supply chain nodes';


-- -----------------------------------------------------------------------------
-- 2. COMMODITY
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS COMMODITY (
    commodity_id            INTEGER         NOT NULL,
    hs_code                 VARCHAR(10)     NOT NULL    COMMENT 'Harmonized System code (6-digit)',
    commodity_description   VARCHAR(500)    NOT NULL    COMMENT 'Official HS description',
    hs_section              VARCHAR(10)     NOT NULL    COMMENT 'HS Section (I through XXI)',
    hs_chapter              VARCHAR(4)      NOT NULL    COMMENT 'HS Chapter (2-digit)',
    hs_chapter_description  VARCHAR(200)                COMMENT 'Chapter-level description',
    esg_risk_flag           BOOLEAN         NOT NULL    DEFAULT FALSE COMMENT 'Flagged for ESG concerns',
    export_control_flag     BOOLEAN         NOT NULL    DEFAULT FALSE COMMENT 'Subject to export controls',
    forced_labor_flag       BOOLEAN         NOT NULL    DEFAULT FALSE COMMENT 'Associated with forced labor risk',
    dual_use_flag           BOOLEAN         NOT NULL    DEFAULT FALSE COMMENT 'Classified as dual-use goods',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'VERIFIED',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_commodity       PRIMARY KEY (commodity_id),
    CONSTRAINT uq_commodity_hs    UNIQUE (hs_code)
)
COMMENT = 'Trade classification reference for parts/products enabling tariff determination, compliance screening, and ESG flagging';


-- =============================================================================
-- BATCH 2: Reference with FK to Batch 1
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 3. COMPLIANCE_LIST
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS COMPLIANCE_LIST (
    list_entry_id           INTEGER         NOT NULL,
    list_source             VARCHAR(50)     NOT NULL    COMMENT 'OFAC-SDN, EU-Sanctions, BIS-Entity-List, UFLPA, UN-Sanctions',
    listed_entity_name      VARCHAR(300)    NOT NULL    COMMENT 'Name of restricted party or commodity',
    listed_entity_type      VARCHAR(30)     NOT NULL    COMMENT 'Organization, Individual, Vessel, Commodity',
    country_id              INTEGER                     COMMENT 'FK: Associated country',
    restriction_type        VARCHAR(30)     NOT NULL    COMMENT 'Full-Block, Partial-Restriction, License-Required, Monitoring',
    effective_date          DATE            NOT NULL    COMMENT 'Date restriction took effect',
    expiration_date         DATE                        COMMENT 'Date restriction expires (NULL = indefinite)',
    basis                   VARCHAR(500)                COMMENT 'Legal authority or reason for listing',
    aliases                 VARCHAR(1000)               COMMENT 'Known aliases (semicolon-delimited)',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'VERIFIED',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_compliance_list PRIMARY KEY (list_entry_id),
    CONSTRAINT fk_compliance_country FOREIGN KEY (country_id) REFERENCES COUNTRY (country_id)
)
COMMENT = 'Regulatory restriction entries (sanctions, export controls, forced labor lists) used for screening suppliers, customers, and commodities';


-- =============================================================================
-- BATCH 3: Master Entities with FK to COUNTRY only
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 4. SUPPLIER
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SUPPLIER (
    supplier_id             INTEGER         NOT NULL,
    supplier_name           VARCHAR(200)    NOT NULL    COMMENT 'Legal or trading name',
    supplier_duns           VARCHAR(9)                  COMMENT 'DUNS Number for entity resolution',
    supplier_lei            VARCHAR(20)                 COMMENT 'Legal Entity Identifier (ISO 17442)',
    supplier_status         VARCHAR(20)     NOT NULL    DEFAULT 'Active' COMMENT 'Active, Qualified, Probation, Blocked, Deactivated',
    supplier_tier           VARCHAR(20)     NOT NULL    DEFAULT 'Approved' COMMENT 'Strategic, Preferred, Approved, Transactional',
    country_id              INTEGER         NOT NULL    COMMENT 'FK: Country of registration/headquarters',
    city                    VARCHAR(100)                COMMENT 'City of primary operations',
    state_province          VARCHAR(100)                COMMENT 'State or province',
    industry_code           VARCHAR(10)                 COMMENT 'Primary NAICS code',
    industry_description    VARCHAR(200)                COMMENT 'NAICS description',
    year_established        INTEGER                     COMMENT 'Year of incorporation',
    employee_count          INTEGER                     COMMENT 'Headcount',
    annual_revenue_usd      NUMBER(15,2)                COMMENT 'Annual revenue in USD',
    primary_contact_name    VARCHAR(150)                COMMENT 'Key account contact',
    primary_contact_email   VARCHAR(200)                COMMENT 'Contact email',
    primary_contact_phone   VARCHAR(30)                 COMMENT 'Contact phone',
    website_url             VARCHAR(300)                COMMENT 'Company website',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'HIGH',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_supplier        PRIMARY KEY (supplier_id),
    CONSTRAINT fk_supplier_country FOREIGN KEY (country_id) REFERENCES COUNTRY (country_id),
    CONSTRAINT uq_supplier_duns   UNIQUE (supplier_duns),
    CONSTRAINT uq_supplier_lei    UNIQUE (supplier_lei)
)
COMMENT = 'Master record of organizations that provide goods, materials, or services to the enterprise under contractual terms';


-- -----------------------------------------------------------------------------
-- 5. CUSTOMER
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS CUSTOMER (
    customer_id             INTEGER         NOT NULL,
    customer_name           VARCHAR(200)    NOT NULL    COMMENT 'Legal or trading name',
    customer_duns           VARCHAR(9)                  COMMENT 'DUNS Number',
    customer_type           VARCHAR(30)     NOT NULL    COMMENT 'B2B-Enterprise, B2B-SMB, Distributor, Government',
    market_segment          VARCHAR(50)     NOT NULL    COMMENT 'Industry vertical',
    country_id              INTEGER         NOT NULL    COMMENT 'FK: Country of headquarters',
    city                    VARCHAR(100)                COMMENT 'Primary location city',
    state_province          VARCHAR(100)                COMMENT 'State or province',
    postal_code             VARCHAR(20)                 COMMENT 'Postal/zip code',
    account_balance_usd     NUMBER(15,2)                COMMENT 'Outstanding credit balance',
    credit_status           VARCHAR(20)     NOT NULL    DEFAULT 'Good-Standing' COMMENT 'Good-Standing, Watch, Hold, Blocked',
    service_level_tier      VARCHAR(20)     NOT NULL    DEFAULT 'Standard' COMMENT 'Platinum, Gold, Silver, Standard',
    customer_since_date     DATE                        COMMENT 'Relationship start date',
    primary_contact_name    VARCHAR(150)                COMMENT 'Key contact',
    primary_contact_email   VARCHAR(200)                COMMENT 'Contact email',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'HIGH',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_customer         PRIMARY KEY (customer_id),
    CONSTRAINT fk_customer_country FOREIGN KEY (country_id) REFERENCES COUNTRY (country_id)
)
COMMENT = 'Master record of organizations or individuals that purchase goods or services, generating demand that drives supply chain activity';


-- -----------------------------------------------------------------------------
-- 6. CARRIER
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS CARRIER (
    carrier_id              INTEGER         NOT NULL,
    carrier_name            VARCHAR(200)    NOT NULL    COMMENT 'Organization name',
    carrier_code            VARCHAR(10)                 COMMENT 'SCAC, IATA, or IMO code',
    carrier_type            VARCHAR(30)     NOT NULL    COMMENT 'Ocean-Line, Air-Freight, Truckload, LTL, Rail, Parcel, Intermodal',
    primary_mode            VARCHAR(20)     NOT NULL    COMMENT 'Ocean, Air, Road, Rail',
    country_id              INTEGER         NOT NULL    COMMENT 'FK: Country of registration',
    contract_status         VARCHAR(30)     NOT NULL    DEFAULT 'Active' COMMENT 'Active, Expired, Under-Negotiation',
    on_time_rate_pct        NUMBER(5,2)                 COMMENT 'Historical on-time delivery percentage',
    damage_rate_pct         NUMBER(5,2)                 COMMENT 'Historical damage claim rate',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'HIGH',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_carrier         PRIMARY KEY (carrier_id),
    CONSTRAINT fk_carrier_country FOREIGN KEY (country_id) REFERENCES COUNTRY (country_id)
)
COMMENT = 'Master record of logistics service providers contracted to physically transport goods';


-- -----------------------------------------------------------------------------
-- 7. PORT
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS PORT (
    port_id                 INTEGER         NOT NULL,
    port_name               VARCHAR(150)    NOT NULL    COMMENT 'Common port name',
    un_locode               VARCHAR(5)                  COMMENT 'UN/LOCODE identifier',
    port_type               VARCHAR(20)     NOT NULL    COMMENT 'Seaport, Airport, Land-Border, Inland-Port',
    country_id              INTEGER         NOT NULL    COMMENT 'FK: Country of location',
    city                    VARCHAR(100)                COMMENT 'City',
    latitude                NUMBER(9,6)                 COMMENT 'Geographic latitude',
    longitude               NUMBER(9,6)                 COMMENT 'Geographic longitude',
    avg_dwell_days          NUMBER(5,2)                 COMMENT 'Average cargo dwell time in days',
    congestion_status       VARCHAR(20)     NOT NULL    DEFAULT 'Normal' COMMENT 'Normal, Elevated, Severe',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'VERIFIED',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_port            PRIMARY KEY (port_id),
    CONSTRAINT fk_port_country    FOREIGN KEY (country_id) REFERENCES COUNTRY (country_id),
    CONSTRAINT uq_port_locode     UNIQUE (un_locode)
)
COMMENT = 'Reference record of customs-controlled facilities where goods enter or exit a trade territory';


-- =============================================================================
-- BATCH 4: Master Entities with FKs to Batch 1 + Batch 3
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 8. PART
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS PART (
    part_id                 INTEGER         NOT NULL,
    part_number             VARCHAR(50)     NOT NULL    COMMENT 'Business-facing part number',
    part_name               VARCHAR(300)    NOT NULL    COMMENT 'Descriptive name',
    gtin                    VARCHAR(14)                 COMMENT 'Global Trade Item Number',
    manufacturer_name       VARCHAR(200)                COMMENT 'Original manufacturer',
    brand                   VARCHAR(100)                COMMENT 'Brand/label',
    part_category           VARCHAR(100)    NOT NULL    COMMENT 'Product family grouping',
    part_type               VARCHAR(30)     NOT NULL    COMMENT 'Raw-Material, Component, Sub-Assembly, Finished-Good',
    commodity_id            INTEGER         NOT NULL    COMMENT 'FK: Trade classification',
    unit_of_measure         VARCHAR(10)     NOT NULL    DEFAULT 'EA' COMMENT 'Standard UOM (EA, KG, LB, M, L)',
    unit_weight_kg          NUMBER(12,4)                COMMENT 'Weight per unit in kg',
    unit_volume_m3          NUMBER(12,6)                COMMENT 'Volume per unit in cubic meters',
    standard_cost_usd       NUMBER(12,4)                COMMENT 'Standard/reference cost',
    retail_price_usd        NUMBER(12,4)                COMMENT 'List/retail price',
    lifecycle_status        VARCHAR(20)     NOT NULL    DEFAULT 'Active' COMMENT 'Active, End-of-Life, Obsolete, Prototype',
    container_type          VARCHAR(30)                 COMMENT 'Packaging form (drum, pallet, carton, bulk)',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'HIGH',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_part             PRIMARY KEY (part_id),
    CONSTRAINT fk_part_commodity   FOREIGN KEY (commodity_id) REFERENCES COMMODITY (commodity_id),
    CONSTRAINT uq_part_number      UNIQUE (part_number),
    CONSTRAINT uq_part_gtin        UNIQUE (gtin)
)
COMMENT = 'Master record of discrete physical items that move through the supply chain';


-- -----------------------------------------------------------------------------
-- 9. WAREHOUSE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS WAREHOUSE (
    warehouse_id            INTEGER         NOT NULL,
    warehouse_name          VARCHAR(200)    NOT NULL    COMMENT 'Facility name',
    warehouse_code          VARCHAR(20)                 COMMENT 'Internal site code',
    warehouse_type          VARCHAR(30)     NOT NULL    COMMENT 'Owned, 3PL, Cross-Dock, Cold-Storage, Bonded',
    country_id              INTEGER         NOT NULL    COMMENT 'FK: Country of location',
    city                    VARCHAR(100)                COMMENT 'City location',
    state_province          VARCHAR(100)                COMMENT 'State or province',
    address                 VARCHAR(300)                COMMENT 'Street address',
    capacity_sqft           INTEGER                     COMMENT 'Total storage area in sq ft',
    operational_status      VARCHAR(20)     NOT NULL    DEFAULT 'Active' COMMENT 'Active, Seasonal, Closed',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'VERIFIED',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_warehouse         PRIMARY KEY (warehouse_id),
    CONSTRAINT fk_warehouse_country FOREIGN KEY (country_id) REFERENCES COUNTRY (country_id)
)
COMMENT = 'Master record of storage/distribution facilities that hold inventory without performing material transformation';


-- -----------------------------------------------------------------------------
-- 10. PLANT
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS PLANT (
    plant_id                INTEGER         NOT NULL,
    plant_name              VARCHAR(200)    NOT NULL    COMMENT 'Facility name',
    plant_code              VARCHAR(20)                 COMMENT 'Internal site code',
    supplier_id             INTEGER         NOT NULL    COMMENT 'FK: Owning/operating supplier',
    country_id              INTEGER         NOT NULL    COMMENT 'FK: Country of location',
    city                    VARCHAR(100)                COMMENT 'City location',
    state_province          VARCHAR(100)                COMMENT 'State or province',
    plant_type              VARCHAR(30)     NOT NULL    COMMENT 'Manufacturing, Assembly, Processing, Testing, Packaging',
    capacity_units_per_day  INTEGER                     COMMENT 'Maximum daily production capacity',
    operational_status      VARCHAR(30)     NOT NULL    DEFAULT 'Operational' COMMENT 'Operational, Idle, Under-Construction, Decommissioned',
    year_commissioned       INTEGER                     COMMENT 'Year plant began operations',
    certifications          VARCHAR(500)                COMMENT 'Semicolon-delimited certification list',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'HIGH',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_plant            PRIMARY KEY (plant_id),
    CONSTRAINT fk_plant_supplier   FOREIGN KEY (supplier_id) REFERENCES SUPPLIER (supplier_id),
    CONSTRAINT fk_plant_country    FOREIGN KEY (country_id) REFERENCES COUNTRY (country_id)
)
COMMENT = 'Master record of manufacturing/processing facilities where value-adding transformation occurs';


-- =============================================================================
-- BATCH 5: Configuration (FK to Batch 1 + Batch 3)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 11. ROUTE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ROUTE (
    route_id                INTEGER         NOT NULL,
    route_name              VARCHAR(200)                COMMENT 'Descriptive route name',
    origin_port_id          INTEGER         NOT NULL    COMMENT 'FK: Starting port/terminal',
    destination_port_id     INTEGER         NOT NULL    COMMENT 'FK: Ending port/terminal',
    origin_country_id       INTEGER         NOT NULL    COMMENT 'FK: Origin country',
    destination_country_id  INTEGER         NOT NULL    COMMENT 'FK: Destination country',
    primary_mode            VARCHAR(20)     NOT NULL    COMMENT 'Ocean, Air, Road, Rail, Intermodal',
    distance_km             NUMBER(10,2)                COMMENT 'Approximate distance',
    avg_transit_days        NUMBER(5,2)                 COMMENT 'Average transit time',
    avg_cost_per_kg_usd     NUMBER(8,4)                 COMMENT 'Typical freight rate',
    reliability_pct         NUMBER(5,2)                 COMMENT 'Historical on-time percentage',
    active_carriers_count   INTEGER                     COMMENT 'Number of carriers serving this route',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'HIGH',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_route               PRIMARY KEY (route_id),
    CONSTRAINT fk_route_origin_port   FOREIGN KEY (origin_port_id) REFERENCES PORT (port_id),
    CONSTRAINT fk_route_dest_port     FOREIGN KEY (destination_port_id) REFERENCES PORT (port_id),
    CONSTRAINT fk_route_origin_country FOREIGN KEY (origin_country_id) REFERENCES COUNTRY (country_id),
    CONSTRAINT fk_route_dest_country  FOREIGN KEY (destination_country_id) REFERENCES COUNTRY (country_id)
)
COMMENT = 'Definition of transportation paths between origin and destination, characterized by mode and performance metrics';


-- =============================================================================
-- BATCH 6: Bridge/Relationship Tables (FK to Batches 2–5)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 12. SUPPLIER_CATALOG
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SUPPLIER_CATALOG (
    supplier_id             INTEGER         NOT NULL    COMMENT 'FK: Offering supplier',
    part_id                 INTEGER         NOT NULL    COMMENT 'FK: Offered part',
    supply_cost_usd         NUMBER(12,4)    NOT NULL    COMMENT 'Quoted unit cost',
    lead_time_days          INTEGER         NOT NULL    COMMENT 'Quoted lead time (order to delivery)',
    available_quantity      NUMBER(12,2)                COMMENT 'Supplier stated availability',
    minimum_order_quantity  NUMBER(10,2)                COMMENT 'MOQ for this item',
    preferred_flag          BOOLEAN         NOT NULL    DEFAULT FALSE COMMENT 'Is this the preferred source?',
    last_quoted_date        DATE                        COMMENT 'Date of most recent quote',
    contract_reference      VARCHAR(50)                 COMMENT 'Governing contract number',
    catalog_status          VARCHAR(20)     NOT NULL    DEFAULT 'Active' COMMENT 'Active, Inactive, Pending',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'HIGH',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_supplier_catalog    PRIMARY KEY (supplier_id, part_id),
    CONSTRAINT fk_sc_supplier         FOREIGN KEY (supplier_id) REFERENCES SUPPLIER (supplier_id),
    CONSTRAINT fk_sc_part             FOREIGN KEY (part_id) REFERENCES PART (part_id)
)
COMMENT = 'M:N bridge recording which parts each supplier offers, with pricing, lead time, and availability';


-- -----------------------------------------------------------------------------
-- 13. PLANT_PART_ASSIGNMENT
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS PLANT_PART_ASSIGNMENT (
    plant_id                INTEGER         NOT NULL    COMMENT 'FK: Manufacturing plant',
    part_id                 INTEGER         NOT NULL    COMMENT 'FK: Part produced',
    production_capacity_per_day INTEGER                 COMMENT 'Daily capacity for this part',
    yield_rate_pct          NUMBER(5,2)                 COMMENT 'Production yield percentage',
    qualification_status    VARCHAR(20)     NOT NULL    DEFAULT 'Qualified' COMMENT 'Qualified, Pending, Disqualified, Under-Review',
    qualification_date      DATE                        COMMENT 'When this plant was qualified',
    manufacturing_cost_usd  NUMBER(12,4)                COMMENT 'Manufacturing cost per unit',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'HIGH',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_plant_part          PRIMARY KEY (plant_id, part_id),
    CONSTRAINT fk_pp_plant            FOREIGN KEY (plant_id) REFERENCES PLANT (plant_id),
    CONSTRAINT fk_pp_part             FOREIGN KEY (part_id) REFERENCES PART (part_id)
)
COMMENT = 'M:N bridge recording which parts each plant is qualified to produce';


-- -----------------------------------------------------------------------------
-- 14. CARRIER_ROUTE_SERVICE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS CARRIER_ROUTE_SERVICE (
    carrier_id              INTEGER         NOT NULL    COMMENT 'FK: Carrier',
    route_id                INTEGER         NOT NULL    COMMENT 'FK: Route',
    service_frequency       VARCHAR(20)                 COMMENT 'Daily, Weekly, Bi-weekly, Monthly, On-demand',
    contracted_rate_usd_per_kg NUMBER(8,4)              COMMENT 'Contracted freight rate',
    average_transit_days    NUMBER(5,2)                 COMMENT 'Carrier-specific transit time on this route',
    on_time_pct             NUMBER(5,2)                 COMMENT 'Carrier x route on-time performance',
    capacity_teu_per_sailing INTEGER                    COMMENT 'TEU capacity per departure',
    service_name            VARCHAR(100)                COMMENT 'Carrier named service',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'HIGH',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_carrier_route       PRIMARY KEY (carrier_id, route_id),
    CONSTRAINT fk_cr_carrier          FOREIGN KEY (carrier_id) REFERENCES CARRIER (carrier_id),
    CONSTRAINT fk_cr_route            FOREIGN KEY (route_id) REFERENCES ROUTE (route_id)
)
COMMENT = 'M:N bridge recording which carriers serve which routes with service characteristics';


-- -----------------------------------------------------------------------------
-- 15. SUPPLIER_COMPLIANCE_MATCH
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SUPPLIER_COMPLIANCE_MATCH (
    supplier_id             INTEGER         NOT NULL    COMMENT 'FK: Matched supplier',
    list_entry_id           INTEGER         NOT NULL    COMMENT 'FK: Compliance list entry',
    match_confidence_pct    NUMBER(5,2)     NOT NULL    COMMENT 'Screening confidence (0–100)',
    match_type              VARCHAR(30)     NOT NULL    COMMENT 'Exact-Name, Alias, Address, Ownership-Chain',
    match_date              DATE            NOT NULL    COMMENT 'Date match was identified',
    resolution_status       VARCHAR(20)     NOT NULL    DEFAULT 'Unresolved' COMMENT 'Unresolved, Confirmed-Match, False-Positive, Escalated',
    resolved_by             VARCHAR(100)                COMMENT 'Analyst who adjudicated',
    resolution_date         DATE                        COMMENT 'When adjudicated',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'HIGH',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_suppl_compliance    PRIMARY KEY (supplier_id, list_entry_id),
    CONSTRAINT fk_scm_supplier        FOREIGN KEY (supplier_id) REFERENCES SUPPLIER (supplier_id),
    CONSTRAINT fk_scm_list            FOREIGN KEY (list_entry_id) REFERENCES COMPLIANCE_LIST (list_entry_id)
)
COMMENT = 'M:N bridge recording screening matches between suppliers and compliance/sanctions lists';


-- -----------------------------------------------------------------------------
-- 16. CUSTOMER_COMPLIANCE_MATCH
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS CUSTOMER_COMPLIANCE_MATCH (
    customer_id             INTEGER         NOT NULL    COMMENT 'FK: Matched customer',
    list_entry_id           INTEGER         NOT NULL    COMMENT 'FK: Compliance list entry',
    match_confidence_pct    NUMBER(5,2)     NOT NULL    COMMENT 'Screening confidence (0–100)',
    match_type              VARCHAR(30)     NOT NULL    COMMENT 'Exact-Name, Alias, Address, Ownership-Chain',
    match_date              DATE            NOT NULL    COMMENT 'Date match was identified',
    resolution_status       VARCHAR(20)     NOT NULL    DEFAULT 'Unresolved' COMMENT 'Unresolved, Confirmed-Match, False-Positive, Escalated',
    resolved_by             VARCHAR(100)                COMMENT 'Analyst who adjudicated',
    resolution_date         DATE                        COMMENT 'When adjudicated',
    order_hold_triggered    BOOLEAN         NOT NULL    DEFAULT FALSE COMMENT 'Whether orders were placed on hold',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'HIGH',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_cust_compliance     PRIMARY KEY (customer_id, list_entry_id),
    CONSTRAINT fk_ccm_customer        FOREIGN KEY (customer_id) REFERENCES CUSTOMER (customer_id),
    CONSTRAINT fk_ccm_list            FOREIGN KEY (list_entry_id) REFERENCES COMPLIANCE_LIST (list_entry_id)
)
COMMENT = 'M:N bridge recording screening matches between customers and compliance/sanctions lists';


-- -----------------------------------------------------------------------------
-- 17. COMMODITY_RESTRICTION
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS COMMODITY_RESTRICTION (
    commodity_id            INTEGER         NOT NULL    COMMENT 'FK: Restricted commodity',
    list_entry_id           INTEGER         NOT NULL    COMMENT 'FK: Compliance list entry',
    restriction_scope       VARCHAR(20)     NOT NULL    COMMENT 'Export-Only, Import-Only, Both',
    license_type_required   VARCHAR(30)                 COMMENT 'Individual, General, Denial-Presumption',
    destination_countries_blocked VARCHAR(500)           COMMENT 'Comma-delimited ISO alpha-2 codes',
    control_reason          VARCHAR(200)                COMMENT 'National Security, Anti-Terrorism, Regional Stability',
    eccn                    VARCHAR(10)                 COMMENT 'Export Control Classification Number',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'VERIFIED',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_commodity_restrict   PRIMARY KEY (commodity_id, list_entry_id),
    CONSTRAINT fk_cr_commodity         FOREIGN KEY (commodity_id) REFERENCES COMMODITY (commodity_id),
    CONSTRAINT fk_cr_list              FOREIGN KEY (list_entry_id) REFERENCES COMPLIANCE_LIST (list_entry_id)
)
COMMENT = 'M:N bridge recording which commodity codes are subject to which export/import restrictions';


-- =============================================================================
-- BATCH 7: Assessment Tables (FK to Batch 3 + 4)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 18. SUPPLIER_RISK_ASSESSMENT
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SUPPLIER_RISK_ASSESSMENT (
    supplier_id             INTEGER         NOT NULL    COMMENT 'FK: Assessed supplier',
    assessment_date         DATE            NOT NULL    COMMENT 'Date of risk evaluation',
    overall_risk_score      NUMBER(5,2)     NOT NULL    COMMENT 'Composite risk (0–100, higher = riskier)',
    financial_risk_score    NUMBER(5,2)                 COMMENT 'Bankruptcy/credit risk component',
    operational_risk_score  NUMBER(5,2)                 COMMENT 'Capacity/quality/delivery risk',
    geopolitical_risk_score NUMBER(5,2)                 COMMENT 'Country/sanctions/conflict risk',
    compliance_risk_score   NUMBER(5,2)                 COMMENT 'Regulatory violation risk',
    concentration_risk_score NUMBER(5,2)                COMMENT 'Single-source dependency risk',
    risk_category           VARCHAR(20)     NOT NULL    COMMENT 'Low, Medium, High, Critical',
    risk_trend              VARCHAR(20)                 COMMENT 'Improving, Stable, Deteriorating',
    mitigation_action       VARCHAR(500)                COMMENT 'Recommended/active mitigation',
    next_review_date        DATE                        COMMENT 'Scheduled re-assessment',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'HIGH',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_supplier_risk       PRIMARY KEY (supplier_id, assessment_date),
    CONSTRAINT fk_sr_supplier         FOREIGN KEY (supplier_id) REFERENCES SUPPLIER (supplier_id)
)
COMMENT = 'Periodic risk evaluations of suppliers covering financial, operational, geopolitical, compliance, and concentration dimensions';


-- -----------------------------------------------------------------------------
-- 19. ESG_SCORE (polymorphic resolved to explicit FKs per approved resolution)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ESG_SCORE (
    esg_score_id            INTEGER         NOT NULL    COMMENT 'Canonical surrogate identifier',
    supplier_id             INTEGER                     COMMENT 'FK: Supplier being scored (NULL if plant-level)',
    plant_id                INTEGER                     COMMENT 'FK: Plant being scored (NULL if supplier-level)',
    scoring_period          DATE            NOT NULL    COMMENT 'Period start date (quarterly)',
    overall_esg_score       NUMBER(5,2)     NOT NULL    COMMENT 'Composite ESG score (0–100, higher = better)',
    environmental_score     NUMBER(5,2)                 COMMENT 'E component',
    social_score            NUMBER(5,2)                 COMMENT 'S component',
    governance_score        NUMBER(5,2)                 COMMENT 'G component',
    carbon_intensity        NUMBER(10,2)                COMMENT 'tCO2e per $M revenue',
    forced_labor_risk       VARCHAR(10)     NOT NULL    DEFAULT 'None' COMMENT 'None, Low, Medium, High',
    controversy_flag        BOOLEAN         NOT NULL    DEFAULT FALSE COMMENT 'Active controversy/incident',
    data_source             VARCHAR(100)                COMMENT 'Scoring provider name',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'HIGH',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_esg_score           PRIMARY KEY (esg_score_id),
    CONSTRAINT fk_esg_supplier        FOREIGN KEY (supplier_id) REFERENCES SUPPLIER (supplier_id),
    CONSTRAINT fk_esg_plant           FOREIGN KEY (plant_id) REFERENCES PLANT (plant_id)
)
COMMENT = 'Periodic ESG assessments of supply chain entities (suppliers and plants). Exactly one of supplier_id or plant_id is non-NULL per row.';


-- =============================================================================
-- BATCH 8: Transaction Tables (FK to Batch 3 + 4)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 20. PURCHASE_ORDER
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS PURCHASE_ORDER (
    order_id                INTEGER         NOT NULL,
    order_number            VARCHAR(30)     NOT NULL    COMMENT 'Business-facing PO number',
    customer_id             INTEGER         NOT NULL    COMMENT 'FK: Buying organization',
    supplier_id             INTEGER         NOT NULL    COMMENT 'FK: Fulfilling supplier',
    order_date              DATE            NOT NULL    COMMENT 'Date order was placed',
    requested_delivery_date DATE                        COMMENT 'Buyer requested delivery',
    order_status            VARCHAR(20)     NOT NULL    DEFAULT 'Open' COMMENT 'Open, Confirmed, In-Transit, Delivered, Closed, Cancelled',
    order_priority          VARCHAR(10)     NOT NULL    DEFAULT 'Normal' COMMENT 'Urgent, High, Normal, Low',
    total_value_usd         NUMBER(15,2)                COMMENT 'Total order value',
    currency_code           CHAR(3)         NOT NULL    DEFAULT 'USD' COMMENT 'Transaction currency',
    payment_terms           VARCHAR(20)                 COMMENT 'Net-30, Net-60, etc.',
    incoterm                VARCHAR(10)                 COMMENT 'FOB, CIF, DDP, EXW',
    channel                 VARCHAR(20)                 COMMENT 'EDI, Direct, Web, Catalog',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'HIGH',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_purchase_order      PRIMARY KEY (order_id),
    CONSTRAINT fk_po_customer         FOREIGN KEY (customer_id) REFERENCES CUSTOMER (customer_id),
    CONSTRAINT fk_po_supplier         FOREIGN KEY (supplier_id) REFERENCES SUPPLIER (supplier_id),
    CONSTRAINT uq_order_number        UNIQUE (order_number)
)
COMMENT = 'Transactional record of formal buying commitments between customers and suppliers';


-- -----------------------------------------------------------------------------
-- 21. ORDER_LINE_ITEM
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ORDER_LINE_ITEM (
    line_item_id            INTEGER         NOT NULL,
    order_id                INTEGER         NOT NULL    COMMENT 'FK: Parent order',
    line_number             INTEGER         NOT NULL    COMMENT 'Sequence within order',
    part_id                 INTEGER         NOT NULL    COMMENT 'FK: Part ordered',
    supplier_id             INTEGER         NOT NULL    COMMENT 'FK: Fulfilling supplier for this line',
    quantity_ordered        NUMBER(12,2)    NOT NULL    COMMENT 'Units ordered',
    unit_price_usd          NUMBER(12,4)    NOT NULL    COMMENT 'Agreed unit price',
    extended_price_usd      NUMBER(15,2)    NOT NULL    COMMENT 'quantity x unit_price',
    discount_percent        NUMBER(5,2)     NOT NULL    DEFAULT 0 COMMENT 'Applied discount percentage',
    tax_percent             NUMBER(5,2)     NOT NULL    DEFAULT 0 COMMENT 'Applicable tax rate',
    promised_ship_date      DATE                        COMMENT 'Supplier committed ship date',
    promised_delivery_date  DATE                        COMMENT 'Contractual delivery date to customer',
    actual_ship_date        DATE                        COMMENT 'Date goods actually shipped',
    actual_receipt_date     DATE                        COMMENT 'Date goods received by customer',
    ship_mode               VARCHAR(20)                 COMMENT 'Air, Ocean, Rail, Truck, Parcel',
    line_status             VARCHAR(20)     NOT NULL    DEFAULT 'Open' COMMENT 'Open, Shipped, Received, Returned, Cancelled',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'HIGH',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_order_line_item     PRIMARY KEY (line_item_id),
    CONSTRAINT fk_oli_order           FOREIGN KEY (order_id) REFERENCES PURCHASE_ORDER (order_id),
    CONSTRAINT fk_oli_part            FOREIGN KEY (part_id) REFERENCES PART (part_id),
    CONSTRAINT fk_oli_supplier        FOREIGN KEY (supplier_id) REFERENCES SUPPLIER (supplier_id),
    CONSTRAINT uq_order_line          UNIQUE (order_id, line_number)
)
COMMENT = 'Line-level detail of purchase orders — each row represents one part/quantity/price commitment';


-- =============================================================================
-- BATCH 9: Execution Tables (FK to Batches 3–8)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 22. SHIPMENT (polymorphic resolved to explicit FKs per approved resolution)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SHIPMENT (
    shipment_id             INTEGER         NOT NULL,
    shipment_reference      VARCHAR(50)                 COMMENT 'External tracking/BOL/AWB number',
    -- Origin (explicit FKs replace polymorphic pattern; at most one is non-NULL)
    origin_supplier_id      INTEGER                     COMMENT 'FK: Origin is a supplier location',
    origin_plant_id         INTEGER                     COMMENT 'FK: Origin is a manufacturing plant',
    origin_warehouse_id     INTEGER                     COMMENT 'FK: Origin is a distribution warehouse',
    -- Destination (explicit FKs; at most one is non-NULL)
    destination_customer_id INTEGER                     COMMENT 'FK: Destination is an end customer',
    destination_plant_id    INTEGER                     COMMENT 'FK: Destination is a plant (materials inbound)',
    destination_warehouse_id INTEGER                    COMMENT 'FK: Destination is a warehouse (replenishment)',
    -- Standard FKs
    carrier_id              INTEGER         NOT NULL    COMMENT 'FK: Transporting carrier',
    route_id                INTEGER                     COMMENT 'FK: Trade lane used (NULL for ad-hoc)',
    ship_mode               VARCHAR(20)     NOT NULL    COMMENT 'Ocean, Air, Truck, Rail, Intermodal, Parcel',
    origin_port_id          INTEGER                     COMMENT 'FK: Port of lading (NULL for domestic)',
    destination_port_id     INTEGER                     COMMENT 'FK: Port of unlading (NULL for domestic)',
    origin_country_id       INTEGER         NOT NULL    COMMENT 'FK: Country of origin',
    destination_country_id  INTEGER         NOT NULL    COMMENT 'FK: Country of destination',
    -- Dates & status
    ship_date               DATE                        COMMENT 'Date goods departed origin',
    estimated_arrival_date  DATE                        COMMENT 'Expected delivery date',
    actual_arrival_date     DATE                        COMMENT 'Confirmed delivery date',
    shipment_status         VARCHAR(20)     NOT NULL    DEFAULT 'Planned' COMMENT 'Planned, In-Transit, At-Port, Customs-Hold, Delivered, Exception',
    -- Measures
    total_weight_kg         NUMBER(12,2)                COMMENT 'Gross weight of shipment',
    total_volume_m3         NUMBER(12,4)                COMMENT 'Cubic volume',
    freight_cost_usd        NUMBER(12,2)                COMMENT 'Transportation cost',
    insurance_cost_usd      NUMBER(10,2)                COMMENT 'Insurance cost',
    duties_usd              NUMBER(10,2)                COMMENT 'Duties and tariffs paid',
    handling_cost_usd       NUMBER(10,2)                COMMENT 'Handling and brokerage',
    transit_days_planned    INTEGER                     COMMENT 'Expected transit time',
    transit_days_actual     INTEGER                     COMMENT 'Actual transit time',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'HIGH',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_shipment                PRIMARY KEY (shipment_id),
    -- Origin explicit FKs
    CONSTRAINT fk_ship_origin_supplier    FOREIGN KEY (origin_supplier_id) REFERENCES SUPPLIER (supplier_id),
    CONSTRAINT fk_ship_origin_plant       FOREIGN KEY (origin_plant_id) REFERENCES PLANT (plant_id),
    CONSTRAINT fk_ship_origin_warehouse   FOREIGN KEY (origin_warehouse_id) REFERENCES WAREHOUSE (warehouse_id),
    -- Destination explicit FKs
    CONSTRAINT fk_ship_dest_customer      FOREIGN KEY (destination_customer_id) REFERENCES CUSTOMER (customer_id),
    CONSTRAINT fk_ship_dest_plant         FOREIGN KEY (destination_plant_id) REFERENCES PLANT (plant_id),
    CONSTRAINT fk_ship_dest_warehouse     FOREIGN KEY (destination_warehouse_id) REFERENCES WAREHOUSE (warehouse_id),
    -- Standard FKs
    CONSTRAINT fk_ship_carrier            FOREIGN KEY (carrier_id) REFERENCES CARRIER (carrier_id),
    CONSTRAINT fk_ship_route              FOREIGN KEY (route_id) REFERENCES ROUTE (route_id),
    CONSTRAINT fk_ship_origin_port        FOREIGN KEY (origin_port_id) REFERENCES PORT (port_id),
    CONSTRAINT fk_ship_dest_port          FOREIGN KEY (destination_port_id) REFERENCES PORT (port_id),
    CONSTRAINT fk_ship_origin_country     FOREIGN KEY (origin_country_id) REFERENCES COUNTRY (country_id),
    CONSTRAINT fk_ship_dest_country       FOREIGN KEY (destination_country_id) REFERENCES COUNTRY (country_id)
)
COMMENT = 'Transactional record of discrete physical goods movements. Origin/destination use explicit nullable FKs (at most one non-NULL per side).';


-- -----------------------------------------------------------------------------
-- 23. SHIPMENT_LINE_ITEM
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SHIPMENT_LINE_ITEM (
    shipment_id             INTEGER         NOT NULL    COMMENT 'FK: Shipment',
    line_item_id            INTEGER         NOT NULL    COMMENT 'FK: Order line being fulfilled',
    quantity_shipped        NUMBER(12,2)    NOT NULL    COMMENT 'Units shipped in this fulfillment',
    package_number          VARCHAR(30)                 COMMENT 'Physical package identifier',
    ship_line_status        VARCHAR(20)     NOT NULL    DEFAULT 'Shipped' COMMENT 'Shipped, In-Transit, Delivered, Returned',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'HIGH',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_shipment_line       PRIMARY KEY (shipment_id, line_item_id),
    CONSTRAINT fk_sli_shipment        FOREIGN KEY (shipment_id) REFERENCES SHIPMENT (shipment_id),
    CONSTRAINT fk_sli_line_item       FOREIGN KEY (line_item_id) REFERENCES ORDER_LINE_ITEM (line_item_id)
)
COMMENT = 'M:N bridge connecting shipments to order line items, recording quantities shipped per fulfillment event';


-- -----------------------------------------------------------------------------
-- 24. INVENTORY_POSITION
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS INVENTORY_POSITION (
    part_id                 INTEGER         NOT NULL    COMMENT 'FK: Part being measured',
    warehouse_id            INTEGER         NOT NULL    COMMENT 'FK: Storage location',
    snapshot_date           DATE            NOT NULL    COMMENT 'Date of measurement',
    quantity_on_hand        NUMBER(12,2)    NOT NULL    COMMENT 'Units physically in stock',
    quantity_reserved       NUMBER(12,2)    NOT NULL    DEFAULT 0 COMMENT 'Units committed to pending orders',
    quantity_available      NUMBER(12,2)    NOT NULL    COMMENT 'on_hand minus reserved',
    quantity_in_transit     NUMBER(12,2)                DEFAULT 0 COMMENT 'Units en route to this location',
    reorder_point           NUMBER(12,2)                COMMENT 'Threshold triggering replenishment',
    safety_stock_level      NUMBER(12,2)                COMMENT 'Minimum buffer quantity',
    -- Audit
    _loaded_at              TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _updated_at             TIMESTAMP_NTZ   NOT NULL    DEFAULT CURRENT_TIMESTAMP(),
    _is_deleted             BOOLEAN         NOT NULL    DEFAULT FALSE,
    _batch_id               VARCHAR(50)     NOT NULL    DEFAULT 'SYNTHETIC_INIT',
    -- Lineage
    _source_system          VARCHAR(100)    NOT NULL    DEFAULT 'SYNTHETIC',
    _source_table           VARCHAR(200),
    _source_key             VARCHAR(500),
    _source_updated_at      TIMESTAMP_NTZ,
    -- Metadata
    _data_quality_score     NUMBER(5,2),
    _confidence_level       VARCHAR(20)                 DEFAULT 'HIGH',
    _version                INTEGER         NOT NULL    DEFAULT 1,

    CONSTRAINT pk_inventory_position  PRIMARY KEY (part_id, warehouse_id, snapshot_date),
    CONSTRAINT fk_inv_part            FOREIGN KEY (part_id) REFERENCES PART (part_id),
    CONSTRAINT fk_inv_warehouse       FOREIGN KEY (warehouse_id) REFERENCES WAREHOUSE (warehouse_id)
)
COMMENT = 'Daily snapshot of stock levels for each part at each warehouse location';


-- =============================================================================
-- VALIDATION: List all created tables and their column counts
-- =============================================================================

-- Query 1: Confirm all 24 tables exist in SCO_SOURCE
SELECT
    TABLE_NAME,
    TABLE_TYPE,
    ROW_COUNT,
    COMMENT
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'SCO_SOURCE'
  AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

-- Query 2: Column inventory per table
SELECT
    TABLE_NAME,
    COUNT(*) AS column_count
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'SCO_SOURCE'
GROUP BY TABLE_NAME
ORDER BY TABLE_NAME;

-- Query 3: Foreign key constraint inventory
SELECT
    TABLE_NAME,
    CONSTRAINT_NAME,
    CONSTRAINT_TYPE
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE TABLE_SCHEMA = 'SCO_SOURCE'
  AND CONSTRAINT_TYPE IN ('PRIMARY KEY', 'FOREIGN KEY', 'UNIQUE')
ORDER BY TABLE_NAME, CONSTRAINT_TYPE, CONSTRAINT_NAME;


-- =============================================================================
-- END OF SCRIPT
-- =============================================================================
