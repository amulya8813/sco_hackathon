--------------------------------------------------------------------------------
-- Supply Chain Ontology — Silver Layer
-- 06_silver_layer.sql
-- Standardized, conformed dimensions and enriched facts sourced only from Bronze.
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
-- Conformed dimensions
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE SLV_DIM_COUNTRY
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Conformed country dimension with standardized ISO, region, sanctions, currency, and risk attributes.'
AS
SELECT
    country_id,
    INITCAP(TRIM(country_name)) AS country_name,
    UPPER(NULLIF(TRIM(iso_alpha2), '')) AS iso_alpha2,
    UPPER(NULLIF(TRIM(iso_alpha3), '')) AS iso_alpha3,
    NULLIF(TRIM(iso_numeric), '') AS iso_numeric,
    INITCAP(NULLIF(TRIM(region_name), '')) AS region_name,
    INITCAP(NULLIF(TRIM(sub_region), '')) AS sub_region,
    UPPER(NULLIF(TRIM(sanctions_status), '')) AS sanctions_status,
    UPPER(NULLIF(TRIM(trade_bloc), '')) AS trade_bloc,
    UPPER(NULLIF(TRIM(currency_code), '')) AS currency_code,
    risk_rating,
    _loaded_at,
    _updated_at,
    _batch_id,
    _source_system,
    _source_table,
    _source_key,
    _source_updated_at,
    _confidence_level,
    _version,
    100 - 20 * (
        IFF(country_id IS NULL, 1, 0)
      + IFF(NULLIF(TRIM(country_name), '') IS NULL, 1, 0)
      + IFF(NULLIF(TRIM(iso_alpha2), '') IS NULL, 1, 0)
      + IFF(NULLIF(TRIM(region_name), '') IS NULL, 1, 0)
      + IFF(NULLIF(TRIM(currency_code), '') IS NULL, 1, 0)
    ) AS _dq_score
FROM SCO_HACKATHON.SCO_BRONZE.BRZ_COUNTRY;

CREATE OR REPLACE DYNAMIC TABLE SLV_DIM_COMMODITY
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Conformed commodity dimension with standardized HS classification and trade/ESG flags.'
AS
SELECT
    commodity_id,
    UPPER(NULLIF(TRIM(hs_code), '')) AS hs_code,
    INITCAP(NULLIF(TRIM(commodity_description), '')) AS commodity_description,
    UPPER(NULLIF(TRIM(hs_section), '')) AS hs_section,
    UPPER(NULLIF(TRIM(hs_chapter), '')) AS hs_chapter,
    INITCAP(NULLIF(TRIM(hs_chapter_description), '')) AS hs_chapter_description,
    esg_risk_flag,
    export_control_flag,
    forced_labor_flag,
    dual_use_flag,
    _loaded_at,
    _updated_at,
    _batch_id,
    _source_system,
    _source_table,
    _source_key,
    _source_updated_at,
    _confidence_level,
    _version,
    100 - 25 * (
        IFF(commodity_id IS NULL, 1, 0)
      + IFF(NULLIF(TRIM(hs_code), '') IS NULL, 1, 0)
      + IFF(NULLIF(TRIM(commodity_description), '') IS NULL, 1, 0)
      + IFF(NULLIF(TRIM(hs_chapter), '') IS NULL, 1, 0)
    ) AS _dq_score
FROM SCO_HACKATHON.SCO_BRONZE.BRZ_COMMODITY;

-- FULL refresh is deliberate: latest risk and ESG records use ROW_NUMBER windows.
CREATE OR REPLACE DYNAMIC TABLE SLV_DIM_SUPPLIER
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = FULL INITIALIZE = ON_CREATE
  COMMENT = 'Conformed supplier dimension enriched with country and latest risk and supplier-level ESG assessments.'
AS
WITH latest_risk AS (
    SELECT
        supplier_id,
        assessment_date,
        overall_risk_score,
        financial_risk_score,
        operational_risk_score,
        geopolitical_risk_score,
        compliance_risk_score,
        concentration_risk_score,
        UPPER(NULLIF(TRIM(risk_category), '')) AS risk_category,
        UPPER(NULLIF(TRIM(risk_trend), '')) AS risk_trend,
        NULLIF(TRIM(mitigation_action), '') AS mitigation_action,
        next_review_date
    FROM SCO_HACKATHON.SCO_BRONZE.BRZ_SUPPLIER_RISK_ASSESSMENT
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY supplier_id ORDER BY assessment_date DESC, _updated_at DESC
    ) = 1
),
latest_esg AS (
    SELECT
        supplier_id,
        esg_score_id,
        scoring_period,
        overall_esg_score,
        environmental_score,
        social_score,
        governance_score,
        carbon_intensity,
        UPPER(NULLIF(TRIM(forced_labor_risk), '')) AS forced_labor_risk,
        controversy_flag,
        INITCAP(NULLIF(TRIM(data_source), '')) AS esg_data_source
    FROM SCO_HACKATHON.SCO_BRONZE.BRZ_ESG_SCORE
    WHERE supplier_id IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY supplier_id ORDER BY scoring_period DESC, esg_score_id DESC
    ) = 1
)
SELECT
    s.supplier_id,
    INITCAP(NULLIF(TRIM(s.supplier_name), '')) AS supplier_name,
    UPPER(NULLIF(TRIM(s.supplier_duns), '')) AS supplier_duns,
    UPPER(NULLIF(TRIM(s.supplier_lei), '')) AS supplier_lei,
    UPPER(NULLIF(TRIM(s.supplier_status), '')) AS supplier_status,
    UPPER(NULLIF(TRIM(s.supplier_tier), '')) AS supplier_tier,
    s.country_id,
    INITCAP(NULLIF(TRIM(s.city), '')) AS city,
    INITCAP(NULLIF(TRIM(s.state_province), '')) AS state_province,
    UPPER(NULLIF(TRIM(s.industry_code), '')) AS industry_code,
    INITCAP(NULLIF(TRIM(s.industry_description), '')) AS industry_description,
    s.year_established,
    s.employee_count,
    s.annual_revenue_usd,
    INITCAP(NULLIF(TRIM(s.primary_contact_name), '')) AS primary_contact_name,
    LOWER(NULLIF(TRIM(s.primary_contact_email), '')) AS primary_contact_email,
    NULLIF(TRIM(s.primary_contact_phone), '') AS primary_contact_phone,
    NULLIF(TRIM(s.website_url), '') AS website_url,
    INITCAP(NULLIF(TRIM(c.country_name), '')) AS country_name,
    UPPER(NULLIF(TRIM(c.iso_alpha2), '')) AS country_iso_alpha2,
    INITCAP(NULLIF(TRIM(c.region_name), '')) AS region_name,
    UPPER(NULLIF(TRIM(c.sanctions_status), '')) AS sanctions_status,
    c.risk_rating AS country_risk_rating,
    r.assessment_date AS latest_risk_assessment_date,
    r.overall_risk_score,
    r.financial_risk_score,
    r.operational_risk_score,
    r.geopolitical_risk_score,
    r.compliance_risk_score,
    r.concentration_risk_score,
    r.risk_category,
    r.risk_trend,
    r.mitigation_action,
    r.next_review_date,
    e.esg_score_id AS latest_esg_score_id,
    e.scoring_period AS latest_esg_scoring_period,
    e.overall_esg_score,
    e.environmental_score,
    e.social_score,
    e.governance_score,
    e.carbon_intensity,
    e.forced_labor_risk,
    e.controversy_flag,
    e.esg_data_source,
    s._loaded_at,
    s._updated_at,
    s._batch_id,
    s._source_system,
    s._source_table,
    s._source_key,
    s._source_updated_at,
    s._confidence_level,
    s._version,
    100 - 20 * (
        IFF(s.supplier_id IS NULL, 1, 0)
      + IFF(NULLIF(TRIM(s.supplier_name), '') IS NULL, 1, 0)
      + IFF(NULLIF(TRIM(s.supplier_status), '') IS NULL, 1, 0)
      + IFF(s.country_id IS NULL, 1, 0)
      + IFF(c.country_id IS NULL, 1, 0)
    ) AS _dq_score
