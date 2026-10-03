--------------------------------------------------------------------------------
-- Supply Chain Ontology — Gold Layer
-- 07_gold_layer.sql
-- Governed, business-ready metrics and scenario-facing analytical products.
--------------------------------------------------------------------------------

SET sco_role='ACCOUNTADMIN';
SET sco_warehouse='COMPUTE_WH';
SET sco_database='SCO_HACKATHON';

USE ROLE IDENTIFIER($sco_role);
USE WAREHOUSE IDENTIFIER($sco_warehouse);
USE DATABASE IDENTIFIER($sco_database);

CREATE SCHEMA IF NOT EXISTS SCO_GOLD;
USE SCHEMA SCO_GOLD;

-- =============================================================================
-- Governed metric products
-- =============================================================================

-- Governed definition (verbatim): The percentage of order line items where
-- goods were received by the customer on or before the committed delivery date.
-- OTD = count(actual_receipt_date <= promised_delivery_date) / count(all line
-- items due in period, excluding Cancelled and not-yet-due lines) * 100.
-- FULL refresh is deliberate because Silver due-state is based on CURRENT_DATE.
CREATE OR REPLACE DYNAMIC TABLE GLD_METRIC_OTD
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = FULL INITIALIZE = ON_CREATE
  COMMENT = 'Governed monthly on-time delivery rate at supplier, customer-region, and part-category grain.'
AS
SELECT
    promised_month_start_date AS month_start_date,
    line_supplier_id AS supplier_id,
    supplier_name,
    customer_region,
    part_category,
    COUNT(*) AS lines_due,
    COUNT_IF(actual_receipt_date <= promised_delivery_date) AS lines_on_time,
    COUNT(*) - COUNT_IF(actual_receipt_date <= promised_delivery_date) AS lines_late,
    ROUND(
        100.0 * COUNT_IF(actual_receipt_date <= promised_delivery_date)
        / NULLIF(COUNT(*), 0),
        2
    ) AS on_time_delivery_rate_pct,
    ROUND(AVG(IFF(actual_receipt_date > promised_delivery_date, days_late, NULL)), 2) AS avg_days_late
FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_ORDER_LINE
WHERE is_excluded_flag = FALSE
GROUP BY
    promised_month_start_date,
    line_supplier_id,
    supplier_name,
    customer_region,
    part_category;

-- Governed definition (verbatim): The percentage of customer demand (in units)
-- that is fulfilled immediately from available inventory without backorder,
-- substitution, or delay.
-- Fill Rate = SUM(MIN(first-attempt quantity_shipped, quantity_ordered)) /
-- SUM(quantity_ordered) * 100. Only the earliest shipment per line counts.
-- FULL refresh is deliberate because first fulfillment uses ROW_NUMBER.
CREATE OR REPLACE DYNAMIC TABLE GLD_METRIC_FILL_RATE
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = FULL INITIALIZE = ON_CREATE
  COMMENT = 'Governed unit-based first-attempt fill rate by month, customer service tier, part category, and derivable warehouse.'
AS
WITH first_attempt AS (
    SELECT
        line_item_id,
        shipment_id,
        origin_warehouse_id AS warehouse_id,
        SUM(quantity_shipped) AS quantity_shipped
    FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_SHIPMENT_LINE
    GROUP BY line_item_id, shipment_id, origin_warehouse_id, ship_date
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY line_item_id
        ORDER BY ship_date ASC NULLS LAST, shipment_id ASC
    ) = 1
),
line_fulfillment AS (
    SELECT
        l.order_month_start_date AS month_start_date,
        l.customer_service_tier,
        l.part_category,
        f.warehouse_id,
        w.warehouse_name,
        l.quantity_ordered,
        LEAST(COALESCE(f.quantity_shipped, 0), l.quantity_ordered) AS units_fulfilled
    FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_ORDER_LINE AS l
    LEFT JOIN first_attempt AS f
      ON f.line_item_id = l.line_item_id
    LEFT JOIN SCO_HACKATHON.SCO_SILVER.SLV_DIM_WAREHOUSE AS w
      ON w.warehouse_id = f.warehouse_id
    WHERE l.order_status <> 'CANCELLED'
)
SELECT
    month_start_date,
    customer_service_tier,
    part_category,
    warehouse_id,
    warehouse_name,
    SUM(units_fulfilled) AS units_fulfilled,
    SUM(quantity_ordered) AS units_ordered,
    ROUND(100.0 * SUM(units_fulfilled) / NULLIF(SUM(quantity_ordered), 0), 2) AS fill_rate_pct
