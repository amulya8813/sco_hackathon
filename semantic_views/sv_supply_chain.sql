-- =============================================================================
-- SV_SUPPLY_CHAIN — Governed semantic view for Cortex Analyst
-- Phase 2: All four governed metrics (OTD, Fill Rate, DOI, Landed Cost)
-- Schema: SCO_HACKATHON.SCO_GOLD
--
-- Multi-fact star model: four logical tables at DIFFERENT grains.
-- Cortex Analyst selects the right table per question.
-- Every ratio metric uses ratio-of-sums or quantity-weighting — never AVG.
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW SCO_HACKATHON.SCO_GOLD.SV_SUPPLY_CHAIN

  TABLES (
    -- ── OTD ── grain: month x supplier x customer-region x part-category
    otd AS SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD
      PRIMARY KEY (MONTH_START_DATE, SUPPLIER_ID, CUSTOMER_REGION, PART_CATEGORY)
      WITH SYNONYMS = ('on-time delivery', 'OTD table', 'delivery performance')
      COMMENT = 'Governed monthly On-Time Delivery metric at the grain month x supplier x customer-region x part-category',

    -- ── FILL RATE ── grain: month x service-tier x part-category x warehouse
    fill AS SCO_HACKATHON.SCO_GOLD.GLD_METRIC_FILL_RATE
      PRIMARY KEY (MONTH_START_DATE, CUSTOMER_SERVICE_TIER, PART_CATEGORY, WAREHOUSE_ID)
      WITH SYNONYMS = ('fill rate', 'fulfillment', 'order fill')
      COMMENT = 'Governed monthly Fill Rate metric at the grain month x service-tier x part-category x warehouse',

    -- ── DOI ── grain: snapshot-date x part x warehouse (PART_WAREHOUSE rows only)
    doi AS (SELECT * FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_DOI WHERE AGGREGATION_LEVEL = 'PART_WAREHOUSE')
      PRIMARY KEY (SNAPSHOT_DATE, PART_ID, WAREHOUSE_ID)
      WITH SYNONYMS = ('days of inventory', 'DOI table', 'inventory days')
      COMMENT = 'Governed Days of Inventory metric at the grain snapshot-date x part x warehouse. Filtered to PART_WAREHOUSE aggregation level only to prevent double-counting.',

    -- ── LANDED COST ── grain: month x supplier x route x part-category
    landed AS SCO_HACKATHON.SCO_GOLD.GLD_METRIC_LANDED_COST
      PRIMARY KEY (MONTH_START_DATE, SUPPLIER_ID, ROUTE_ID, PART_CATEGORY)
      WITH SYNONYMS = ('landed cost', 'delivered cost', 'total cost')
      COMMENT = 'Governed monthly Landed Cost metric at the grain month x supplier x route x part-category'
  )

  DIMENSIONS (
    -- ── OTD dimensions ──
    otd.delivery_month
      AS otd.MONTH_START_DATE
      WITH SYNONYMS = ('month', 'period', 'delivery month')
      COMMENT = 'First day of the month in which delivery was promised',

    otd.supplier
      AS otd.SUPPLIER_NAME
      WITH SYNONYMS = ('supplier', 'vendor')
      COMMENT = 'Name of the supplying vendor',

    otd.region
      AS otd.CUSTOMER_REGION
      WITH SYNONYMS = ('region', 'market')
      COMMENT = 'Customer geographic region',

    otd.category
      AS otd.PART_CATEGORY
      WITH SYNONYMS = ('category', 'product category')
      COMMENT = 'Part/product category',

    -- ── Fill Rate dimensions ──
    fill.fill_month
      AS fill.MONTH_START_DATE
      WITH SYNONYMS = ('month', 'period')
      COMMENT = 'First day of the month for the fill rate measurement',

    fill.service_tier
      AS fill.CUSTOMER_SERVICE_TIER
      WITH SYNONYMS = ('service tier', 'customer tier', 'tier')
      COMMENT = 'Customer service-level tier',

    fill.fill_category
      AS fill.PART_CATEGORY
      WITH SYNONYMS = ('category', 'product category')
      COMMENT = 'Part/product category for fill rate',

    fill.warehouse
      AS fill.WAREHOUSE_NAME
      WITH SYNONYMS = ('warehouse', 'DC', 'distribution center')
      COMMENT = 'Fulfillment warehouse or distribution center',

    -- ── DOI dimensions ──
    doi.snapshot_date
      AS doi.SNAPSHOT_DATE
      WITH SYNONYMS = ('snapshot date', 'date', 'as of date')
      COMMENT = 'Date of the inventory snapshot',

    doi.doi_part
      AS doi.PART_NAME
      WITH SYNONYMS = ('part', 'item', 'material')
      COMMENT = 'Part or material name',

    doi.doi_part_number
      AS doi.PART_NUMBER
      WITH SYNONYMS = ('part number', 'SKU')
      COMMENT = 'Part number or SKU identifier',

    doi.doi_category
      AS doi.PART_CATEGORY
      WITH SYNONYMS = ('category', 'product category')
      COMMENT = 'Part/product category for inventory',

    doi.doi_warehouse
      AS doi.WAREHOUSE_NAME
      WITH SYNONYMS = ('warehouse', 'DC')
      COMMENT = 'Warehouse holding the inventory',

    -- ── Landed Cost dimensions ──
    landed.landed_month
      AS landed.MONTH_START_DATE
      WITH SYNONYMS = ('month', 'period')
      COMMENT = 'First day of the month for the landed cost measurement',

    landed.landed_supplier
      AS landed.SUPPLIER_NAME
      WITH SYNONYMS = ('supplier', 'vendor')
      COMMENT = 'Name of the supplying vendor for landed cost',

    landed.route
      AS landed.ROUTE_NAME
      WITH SYNONYMS = ('route', 'lane', 'trade lane')
      COMMENT = 'Shipping route or trade lane',

    landed.landed_category
      AS landed.PART_CATEGORY
      WITH SYNONYMS = ('category', 'product category')
      COMMENT = 'Part/product category for landed cost'
  )

  METRICS (
    -- ── OTD metrics ──
    otd.on_time_delivery_rate
      AS SUM(otd.LINES_ON_TIME) / NULLIF(SUM(otd.LINES_DUE), 0) * 100
      WITH SYNONYMS = ('OTD', 'on-time delivery', 'on time delivery rate', 'delivery performance', 'on time rate', 'on-time rate')
      COMMENT = 'The percentage of order line items where goods were received by the customer on or before the committed delivery date, excluding Cancelled and not-yet-due lines. Target: 95-100%. Owning domain: Logistics.',

    otd.total_lines_due
      AS SUM(otd.LINES_DUE)
      WITH SYNONYMS = ('lines due', 'orders due')
      COMMENT = 'Total order lines due in the period',

    otd.total_lines_on_time
      AS SUM(otd.LINES_ON_TIME)
      WITH SYNONYMS = ('lines on time', 'on-time lines')
      COMMENT = 'Total order lines received on or before the promised date',

    -- ── Fill Rate metrics ──
    fill.fill_rate
      AS SUM(fill.UNITS_FULFILLED) / NULLIF(SUM(fill.UNITS_ORDERED), 0) * 100
      WITH SYNONYMS = ('fill rate', 'order fill rate', 'fulfillment rate', 'fill %')
      COMMENT = 'The percentage of customer demand (in units) fulfilled immediately from available inventory on the first attempt, without backorder, substitution, or delay. Target: 92-100%. Owning domain: Inventory Planning.',

    fill.total_units_ordered
      AS SUM(fill.UNITS_ORDERED)
      WITH SYNONYMS = ('units ordered')
      COMMENT = 'Total units ordered in the period',

    fill.total_units_fulfilled
      AS SUM(fill.UNITS_FULFILLED)
      WITH SYNONYMS = ('units fulfilled')
      COMMENT = 'Total units fulfilled from available inventory',

    -- ── DOI metrics ──
    doi.days_of_inventory
      AS SUM(doi.QUANTITY_ON_HAND) / NULLIF(SUM(doi.AVG_DAILY_DEMAND), 0)
      WITH SYNONYMS = ('DOI', 'days of inventory', 'days of supply', 'inventory days', 'days on hand')
      COMMENT = 'The number of calendar days current on-hand inventory would last at the current rate of demand, assuming no replenishment. Computed as a quantity-weighted ratio (total on-hand / total average daily demand) when rolled up. NULL when demand is zero. Target: category-dependent, typically 15-45 days. Owning domain: Inventory Planning.',

    doi.total_on_hand
      AS SUM(doi.QUANTITY_ON_HAND)
      WITH SYNONYMS = ('on hand', 'quantity on hand', 'stock')
      COMMENT = 'Total units of inventory on hand',

    -- ── Landed Cost metrics ──
    landed.landed_cost_per_unit
      AS SUM(landed.LANDED_COST_PER_UNIT_USD * landed.TOTAL_UNITS) / NULLIF(SUM(landed.TOTAL_UNITS), 0)
      WITH SYNONYMS = ('landed cost', 'landed cost per unit', 'total delivered cost', 'unit landed cost')
      COMMENT = 'The total cost to acquire one unit of a part and deliver it to its final destination: purchase price plus allocated freight, insurance, duties, and handling. Reported as a quantity-weighted cost per unit. Owning domain: Procurement.',

    landed.total_landed_units
      AS SUM(landed.TOTAL_UNITS)
      WITH SYNONYMS = ('units shipped', 'total units')
      COMMENT = 'Total units shipped in the period'
  )

  COMMENT = 'Governed supply-chain semantic model for Cortex Analyst. Covers the four governed metrics — On-Time Delivery, Fill Rate, Days of Inventory, and Landed Cost — read from the governed SCO_GOLD layer. One metric, one definition, consistent across all users.';