FROM SCO_HACKATHON.SCO_BRONZE.BRZ_SUPPLIER AS s
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_COUNTRY AS c
  ON c.country_id = s.country_id
LEFT JOIN latest_risk AS r
  ON r.supplier_id = s.supplier_id
LEFT JOIN latest_esg AS e
  ON e.supplier_id = s.supplier_id;

CREATE OR REPLACE DYNAMIC TABLE SLV_DIM_CUSTOMER
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Conformed customer dimension enriched with geographic region and standardized service attributes.'
AS
SELECT
    c.customer_id,
    INITCAP(NULLIF(TRIM(c.customer_name), '')) AS customer_name,
    UPPER(NULLIF(TRIM(c.customer_duns), '')) AS customer_duns,
    UPPER(NULLIF(TRIM(c.customer_type), '')) AS customer_type,
    INITCAP(NULLIF(TRIM(c.market_segment), '')) AS market_segment,
    c.country_id,
    INITCAP(NULLIF(TRIM(c.city), '')) AS city,
    INITCAP(NULLIF(TRIM(c.state_province), '')) AS state_province,
    UPPER(NULLIF(TRIM(c.postal_code), '')) AS postal_code,
    c.account_balance_usd,
    UPPER(NULLIF(TRIM(c.credit_status), '')) AS credit_status,
    UPPER(NULLIF(TRIM(c.service_level_tier), '')) AS service_level_tier,
    c.customer_since_date,
    INITCAP(NULLIF(TRIM(c.primary_contact_name), '')) AS primary_contact_name,
    LOWER(NULLIF(TRIM(c.primary_contact_email), '')) AS primary_contact_email,
    INITCAP(NULLIF(TRIM(co.country_name), '')) AS country_name,
    UPPER(NULLIF(TRIM(co.iso_alpha2), '')) AS country_iso_alpha2,
    INITCAP(NULLIF(TRIM(co.region_name), '')) AS customer_region,
    INITCAP(NULLIF(TRIM(co.sub_region), '')) AS customer_sub_region,
    c._loaded_at,
    c._updated_at,
    c._batch_id,
    c._source_system,
    c._source_table,
    c._source_key,
    c._source_updated_at,
    c._confidence_level,
    c._version,
    100 - 20 * (
        IFF(c.customer_id IS NULL, 1, 0)
      + IFF(NULLIF(TRIM(c.customer_name), '') IS NULL, 1, 0)
      + IFF(NULLIF(TRIM(c.service_level_tier), '') IS NULL, 1, 0)
      + IFF(c.country_id IS NULL, 1, 0)
      + IFF(co.country_id IS NULL, 1, 0)
    ) AS _dq_score
FROM SCO_HACKATHON.SCO_BRONZE.BRZ_CUSTOMER AS c
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_COUNTRY AS co
  ON co.country_id = c.country_id;

CREATE OR REPLACE DYNAMIC TABLE SLV_DIM_PART
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Conformed part dimension enriched with commodity classification and compliance flags.'
AS
SELECT
    p.part_id,
    UPPER(NULLIF(TRIM(p.part_number), '')) AS part_number,
    INITCAP(NULLIF(TRIM(p.part_name), '')) AS part_name,
    UPPER(NULLIF(TRIM(p.gtin), '')) AS gtin,
    INITCAP(NULLIF(TRIM(p.manufacturer_name), '')) AS manufacturer_name,
    INITCAP(NULLIF(TRIM(p.brand), '')) AS brand,
    INITCAP(NULLIF(TRIM(p.part_category), '')) AS part_category,
    UPPER(NULLIF(TRIM(p.part_type), '')) AS part_type,
    p.commodity_id,
    UPPER(NULLIF(TRIM(p.unit_of_measure), '')) AS unit_of_measure,
    p.unit_weight_kg,
    p.unit_volume_m3,
    p.standard_cost_usd,
    p.retail_price_usd,
    UPPER(NULLIF(TRIM(p.lifecycle_status), '')) AS lifecycle_status,
    UPPER(NULLIF(TRIM(p.container_type), '')) AS container_type,
    UPPER(NULLIF(TRIM(c.hs_code), '')) AS hs_code,
    INITCAP(NULLIF(TRIM(c.commodity_description), '')) AS commodity_description,
    UPPER(NULLIF(TRIM(c.hs_section), '')) AS hs_section,
    UPPER(NULLIF(TRIM(c.hs_chapter), '')) AS hs_chapter,
    c.esg_risk_flag,
    c.export_control_flag,
    c.forced_labor_flag,
    c.dual_use_flag,
    p._loaded_at,
    p._updated_at,
    p._batch_id,
    p._source_system,
    p._source_table,
    p._source_key,
    p._source_updated_at,
    p._confidence_level,
    p._version,
    100 - 20 * (
        IFF(p.part_id IS NULL, 1, 0)
      + IFF(NULLIF(TRIM(p.part_number), '') IS NULL, 1, 0)
      + IFF(NULLIF(TRIM(p.part_name), '') IS NULL, 1, 0)
      + IFF(p.commodity_id IS NULL, 1, 0)
      + IFF(c.commodity_id IS NULL, 1, 0)
    ) AS _dq_score