FROM line_fulfillment
GROUP BY
    month_start_date,
    customer_service_tier,
    part_category,
    warehouse_id,
    warehouse_name;

-- Governed definition (verbatim): The number of calendar days that current
-- on-hand inventory would last at the current rate of demand, assuming no
-- replenishment.
-- DOI = quantity_on_hand / (trailing-30-day SUM(quantity_ordered) / 30).
-- If average daily demand is zero, DOI is NULL and obsolescence is flagged.
-- In-transit inventory is excluded. FULL refresh supports the range join and
-- the explicit part-level UNION ALL rollup.
CREATE OR REPLACE DYNAMIC TABLE GLD_METRIC_DOI
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = FULL INITIALIZE = ON_CREATE
  COMMENT = 'Governed days of inventory by snapshot, part, and warehouse, plus an all-warehouse part rollup using trailing 30-day actual demand.'
AS
WITH demand_by_snapshot AS (
    SELECT
        i.snapshot_date,
        i.part_id,
        i.warehouse_id,
        i.part_number,
        i.part_name,
        i.part_category,
        i.warehouse_name,
        i.quantity_on_hand,
        COALESCE(SUM(l.quantity_ordered), 0) AS trailing_30_day_demand
    FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_INVENTORY AS i
    LEFT JOIN SCO_HACKATHON.SCO_SILVER.SLV_FACT_ORDER_LINE AS l
      ON l.part_id = i.part_id
     AND l.order_status <> 'CANCELLED'
     AND l.order_date BETWEEN DATEADD('day', -29, i.snapshot_date) AND i.snapshot_date
    GROUP BY
        i.snapshot_date,
        i.part_id,
        i.warehouse_id,
        i.part_number,
        i.part_name,
        i.part_category,
        i.warehouse_name,
        i.quantity_on_hand
),
part_rollup AS (
    SELECT
        snapshot_date,
        part_id,
        part_number,
        part_name,
        part_category,
        SUM(quantity_on_hand) AS quantity_on_hand,
        MAX(trailing_30_day_demand) AS trailing_30_day_demand
    FROM demand_by_snapshot
    GROUP BY snapshot_date, part_id, part_number, part_name, part_category
)
SELECT
    'PART_WAREHOUSE' AS aggregation_level,
    snapshot_date,
    part_id,
    part_number,
    part_name,
    part_category,
    warehouse_id,
    warehouse_name,
    quantity_on_hand,
    trailing_30_day_demand,
    trailing_30_day_demand / 30.0 AS avg_daily_demand,
    IFF(
        trailing_30_day_demand = 0,
        NULL,
        ROUND(quantity_on_hand / (trailing_30_day_demand / 30.0), 2)
    ) AS days_of_inventory,
    IFF(trailing_30_day_demand = 0, TRUE, FALSE) AS obsolescence_review_flag
FROM demand_by_snapshot
UNION ALL
SELECT
    'PART_ALL_WAREHOUSES' AS aggregation_level,
    snapshot_date,
    part_id,
    part_number,
    part_name,
    part_category,
    CAST(NULL AS INTEGER) AS warehouse_id,
    'All Warehouses' AS warehouse_name,
    quantity_on_hand,
    trailing_30_day_demand,
    trailing_30_day_demand / 30.0 AS avg_daily_demand,
    IFF(
        trailing_30_day_demand = 0,
        NULL,
        ROUND(quantity_on_hand / (trailing_30_day_demand / 30.0), 2)
    ) AS days_of_inventory,
    IFF(trailing_30_day_demand = 0, TRUE, FALSE) AS obsolescence_review_flag
FROM part_rollup;

-- Governed definition (verbatim): The total cost to acquire one unit of a part
-- and deliver it to its final destination, including purchase price, freight,
-- insurance, duties, taxes, handling, and brokerage.
-- Landed cost per unit = supply_cost_usd + freight/unit + insurance/unit +
-- duties/unit + handling/unit. The source model stores actual shipment-level
-- insurance, duties, and handling dollars; each is allocated by shipment units.
-- FULL refresh is deliberate because shipment totals are window-derived in Silver.
CREATE OR REPLACE DYNAMIC TABLE GLD_METRIC_LANDED_COST
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = FULL INITIALIZE = ON_CREATE
  COMMENT = 'Governed quantity-weighted landed cost per unit with purchase, freight, insurance, duties, and handling components.'
AS
WITH line_cost AS (
    SELECT
        s.ship_month_start_date AS month_start_date,
        s.supplier_id,
        d.supplier_name,
        s.route_id,
        r.route_name,
        s.part_category,
        s.quantity_shipped,
        s.supply_cost_usd,
        COALESCE(s.allocated_freight_cost_usd, 0) AS allocated_freight_cost_usd,
        COALESCE(s.allocated_insurance_cost_usd, 0) AS allocated_insurance_cost_usd,
        COALESCE(s.allocated_duties_usd, 0) AS allocated_duties_usd,
        COALESCE(s.allocated_handling_cost_usd, 0) AS allocated_handling_cost_usd
    FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_SHIPMENT_LINE AS s
    LEFT JOIN SCO_HACKATHON.SCO_SILVER.SLV_DIM_SUPPLIER AS d
      ON d.supplier_id = s.supplier_id
    LEFT JOIN SCO_HACKATHON.SCO_SILVER.SLV_DIM_ROUTE AS r
      ON r.route_id = s.route_id
    WHERE s.quantity_shipped > 0
      AND s.supply_cost_usd IS NOT NULL
)
SELECT
    month_start_date,
    supplier_id,
    supplier_name,
    route_id,
    route_name,
    part_category,
    SUM(quantity_shipped) AS total_units,
    ROUND(SUM(supply_cost_usd * quantity_shipped) / NULLIF(SUM(quantity_shipped), 0), 4) AS purchase_cost_per_unit_usd,
    ROUND(SUM(allocated_freight_cost_usd) / NULLIF(SUM(quantity_shipped), 0), 4) AS freight_cost_per_unit_usd,
    ROUND(SUM(allocated_insurance_cost_usd) / NULLIF(SUM(quantity_shipped), 0), 4) AS insurance_cost_per_unit_usd,
    ROUND(SUM(allocated_duties_usd) / NULLIF(SUM(quantity_shipped), 0), 4) AS duties_cost_per_unit_usd,
    ROUND(SUM(allocated_handling_cost_usd) / NULLIF(SUM(quantity_shipped), 0), 4) AS handling_cost_per_unit_usd,
    ROUND(
        (
            SUM(supply_cost_usd * quantity_shipped)
          + SUM(allocated_freight_cost_usd)
          + SUM(allocated_insurance_cost_usd)
          + SUM(allocated_duties_usd)
          + SUM(allocated_handling_cost_usd)
        ) / NULLIF(SUM(quantity_shipped), 0),
        4
    ) AS landed_cost_per_unit_usd
FROM line_cost
GROUP BY month_start_date, supplier_id, supplier_name, route_id, route_name, part_category;

-- =============================================================================
-- Scenario-facing analytical products
-- =============================================================================

-- FULL refresh is deliberate because first-attempt shipment selection uses ROW_NUMBER.
CREATE OR REPLACE DYNAMIC TABLE GLD_SUPPLIER_SCORECARD
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = FULL INITIALIZE = ON_CREATE
  COMMENT = 'Monthly supplier scorecard combining governed delivery, fill, landed cost, risk, ESG, compliance, volume, and spend measures.'