FROM SCO_HACKATHON.SCO_BRONZE.BRZ_PART AS p
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_COMMODITY AS c
  ON c.commodity_id = p.commodity_id;

CREATE OR REPLACE DYNAMIC TABLE SLV_DIM_WAREHOUSE
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Conformed warehouse dimension enriched with country and regional attributes.'
AS
SELECT
    w.warehouse_id,
    INITCAP(NULLIF(TRIM(w.warehouse_name), '')) AS warehouse_name,
    UPPER(NULLIF(TRIM(w.warehouse_code), '')) AS warehouse_code,
    UPPER(NULLIF(TRIM(w.warehouse_type), '')) AS warehouse_type,
    w.country_id,
    INITCAP(NULLIF(TRIM(w.city), '')) AS city,
    INITCAP(NULLIF(TRIM(w.state_province), '')) AS state_province,
    NULLIF(TRIM(w.address), '') AS address,
    w.capacity_sqft,
    UPPER(NULLIF(TRIM(w.operational_status), '')) AS operational_status,
    INITCAP(NULLIF(TRIM(c.country_name), '')) AS country_name,
    UPPER(NULLIF(TRIM(c.iso_alpha2), '')) AS country_iso_alpha2,
    INITCAP(NULLIF(TRIM(c.region_name), '')) AS region_name,
    w._loaded_at,
    w._updated_at,
    w._batch_id,
    w._source_system,
    w._source_table,
    w._source_key,
    w._source_updated_at,
    w._confidence_level,
    w._version,
    100 - 25 * (
        IFF(w.warehouse_id IS NULL, 1, 0)
      + IFF(NULLIF(TRIM(w.warehouse_name), '') IS NULL, 1, 0)
      + IFF(w.country_id IS NULL, 1, 0)
      + IFF(c.country_id IS NULL, 1, 0)
    ) AS _dq_score
FROM SCO_HACKATHON.SCO_BRONZE.BRZ_WAREHOUSE AS w
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_COUNTRY AS c
  ON c.country_id = w.country_id;

CREATE OR REPLACE DYNAMIC TABLE SLV_DIM_CARRIER
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Conformed carrier dimension enriched with geography and standardized mode and contract attributes.'
AS
SELECT
    ca.carrier_id,
    INITCAP(NULLIF(TRIM(ca.carrier_name), '')) AS carrier_name,
    UPPER(NULLIF(TRIM(ca.carrier_code), '')) AS carrier_code,
    UPPER(NULLIF(TRIM(ca.carrier_type), '')) AS carrier_type,
    UPPER(NULLIF(TRIM(ca.primary_mode), '')) AS primary_mode,
    ca.country_id,
    UPPER(NULLIF(TRIM(ca.contract_status), '')) AS contract_status,
    ca.on_time_rate_pct,
    ca.damage_rate_pct,
    INITCAP(NULLIF(TRIM(c.country_name), '')) AS country_name,
    UPPER(NULLIF(TRIM(c.iso_alpha2), '')) AS country_iso_alpha2,
    INITCAP(NULLIF(TRIM(c.region_name), '')) AS region_name,
    ca._loaded_at,
    ca._updated_at,
    ca._batch_id,
    ca._source_system,
    ca._source_table,
    ca._source_key,
    ca._source_updated_at,
    ca._confidence_level,
    ca._version,
    100 - 25 * (
        IFF(ca.carrier_id IS NULL, 1, 0)
      + IFF(NULLIF(TRIM(ca.carrier_name), '') IS NULL, 1, 0)
      + IFF(ca.country_id IS NULL, 1, 0)
      + IFF(c.country_id IS NULL, 1, 0)
    ) AS _dq_score
FROM SCO_HACKATHON.SCO_BRONZE.BRZ_CARRIER AS ca
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_COUNTRY AS c
  ON c.country_id = ca.country_id;

CREATE OR REPLACE DYNAMIC TABLE SLV_DIM_ROUTE
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Conformed route dimension enriched with origin/destination ports and countries.'
AS
SELECT
    r.route_id,
    INITCAP(NULLIF(TRIM(r.route_name), '')) AS route_name,
    r.origin_port_id,
    INITCAP(NULLIF(TRIM(op.port_name), '')) AS origin_port_name,
    UPPER(NULLIF(TRIM(op.un_locode), '')) AS origin_port_un_locode,
    UPPER(NULLIF(TRIM(op.congestion_status), '')) AS origin_port_congestion_status,
    op.avg_dwell_days AS origin_port_avg_dwell_days,
    r.destination_port_id,
    INITCAP(NULLIF(TRIM(dp.port_name), '')) AS destination_port_name,
    UPPER(NULLIF(TRIM(dp.un_locode), '')) AS destination_port_un_locode,
    UPPER(NULLIF(TRIM(dp.congestion_status), '')) AS destination_port_congestion_status,
    dp.avg_dwell_days AS destination_port_avg_dwell_days,
    r.origin_country_id,
    INITCAP(NULLIF(TRIM(oc.country_name), '')) AS origin_country_name,
    UPPER(NULLIF(TRIM(oc.iso_alpha2), '')) AS origin_country_iso_alpha2,
    INITCAP(NULLIF(TRIM(oc.region_name), '')) AS origin_region_name,
    r.destination_country_id,
    INITCAP(NULLIF(TRIM(dc.country_name), '')) AS destination_country_name,
    UPPER(NULLIF(TRIM(dc.iso_alpha2), '')) AS destination_country_iso_alpha2,
    INITCAP(NULLIF(TRIM(dc.region_name), '')) AS destination_region_name,
    UPPER(NULLIF(TRIM(r.primary_mode), '')) AS primary_mode,
    r.distance_km,
    r.avg_transit_days,
    r.avg_cost_per_kg_usd,
    r.reliability_pct,
    r.active_carriers_count,
    r._loaded_at,
    r._updated_at,
    r._batch_id,
    r._source_system,
    r._source_table,
    r._source_key,
    r._source_updated_at,
    r._confidence_level,
    r._version,
    100 - 12.5 * (
        IFF(r.route_id IS NULL, 1, 0)
      + IFF(r.origin_port_id IS NULL, 1, 0)
      + IFF(op.port_id IS NULL, 1, 0)
      + IFF(r.destination_port_id IS NULL, 1, 0)
      + IFF(dp.port_id IS NULL, 1, 0)
      + IFF(r.origin_country_id IS NULL, 1, 0)
      + IFF(r.destination_country_id IS NULL, 1, 0)
      + IFF(NULLIF(TRIM(r.primary_mode), '') IS NULL, 1, 0)
    ) AS _dq_score