AS
WITH first_attempt AS (
    SELECT line_item_id, shipment_id, SUM(quantity_shipped) AS quantity_shipped
    FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_SHIPMENT_LINE
    GROUP BY line_item_id, shipment_id, ship_date
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY line_item_id
        ORDER BY ship_date ASC NULLS LAST, shipment_id ASC
    ) = 1
),
orders AS (
    SELECT
        l.line_supplier_id AS supplier_id,
        l.order_month_start_date AS month_start_date,
        COUNT(DISTINCT l.order_id) AS order_volume,
        SUM(l.extended_price_usd) AS spend_usd,
        SUM(LEAST(COALESCE(f.quantity_shipped, 0), l.quantity_ordered)) AS units_fulfilled,
        SUM(l.quantity_ordered) AS units_ordered
    FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_ORDER_LINE AS l
    LEFT JOIN first_attempt AS f
      ON f.line_item_id = l.line_item_id
    WHERE l.order_status <> 'CANCELLED'
    GROUP BY l.line_supplier_id, l.order_month_start_date
),
otd AS (
    SELECT
        line_supplier_id AS supplier_id,
        promised_month_start_date AS month_start_date,
        COUNT(*) AS lines_due,
        COUNT_IF(actual_receipt_date <= promised_delivery_date) AS lines_on_time
    FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_ORDER_LINE
    WHERE is_excluded_flag = FALSE
    GROUP BY line_supplier_id, promised_month_start_date
),
landed AS (
    SELECT
        supplier_id,
        ship_month_start_date AS month_start_date,
        SUM(
            supply_cost_usd * quantity_shipped
          + COALESCE(allocated_freight_cost_usd, 0)
          + COALESCE(allocated_insurance_cost_usd, 0)
          + COALESCE(allocated_duties_usd, 0)
          + COALESCE(allocated_handling_cost_usd, 0)
        ) / NULLIF(SUM(quantity_shipped), 0) AS avg_landed_cost_per_unit_usd
    FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_SHIPMENT_LINE
    WHERE quantity_shipped > 0 AND supply_cost_usd IS NOT NULL
    GROUP BY supplier_id, ship_month_start_date
),
risk AS (
    SELECT
        supplier_id,
        assessment_month_start_date AS month_start_date,
        AVG(overall_risk_score) AS risk_score
    FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_SUPPLIER_RISK
    GROUP BY supplier_id, assessment_month_start_date
),
esg AS (
    SELECT
        supplier_id,
        scoring_month_start_date AS month_start_date,
        AVG(overall_esg_score) AS esg_score
    FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_ESG
    WHERE supplier_id IS NOT NULL
    GROUP BY supplier_id, scoring_month_start_date
),
compliance AS (
    SELECT
        supplier_id,
        match_month_start_date AS month_start_date,
        COUNT(DISTINCT list_entry_id) AS compliance_match_count
    FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_SUPPLIER_COMPLIANCE
    GROUP BY supplier_id, match_month_start_date
),
keys AS (
    SELECT supplier_id, month_start_date FROM orders
    UNION
    SELECT supplier_id, month_start_date FROM otd
    UNION
    SELECT supplier_id, month_start_date FROM landed
    UNION
    SELECT supplier_id, month_start_date FROM risk
    UNION
    SELECT supplier_id, month_start_date FROM esg
    UNION
    SELECT supplier_id, month_start_date FROM compliance
)
SELECT
    k.supplier_id,
    d.supplier_name,
    k.month_start_date,
    ROUND(100.0 * ot.lines_on_time / NULLIF(ot.lines_due, 0), 2) AS on_time_delivery_rate_pct,
    ROUND(100.0 * o.units_fulfilled / NULLIF(o.units_ordered, 0), 2) AS fill_rate_pct,
    ROUND(l.avg_landed_cost_per_unit_usd, 4) AS avg_landed_cost_per_unit_usd,
    ROUND(r.risk_score, 2) AS risk_score,
    ROUND(e.esg_score, 2) AS esg_score,
    COALESCE(c.compliance_match_count, 0) AS compliance_match_count,
    COALESCE(o.order_volume, 0) AS order_volume,
    COALESCE(o.spend_usd, 0) AS spend_usd
FROM keys AS k
LEFT JOIN SCO_HACKATHON.SCO_SILVER.SLV_DIM_SUPPLIER AS d
  ON d.supplier_id = k.supplier_id
LEFT JOIN orders AS o
  ON o.supplier_id = k.supplier_id AND o.month_start_date = k.month_start_date
LEFT JOIN otd AS ot
  ON ot.supplier_id = k.supplier_id AND ot.month_start_date = k.month_start_date
LEFT JOIN landed AS l
  ON l.supplier_id = k.supplier_id AND l.month_start_date = k.month_start_date
LEFT JOIN risk AS r
  ON r.supplier_id = k.supplier_id AND r.month_start_date = k.month_start_date
LEFT JOIN esg AS e
  ON e.supplier_id = k.supplier_id AND e.month_start_date = k.month_start_date
LEFT JOIN compliance AS c
  ON c.supplier_id = k.supplier_id AND c.month_start_date = k.month_start_date;

-- FULL refresh is deliberate because current position uses ROW_NUMBER and DOI
-- uses a trailing 30-day range join. days_of_cover is derived from available
-- inventory because the source has no separate coverage measure.
CREATE OR REPLACE DYNAMIC TABLE GLD_INVENTORY_HEALTH
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = FULL INITIALIZE = ON_CREATE
  COMMENT = 'Latest part-warehouse inventory position with governed DOI, available-stock cover, reorder, stockout, and excess indicators.'
AS
WITH current_inventory AS (
    SELECT *
    FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_INVENTORY
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY part_id, warehouse_id ORDER BY snapshot_date DESC
    ) = 1
),
health AS (
    SELECT
        i.part_id,
        i.part_number,
        i.part_name,
        i.part_category,
        i.warehouse_id,
        i.warehouse_name,
        i.snapshot_date,
        i.quantity_on_hand,
        i.quantity_available,
        i.reorder_point,
        i.safety_stock_level,
        i.stockout_flag,
        i.below_reorder_flag,
        COALESCE(SUM(l.quantity_ordered), 0) / 30.0 AS avg_daily_demand
    FROM current_inventory AS i
    LEFT JOIN SCO_HACKATHON.SCO_SILVER.SLV_FACT_ORDER_LINE AS l
      ON l.part_id = i.part_id
     AND l.order_status <> 'CANCELLED'
     AND l.order_date BETWEEN DATEADD('day', -29, i.snapshot_date) AND i.snapshot_date
    GROUP BY
        i.part_id,
        i.part_number,
        i.part_name,
        i.part_category,
        i.warehouse_id,
        i.warehouse_name,
        i.snapshot_date,
        i.quantity_on_hand,
        i.quantity_available,
        i.reorder_point,
        i.safety_stock_level,
        i.stockout_flag,
        i.below_reorder_flag
)
SELECT
    part_id,
    part_number,
    part_name,
    part_category,
    warehouse_id,
    warehouse_name,
    snapshot_date,
    quantity_on_hand,
    quantity_available,
    reorder_point,
    safety_stock_level,
    avg_daily_demand,
    IFF(avg_daily_demand = 0, NULL, ROUND(quantity_on_hand / avg_daily_demand, 2)) AS days_of_inventory,
    IFF(avg_daily_demand = 0, NULL, ROUND(quantity_available / avg_daily_demand, 2)) AS days_of_cover,
    stockout_flag,
    below_reorder_flag,
    IFF(avg_daily_demand > 0 AND quantity_on_hand / avg_daily_demand > 90, TRUE, FALSE) AS excess_flag,
    IFF(avg_daily_demand = 0, TRUE, FALSE) AS obsolescence_review_flag
FROM health;

CREATE OR REPLACE DYNAMIC TABLE GLD_SHIPMENT_PERFORMANCE
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = AUTO INITIALIZE = ON_CREATE
  COMMENT = 'Monthly route-carrier shipment performance covering on-time arrival, transit variance, and freight cost per kilogram.'