FROM SCO_HACKATHON.SCO_BRONZE.BRZ_ROUTE AS r
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_PORT AS op
  ON op.port_id = r.origin_port_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_PORT AS dp
  ON dp.port_id = r.destination_port_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_COUNTRY AS oc
  ON oc.country_id = r.origin_country_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_COUNTRY AS dc
  ON dc.country_id = r.destination_country_id;

CREATE OR REPLACE DYNAMIC TABLE SLV_DIM_PLANT
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Conformed plant dimension enriched with owning supplier and country.'
AS
SELECT
    p.plant_id,
    INITCAP(NULLIF(TRIM(p.plant_name), '')) AS plant_name,
    UPPER(NULLIF(TRIM(p.plant_code), '')) AS plant_code,
    p.supplier_id,
    INITCAP(NULLIF(TRIM(s.supplier_name), '')) AS supplier_name,
    p.country_id,
    INITCAP(NULLIF(TRIM(c.country_name), '')) AS country_name,
    UPPER(NULLIF(TRIM(c.iso_alpha2), '')) AS country_iso_alpha2,
    INITCAP(NULLIF(TRIM(c.region_name), '')) AS region_name,
    INITCAP(NULLIF(TRIM(p.city), '')) AS city,
    INITCAP(NULLIF(TRIM(p.state_province), '')) AS state_province,
    UPPER(NULLIF(TRIM(p.plant_type), '')) AS plant_type,
    p.capacity_units_per_day,
    UPPER(NULLIF(TRIM(p.operational_status), '')) AS operational_status,
    p.year_commissioned,
    NULLIF(TRIM(p.certifications), '') AS certifications,
    p._loaded_at,
    p._updated_at,
    p._batch_id,
    p._source_system,
    p._source_table,
    p._source_key,
    p._source_updated_at,
    p._confidence_level,
    p._version,
    100 - 20 * (
        IFF(p.plant_id IS NULL, 1, 0)
      + IFF(NULLIF(TRIM(p.plant_name), '') IS NULL, 1, 0)
      + IFF(p.supplier_id IS NULL, 1, 0)
      + IFF(s.supplier_id IS NULL, 1, 0)
      + IFF(c.country_id IS NULL, 1, 0)
    ) AS _dq_score
FROM SCO_HACKATHON.SCO_BRONZE.BRZ_PLANT AS p
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_SUPPLIER AS s
  ON s.supplier_id = p.supplier_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_COUNTRY AS c
  ON c.country_id = p.country_id;

-- Regular TABLE by necessity: Snowflake rejects a dynamic table with no base
-- table, and this calendar comes purely from GENERATOR. Static reference data
-- with no upstream, so there is nothing for a refresh to track.
CREATE OR REPLACE TABLE SLV_DIM_DATE
  COMMENT = 'Generated Gregorian and fiscal date dimension covering every day from 2024-01-01 through 2025-12-31.'
AS
WITH dates AS (
    SELECT DATEADD(
        'day',
        ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1,
        TO_DATE('2024-01-01')
    )::DATE AS date_day
    FROM TABLE(GENERATOR(ROWCOUNT => 731))
)
SELECT
    date_day,
    DAY(date_day) AS day_of_month,
    DAYOFWEEKISO(date_day) AS day_of_week_iso,
    DAYNAME(date_day) AS day_name,
    WEEKISO(date_day) AS week_of_year_iso,
    DATE_TRUNC('week', date_day)::DATE AS week_start_date,
    MONTH(date_day) AS month_number,
    MONTHNAME(date_day) AS month_name,
    DATE_TRUNC('month', date_day)::DATE AS month_start_date,
    QUARTER(date_day) AS quarter_number,
    DATE_TRUNC('quarter', date_day)::DATE AS quarter_start_date,
    YEAR(date_day) AS calendar_year,
    IFF(DAYOFWEEKISO(date_day) IN (6, 7), TRUE, FALSE) AS is_weekend,
    IFF(DAYOFWEEKISO(date_day) IN (6, 7), FALSE, TRUE) AS is_business_day,
    YEAR(DATEADD('month', 6, date_day)) AS fiscal_year,
    QUARTER(DATEADD('month', 6, date_day)) AS fiscal_quarter,
    MONTH(DATEADD('month', 6, date_day)) AS fiscal_month,
    100 AS _dq_score
FROM dates;

-- =============================================================================
-- Conformed transactional facts
-- =============================================================================

-- FULL refresh is deliberate because CURRENT_DATE drives due/open OTD state.
CREATE OR REPLACE DYNAMIC TABLE SLV_FACT_ORDER_LINE
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = FULL INITIALIZE = ON_CREATE
  COMMENT = 'Order-line fact with parent order context and governed delivery-timeliness flags.'