AS
SELECT
    route_id,
    route_name,
    carrier_id,
    carrier_name,
    ship_month_start_date AS month_start_date,
    COUNT(DISTINCT shipment_id) AS shipment_count,
    ROUND(100.0 * COUNT_IF(on_time_arrival_flag) / NULLIF(COUNT_IF(actual_arrival_date IS NOT NULL), 0), 2) AS on_time_arrival_rate_pct,
    ROUND(AVG(transit_variance_days), 2) AS avg_transit_variance_days,
    ROUND(SUM(freight_cost_usd) / NULLIF(SUM(total_weight_kg), 0), 4) AS avg_freight_cost_per_kg_usd
FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_SHIPMENT
GROUP BY route_id, route_name, carrier_id, carrier_name, ship_month_start_date;

-- FULL refresh is deliberate because the sourcing bridge and supplier dimension
-- use window-selected conformance and the order-line upstream is FULL refresh.
CREATE OR REPLACE DYNAMIC TABLE GLD_RISK_EXPOSURE
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = FULL INITIALIZE = ON_CREATE
  COMMENT = 'Monthly supplier risk exposure combining risk, ESG, sanctions, spend at risk, and sole-source part concentration.'
AS
WITH risk AS (
    SELECT
        supplier_id,
        assessment_month_start_date AS month_start_date,
        AVG(overall_risk_score) AS risk_score
    FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_SUPPLIER_RISK
    GROUP BY supplier_id, assessment_month_start_date
),
esg AS (
    SELECT
        supplier_id,
        scoring_month_start_date AS month_start_date,
        AVG(overall_esg_score) AS esg_score
    FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_ESG
    WHERE supplier_id IS NOT NULL
    GROUP BY supplier_id, scoring_month_start_date
),
sanctions AS (
    SELECT
        supplier_id,
        match_month_start_date AS month_start_date,
        COUNT(DISTINCT list_entry_id) AS sanctions_match_count
    FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_SUPPLIER_COMPLIANCE
    GROUP BY supplier_id, match_month_start_date
),
spend AS (
    SELECT
        line_supplier_id AS supplier_id,
        order_month_start_date AS month_start_date,
        SUM(extended_price_usd) AS spend_at_risk_usd
    FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_ORDER_LINE
    WHERE order_status <> 'CANCELLED'
    GROUP BY line_supplier_id, order_month_start_date
),
sole_source AS (
    SELECT supplier_id, COUNT(DISTINCT part_id) AS sole_source_part_count
    FROM SCO_HACKATHON.SCO_SILVER.SLV_BRIDGE_SUPPLIER_PART
    WHERE sole_source_flag
    GROUP BY supplier_id
),
keys AS (
    SELECT supplier_id, month_start_date FROM risk
    UNION
    SELECT supplier_id, month_start_date FROM esg
    UNION
    SELECT supplier_id, month_start_date FROM sanctions
    UNION
    SELECT supplier_id, month_start_date FROM spend
)
SELECT
    k.supplier_id,
    d.supplier_name,
    k.month_start_date,
    ROUND(r.risk_score, 2) AS risk_score,
    ROUND(e.esg_score, 2) AS esg_score,
    COALESCE(s.sanctions_match_count, 0) AS sanctions_match_count,
    COALESCE(sp.spend_at_risk_usd, 0) AS spend_at_risk_usd,
    COALESCE(ss.sole_source_part_count, 0) AS sole_source_part_count
FROM keys AS k
LEFT JOIN SCO_HACKATHON.SCO_SILVER.SLV_DIM_SUPPLIER AS d
  ON d.supplier_id = k.supplier_id
LEFT JOIN risk AS r
  ON r.supplier_id = k.supplier_id AND r.month_start_date = k.month_start_date
LEFT JOIN esg AS e
  ON e.supplier_id = k.supplier_id AND e.month_start_date = k.month_start_date