AS
WITH order_line_enriched AS (
SELECT
    l.line_item_id,
    l.order_id,
    l.line_number,
    UPPER(NULLIF(TRIM(o.order_number), '')) AS order_number,
    o.order_date,
    DATE_TRUNC('month', o.order_date)::DATE AS order_month_start_date,
    YEAR(o.order_date) AS order_year,
    MONTH(o.order_date) AS order_month,
    QUARTER(o.order_date) AS order_quarter,
    o.requested_delivery_date,
    UPPER(NULLIF(TRIM(o.order_status), '')) AS order_status,
    UPPER(NULLIF(TRIM(o.order_priority), '')) AS order_priority,
    o.total_value_usd AS order_total_value_usd,
    UPPER(NULLIF(TRIM(o.currency_code), '')) AS currency_code,
    UPPER(NULLIF(TRIM(o.payment_terms), '')) AS payment_terms,
    UPPER(NULLIF(TRIM(o.incoterm), '')) AS incoterm,
    UPPER(NULLIF(TRIM(o.channel), '')) AS channel,
    o.customer_id,
    INITCAP(NULLIF(TRIM(c.customer_name), '')) AS customer_name,
    UPPER(NULLIF(TRIM(c.service_level_tier), '')) AS customer_service_tier,
    INITCAP(NULLIF(TRIM(cc.region_name), '')) AS customer_region,
    o.supplier_id AS order_supplier_id,
    l.supplier_id AS line_supplier_id,
    INITCAP(NULLIF(TRIM(s.supplier_name), '')) AS supplier_name,
    UPPER(NULLIF(TRIM(s.supplier_tier), '')) AS supplier_tier,
    l.part_id,
    UPPER(NULLIF(TRIM(p.part_number), '')) AS part_number,
    INITCAP(NULLIF(TRIM(p.part_name), '')) AS part_name,
    INITCAP(NULLIF(TRIM(p.part_category), '')) AS part_category,
    UPPER(NULLIF(TRIM(p.part_type), '')) AS part_type,
    p.commodity_id,
    l.quantity_ordered,
    l.unit_price_usd,
    l.extended_price_usd,
    l.discount_percent,
    l.tax_percent,
    l.promised_ship_date,
    l.promised_delivery_date,
    DATE_TRUNC('month', l.promised_delivery_date)::DATE AS promised_month_start_date,
    YEAR(l.promised_delivery_date) AS promised_year,
    MONTH(l.promised_delivery_date) AS promised_month,
    QUARTER(l.promised_delivery_date) AS promised_quarter,
    l.actual_ship_date,
    l.actual_receipt_date,
    UPPER(NULLIF(TRIM(l.ship_mode), '')) AS ship_mode,
    UPPER(NULLIF(TRIM(l.line_status), '')) AS line_status,
    IFF(
        l.actual_receipt_date IS NULL OR l.promised_delivery_date IS NULL,
        NULL,
        GREATEST(DATEDIFF('day', l.promised_delivery_date, l.actual_receipt_date), 0)
    ) AS days_late,
    IFF(
        l.actual_receipt_date IS NOT NULL
        AND l.promised_delivery_date IS NOT NULL
        AND l.actual_receipt_date <= l.promised_delivery_date,
        TRUE,
        FALSE
    ) AS on_time_flag,
    DATEDIFF('day', o.order_date, l.promised_delivery_date) AS promised_order_cycle_days,
    DATEDIFF('day', l.actual_ship_date, l.actual_receipt_date) AS actual_transit_days,
    l._loaded_at,
    l._updated_at,
    l._batch_id,
    l._source_system,
    l._source_table,
    l._source_key,
    l._source_updated_at,
    l._confidence_level,
    l._version,
    100 - (100 / 7.0) * (
        IFF(l.line_item_id IS NULL, 1, 0)
      + IFF(l.order_id IS NULL, 1, 0)
      + IFF(o.order_id IS NULL, 1, 0)
      + IFF(l.part_id IS NULL, 1, 0)
      + IFF(l.supplier_id IS NULL, 1, 0)
      + IFF(l.quantity_ordered IS NULL, 1, 0)
      + IFF(l.promised_delivery_date IS NULL, 1, 0)
    ) AS _dq_score
FROM SCO_HACKATHON.SCO_BRONZE.BRZ_ORDER_LINE_ITEM AS l
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_PURCHASE_ORDER AS o
  ON o.order_id = l.order_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_CUSTOMER AS c
  ON c.customer_id = o.customer_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_COUNTRY AS cc
  ON cc.country_id = c.country_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_SUPPLIER AS s
  ON s.supplier_id = l.supplier_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_PART AS p
  ON p.part_id = l.part_id
)
SELECT
    e.*,
    TRUE AS is_due_flag,
    IFF(e.order_status = 'CANCELLED', TRUE, FALSE) AS is_excluded_flag
FROM order_line_enriched AS e
WHERE e.promised_delivery_date <= CURRENT_DATE()
UNION ALL
SELECT
    e.*,
    FALSE AS is_due_flag,
    TRUE AS is_excluded_flag
FROM order_line_enriched AS e
WHERE e.promised_delivery_date > CURRENT_DATE()
UNION ALL
SELECT
    e.*,
    FALSE AS is_due_flag,
    TRUE AS is_excluded_flag
FROM order_line_enriched AS e
WHERE e.promised_delivery_date IS NULL;

CREATE OR REPLACE DYNAMIC TABLE SLV_FACT_SHIPMENT
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Shipment fact with standardized logistics attributes and resolved polymorphic origin and destination names.'
AS
SELECT
    sh.shipment_id,
    UPPER(NULLIF(TRIM(sh.shipment_reference), '')) AS shipment_reference,
    sh.origin_supplier_id,
    sh.origin_plant_id,
    sh.origin_warehouse_id,
    CASE
        WHEN sh.origin_supplier_id IS NOT NULL THEN 'SUPPLIER'
        WHEN sh.origin_plant_id IS NOT NULL THEN 'PLANT'
        WHEN sh.origin_warehouse_id IS NOT NULL THEN 'WAREHOUSE'
        ELSE 'UNKNOWN'
    END AS origin_type,
    COALESCE(
        INITCAP(NULLIF(TRIM(os.supplier_name), '')),
        INITCAP(NULLIF(TRIM(op.plant_name), '')),
        INITCAP(NULLIF(TRIM(ow.warehouse_name), ''))
    ) AS origin_name,
    sh.destination_customer_id,
    sh.destination_plant_id,
    sh.destination_warehouse_id,
    CASE
        WHEN sh.destination_customer_id IS NOT NULL THEN 'CUSTOMER'
        WHEN sh.destination_plant_id IS NOT NULL THEN 'PLANT'
        WHEN sh.destination_warehouse_id IS NOT NULL THEN 'WAREHOUSE'
        ELSE 'UNKNOWN'
    END AS destination_type,
    COALESCE(
        INITCAP(NULLIF(TRIM(dc.customer_name), '')),
        INITCAP(NULLIF(TRIM(dp.plant_name), '')),
        INITCAP(NULLIF(TRIM(dw.warehouse_name), ''))
    ) AS destination_name,
    sh.carrier_id,
    INITCAP(NULLIF(TRIM(ca.carrier_name), '')) AS carrier_name,
    sh.route_id,
    INITCAP(NULLIF(TRIM(r.route_name), '')) AS route_name,
    UPPER(NULLIF(TRIM(sh.ship_mode), '')) AS ship_mode,
    sh.origin_port_id,
    INITCAP(NULLIF(TRIM(oport.port_name), '')) AS origin_port_name,
    sh.destination_port_id,
    INITCAP(NULLIF(TRIM(dport.port_name), '')) AS destination_port_name,
    sh.origin_country_id,
    INITCAP(NULLIF(TRIM(oc.country_name), '')) AS origin_country_name,
    INITCAP(NULLIF(TRIM(oc.region_name), '')) AS origin_region_name,
    sh.destination_country_id,
    INITCAP(NULLIF(TRIM(dco.country_name), '')) AS destination_country_name,
    INITCAP(NULLIF(TRIM(dco.region_name), '')) AS destination_region_name,
    sh.ship_date,
    DATE_TRUNC('month', sh.ship_date)::DATE AS ship_month_start_date,
    YEAR(sh.ship_date) AS ship_year,
    MONTH(sh.ship_date) AS ship_month,
    QUARTER(sh.ship_date) AS ship_quarter,
    sh.estimated_arrival_date,
    sh.actual_arrival_date,
    UPPER(NULLIF(TRIM(sh.shipment_status), '')) AS shipment_status,
    sh.total_weight_kg,
    sh.total_volume_m3,
    sh.freight_cost_usd,
    sh.insurance_cost_usd,
    sh.duties_usd,
    sh.handling_cost_usd,
    sh.transit_days_planned,
    sh.transit_days_actual,
    sh.transit_days_actual - sh.transit_days_planned AS transit_variance_days,
    IFF(
        sh.actual_arrival_date IS NOT NULL
        AND sh.estimated_arrival_date IS NOT NULL
        AND sh.actual_arrival_date <= sh.estimated_arrival_date,
        TRUE,
        FALSE
    ) AS on_time_arrival_flag,
    sh._loaded_at,
    sh._updated_at,
    sh._batch_id,
    sh._source_system,
    sh._source_table,
    sh._source_key,
    sh._source_updated_at,
    sh._confidence_level,
    sh._version,
    100 - 10 * (
        IFF(sh.shipment_id IS NULL, 1, 0)
      + IFF(sh.carrier_id IS NULL, 1, 0)
      + IFF(ca.carrier_id IS NULL, 1, 0)
      + IFF(sh.origin_country_id IS NULL, 1, 0)
      + IFF(sh.destination_country_id IS NULL, 1, 0)
      + IFF(sh.ship_date IS NULL, 1, 0)
      + IFF(NULLIF(TRIM(sh.shipment_status), '') IS NULL, 1, 0)
      + IFF(sh.origin_supplier_id IS NULL AND sh.origin_plant_id IS NULL AND sh.origin_warehouse_id IS NULL, 1, 0)
      + IFF(sh.destination_customer_id IS NULL AND sh.destination_plant_id IS NULL AND sh.destination_warehouse_id IS NULL, 1, 0)
      + IFF(sh.route_id IS NOT NULL AND r.route_id IS NULL, 1, 0)
    ) AS _dq_score
FROM SCO_HACKATHON.SCO_BRONZE.BRZ_SHIPMENT AS sh
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_SUPPLIER AS os
  ON os.supplier_id = sh.origin_supplier_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_PLANT AS op
  ON op.plant_id = sh.origin_plant_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_WAREHOUSE AS ow
  ON ow.warehouse_id = sh.origin_warehouse_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_CUSTOMER AS dc
  ON dc.customer_id = sh.destination_customer_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_PLANT AS dp
  ON dp.plant_id = sh.destination_plant_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_WAREHOUSE AS dw
  ON dw.warehouse_id = sh.destination_warehouse_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_CARRIER AS ca
  ON ca.carrier_id = sh.carrier_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_ROUTE AS r
  ON r.route_id = sh.route_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_PORT AS oport
  ON oport.port_id = sh.origin_port_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_PORT AS dport
  ON dport.port_id = sh.destination_port_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_COUNTRY AS oc
  ON oc.country_id = sh.origin_country_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_COUNTRY AS dco
  ON dco.country_id = sh.destination_country_id;

-- FULL refresh is deliberate because shipment total units use a partitioned window.
CREATE OR REPLACE DYNAMIC TABLE SLV_FACT_SHIPMENT_LINE
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = FULL INITIALIZE = ON_CREATE
  COMMENT = 'Shipment-line bridge enriched with order, part, supplier, warehouse, route, and allocable shipment-cost context.'
AS
WITH shipment_lines AS (
    SELECT
        sli.*,
        SUM(sli.quantity_shipped) OVER (PARTITION BY sli.shipment_id) AS shipment_total_units
    FROM SCO_HACKATHON.SCO_BRONZE.BRZ_SHIPMENT_LINE_ITEM AS sli
)
SELECT
    sl.shipment_id,
    sl.line_item_id,
    sl.quantity_shipped,
    sl.shipment_total_units,
    UPPER(NULLIF(TRIM(sl.package_number), '')) AS package_number,
    UPPER(NULLIF(TRIM(sl.ship_line_status), '')) AS ship_line_status,
    sh.ship_date,
    DATE_TRUNC('month', sh.ship_date)::DATE AS ship_month_start_date,
    sh.estimated_arrival_date,
    sh.actual_arrival_date,
    UPPER(NULLIF(TRIM(sh.shipment_status), '')) AS shipment_status,
    sh.origin_supplier_id,
    sh.origin_plant_id,
    sh.origin_warehouse_id,
    sh.destination_customer_id,
    sh.destination_plant_id,
    sh.destination_warehouse_id,
    sh.carrier_id,
    sh.route_id,
    sh.freight_cost_usd,
    sh.insurance_cost_usd,
    sh.duties_usd,
    sh.handling_cost_usd,
    l.order_id,
    o.order_date,
    o.customer_id,
    l.supplier_id,
    l.part_id,
    l.quantity_ordered,
    l.unit_price_usd,
    l.extended_price_usd,
    INITCAP(NULLIF(TRIM(p.part_category), '')) AS part_category,
    UPPER(NULLIF(TRIM(p.unit_of_measure), '')) AS unit_of_measure,
    sc.supply_cost_usd,
    IFF(
        sl.shipment_total_units IS NULL OR sl.shipment_total_units = 0,
        NULL,
        sh.freight_cost_usd * sl.quantity_shipped / sl.shipment_total_units
    ) AS allocated_freight_cost_usd,
    IFF(
        sl.shipment_total_units IS NULL OR sl.shipment_total_units = 0,
        NULL,
        sh.insurance_cost_usd * sl.quantity_shipped / sl.shipment_total_units
    ) AS allocated_insurance_cost_usd,
    IFF(
        sl.shipment_total_units IS NULL OR sl.shipment_total_units = 0,
        NULL,
        sh.duties_usd * sl.quantity_shipped / sl.shipment_total_units
    ) AS allocated_duties_usd,
    IFF(
        sl.shipment_total_units IS NULL OR sl.shipment_total_units = 0,
        NULL,
        sh.handling_cost_usd * sl.quantity_shipped / sl.shipment_total_units
    ) AS allocated_handling_cost_usd,
    sl._loaded_at,
    sl._updated_at,
    sl._batch_id,
    sl._source_system,
    sl._source_table,
    sl._source_key,
    sl._source_updated_at,
    sl._confidence_level,
    sl._version,
    100 - (100 / 8.0) * (
        IFF(sl.shipment_id IS NULL, 1, 0)
      + IFF(sh.shipment_id IS NULL, 1, 0)
      + IFF(sl.line_item_id IS NULL, 1, 0)
      + IFF(l.line_item_id IS NULL, 1, 0)
      + IFF(sl.quantity_shipped IS NULL, 1, 0)
      + IFF(l.part_id IS NULL, 1, 0)
      + IFF(l.supplier_id IS NULL, 1, 0)
      + IFF(sl.shipment_total_units IS NULL OR sl.shipment_total_units = 0, 1, 0)
    ) AS _dq_score