LEFT JOIN sanctions AS s
  ON s.supplier_id = k.supplier_id AND s.month_start_date = k.month_start_date
LEFT JOIN spend AS sp
  ON sp.supplier_id = k.supplier_id AND sp.month_start_date = k.month_start_date
LEFT JOIN sole_source AS ss
  ON ss.supplier_id = k.supplier_id;

-- FULL refresh is deliberate because the governed order-line upstream uses a
-- current-date filter and therefore refreshes in FULL mode.
CREATE OR REPLACE DYNAMIC TABLE GLD_DEMAND_HISTORY
  TARGET_LAG = '1 hour' WAREHOUSE = COMPUTE_WH REFRESH_MODE = FULL INITIALIZE = ON_CREATE
  COMMENT = 'Clean monthly part demand time series for Cortex ML forecasting, with total ordered quantity and distinct order count.'
AS
SELECT
    part_id,
    order_month_start_date AS month_start_date,
    SUM(quantity_ordered) AS total_quantity,
    COUNT(DISTINCT order_id) AS order_count
FROM SCO_HACKATHON.SCO_SILVER.SLV_FACT_ORDER_LINE
WHERE order_status <> 'CANCELLED'
GROUP BY part_id, order_month_start_date;

-- =============================================================================
-- Governed metric catalog
-- =============================================================================

CREATE OR REPLACE TABLE GLD_METRIC_DEFINITIONS (
    metric_name VARCHAR(100) NOT NULL,
    governed_definition VARCHAR(2000) NOT NULL,
    formula VARCHAR(2000) NOT NULL,
    grain VARCHAR(500) NOT NULL,
    unit VARCHAR(100) NOT NULL,
    target_range VARCHAR(200) NOT NULL,
    owning_domain VARCHAR(100) NOT NULL,
    refreshed_at TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_gld_metric_definitions PRIMARY KEY (metric_name)
)
COMMENT = 'Authoritative catalog of the four governed supply-chain metric definitions for citation by downstream analytics.';

INSERT INTO GLD_METRIC_DEFINITIONS (
    metric_name,
    governed_definition,
    formula,
    grain,
    unit,
    target_range,
    owning_domain
)
SELECT * FROM VALUES
    (
        'on_time_delivery_rate',
        'The percentage of order line items where goods were received by the customer on or before the committed delivery date',
        'COUNT(line items where actual_receipt_date <= promised_delivery_date) / COUNT(line items due in period excluding Cancelled and not-yet-due) * 100',
        'Month x Supplier x Customer Region x Part Category',
        'Percent (%)',
        '95-100%; world-class >=98%',
        'Logistics'
    ),
    (
        'order_fill_rate',
        'The percentage of customer demand (in units) that is fulfilled immediately from available inventory without backorder, substitution, or delay',
        'SUM(LEAST(quantity_shipped on first fulfillment attempt, quantity_ordered)) / SUM(quantity_ordered) * 100',
        'Month x Customer Service Tier x Part Category x Warehouse',
        'Percent (%)',
        '92-100%; world-class >=97%',
        'Inventory Planning'
    ),
    (
        'days_of_inventory',
        'The number of calendar days that current on-hand inventory would last at the current rate of demand, assuming no replenishment',
        'quantity_on_hand / (SUM(quantity_ordered over trailing 30 calendar days) / 30); NULL when average daily demand is zero',
        'Snapshot Date x Part x Warehouse',
        'Days',
        'Category-dependent; typically 15-45 days (lean: 10-20; safety-buffered: 30-60)',
        'Inventory Planning'
    ),
    (
        'landed_cost_per_unit_usd',
        'The total cost to acquire one unit of a part and deliver it to its final destination, including purchase price, freight, insurance, duties, taxes, handling, and brokerage',
        'supply_cost_usd + freight_cost_usd/shipment_total_units + insurance_cost_usd/shipment_total_units + duties_usd/shipment_total_units + handling_cost_usd/shipment_total_units',
        'Month x Supplier x Route x Part Category',
        'USD per unit',
        'Part-specific; benchmark against historical and market',
        'Procurement'
    );