FROM shipment_lines AS sl
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_SHIPMENT AS sh
  ON sh.shipment_id = sl.shipment_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_ORDER_LINE_ITEM AS l
  ON l.line_item_id = sl.line_item_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_PURCHASE_ORDER AS o
  ON o.order_id = l.order_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_PART AS p
  ON p.part_id = l.part_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_SUPPLIER_CATALOG AS sc
  ON sc.supplier_id = l.supplier_id
 AND sc.part_id = l.part_id;

CREATE OR REPLACE DYNAMIC TABLE SLV_FACT_INVENTORY
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Inventory snapshot fact enriched with part, warehouse, safety-stock, and stockout indicators.'
AS
SELECT
    i.part_id,
    UPPER(NULLIF(TRIM(p.part_number), '')) AS part_number,
    INITCAP(NULLIF(TRIM(p.part_name), '')) AS part_name,
    INITCAP(NULLIF(TRIM(p.part_category), '')) AS part_category,
    p.standard_cost_usd,
    i.warehouse_id,
    INITCAP(NULLIF(TRIM(w.warehouse_name), '')) AS warehouse_name,
    UPPER(NULLIF(TRIM(w.warehouse_code), '')) AS warehouse_code,
    i.snapshot_date,
    YEAR(i.snapshot_date) AS snapshot_year,
    MONTH(i.snapshot_date) AS snapshot_month,
    QUARTER(i.snapshot_date) AS snapshot_quarter,
    DATE_TRUNC('month', i.snapshot_date)::DATE AS snapshot_month_start_date,
    i.quantity_on_hand,
    i.quantity_reserved,
    i.quantity_available,
    i.quantity_in_transit,
    i.reorder_point,
    i.safety_stock_level,
    IFF(i.safety_stock_level IS NOT NULL AND i.quantity_on_hand < i.safety_stock_level, TRUE, FALSE) AS below_safety_stock_flag,
    IFF(i.quantity_available <= 0, TRUE, FALSE) AS stockout_flag,
    IFF(i.reorder_point IS NOT NULL AND i.quantity_on_hand < i.reorder_point, TRUE, FALSE) AS below_reorder_flag,
    i._loaded_at,
    i._updated_at,
    i._batch_id,
    i._source_system,
    i._source_table,
    i._source_key,
    i._source_updated_at,
    i._confidence_level,
    i._version,
    100 - (100 / 7.0) * (
        IFF(i.part_id IS NULL, 1, 0)
      + IFF(p.part_id IS NULL, 1, 0)
      + IFF(i.warehouse_id IS NULL, 1, 0)
      + IFF(w.warehouse_id IS NULL, 1, 0)
      + IFF(i.snapshot_date IS NULL, 1, 0)
      + IFF(i.quantity_on_hand IS NULL, 1, 0)
      + IFF(i.quantity_available IS NULL, 1, 0)
    ) AS _dq_score
FROM SCO_HACKATHON.SCO_BRONZE.BRZ_INVENTORY_POSITION AS i
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_PART AS p
  ON p.part_id = i.part_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_WAREHOUSE AS w
  ON w.warehouse_id = i.warehouse_id;

CREATE OR REPLACE DYNAMIC TABLE SLV_FACT_SUPPLIER_RISK
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Supplier risk assessment history with standardized categories and monthly date attributes.'
AS
SELECT
    r.supplier_id,
    INITCAP(NULLIF(TRIM(s.supplier_name), '')) AS supplier_name,
    UPPER(NULLIF(TRIM(s.supplier_tier), '')) AS supplier_tier,
    r.assessment_date,
    DATE_TRUNC('month', r.assessment_date)::DATE AS assessment_month_start_date,
    YEAR(r.assessment_date) AS assessment_year,
    MONTH(r.assessment_date) AS assessment_month,
    QUARTER(r.assessment_date) AS assessment_quarter,
    r.overall_risk_score,
    r.financial_risk_score,
    r.operational_risk_score,
    r.geopolitical_risk_score,
    r.compliance_risk_score,
    r.concentration_risk_score,
    UPPER(NULLIF(TRIM(r.risk_category), '')) AS risk_category,
    UPPER(NULLIF(TRIM(r.risk_trend), '')) AS risk_trend,
    NULLIF(TRIM(r.mitigation_action), '') AS mitigation_action,
    r.next_review_date,
    r._loaded_at,
    r._updated_at,
    r._batch_id,
    r._source_system,
    r._source_table,
    r._source_key,
    r._source_updated_at,
    r._confidence_level,
    r._version,
    100 - 25 * (
        IFF(r.supplier_id IS NULL, 1, 0)
      + IFF(s.supplier_id IS NULL, 1, 0)
      + IFF(r.assessment_date IS NULL, 1, 0)
      + IFF(r.overall_risk_score IS NULL, 1, 0)
    ) AS _dq_score
FROM SCO_HACKATHON.SCO_BRONZE.BRZ_SUPPLIER_RISK_ASSESSMENT AS r
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_SUPPLIER AS s
  ON s.supplier_id = r.supplier_id;

CREATE OR REPLACE DYNAMIC TABLE SLV_FACT_ESG
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Supplier and plant ESG score history with standardized risk values and monthly date attributes.'
AS
SELECT
    e.esg_score_id,
    e.supplier_id,
    INITCAP(NULLIF(TRIM(s.supplier_name), '')) AS supplier_name,
    e.plant_id,
    INITCAP(NULLIF(TRIM(p.plant_name), '')) AS plant_name,
    e.scoring_period,
    DATE_TRUNC('month', e.scoring_period)::DATE AS scoring_month_start_date,
    YEAR(e.scoring_period) AS scoring_year,
    MONTH(e.scoring_period) AS scoring_month,
    QUARTER(e.scoring_period) AS scoring_quarter,
    e.overall_esg_score,
    e.environmental_score,
    e.social_score,
    e.governance_score,
    e.carbon_intensity,
    UPPER(NULLIF(TRIM(e.forced_labor_risk), '')) AS forced_labor_risk,
    e.controversy_flag,
    INITCAP(NULLIF(TRIM(e.data_source), '')) AS data_source,
    e._loaded_at,
    e._updated_at,
    e._batch_id,
    e._source_system,
    e._source_table,
    e._source_key,
    e._source_updated_at,
    e._confidence_level,
    e._version,
    100 - 20 * (
        IFF(e.esg_score_id IS NULL, 1, 0)
      + IFF(e.supplier_id IS NULL AND e.plant_id IS NULL, 1, 0)
      + IFF(e.scoring_period IS NULL, 1, 0)
      + IFF(e.overall_esg_score IS NULL, 1, 0)
      + IFF(NULLIF(TRIM(e.forced_labor_risk), '') IS NULL, 1, 0)
    ) AS _dq_score
FROM SCO_HACKATHON.SCO_BRONZE.BRZ_ESG_SCORE AS e
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_SUPPLIER AS s
  ON s.supplier_id = e.supplier_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_PLANT AS p
  ON p.plant_id = e.plant_id;

-- =============================================================================
-- Supporting conformed facts for Gold risk, compliance, and sourcing analysis
-- =============================================================================

-- FULL refresh is deliberate because qualified-source counts use a window.
CREATE OR REPLACE DYNAMIC TABLE SLV_BRIDGE_SUPPLIER_PART
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = FULL INITIALIZE = ON_CREATE
  COMMENT = 'Conformed supplier-part sourcing bridge with source-count context for sole-source exposure.'
AS
SELECT
    sc.supplier_id,
    INITCAP(NULLIF(TRIM(s.supplier_name), '')) AS supplier_name,
    sc.part_id,
    UPPER(NULLIF(TRIM(p.part_number), '')) AS part_number,
    INITCAP(NULLIF(TRIM(p.part_name), '')) AS part_name,
    INITCAP(NULLIF(TRIM(p.part_category), '')) AS part_category,
    sc.supply_cost_usd,
    sc.lead_time_days,
    sc.available_quantity,
    sc.minimum_order_quantity,
    sc.preferred_flag,
    sc.last_quoted_date,
    UPPER(NULLIF(TRIM(sc.contract_reference), '')) AS contract_reference,
    UPPER(NULLIF(TRIM(sc.catalog_status), '')) AS catalog_status,
    COUNT_IF(UPPER(TRIM(sc.catalog_status)) = 'ACTIVE') OVER (PARTITION BY sc.part_id) AS active_supplier_count,
    IFF(
        UPPER(TRIM(sc.catalog_status)) = 'ACTIVE'
        AND COUNT_IF(UPPER(TRIM(sc.catalog_status)) = 'ACTIVE') OVER (PARTITION BY sc.part_id) = 1,
        TRUE,
        FALSE
    ) AS sole_source_flag,
    sc._loaded_at,
    sc._updated_at,
    sc._batch_id,
    sc._source_system,
    sc._source_table,
    sc._source_key,
    sc._source_updated_at,
    sc._confidence_level,
    sc._version,
    100 - 20 * (
        IFF(sc.supplier_id IS NULL, 1, 0)
      + IFF(s.supplier_id IS NULL, 1, 0)
      + IFF(sc.part_id IS NULL, 1, 0)
      + IFF(p.part_id IS NULL, 1, 0)
      + IFF(sc.supply_cost_usd IS NULL, 1, 0)
    ) AS _dq_score
FROM SCO_HACKATHON.SCO_BRONZE.BRZ_SUPPLIER_CATALOG AS sc
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_SUPPLIER AS s
  ON s.supplier_id = sc.supplier_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_PART AS p
  ON p.part_id = sc.part_id;

CREATE OR REPLACE DYNAMIC TABLE SLV_FACT_SUPPLIER_COMPLIANCE
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Supplier compliance matches enriched with restriction-list and country context.'
AS
SELECT
    m.supplier_id,
    INITCAP(NULLIF(TRIM(s.supplier_name), '')) AS supplier_name,
    m.list_entry_id,
    UPPER(NULLIF(TRIM(l.list_source), '')) AS list_source,
    INITCAP(NULLIF(TRIM(l.listed_entity_name), '')) AS listed_entity_name,
    UPPER(NULLIF(TRIM(l.listed_entity_type), '')) AS listed_entity_type,
    l.country_id,
    INITCAP(NULLIF(TRIM(c.country_name), '')) AS country_name,
    UPPER(NULLIF(TRIM(l.restriction_type), '')) AS restriction_type,
    l.effective_date,
    l.expiration_date,
    m.match_confidence_pct,
    UPPER(NULLIF(TRIM(m.match_type), '')) AS match_type,
    m.match_date,
    DATE_TRUNC('month', m.match_date)::DATE AS match_month_start_date,
    UPPER(NULLIF(TRIM(m.resolution_status), '')) AS resolution_status,
    INITCAP(NULLIF(TRIM(m.resolved_by), '')) AS resolved_by,
    m.resolution_date,
    m._loaded_at,
    m._updated_at,
    m._batch_id,
    m._source_system,
    m._source_table,
    m._source_key,
    m._source_updated_at,
    m._confidence_level,
    m._version,
    100 - 20 * (
        IFF(m.supplier_id IS NULL, 1, 0)
      + IFF(s.supplier_id IS NULL, 1, 0)
      + IFF(m.list_entry_id IS NULL, 1, 0)
      + IFF(l.list_entry_id IS NULL, 1, 0)
      + IFF(m.match_date IS NULL, 1, 0)
    ) AS _dq_score
FROM SCO_HACKATHON.SCO_BRONZE.BRZ_SUPPLIER_COMPLIANCE_MATCH AS m
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_SUPPLIER AS s
  ON s.supplier_id = m.supplier_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_COMPLIANCE_LIST AS l
  ON l.list_entry_id = m.list_entry_id
LEFT JOIN SCO_HACKATHON.SCO_BRONZE.BRZ_COUNTRY AS c
  ON c.country_id = l.country_id;
