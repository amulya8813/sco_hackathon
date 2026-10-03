--------------------------------------------------------------------------------
-- Supply Chain Ontology — Synthetic Data Generation
-- 03_generate_synthetic_data.sql
--
-- Prompt source: prompts_for_DDLandDataPopulation.txt, Prompt 4
--   "Generate realistic synthetic supply chain data while maintaining
--    referential integrity."
--
-- Design basis : Supply_Chain_Synthetic_Data_Strategy.md
--                Supply_Chain_Demonstration_Scenarios.md
--
-- METHOD -----------------------------------------------------------------
-- Pure set-based Snowflake SQL. No external files, no stages, no COPY, no
-- Python. Every row is produced by TABLE(GENERATOR(...)) and every random-
-- looking value comes from ABS(HASH(seed, 'salt')), which is DETERMINISTIC in
-- Snowflake. Re-running this script therefore reproduces byte-identical data.
--
-- SEQ4() CONTRACT --------------------------------------------------------
-- Snowflake does not guarantee that two SEQ4() calls in the same SELECT
-- return the same value. Every section therefore emits SEQ4() exactly once,
-- in an isolated `seq` CTE, and all derived expressions read that column.
-- Collapsing these CTEs would silently corrupt the generated keys.
--
-- REFERENTIAL INTEGRITY --------------------------------------------------
-- Snowflake does not enforce FK constraints. Integrity here is guaranteed by
-- CONSTRUCTION: every foreign key is either
--   (a) derived as 1 + MOD(<expr>, <parent row count>), which cannot fall
--       outside the parent key range, or
--   (b) taken directly from a JOIN against the already-loaded parent table.
-- Composite primary keys are collision-free by using multiplier steps that are
-- coprime with the modulus (e.g. step 997 against modulus 5000).
--
-- IDEMPOTENCY ------------------------------------------------------------
-- Each section begins with a DELETE scoped to this batch id, so the script is
-- safely re-runnable. It never drops or replaces a table.
--
-- ORDER ------------------------------------------------------------------
-- Sections follow the dependency layers in Supply_Chain_Synthetic_Data_Strategy.md.
-- Run top to bottom in a single session.
--
-- Run AFTER : 01_create_source_tables.sql, 02_validate_source_layer.sql
-- Run BEFORE: 04_validate_synthetic_data.sql
--------------------------------------------------------------------------------

SET sco_role      = 'ACCOUNTADMIN';
SET sco_warehouse = 'COMPUTE_WH';
SET sco_database  = 'SCO_HACKATHON';
SET sco_batch     = 'SYNTH_V1';
SET win_start     = '2024-01-01'::DATE;   -- synthetic data window start
SET win_end       = '2025-12-31'::DATE;   -- synthetic data window end

USE ROLE      IDENTIFIER($sco_role);
USE WAREHOUSE IDENTIFIER($sco_warehouse);
USE DATABASE  IDENTIFIER($sco_database);
USE SCHEMA    SCO_SOURCE;

SELECT CURRENT_ROLE()     AS active_role,
       CURRENT_DATABASE() AS active_database,
       CURRENT_SCHEMA()   AS active_schema,
       $sco_batch         AS batch_id,
       $win_start         AS window_start,
       $win_end           AS window_end;


-- =============================================================================
-- IDEMPOTENCY: remove any prior rows from this batch, in reverse FK order.
-- =============================================================================
DELETE FROM INVENTORY_POSITION        WHERE _batch_id = $sco_batch;
DELETE FROM SHIPMENT_LINE_ITEM        WHERE _batch_id = $sco_batch;
DELETE FROM SHIPMENT                  WHERE _batch_id = $sco_batch;
DELETE FROM ORDER_LINE_ITEM           WHERE _batch_id = $sco_batch;
DELETE FROM PURCHASE_ORDER            WHERE _batch_id = $sco_batch;
DELETE FROM ESG_SCORE                 WHERE _batch_id = $sco_batch;
DELETE FROM SUPPLIER_RISK_ASSESSMENT  WHERE _batch_id = $sco_batch;
DELETE FROM COMMODITY_RESTRICTION     WHERE _batch_id = $sco_batch;
DELETE FROM CUSTOMER_COMPLIANCE_MATCH WHERE _batch_id = $sco_batch;
DELETE FROM SUPPLIER_COMPLIANCE_MATCH WHERE _batch_id = $sco_batch;
DELETE FROM CARRIER_ROUTE_SERVICE     WHERE _batch_id = $sco_batch;
DELETE FROM PLANT_PART_ASSIGNMENT     WHERE _batch_id = $sco_batch;
DELETE FROM SUPPLIER_CATALOG          WHERE _batch_id = $sco_batch;
DELETE FROM ROUTE                     WHERE _batch_id = $sco_batch;
DELETE FROM PLANT                     WHERE _batch_id = $sco_batch;
DELETE FROM WAREHOUSE                 WHERE _batch_id = $sco_batch;
DELETE FROM PART                      WHERE _batch_id = $sco_batch;
DELETE FROM PORT                      WHERE _batch_id = $sco_batch;
DELETE FROM CARRIER                   WHERE _batch_id = $sco_batch;
DELETE FROM CUSTOMER                  WHERE _batch_id = $sco_batch;
DELETE FROM SUPPLIER                  WHERE _batch_id = $sco_batch;
DELETE FROM COMPLIANCE_LIST           WHERE _batch_id = $sco_batch;
DELETE FROM COMMODITY                 WHERE _batch_id = $sco_batch;
DELETE FROM COUNTRY                   WHERE _batch_id = $sco_batch;


-- #############################################################################
-- LAYER 1 — REFERENCE DATA (no FK dependencies)
-- #############################################################################

-- =============================================================================
-- 1. COUNTRY — 50 rows. Real ISO 3166-1 codes so Cortex answers look credible.
--    Scenario 6 (Risk Events, 2024-04..2024-06) is seeded here through the
--    elevated risk_rating / sanctions_status on RU, UA, TR, CN.
-- =============================================================================
INSERT INTO COUNTRY (
    country_id, country_name, iso_alpha2, iso_alpha3, iso_numeric,
    region_name, sub_region, sanctions_status, trade_bloc, currency_code,
    risk_rating, _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
SELECT country_id, country_name, iso_alpha2, iso_alpha3, iso_numeric,
       region_name, sub_region, sanctions_status, trade_bloc, currency_code,
       risk_rating,
       $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
       'COUNTRY:' || country_id, 100.00, 'VERIFIED'
FROM VALUES
 (1,'United States','US','USA','840','Americas','Northern America','None','USMCA','USD',12.50),
 (2,'Canada','CA','CAN','124','Americas','Northern America','None','USMCA','CAD',8.20),
 (3,'Mexico','MX','MEX','484','Americas','Central America','None','USMCA','MXN',32.40),
 (4,'Brazil','BR','BRA','076','Americas','South America','None','MERCOSUR','BRL',38.60),
 (5,'Argentina','AR','ARG','032','Americas','South America','None','MERCOSUR','ARS',52.30),
 (6,'Chile','CL','CHL','152','Americas','South America','None','Pacific-Alliance','CLP',21.70),
 (7,'Colombia','CO','COL','170','Americas','South America','None','Pacific-Alliance','COP',41.20),
 (8,'Peru','PE','PER','604','Americas','South America','None','Pacific-Alliance','PEN',39.50),
 (9,'United Kingdom','GB','GBR','826','EMEA','Northern Europe','None','UK-Global','GBP',14.10),
 (10,'Germany','DE','DEU','276','EMEA','Western Europe','None','EU','EUR',9.80),
 (11,'France','FR','FRA','250','EMEA','Western Europe','None','EU','EUR',13.40),
 (12,'Netherlands','NL','NLD','528','EMEA','Western Europe','None','EU','EUR',8.90),
 (13,'Belgium','BE','BEL','056','EMEA','Western Europe','None','EU','EUR',11.20),
 (14,'Italy','IT','ITA','380','EMEA','Southern Europe','None','EU','EUR',19.60),
 (15,'Spain','ES','ESP','724','EMEA','Southern Europe','None','EU','EUR',17.80),
 (16,'Portugal','PT','PRT','620','EMEA','Southern Europe','None','EU','EUR',18.30),
 (17,'Poland','PL','POL','616','EMEA','Eastern Europe','None','EU','PLN',22.50),
 (18,'Czechia','CZ','CZE','203','EMEA','Eastern Europe','None','EU','CZK',16.90),
 (19,'Hungary','HU','HUN','348','EMEA','Eastern Europe','None','EU','HUF',27.40),
 (20,'Romania','RO','ROU','642','EMEA','Eastern Europe','None','EU','RON',29.80),
 (21,'Sweden','SE','SWE','752','EMEA','Northern Europe','None','EU','SEK',7.40),
 (22,'Norway','NO','NOR','578','EMEA','Northern Europe','None','EFTA','NOK',6.90),
 (23,'Denmark','DK','DNK','208','EMEA','Northern Europe','None','EU','DKK',7.10),
 (24,'Finland','FI','FIN','246','EMEA','Northern Europe','None','EU','EUR',8.50),
 (25,'Ireland','IE','IRL','372','EMEA','Northern Europe','None','EU','EUR',10.30),
 (26,'Switzerland','CH','CHE','756','EMEA','Western Europe','None','EFTA','CHF',5.80),
 (27,'Austria','AT','AUT','040','EMEA','Western Europe','None','EU','EUR',9.10),
 (28,'Turkey','TR','TUR','792','EMEA','Western Asia','Partial','Customs-Union','TRY',48.70),
 (29,'Russia','RU','RUS','643','EMEA','Eastern Europe','Comprehensive','EAEU','RUB',88.40),
 (30,'Ukraine','UA','UKR','804','EMEA','Eastern Europe','Partial','DCFTA','UAH',76.20),
 (31,'South Africa','ZA','ZAF','710','Africa','Southern Africa','None','AfCFTA','ZAR',44.90),
 (32,'Nigeria','NG','NGA','566','Africa','Western Africa','None','AfCFTA','NGN',61.30),
 (33,'Kenya','KE','KEN','404','Africa','Eastern Africa','None','AfCFTA','KES',49.80),
 (34,'Egypt','EG','EGY','818','Africa','Northern Africa','None','AfCFTA','EGP',55.10),
 (35,'Morocco','MA','MAR','504','Africa','Northern Africa','None','AfCFTA','MAD',33.60),
 (36,'Saudi Arabia','SA','SAU','682','EMEA','Western Asia','None','GCC','SAR',31.20),
 (37,'United Arab Emirates','AE','ARE','784','EMEA','Western Asia','None','GCC','AED',19.40),
 (38,'Israel','IL','ISR','376','EMEA','Western Asia','None','None','ILS',36.80),
 (39,'China','CN','CHN','156','Asia-Pacific','Eastern Asia','Partial','RCEP','CNY',57.60),
 (40,'Japan','JP','JPN','392','Asia-Pacific','Eastern Asia','None','RCEP','JPY',10.70),
 (41,'South Korea','KR','KOR','410','Asia-Pacific','Eastern Asia','None','RCEP','KRW',15.30),
 (42,'Taiwan','TW','TWN','158','Asia-Pacific','Eastern Asia','None','None','TWD',34.20),
 (43,'Hong Kong','HK','HKG','344','Asia-Pacific','Eastern Asia','None','RCEP','HKD',28.90),
 (44,'Singapore','SG','SGP','702','Asia-Pacific','South-Eastern Asia','None','ASEAN','SGD',6.20),
 (45,'Malaysia','MY','MYS','458','Asia-Pacific','South-Eastern Asia','None','ASEAN','MYR',24.60),
 (46,'Thailand','TH','THA','764','Asia-Pacific','South-Eastern Asia','None','ASEAN','THB',30.10),
 (47,'Vietnam','VN','VNM','704','Asia-Pacific','South-Eastern Asia','None','ASEAN','VND',35.70),
 (48,'Indonesia','ID','IDN','360','Asia-Pacific','South-Eastern Asia','None','ASEAN','IDR',37.90),
 (49,'Philippines','PH','PHL','608','Asia-Pacific','South-Eastern Asia','None','ASEAN','PHP',42.30),
 (50,'India','IN','IND','356','South Asia','Southern Asia','None','SAFTA','INR',40.80)
AS c(country_id, country_name, iso_alpha2, iso_alpha3, iso_numeric,
     region_name, sub_region, sanctions_status, trade_bloc, currency_code, risk_rating);


-- =============================================================================
-- 2. COMMODITY — 200 rows = 20 real HS chapters x 10 subheadings.
--    Scenario "Tariff shock" targets HS Chapter 85 (electrical machinery).
--    Scenario 7 (ESG / forced labour) targets textile chapters 52, 61, 62.
-- =============================================================================
INSERT INTO COMMODITY (
    commodity_id, hs_code, commodity_description, hs_section, hs_chapter,
    hs_chapter_description, esg_risk_flag, export_control_flag,
    forced_labor_flag, dual_use_flag,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH chapters AS (
    SELECT * FROM VALUES
      ('27','V','Mineral fuels, mineral oils and products of their distillation',TRUE ,FALSE,FALSE),
      ('28','VI','Inorganic chemicals; compounds of precious metals',TRUE ,TRUE ,TRUE ),
      ('29','VI','Organic chemicals',TRUE ,TRUE ,TRUE ),
      ('38','VI','Miscellaneous chemical products',TRUE ,TRUE ,FALSE),
      ('39','VII','Plastics and articles thereof',TRUE ,FALSE,FALSE),
      ('40','VII','Rubber and articles thereof',FALSE,FALSE,FALSE),
      ('44','IX','Wood and articles of wood; wood charcoal',TRUE ,FALSE,FALSE),
      ('48','X','Paper and paperboard; articles of paper pulp',FALSE,FALSE,FALSE),
      ('52','XI','Cotton',TRUE ,FALSE,FALSE),
      ('61','XI','Articles of apparel and clothing accessories, knitted',TRUE ,FALSE,FALSE),
      ('62','XI','Articles of apparel and clothing accessories, not knitted',TRUE ,FALSE,FALSE),
      ('72','XV','Iron and steel',TRUE ,FALSE,FALSE),
      ('73','XV','Articles of iron or steel',FALSE,FALSE,FALSE),
      ('74','XV','Copper and articles thereof',TRUE ,FALSE,FALSE),
      ('76','XV','Aluminium and articles thereof',TRUE ,FALSE,FALSE),
      ('81','XV','Other base metals; cermets; articles thereof',TRUE ,TRUE ,TRUE ),
      ('84','XVI','Nuclear reactors, boilers, machinery and mechanical appliances',FALSE,TRUE ,TRUE ),
      ('85','XVI','Electrical machinery and equipment and parts thereof',FALSE,TRUE ,TRUE ),
      ('87','XVII','Vehicles other than railway or tramway rolling stock',FALSE,FALSE,FALSE),
      ('90','XVIII','Optical, photographic, measuring, medical instruments',FALSE,TRUE ,TRUE )
    AS ch(hs_chapter, hs_section, hs_chapter_description,
          esg_base, export_base, dual_base)
),
sub AS (
    SELECT SEQ4() AS k FROM TABLE(GENERATOR(ROWCOUNT => 10))
),
gen AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY ch.hs_chapter, sub.k)              AS commodity_id,
        ch.hs_chapter || LPAD(TO_VARCHAR((sub.k + 1) * 101), 4, '0')   AS hs_code,
        ch.hs_chapter_description || ' — subheading '
            || LPAD(TO_VARCHAR((sub.k + 1) * 101), 4, '0')             AS commodity_description,
        ch.hs_section,
        ch.hs_chapter,
        ch.hs_chapter_description,
        ch.esg_base    AND MOD(sub.k, 2) = 0                           AS esg_risk_flag,
        ch.export_base AND MOD(sub.k, 3) <> 2                          AS export_control_flag,
        -- Forced-labour exposure concentrated in textiles (Scenario 7)
        (ch.hs_chapter IN ('52','61','62') AND MOD(sub.k, 2) = 0)      AS forced_labor_flag,
        ch.dual_base   AND MOD(sub.k, 4) = 0                           AS dual_use_flag
    FROM chapters ch CROSS JOIN sub
)
SELECT commodity_id, hs_code, commodity_description, hs_section, hs_chapter,
       hs_chapter_description, esg_risk_flag, export_control_flag,
       forced_labor_flag, dual_use_flag,
       $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
       'COMMODITY:' || hs_code, 99.00, 'VERIFIED'
FROM gen;


-- =============================================================================
-- 3. COMPLIANCE_LIST — 500 restriction entries across 5 real list programmes.
--    Scenario "New sanctions" adds entries dated 2024-09 (month 9).
-- =============================================================================
INSERT INTO COMPLIANCE_LIST (
    list_entry_id, list_source, listed_entity_name, listed_entity_type,
    country_id, restriction_type, effective_date, expiration_date, basis, aliases,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH seq AS (
    SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 500))
),
gen AS (
    SELECT
        n,
        ABS(HASH(n, 'cl_src'))  AS h_src,
        ABS(HASH(n, 'cl_type')) AS h_type,
        ABS(HASH(n, 'cl_ctry')) AS h_ctry,
        ABS(HASH(n, 'cl_rest')) AS h_rest,
        ABS(HASH(n, 'cl_date')) AS h_date
    FROM seq
),
shaped AS (
    SELECT
        n AS list_entry_id,
        DECODE(MOD(h_src, 5),
               0,'OFAC-SDN', 1,'EU-Sanctions', 2,'BIS-Entity-List',
               3,'UFLPA', 'UN-Sanctions')                          AS list_source,
        DECODE(MOD(h_type, 4),
               0,'Organization', 1,'Individual', 2,'Vessel', 'Commodity') AS listed_entity_type,
        -- Restricted parties concentrate in higher-risk jurisdictions
        CASE WHEN MOD(n, 3) = 0 THEN 1 + MOD(h_ctry, 50)
             ELSE DECODE(MOD(h_ctry, 6), 0,29, 1,30, 2,28, 3,39, 4,32, 34)
        END                                                          AS country_id,
        DECODE(MOD(h_rest, 4),
               0,'Full-Block', 1,'Partial-Restriction',
               2,'License-Required', 'Monitoring')                   AS restriction_type,
        DATEADD(day, MOD(h_date, 730), $win_start)                   AS effective_date
    FROM gen
)
SELECT
    s.list_entry_id,
    s.list_source,
    CASE s.listed_entity_type
         WHEN 'Individual'   THEN 'Restricted Person ' || s.list_entry_id
         WHEN 'Vessel'       THEN 'MV ' || c.country_name || ' Trader ' || s.list_entry_id
         WHEN 'Commodity'    THEN 'Controlled Commodity Group ' || s.list_entry_id
         ELSE UPPER(LEFT(c.iso_alpha3,3)) || ' Industrial Holdings ' || s.list_entry_id || ' Ltd'
    END                                                              AS listed_entity_name,
    s.listed_entity_type,
    s.country_id,
    s.restriction_type,
    s.effective_date,
    CASE WHEN MOD(s.list_entry_id, 5) = 0
         THEN DATEADD(day, 365, s.effective_date) END                AS expiration_date,
    CASE s.list_source
         WHEN 'OFAC-SDN'        THEN 'Executive Order 13382 — proliferation activities'
         WHEN 'EU-Sanctions'    THEN 'Council Regulation (EU) restrictive measures'
         WHEN 'BIS-Entity-List' THEN '15 CFR Part 744 — national security concern'
         WHEN 'UFLPA'           THEN 'Uyghur Forced Labor Prevention Act rebuttable presumption'
         ELSE 'UN Security Council Resolution designation'
    END                                                              AS basis,
    'ALIAS-' || s.list_entry_id || 'A;ALIAS-' || s.list_entry_id || 'B' AS aliases,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'COMPLIANCE_LIST:' || s.list_entry_id, 97.50, 'VERIFIED'
FROM shaped s
JOIN COUNTRY c ON c.country_id = s.country_id;


-- #############################################################################
-- LAYER 2 — MASTER ENTITIES (FK to COUNTRY / COMMODITY)
-- #############################################################################

-- =============================================================================
-- 4. SUPPLIER — 1,000 rows.
--    Pareto tiering: supplier_id 1..50 are Strategic (top decile of spend).
--    Scenario 1 seed: supplier_id = 7 is "NanoTech Precision Ltd" (Taiwan,
--    Strategic) — the sole-source supplier that goes dark on 2025-09-01.
--    Scenario 7 seed: suppliers 201-205 carry the forced-labour ESG finding.
-- =============================================================================
INSERT INTO SUPPLIER (
    supplier_id, supplier_name, supplier_duns, supplier_lei, supplier_status,
    supplier_tier, country_id, city, state_province, industry_code,
    industry_description, year_established, employee_count, annual_revenue_usd,
    primary_contact_name, primary_contact_email, primary_contact_phone, website_url,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH seq AS (
    SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 1000))
),
gen AS (
    SELECT n,
           ABS(HASH(n,'sup_ctry')) AS h_ctry,
           ABS(HASH(n,'sup_ind'))  AS h_ind,
           ABS(HASH(n,'sup_yr'))   AS h_yr,
           ABS(HASH(n,'sup_emp'))  AS h_emp,
           ABS(HASH(n,'sup_rev'))  AS h_rev,
           ABS(HASH(n,'sup_city')) AS h_city,
           ABS(HASH(n,'sup_stat')) AS h_stat
    FROM seq
),
shaped AS (
    SELECT
        n AS supplier_id,
        -- Scenario 1 protagonist is pinned to Taiwan (country_id 42)
        CASE WHEN n = 7 THEN 42 ELSE 1 + MOD(h_ctry, 50) END        AS country_id,
        CASE WHEN n <= 50  THEN 'Strategic'
             WHEN n <= 200 THEN 'Preferred'
             WHEN n <= 700 THEN 'Approved'
             ELSE 'Transactional' END                               AS supplier_tier,
        -- 3% of the base is not Active, giving the compliance/risk stories teeth
        CASE WHEN MOD(h_stat, 100) < 2  THEN 'Blocked'
             WHEN MOD(h_stat, 100) < 5  THEN 'Probation'
             WHEN MOD(h_stat, 100) < 8  THEN 'Deactivated'
             WHEN MOD(h_stat, 100) < 25 THEN 'Qualified'
             ELSE 'Active' END                                      AS supplier_status,
        DECODE(MOD(h_ind, 8),
               0,'333514', 1,'334413', 2,'336390', 3,'325199',
               4,'331110', 5,'326199', 6,'335999', '332710')        AS industry_code,
        DECODE(MOD(h_ind, 8),
               0,'Special Die and Tool Manufacturing',
               1,'Semiconductor and Related Device Manufacturing',
               2,'Motor Vehicle Parts Manufacturing',
               3,'Basic Organic Chemical Manufacturing',
               4,'Iron and Steel Mills',
               5,'Plastics Product Manufacturing',
               6,'Electrical Equipment Manufacturing',
               'Machine Shops')                                     AS industry_description,
        1950 + MOD(h_yr, 72)                                        AS year_established,
        n, h_emp, h_rev, h_city
    FROM gen
)
SELECT
    s.supplier_id,
    CASE WHEN s.supplier_id = 7 THEN 'NanoTech Precision Ltd'
         ELSE DECODE(MOD(s.h_city, 10),
                0,'Apex ', 1,'Vertex ', 2,'Nova ', 3,'Prime ', 4,'Delta ',
                5,'Summit ', 6,'Pinnacle ', 7,'Catalyst ', 8,'Meridian ', 'Vanguard ')
              || c.country_name || ' '
              || DECODE(MOD(s.h_city, 6),
                   0,'Components', 1,'Industries', 2,'Manufacturing',
                   3,'Materials', 4,'Technologies', 'Fabrication')
              || ' ' || s.supplier_id
    END                                                             AS supplier_name,
    LPAD(TO_VARCHAR(100000000 + s.supplier_id * 7919), 9, '0')      AS supplier_duns,
    'LEI' || LPAD(TO_VARCHAR(s.supplier_id * 104729), 17, '0')      AS supplier_lei,
    s.supplier_status,
    s.supplier_tier,
    s.country_id,
    c.country_name || ' Industrial Park '
        || TO_VARCHAR(1 + MOD(s.h_city, 40))                        AS city,
    'Region-' || TO_VARCHAR(1 + MOD(s.h_city, 12))                  AS state_province,
    s.industry_code,
    s.industry_description,
    s.year_established,
    -- Log-normal-ish headcount: strategic suppliers are materially larger
    CASE WHEN s.supplier_tier = 'Strategic'    THEN 2000 + MOD(s.h_emp, 48000)
         WHEN s.supplier_tier = 'Preferred'    THEN  500 + MOD(s.h_emp, 4500)
         WHEN s.supplier_tier = 'Approved'     THEN   80 + MOD(s.h_emp, 900)
         ELSE 10 + MOD(s.h_emp, 200) END                            AS employee_count,
    ROUND(
      CASE WHEN s.supplier_tier = 'Strategic' THEN 250000000 + MOD(s.h_rev, 4750000000)
           WHEN s.supplier_tier = 'Preferred' THEN  40000000 + MOD(s.h_rev, 210000000)
           WHEN s.supplier_tier = 'Approved'  THEN   5000000 + MOD(s.h_rev, 35000000)
           ELSE 250000 + MOD(s.h_rev, 4750000) END, 2)              AS annual_revenue_usd,
    'Contact ' || s.supplier_id                                     AS primary_contact_name,
    'supplier' || s.supplier_id || '@'
        || LOWER(c.iso_alpha3) || '-supply.example.com'             AS primary_contact_email,
    '+' || TO_VARCHAR(1 + MOD(s.h_city, 98)) || '-555-'
        || LPAD(TO_VARCHAR(MOD(s.h_city, 10000)), 4, '0')           AS primary_contact_phone,
    'https://www.supplier' || s.supplier_id || '.example.com'       AS website_url,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'SUPPLIER:' || s.supplier_id,
    ROUND(85 + MOD(s.h_emp, 15) + MOD(s.h_rev, 100) / 100.0, 2),
    'HIGH'
FROM shaped s
JOIN COUNTRY c ON c.country_id = s.country_id;


-- =============================================================================
-- 5. CUSTOMER — 2,000 rows. Pareto: customer_id 1..200 are the top decile
--    that will place ~60% of orders.
-- =============================================================================
INSERT INTO CUSTOMER (
    customer_id, customer_name, customer_duns, customer_type, market_segment,
    country_id, city, state_province, postal_code, account_balance_usd,
    credit_status, service_level_tier, customer_since_date,
    primary_contact_name, primary_contact_email,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH seq AS (
    SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 2000))
),
gen AS (
    SELECT n,
           ABS(HASH(n,'cus_ctry')) AS h_ctry,
           ABS(HASH(n,'cus_seg'))  AS h_seg,
           ABS(HASH(n,'cus_bal'))  AS h_bal,
           ABS(HASH(n,'cus_cred')) AS h_cred,
           ABS(HASH(n,'cus_date')) AS h_date,
           ABS(HASH(n,'cus_city')) AS h_city
    FROM seq
)
SELECT
    g.n                                                             AS customer_id,
    DECODE(MOD(g.h_city, 10),
        0,'Northwind ', 1,'Beacon ', 2,'Harbor ', 3,'Ironclad ', 4,'Redwood ',
        5,'Silverline ', 6,'Blue Ridge ', 7,'Keystone ', 8,'Crestview ', 'Lakeshore ')
      || DECODE(MOD(g.h_seg, 6),
           0,'Automotive', 1,'Aerospace', 2,'Electronics',
           3,'Industrial', 4,'Healthcare', 'Consumer')
      || ' ' || DECODE(MOD(g.h_city, 5),
           0,'Group', 1,'Holdings', 2,'Corporation', 3,'Partners', 'Systems')
      || ' ' || g.n                                                 AS customer_name,
    LPAD(TO_VARCHAR(200000000 + g.n * 6551), 9, '0')                AS customer_duns,
    CASE WHEN g.n <= 200 THEN 'B2B-Enterprise'
         ELSE DECODE(MOD(g.h_seg, 4),
                0,'B2B-Enterprise', 1,'B2B-SMB', 2,'Distributor', 'Government')
    END                                                             AS customer_type,
    DECODE(MOD(g.h_seg, 8),
        0,'Automotive', 1,'Aerospace & Defense', 2,'Consumer Electronics',
        3,'Industrial Machinery', 4,'Medical Devices', 5,'Energy & Utilities',
        6,'Telecommunications', 'Retail & Consumer Goods')          AS market_segment,
    1 + MOD(g.h_ctry, 50)                                           AS country_id,
    'Metro ' || TO_VARCHAR(1 + MOD(g.h_city, 60))                   AS city,
    'Province-' || TO_VARCHAR(1 + MOD(g.h_city, 15))                AS state_province,
    LPAD(TO_VARCHAR(MOD(g.h_city, 99999)), 5, '0')                  AS postal_code,
    ROUND(MOD(g.h_bal, 8000000) / 100.0, 2)                         AS account_balance_usd,
    CASE WHEN MOD(g.h_cred, 100) < 2  THEN 'Blocked'
         WHEN MOD(g.h_cred, 100) < 6  THEN 'Hold'
         WHEN MOD(g.h_cred, 100) < 18 THEN 'Watch'
         ELSE 'Good-Standing' END                                   AS credit_status,
    CASE WHEN g.n <= 50   THEN 'Platinum'
         WHEN g.n <= 200  THEN 'Gold'
         WHEN g.n <= 700  THEN 'Silver'
         ELSE 'Standard' END                                        AS service_level_tier,
    DATEADD(day, -MOD(g.h_date, 5475), $win_start)                  AS customer_since_date,
    'Buyer ' || g.n                                                 AS primary_contact_name,
    'buyer' || g.n || '@customer' || g.n || '.example.com'          AS primary_contact_email,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'CUSTOMER:' || g.n,
    ROUND(88 + MOD(g.h_bal, 12) + MOD(g.h_cred, 100) / 100.0, 2),
    'HIGH'
FROM gen g;


-- =============================================================================
-- 6. CARRIER — 50 rows. Top 5 carriers will move ~50% of shipments.
-- =============================================================================
INSERT INTO CARRIER (
    carrier_id, carrier_name, carrier_code, carrier_type, primary_mode,
    country_id, contract_status, on_time_rate_pct, damage_rate_pct,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH seq AS (
    SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 50))
),
gen AS (
    SELECT n,
           ABS(HASH(n,'car_ctry')) AS h_ctry,
           ABS(HASH(n,'car_otd'))  AS h_otd,
           ABS(HASH(n,'car_dmg'))  AS h_dmg
    FROM seq
)
SELECT
    g.n                                                             AS carrier_id,
    DECODE(MOD(g.n, 10),
        0,'Pacific Line ', 1,'AeroFreight ', 2,'TransContinental ', 3,'BlueWave ',
        4,'RailLink ', 5,'SwiftParcel ', 6,'GlobalBridge ', 7,'Meridian Cargo ',
        8,'NorthStar Logistics ', 'IronRoad ')
      || 'Carrier ' || g.n                                          AS carrier_name,
    UPPER(LEFT(DECODE(MOD(g.n, 10),
        0,'PACL',1,'AERF',2,'TRCT',3,'BLWV',4,'RLNK',
        5,'SWPC',6,'GLBR',7,'MRDC',8,'NSLG','IRRD'), 4))
      || LPAD(TO_VARCHAR(g.n), 2, '0')                              AS carrier_code,
    DECODE(MOD(g.n, 7),
        0,'Ocean-Line', 1,'Air-Freight', 2,'Truckload', 3,'LTL',
        4,'Rail', 5,'Parcel', 'Intermodal')                         AS carrier_type,
    DECODE(MOD(g.n, 7),
        0,'Ocean', 1,'Air', 2,'Road', 3,'Road',
        4,'Rail', 5,'Air', 'Ocean')                                 AS primary_mode,
    1 + MOD(g.h_ctry, 50)                                           AS country_id,
    CASE WHEN MOD(g.n, 17) = 0 THEN 'Under-Negotiation'
         WHEN MOD(g.n, 23) = 0 THEN 'Expired'
         ELSE 'Active' END                                          AS contract_status,
    ROUND(78 + MOD(g.h_otd, 2000) / 100.0, 2)                       AS on_time_rate_pct,
    ROUND(MOD(g.h_dmg, 400) / 100.0, 2)                             AS damage_rate_pct,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'CARRIER:' || g.n, 96.00, 'HIGH'
FROM gen g;


-- =============================================================================
-- 7. PORT — 80 rows. Scenario 3 (Port Congestion, 2024-08..2024-09) is seeded
--    by setting port_id 3 and 11 to congestion_status = 'Severe'.
-- =============================================================================
INSERT INTO PORT (
    port_id, port_name, un_locode, port_type, country_id, city,
    latitude, longitude, avg_dwell_days, congestion_status,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH seq AS (
    SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 80))
),
gen AS (
    SELECT n,
           ABS(HASH(n,'prt_ctry')) AS h_ctry,
           ABS(HASH(n,'prt_lat'))  AS h_lat,
           ABS(HASH(n,'prt_lon'))  AS h_lon,
           ABS(HASH(n,'prt_dwl'))  AS h_dwl
    FROM seq
)
SELECT
    g.n                                                             AS port_id,
    c.country_name || ' '
      || DECODE(MOD(g.n, 4), 0,'International Seaport',
                             1,'International Airport',
                             2,'Inland Terminal', 'Border Crossing')
      || ' ' || g.n                                                 AS port_name,
    c.iso_alpha2 || LPAD(TO_VARCHAR(MOD(g.n * 37, 1000)), 3, '0')   AS un_locode,
    DECODE(MOD(g.n, 4), 0,'Seaport', 1,'Airport',
                        2,'Inland-Port', 'Land-Border')             AS port_type,
    g.n_country                                                     AS country_id,
    'Port City ' || g.n                                             AS city,
    ROUND(-60 + MOD(g.h_lat, 12000) / 100.0, 6)                     AS latitude,
    ROUND(-180 + MOD(g.h_lon, 36000) / 100.0, 6)                    AS longitude,
    -- Congested gateways dwell far longer (Scenario 3)
    CASE WHEN g.n IN (3, 11) THEN ROUND(9 + MOD(g.h_dwl, 600) / 100.0, 2)
         ELSE ROUND(1 + MOD(g.h_dwl, 500) / 100.0, 2) END           AS avg_dwell_days,
    CASE WHEN g.n IN (3, 11)     THEN 'Severe'
         WHEN MOD(g.n, 9) = 0    THEN 'Elevated'
         ELSE 'Normal' END                                          AS congestion_status,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'PORT:' || g.n, 98.00, 'VERIFIED'
FROM (SELECT g.*, 1 + MOD(g.h_ctry, 50) AS n_country FROM gen g) g
JOIN COUNTRY c ON c.country_id = g.n_country;


-- =============================================================================
-- 8. PART — 5,000 rows. Pareto: part_id 1..1000 are the fast movers that will
--    carry ~80% of line volume. Parts 101-112 are Scenario 1 sole-source items.
-- =============================================================================
INSERT INTO PART (
    part_id, part_number, part_name, gtin, manufacturer_name, brand,
    part_category, part_type, commodity_id, unit_of_measure,
    unit_weight_kg, unit_volume_m3, standard_cost_usd, retail_price_usd,
    lifecycle_status, container_type,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH seq AS (
    SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 5000))
),
gen AS (
    SELECT n,
           ABS(HASH(n,'prt_cmdy')) AS h_cmdy,
           ABS(HASH(n,'prt_cat'))  AS h_cat,
           ABS(HASH(n,'prt_wt'))   AS h_wt,
           ABS(HASH(n,'prt_cost')) AS h_cost,
           ABS(HASH(n,'prt_life')) AS h_life
    FROM seq
),
shaped AS (
    SELECT n,
        -- Scenario 1 parts are forced into HS chapter 85 (commodity 171..180)
        CASE WHEN n BETWEEN 101 AND 112 THEN 171 + MOD(n, 10)
             ELSE 1 + MOD(h_cmdy, 200) END                          AS commodity_id,
        DECODE(MOD(h_cat, 10),
            0,'Semiconductors', 1,'Passive Components', 2,'Connectors',
            3,'Fasteners', 4,'Castings', 5,'Bearings', 6,'Wiring Harnesses',
            7,'Enclosures', 8,'Polymers', 'Sub-Assemblies')         AS part_category,
        DECODE(MOD(h_cat, 4),
            0,'Raw-Material', 1,'Component', 2,'Sub-Assembly',
            'Finished-Good')                                        AS part_type,
        ROUND(0.0050 + MOD(h_wt, 500000) / 10000.0, 4)              AS unit_weight_kg,
        ROUND(0.000010 + MOD(h_wt, 250000) / 1000000.0, 6)          AS unit_volume_m3,
        -- Log-normal-ish cost: cheap high-runners, expensive long tail
        ROUND(CASE WHEN MOD(h_cost, 100) < 60 THEN 0.5000 + MOD(h_cost, 5000)  / 100.0
                   WHEN MOD(h_cost, 100) < 90 THEN 50.0000 + MOD(h_cost, 95000) / 100.0
                   ELSE 1000.0000 + MOD(h_cost, 4000000) / 100.0
              END, 4)                                               AS standard_cost_usd,
        h_life, h_cat, h_cost, h_wt
    FROM gen
)
SELECT
    s.n                                                             AS part_id,
    'P-' || LPAD(TO_VARCHAR(s.n), 6, '0')                           AS part_number,
    s.part_category || ' '
      || DECODE(MOD(s.h_cat, 5), 0,'Type A', 1,'Type B', 2,'Type C',
                                 3,'Type D', 'Type E')
      || ' — ' || cm.hs_chapter_description
      || ' (' || s.part_number_seed || ')'                          AS part_name,
    LPAD(TO_VARCHAR(8000000000000 + s.n * 1301), 14, '0')           AS gtin,
    'Manufacturer ' || TO_VARCHAR(1 + MOD(s.h_cat, 250))            AS manufacturer_name,
    DECODE(MOD(s.h_cat, 8), 0,'Axion', 1,'Corevex', 2,'Duratek', 3,'Elytra',
                            4,'Ferralux', 5,'Grendix', 6,'Halcyon', 'Ionex') AS brand,
    s.part_category,
    s.part_type,
    s.commodity_id,
    DECODE(MOD(s.h_wt_mod, 5), 0,'KG', 1,'M', 2,'L', 3,'LB', 'EA')  AS unit_of_measure,
    s.unit_weight_kg,
    s.unit_volume_m3,
    s.standard_cost_usd,
    ROUND(s.standard_cost_usd * (1.25 + MOD(s.h_cost, 75) / 100.0), 4) AS retail_price_usd,
    CASE WHEN MOD(s.h_life, 100) < 3  THEN 'Obsolete'
         WHEN MOD(s.h_life, 100) < 8  THEN 'End-of-Life'
         WHEN MOD(s.h_life, 100) < 11 THEN 'Prototype'
         ELSE 'Active' END                                          AS lifecycle_status,
    DECODE(MOD(s.h_wt_mod, 5), 0,'Drum', 1,'Pallet', 2,'Carton',
                               3,'Bulk', 'Tray')                    AS container_type,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'PART:' || s.n,
    ROUND(90 + MOD(s.h_cost, 10) + MOD(s.h_life, 100) / 100.0, 2),
    'HIGH'
FROM (
    SELECT s.*,
           MOD(s.h_wt, 5)                    AS h_wt_mod,
           'P-' || LPAD(TO_VARCHAR(s.n), 6, '0') AS part_number_seed
    FROM shaped s
) s
JOIN COMMODITY cm ON cm.commodity_id = s.commodity_id;


-- =============================================================================
-- 9. WAREHOUSE — 30 rows. Warehouses 1..3 hold the dense inventory grid.
-- =============================================================================
INSERT INTO WAREHOUSE (
    warehouse_id, warehouse_name, warehouse_code, warehouse_type, country_id,
    city, state_province, address, capacity_sqft, operational_status,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH seq AS (
    SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 30))
),
gen AS (
    SELECT n,
           ABS(HASH(n,'wh_ctry')) AS h_ctry,
           ABS(HASH(n,'wh_cap'))  AS h_cap
    FROM seq
)
SELECT
    g.n                                                             AS warehouse_id,
    c.country_name || ' Distribution Center ' || g.n                AS warehouse_name,
    'WH-' || LPAD(TO_VARCHAR(g.n), 3, '0')                          AS warehouse_code,
    DECODE(MOD(g.n, 5), 0,'Owned', 1,'3PL', 2,'Cross-Dock',
                        3,'Cold-Storage', 'Bonded')                 AS warehouse_type,
    g.n_country                                                     AS country_id,
    'Logistics Hub ' || g.n                                         AS city,
    'Zone-' || TO_VARCHAR(1 + MOD(g.h_cap, 8))                      AS state_province,
    TO_VARCHAR(100 + MOD(g.h_cap, 9900)) || ' Distribution Parkway' AS address,
    50000 + MOD(g.h_cap, 950000)                                    AS capacity_sqft,
    CASE WHEN g.n = 29 THEN 'Seasonal'
         WHEN g.n = 30 THEN 'Closed'
         ELSE 'Active' END                                          AS operational_status,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'WAREHOUSE:' || g.n, 98.50, 'VERIFIED'
FROM (SELECT g.*, 1 + MOD(g.h_ctry, 50) AS n_country FROM gen g) g
JOIN COUNTRY c ON c.country_id = g.n_country;


-- =============================================================================
-- 10. PLANT — 150 rows. plant_id 1 belongs to supplier 7 (Scenario 1 fire site).
-- =============================================================================
INSERT INTO PLANT (
    plant_id, plant_name, plant_code, supplier_id, country_id, city,
    state_province, plant_type, capacity_units_per_day, operational_status,
    year_commissioned, certifications,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH seq AS (
    SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 150))
),
gen AS (
    SELECT n,
           ABS(HASH(n,'pl_sup')) AS h_sup,
           ABS(HASH(n,'pl_cap')) AS h_cap,
           ABS(HASH(n,'pl_yr'))  AS h_yr
    FROM seq
),
shaped AS (
    SELECT n,
           CASE WHEN n = 1 THEN 7 ELSE 1 + MOD(h_sup, 1000) END     AS supplier_id,
           h_cap, h_yr
    FROM gen
)
SELECT
    s.n                                                             AS plant_id,
    sup.supplier_name || ' Plant ' || s.n                           AS plant_name,
    'PL-' || LPAD(TO_VARCHAR(s.n), 4, '0')                          AS plant_code,
    s.supplier_id,
    sup.country_id,
    'Industrial Zone ' || TO_VARCHAR(1 + MOD(s.h_cap, 30))          AS city,
    'District-' || TO_VARCHAR(1 + MOD(s.h_cap, 10))                 AS state_province,
    DECODE(MOD(s.n, 5), 0,'Manufacturing', 1,'Assembly', 2,'Processing',
                        3,'Testing', 'Packaging')                   AS plant_type,
    1000 + MOD(s.h_cap, 99000)                                      AS capacity_units_per_day,
    -- Scenario 1: the sole-source plant is idle from the 2025-09 fire onward
    CASE WHEN s.n = 1            THEN 'Idle'
         WHEN MOD(s.n, 37) = 0   THEN 'Under-Construction'
         WHEN MOD(s.n, 43) = 0   THEN 'Decommissioned'
         ELSE 'Operational' END                                     AS operational_status,
    1975 + MOD(s.h_yr, 48)                                          AS year_commissioned,
    'ISO9001;ISO14001'
      || IFF(MOD(s.h_yr, 3) = 0, ';IATF16949', '')
      || IFF(MOD(s.h_yr, 4) = 0, ';AS9100', '')                     AS certifications,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'PLANT:' || s.n, 97.00, 'HIGH'
FROM shaped s
JOIN SUPPLIER sup ON sup.supplier_id = s.supplier_id;


-- =============================================================================
-- 11. ROUTE — 200 rows. Routes through ports 3 / 11 inherit the congestion
--     penalty that drives Scenario 2 and 3.
-- =============================================================================
INSERT INTO ROUTE (
    route_id, route_name, origin_port_id, destination_port_id,
    origin_country_id, destination_country_id, primary_mode, distance_km,
    avg_transit_days, avg_cost_per_kg_usd, reliability_pct, active_carriers_count,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH seq AS (
    SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 200))
),
gen AS (
    SELECT n,
           ABS(HASH(n,'rt_op'))   AS h_op,
           ABS(HASH(n,'rt_dp'))   AS h_dp,
           ABS(HASH(n,'rt_dist')) AS h_dist,
           ABS(HASH(n,'rt_rel'))  AS h_rel
    FROM seq
),
shaped AS (
    SELECT n,
           1 + MOD(h_op, 80)                                        AS origin_port_id,
           1 + MOD(h_op * 7 + h_dp, 80)                             AS destination_port_id_raw,
           h_dist, h_rel
    FROM gen
),
fixed AS (
    SELECT n, origin_port_id,
           IFF(destination_port_id_raw = origin_port_id,
               1 + MOD(origin_port_id, 80),
               destination_port_id_raw)                             AS destination_port_id,
           h_dist, h_rel
    FROM shaped
)
SELECT
    f.n                                                             AS route_id,
    po.port_name || ' → ' || pd.port_name                           AS route_name,
    f.origin_port_id,
    f.destination_port_id,
    po.country_id                                                   AS origin_country_id,
    pd.country_id                                                   AS destination_country_id,
    DECODE(MOD(f.n, 5), 0,'Ocean', 1,'Air', 2,'Road',
                        3,'Rail', 'Intermodal')                     AS primary_mode,
    ROUND(200 + MOD(f.h_dist, 1900000) / 100.0, 2)                  AS distance_km,
    -- Air is fast, ocean is slow; congested gateways add ~10 days (Scenario 3)
    ROUND(
      CASE MOD(f.n, 5)
           WHEN 1 THEN 2  + MOD(f.h_dist, 400) / 100.0
           WHEN 0 THEN 18 + MOD(f.h_dist, 2200) / 100.0
           WHEN 3 THEN 9  + MOD(f.h_dist, 900) / 100.0
           ELSE        4  + MOD(f.h_dist, 700) / 100.0 END
      + IFF(f.origin_port_id IN (3,11) OR f.destination_port_id IN (3,11), 10, 0)
    , 2)                                                            AS avg_transit_days,
    ROUND(
      CASE MOD(f.n, 5)
           WHEN 1 THEN 3.5000 + MOD(f.h_dist, 25000) / 10000.0
           WHEN 0 THEN 0.1500 + MOD(f.h_dist, 6000)  / 10000.0
           WHEN 3 THEN 0.4000 + MOD(f.h_dist, 9000)  / 10000.0
           ELSE        0.8000 + MOD(f.h_dist, 14000) / 10000.0 END
    , 4)                                                            AS avg_cost_per_kg_usd,
    ROUND(
      GREATEST(55.00,
        (70 + MOD(f.h_rel, 2900) / 100.0)
        - IFF(f.origin_port_id IN (3,11) OR f.destination_port_id IN (3,11), 18, 0))
    , 2)                                                            AS reliability_pct,
    1 + MOD(f.h_rel, 12)                                            AS active_carriers_count,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'ROUTE:' || f.n, 95.00, 'HIGH'
FROM fixed f
JOIN PORT po ON po.port_id = f.origin_port_id
JOIN PORT pd ON pd.port_id = f.destination_port_id;


-- #############################################################################
-- LAYER 3 — BRIDGE / RELATIONSHIP TABLES
-- #############################################################################

-- =============================================================================
-- 12. SUPPLIER_CATALOG — 15,000 rows (supplier x part offers).
--     This is the master sourcing table: ORDER_LINE_ITEM draws (supplier, part)
--     pairs from here, which is what makes "you cannot order what isn't
--     offered" hold true in the generated data.
--     PK (supplier_id, part_id) is collision-free: for a fixed supplier the
--     part step 997 is coprime with 5000, so 15 draws never repeat.
-- =============================================================================
INSERT INTO SUPPLIER_CATALOG (
    supplier_id, part_id, supply_cost_usd, lead_time_days, available_quantity,
    minimum_order_quantity, preferred_flag, last_quoted_date,
    contract_reference, catalog_status,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH seq AS (
    SELECT SEQ4() AS k FROM TABLE(GENERATOR(ROWCOUNT => 15000))
),
pairs AS (
    SELECT
        1 + MOD(k, 1000)                                            AS supplier_id,
        1 + MOD((MOD(k, 1000) * 131 + FLOOR(k / 1000) * 997), 5000) AS part_id,
        k
    FROM seq
),
gen AS (
    SELECT p.supplier_id, p.part_id, p.k,
           ABS(HASH(p.supplier_id, p.part_id, 'sc_lt'))   AS h_lt,
           ABS(HASH(p.supplier_id, p.part_id, 'sc_qty'))  AS h_qty,
           ABS(HASH(p.supplier_id, p.part_id, 'sc_cost')) AS h_cost,
           ABS(HASH(p.supplier_id, p.part_id, 'sc_date')) AS h_date
    FROM pairs p
)
SELECT
    g.supplier_id,
    g.part_id,
    -- Quoted cost sits within +/-15% of the part's standard cost
    ROUND(pt.standard_cost_usd * (0.85 + MOD(g.h_cost, 30) / 100.0), 4) AS supply_cost_usd,
    -- Lead time follows the shipping distance reality of the supplier's region
    CASE WHEN c.region_name = 'Asia-Pacific' THEN 21 + MOD(g.h_lt, 45)
         WHEN c.region_name = 'South Asia'   THEN 25 + MOD(g.h_lt, 50)
         WHEN c.region_name = 'EMEA'         THEN 10 + MOD(g.h_lt, 30)
         WHEN c.region_name = 'Africa'       THEN 20 + MOD(g.h_lt, 40)
         ELSE 5 + MOD(g.h_lt, 21) END                                AS lead_time_days,
    ROUND(100 + MOD(g.h_qty, 500000), 2)                             AS available_quantity,
    ROUND(DECODE(MOD(g.h_qty, 5), 0,1, 1,10, 2,25, 3,100, 500), 2)   AS minimum_order_quantity,
    (MOD(g.h_cost, 4) = 0)                                           AS preferred_flag,
    DATEADD(day, -MOD(g.h_date, 365), $win_end)                      AS last_quoted_date,
    'CTR-' || LPAD(TO_VARCHAR(g.supplier_id), 4, '0')
        || '-' || LPAD(TO_VARCHAR(MOD(g.h_date, 9999)), 4, '0')      AS contract_reference,
    CASE WHEN MOD(g.h_qty, 50) = 0 THEN 'Inactive'
         WHEN MOD(g.h_qty, 71) = 0 THEN 'Pending'
         ELSE 'Active' END                                           AS catalog_status,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'SUPPLIER_CATALOG:' || g.supplier_id || ':' || g.part_id,
    ROUND(90 + MOD(g.h_cost, 10), 2), 'HIGH'
FROM gen g
JOIN PART     pt  ON pt.part_id      = g.part_id
JOIN SUPPLIER sup ON sup.supplier_id = g.supplier_id
JOIN COUNTRY  c   ON c.country_id    = sup.country_id;


-- =============================================================================
-- 13. PLANT_PART_ASSIGNMENT — 3,000 rows. Step 331 vs modulus 5000 keeps the
--     20 parts drawn per plant distinct.
-- =============================================================================
INSERT INTO PLANT_PART_ASSIGNMENT (
    plant_id, part_id, production_capacity_per_day, yield_rate_pct,
    qualification_status, qualification_date, manufacturing_cost_usd,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH seq AS (
    SELECT SEQ4() AS k FROM TABLE(GENERATOR(ROWCOUNT => 3000))
),
pairs AS (
    SELECT 1 + MOD(k, 150)                                          AS plant_id,
           1 + MOD((MOD(k, 150) * 71 + FLOOR(k / 150) * 331), 5000) AS part_id
    FROM seq
),
gen AS (
    SELECT p.plant_id, p.part_id,
           ABS(HASH(p.plant_id, p.part_id, 'pp_cap'))   AS h_cap,
           ABS(HASH(p.plant_id, p.part_id, 'pp_yield')) AS h_yield,
           ABS(HASH(p.plant_id, p.part_id, 'pp_qual'))  AS h_qual
    FROM pairs p
)
SELECT
    g.plant_id, g.part_id,
    100 + MOD(g.h_cap, 20000)                                       AS production_capacity_per_day,
    ROUND(80 + MOD(g.h_yield, 1999) / 100.0, 2)                     AS yield_rate_pct,
    CASE WHEN MOD(g.h_qual, 100) < 5  THEN 'Disqualified'
         WHEN MOD(g.h_qual, 100) < 12 THEN 'Under-Review'
         WHEN MOD(g.h_qual, 100) < 20 THEN 'Pending'
         ELSE 'Qualified' END                                       AS qualification_status,
    DATEADD(day, -MOD(g.h_qual, 1460), $win_end)                    AS qualification_date,
    ROUND(pt.standard_cost_usd * (0.55 + MOD(g.h_cap, 30) / 100.0), 4) AS manufacturing_cost_usd,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'PLANT_PART:' || g.plant_id || ':' || g.part_id,
    ROUND(91 + MOD(g.h_yield, 9), 2), 'HIGH'
FROM gen g
JOIN PART pt ON pt.part_id = g.part_id;


-- =============================================================================
-- 14. CARRIER_ROUTE_SERVICE — 500 rows. Step 47 vs modulus 200 keeps the
--     10 routes drawn per carrier distinct.
-- =============================================================================
INSERT INTO CARRIER_ROUTE_SERVICE (
    carrier_id, route_id, service_frequency, contracted_rate_usd_per_kg,
    average_transit_days, on_time_pct, capacity_teu_per_sailing, service_name,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH seq AS (
    SELECT SEQ4() AS k FROM TABLE(GENERATOR(ROWCOUNT => 500))
),
pairs AS (
    SELECT 1 + MOD(k, 50)                                         AS carrier_id,
           1 + MOD((MOD(k, 50) * 13 + FLOOR(k / 50) * 47), 200)   AS route_id
    FROM seq
),
gen AS (
    SELECT p.carrier_id, p.route_id,
           ABS(HASH(p.carrier_id, p.route_id, 'crs_rate')) AS h_rate,
           ABS(HASH(p.carrier_id, p.route_id, 'crs_otd'))  AS h_otd,
           ABS(HASH(p.carrier_id, p.route_id, 'crs_cap'))  AS h_cap
    FROM pairs p
)
SELECT
    g.carrier_id, g.route_id,
    DECODE(MOD(g.h_cap, 5), 0,'Daily', 1,'Weekly', 2,'Bi-weekly',
                            3,'Monthly', 'On-demand')               AS service_frequency,
    ROUND(r.avg_cost_per_kg_usd * (0.80 + MOD(g.h_rate, 50) / 100.0), 4)
                                                                    AS contracted_rate_usd_per_kg,
    ROUND(r.avg_transit_days * (0.90 + MOD(g.h_otd, 30) / 100.0), 2) AS average_transit_days,
    ROUND(LEAST(99.50, GREATEST(60.00,
        car.on_time_rate_pct * (0.95 + MOD(g.h_otd, 12) / 100.0))), 2) AS on_time_pct,
    IFF(r.primary_mode IN ('Ocean','Intermodal'), 500 + MOD(g.h_cap, 23500), NULL)
                                                                    AS capacity_teu_per_sailing,
    car.carrier_name || ' ' || DECODE(MOD(g.h_cap, 4),
        0,'Express Service', 1,'Standard Service',
        2,'Economy Service', 'Priority Service')                    AS service_name,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'CARRIER_ROUTE:' || g.carrier_id || ':' || g.route_id,
    ROUND(92 + MOD(g.h_rate, 8), 2), 'HIGH'
FROM gen g
JOIN ROUTE   r   ON r.route_id     = g.route_id
JOIN CARRIER car ON car.carrier_id = g.carrier_id;


-- =============================================================================
-- 15. SUPPLIER_COMPLIANCE_MATCH — 150 rows across 30 flagged suppliers.
--     Confidence is bimodal: true positives 85-99, false positives 40-65.
-- =============================================================================
INSERT INTO SUPPLIER_COMPLIANCE_MATCH (
    supplier_id, list_entry_id, match_confidence_pct, match_type, match_date,
    resolution_status, resolved_by, resolution_date,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH seq AS (
    SELECT SEQ4() AS k FROM TABLE(GENERATOR(ROWCOUNT => 150))
),
pairs AS (
    SELECT 1 + MOD(k, 30) * 13                                    AS supplier_id,
           1 + MOD((MOD(k, 30) * 17 + FLOOR(k / 30) * 89), 500)   AS list_entry_id,
           k
    FROM seq
),
gen AS (
    SELECT p.supplier_id, p.list_entry_id, p.k,
           ABS(HASH(p.supplier_id, p.list_entry_id, 'scm_conf')) AS h_conf,
           ABS(HASH(p.supplier_id, p.list_entry_id, 'scm_type')) AS h_type,
           ABS(HASH(p.supplier_id, p.list_entry_id, 'scm_res'))  AS h_res
    FROM pairs p
),
shaped AS (
    SELECT g.*,
           (MOD(g.h_conf, 100) < 30) AS is_true_positive
    FROM gen g
)
SELECT
    s.supplier_id, s.list_entry_id,
    ROUND(IFF(s.is_true_positive,
              85 + MOD(s.h_conf, 1400) / 100.0,
              40 + MOD(s.h_conf, 2500) / 100.0), 2)                 AS match_confidence_pct,
    DECODE(MOD(s.h_type, 20),
        0,'Exact-Name', 1,'Exact-Name', 2,'Exact-Name', 3,'Exact-Name',
        4,'Address', 5,'Address', 6,'Address', 7,'Address', 8,'Address',
        9,'Ownership-Chain', 10,'Ownership-Chain', 11,'Ownership-Chain',
        'Alias')                                                    AS match_type,
    DATEADD(day, MOD(s.h_res, 700), $win_start)                     AS match_date,
    CASE WHEN s.is_true_positive AND MOD(s.h_res, 4) = 0 THEN 'Confirmed-Match'
         WHEN s.is_true_positive                          THEN 'Escalated'
         WHEN MOD(s.h_res, 100) < 25                      THEN 'Unresolved'
         ELSE 'False-Positive' END                                  AS resolution_status,
    IFF(MOD(s.h_res, 100) < 25, NULL,
        'Compliance Analyst ' || TO_VARCHAR(1 + MOD(s.h_res, 12)))   AS resolved_by,
    IFF(MOD(s.h_res, 100) < 25, NULL,
        DATEADD(day, MOD(s.h_res, 700) + 14, $win_start))            AS resolution_date,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'SUP_COMPLIANCE:' || s.supplier_id || ':' || s.list_entry_id,
    ROUND(93 + MOD(s.h_conf, 7), 2), 'HIGH'
FROM shaped s
JOIN SUPPLIER       sup ON sup.supplier_id  = s.supplier_id
JOIN COMPLIANCE_LIST cl ON cl.list_entry_id = s.list_entry_id;


-- =============================================================================
-- 16. CUSTOMER_COMPLIANCE_MATCH — 80 rows across 40 flagged customers.
-- =============================================================================
INSERT INTO CUSTOMER_COMPLIANCE_MATCH (
    customer_id, list_entry_id, match_confidence_pct, match_type, match_date,
    resolution_status, resolved_by, resolution_date, order_hold_triggered,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH seq AS (
    SELECT SEQ4() AS k FROM TABLE(GENERATOR(ROWCOUNT => 80))
),
pairs AS (
    SELECT 1 + MOD(k, 40) * 47                                    AS customer_id,
           1 + MOD((MOD(k, 40) * 23 + FLOOR(k / 40) * 113), 500)  AS list_entry_id
    FROM seq
),
gen AS (
    SELECT p.customer_id, p.list_entry_id,
           ABS(HASH(p.customer_id, p.list_entry_id, 'ccm_conf')) AS h_conf,
           ABS(HASH(p.customer_id, p.list_entry_id, 'ccm_type')) AS h_type,
           ABS(HASH(p.customer_id, p.list_entry_id, 'ccm_res'))  AS h_res
    FROM pairs p
),
shaped AS (
    SELECT g.*, (MOD(g.h_conf, 100) < 25) AS is_true_positive FROM gen g
)
SELECT
    s.customer_id, s.list_entry_id,
    ROUND(IFF(s.is_true_positive,
              85 + MOD(s.h_conf, 1400) / 100.0,
              40 + MOD(s.h_conf, 2500) / 100.0), 2)                 AS match_confidence_pct,
    DECODE(MOD(s.h_type, 20),
        0,'Exact-Name', 1,'Exact-Name', 2,'Exact-Name', 3,'Exact-Name',
        4,'Address', 5,'Address', 6,'Address', 7,'Address', 8,'Address',
        9,'Ownership-Chain', 10,'Ownership-Chain', 11,'Ownership-Chain',
        'Alias')                                                    AS match_type,
    DATEADD(day, MOD(s.h_res, 700), $win_start)                     AS match_date,
    CASE WHEN s.is_true_positive AND MOD(s.h_res, 4) = 0 THEN 'Confirmed-Match'
         WHEN s.is_true_positive                          THEN 'Escalated'
         WHEN MOD(s.h_res, 100) < 25                      THEN 'Unresolved'
         ELSE 'False-Positive' END                                  AS resolution_status,
    IFF(MOD(s.h_res, 100) < 25, NULL,
        'Compliance Analyst ' || TO_VARCHAR(1 + MOD(s.h_res, 12)))   AS resolved_by,
    IFF(MOD(s.h_res, 100) < 25, NULL,
        DATEADD(day, MOD(s.h_res, 700) + 21, $win_start))            AS resolution_date,
    (s.is_true_positive AND MOD(s.h_res, 3) = 0)                    AS order_hold_triggered,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'CUST_COMPLIANCE:' || s.customer_id || ':' || s.list_entry_id,
    ROUND(93 + MOD(s.h_conf, 7), 2), 'HIGH'
FROM shaped s
JOIN CUSTOMER        cu ON cu.customer_id   = s.customer_id
JOIN COMPLIANCE_LIST cl ON cl.list_entry_id = s.list_entry_id;


-- =============================================================================
-- 17. COMMODITY_RESTRICTION — 100 rows. Only commodities that actually carry a
--     control flag are restricted, per the design's business rule.
-- =============================================================================
INSERT INTO COMMODITY_RESTRICTION (
    commodity_id, list_entry_id, restriction_scope, license_type_required,
    destination_countries_blocked, control_reason, eccn,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH controlled AS (
    SELECT commodity_id,
           ROW_NUMBER() OVER (ORDER BY commodity_id) AS rn
    FROM COMMODITY
    WHERE export_control_flag OR dual_use_flag OR forced_labor_flag
),
seq AS (
    SELECT SEQ4() AS k FROM TABLE(GENERATOR(ROWCOUNT => 100))
),
pairs AS (
    SELECT c.commodity_id,
           1 + MOD((c.commodity_id * 29 + FLOOR(s.k / 50) * 181), 500) AS list_entry_id
    FROM seq s
    JOIN controlled c
      ON c.rn = 1 + MOD(s.k, (SELECT COUNT(*) FROM controlled))
),
deduped AS (
    SELECT commodity_id, list_entry_id
    FROM pairs
    GROUP BY commodity_id, list_entry_id
),
gen AS (
    SELECT d.commodity_id, d.list_entry_id,
           ABS(HASH(d.commodity_id, d.list_entry_id, 'crst_sc'))  AS h_sc,
           ABS(HASH(d.commodity_id, d.list_entry_id, 'crst_lic')) AS h_lic,
           ABS(HASH(d.commodity_id, d.list_entry_id, 'crst_cty')) AS h_cty
    FROM deduped d
)
SELECT
    g.commodity_id, g.list_entry_id,
    DECODE(MOD(g.h_sc, 10), 0,'Import-Only', 1,'Import-Only',
        2,'Both', 3,'Both', 4,'Both', 'Export-Only')                AS restriction_scope,
    DECODE(MOD(g.h_lic, 20),
        0,'Denial-Presumption', 1,'Denial-Presumption', 2,'Denial-Presumption',
        3,'Denial-Presumption', 4,'Denial-Presumption',
        5,'General', 6,'General', 7,'General', 8,'General', 9,'General',
        10,'General', 11,'General', 'Individual')                   AS license_type_required,
    blk.blocked_list                                                AS destination_countries_blocked,
    DECODE(MOD(g.h_lic, 4), 0,'National Security', 1,'Anti-Terrorism',
                            2,'Regional Stability', 'Nonproliferation') AS control_reason,
    TO_VARCHAR(1 + MOD(g.h_sc, 9))
      || DECODE(MOD(g.h_sc, 5), 0,'A', 1,'B', 2,'D', 3,'E', 'C')
      || TO_VARCHAR(100 + MOD(g.h_lic, 900))                        AS eccn,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'COMMODITY_RESTRICTION:' || g.commodity_id || ':' || g.list_entry_id,
    ROUND(94 + MOD(g.h_sc, 6), 2), 'VERIFIED'
FROM gen g
JOIN COMPLIANCE_LIST cl ON cl.list_entry_id = g.list_entry_id
CROSS JOIN (
    SELECT LISTAGG(iso_alpha2, ',') WITHIN GROUP (ORDER BY country_id) AS blocked_list
    FROM COUNTRY
    WHERE sanctions_status <> 'None'
) blk;


-- #############################################################################
-- LAYER 4 — ASSESSMENTS (temporal, FK to SUPPLIER / PLANT)
-- #############################################################################

-- =============================================================================
-- 18. SUPPLIER_RISK_ASSESSMENT — quarterly assessments for the first 500
--     suppliers across 8 quarters = 4,000 rows.
--     PK (supplier_id, assessment_date) is unique by construction.
--     Scenario 6 (Risk Events 2024-04..2024-06): suppliers in sanctioned or
--     high-risk countries get a geopolitical spike in Q2 2024.
--     Scenario 1: supplier 7 deteriorates sharply from Q3 2025.
-- =============================================================================
INSERT INTO SUPPLIER_RISK_ASSESSMENT (
    supplier_id, assessment_date, overall_risk_score, financial_risk_score,
    operational_risk_score, geopolitical_risk_score, compliance_risk_score,
    concentration_risk_score, risk_category, risk_trend, mitigation_action,
    next_review_date,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH quarters AS (
    SELECT SEQ4() AS q FROM TABLE(GENERATOR(ROWCOUNT => 8))
),
suppliers AS (
    SELECT supplier_id, country_id, supplier_tier
    FROM SUPPLIER
    WHERE supplier_id <= 500
),
grid AS (
    SELECT s.supplier_id, s.country_id, s.supplier_tier, q.q,
           DATEADD(quarter, q.q, $win_start) AS assessment_date
    FROM suppliers s CROSS JOIN quarters q
),
scored AS (
    SELECT g.*,
           c.risk_rating, c.sanctions_status,
           ABS(HASH(g.supplier_id, g.q, 'ra_fin')) AS h_fin,
           ABS(HASH(g.supplier_id, g.q, 'ra_ops')) AS h_ops,
           ABS(HASH(g.supplier_id, g.q, 'ra_cmp')) AS h_cmp,
           ABS(HASH(g.supplier_id, g.q, 'ra_con')) AS h_con,
           -- Scenario 6 window: Q2 2024 geopolitical escalation
           IFF(g.assessment_date BETWEEN '2024-04-01' AND '2024-06-30'
               AND (c.sanctions_status <> 'None' OR c.risk_rating > 45), 22, 0) AS geo_shock,
           -- Scenario 1 window: supplier 7 collapse from Q3 2025
           IFF(g.supplier_id = 7 AND g.assessment_date >= '2025-07-01', 35, 0)  AS fire_shock
    FROM grid g
    JOIN COUNTRY c ON c.country_id = g.country_id
),
components AS (
    SELECT s.*,
        ROUND(LEAST(100, 8 + MOD(s.h_fin, 45) + s.fire_shock), 2)                       AS financial_risk_score,
        ROUND(LEAST(100, 10 + MOD(s.h_ops, 40) + s.fire_shock), 2)                      AS operational_risk_score,
        ROUND(LEAST(100, s.risk_rating * 0.6 + MOD(s.h_cmp, 25) + s.geo_shock), 2)      AS geopolitical_risk_score,
        ROUND(LEAST(100, 5 + MOD(s.h_cmp, 38)
              + IFF(s.sanctions_status = 'Comprehensive', 30, 0)), 2)                   AS compliance_risk_score,
        ROUND(LEAST(100, IFF(s.supplier_tier = 'Strategic', 45, 12)
              + MOD(s.h_con, 35) + s.fire_shock), 2)                                    AS concentration_risk_score
    FROM scored s
),
final AS (
    SELECT c.*,
           ROUND((c.financial_risk_score * 0.20 + c.operational_risk_score * 0.25
                + c.geopolitical_risk_score * 0.20 + c.compliance_risk_score * 0.20
                + c.concentration_risk_score * 0.15), 2)            AS overall_risk_score
    FROM components c
)
SELECT
    f.supplier_id,
    f.assessment_date,
    f.overall_risk_score,
    f.financial_risk_score,
    f.operational_risk_score,
    f.geopolitical_risk_score,
    f.compliance_risk_score,
    f.concentration_risk_score,
    CASE WHEN f.overall_risk_score >= 70 THEN 'Critical'
         WHEN f.overall_risk_score >= 50 THEN 'High'
         WHEN f.overall_risk_score >= 30 THEN 'Medium'
         ELSE 'Low' END                                             AS risk_category,
    CASE WHEN f.fire_shock > 0 OR f.geo_shock > 0 THEN 'Deteriorating'
         WHEN MOD(f.h_fin, 3) = 0                 THEN 'Improving'
         ELSE 'Stable' END                                          AS risk_trend,
    CASE WHEN f.overall_risk_score >= 70
              THEN 'Qualify alternate source; enforce weekly business review'
         WHEN f.overall_risk_score >= 50
              THEN 'Increase safety stock; quarterly on-site audit'
         WHEN f.overall_risk_score >= 30
              THEN 'Standard monitoring; annual reassessment'
         ELSE 'No action required' END                              AS mitigation_action,
    DATEADD(quarter, 1, f.assessment_date)                          AS next_review_date,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'SUPPLIER_RISK:' || f.supplier_id || ':' || TO_VARCHAR(f.assessment_date),
    ROUND(92 + MOD(f.h_ops, 8), 2), 'HIGH'
FROM final f;


-- =============================================================================
-- 19. ESG_SCORE — 3,000 rows. Polymorphism is resolved per the approved design:
--     exactly ONE of supplier_id / plant_id is non-NULL on every row.
--     2,400 supplier-level rows (300 suppliers x 8 quarters)
--       + 600 plant-level rows (75 plants x 8 quarters).
--     Scenario 7 (Forced Labour Discovery, 2025-04..2025-06): suppliers
--     201-205 drop hard on the social score and raise controversy_flag.
--     These IDs must fall inside the 300-supplier ESG cohort below, or the
--     scenario generates nothing and the demo query returns zero rows.
-- =============================================================================
INSERT INTO ESG_SCORE (
    esg_score_id, supplier_id, plant_id, scoring_period, overall_esg_score,
    environmental_score, social_score, governance_score, carbon_intensity,
    forced_labor_risk, controversy_flag, data_source,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH quarters AS (
    SELECT SEQ4() AS q FROM TABLE(GENERATOR(ROWCOUNT => 8))
),
supplier_rows AS (
    SELECT
        s.supplier_id                                   AS supplier_id,
        NULL::INTEGER                                   AS plant_id,
        q.q,
        DATEADD(quarter, q.q, $win_start)               AS scoring_period,
        (s.supplier_id - 1) * 8 + q.q + 1               AS esg_score_id
    FROM (SELECT supplier_id FROM SUPPLIER WHERE supplier_id <= 300) s
    CROSS JOIN quarters q
),
plant_rows AS (
    SELECT
        NULL::INTEGER                                   AS supplier_id,
        p.plant_id                                      AS plant_id,
        q.q,
        DATEADD(quarter, q.q, $win_start)               AS scoring_period,
        100000 + (p.plant_id - 1) * 8 + q.q + 1         AS esg_score_id
    FROM (SELECT plant_id FROM PLANT WHERE plant_id <= 75) p
    CROSS JOIN quarters q
),
unioned AS (
    SELECT * FROM supplier_rows
    UNION ALL
    SELECT * FROM plant_rows
),
scored AS (
    SELECT u.*,
        ABS(HASH(u.esg_score_id, 'esg_e')) AS h_e,
        ABS(HASH(u.esg_score_id, 'esg_s')) AS h_s,
        ABS(HASH(u.esg_score_id, 'esg_g')) AS h_g,
        ABS(HASH(u.esg_score_id, 'esg_c')) AS h_c,
        -- COALESCE is load-bearing. On plant rows supplier_id IS NULL, so
        -- BETWEEN returns NULL, which propagates into NOT NULL controversy_flag.
        COALESCE(u.supplier_id BETWEEN 201 AND 205
                 AND u.scoring_period >= '2025-04-01', FALSE) AS is_forced_labor_event
    FROM unioned u
),
components AS (
    SELECT s.*,
        ROUND(40 + MOD(s.h_e, 5500) / 100.0, 2)                                  AS environmental_score,
        ROUND(IFF(s.is_forced_labor_event,
                  8 + MOD(s.h_s, 1500) / 100.0,
                  45 + MOD(s.h_s, 5000) / 100.0), 2)                             AS social_score,
        ROUND(50 + MOD(s.h_g, 4800) / 100.0, 2)                                  AS governance_score,
        ROUND(20 + MOD(s.h_c, 48000) / 100.0, 2)                                 AS carbon_intensity
    FROM scored s
)
SELECT
    c.esg_score_id,
    c.supplier_id,
    c.plant_id,
    c.scoring_period,
    ROUND((c.environmental_score + c.social_score + c.governance_score) / 3.0, 2) AS overall_esg_score,
    c.environmental_score,
    c.social_score,
    c.governance_score,
    c.carbon_intensity,
    CASE WHEN c.is_forced_labor_event    THEN 'High'
         WHEN c.social_score < 55        THEN 'Medium'
         WHEN c.social_score < 70        THEN 'Low'
         ELSE 'None' END                                            AS forced_labor_risk,
    COALESCE(c.is_forced_labor_event OR MOD(c.h_g, 100) < 6, FALSE) AS controversy_flag,
    DECODE(MOD(c.h_e, 4), 0,'EcoVadis', 1,'Sustainalytics',
                          2,'MSCI ESG', 'CDP Disclosure')           AS data_source,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'ESG:' || c.esg_score_id,
    ROUND(89 + MOD(c.h_c, 11), 2), 'HIGH'
FROM components c;


-- #############################################################################
-- LAYER 5 — TRANSACTIONS
--
-- "AS-OF" DATE: order lifecycle status is assigned relative to $win_end
-- (2025-12-31), the last day of the synthetic window — NOT relative to the
-- real wall-clock date. Without this the entire two-year history would age
-- into 'Closed' and the open-order pipeline would vanish.
-- #############################################################################

-- =============================================================================
-- 20. PURCHASE_ORDER — 50,000 rows.
--   * Customer concentration: top 200 customers (10%) take ~60% of orders.
--   * Supplier concentration: only Active suppliers that actually publish a
--     catalog are eligible to fulfil.
--   * Credit gate: Blocked / Hold customers cannot place orders.
--   * order_date is a business day (Mon–Fri) with seasonal weighting.
--   * total_value_usd is left NULL here and back-filled from the line items
--     once they exist, so header and lines can never disagree.
-- =============================================================================
INSERT INTO PURCHASE_ORDER (
    order_id, order_number, customer_id, supplier_id, order_date,
    requested_delivery_date, order_status, order_priority, total_value_usd,
    currency_code, payment_terms, incoterm, channel,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH seq AS (
    SELECT SEQ4() + 1 AS n FROM TABLE(GENERATOR(ROWCOUNT => 50000))
),
eligible_customers AS (
    SELECT customer_id,
           ROW_NUMBER() OVER (ORDER BY customer_id) AS rn,
           COUNT(*)    OVER ()                      AS cnt
    FROM CUSTOMER
    WHERE credit_status IN ('Good-Standing','Watch')
),
top_customers AS (
    SELECT customer_id,
           ROW_NUMBER() OVER (ORDER BY customer_id) AS rn,
           COUNT(*)    OVER ()                      AS cnt
    FROM CUSTOMER
    WHERE credit_status IN ('Good-Standing','Watch')
      AND customer_id <= 200
),
eligible_suppliers AS (
    SELECT s.supplier_id,
           ROW_NUMBER() OVER (ORDER BY s.supplier_id) AS rn,
           COUNT(*)    OVER ()                        AS cnt
    FROM SUPPLIER s
    WHERE s.supplier_status IN ('Active','Qualified')
      AND EXISTS (SELECT 1 FROM SUPPLIER_CATALOG sc
                   WHERE sc.supplier_id = s.supplier_id
                     AND sc.catalog_status = 'Active')
),
pool_sizes AS (
    SELECT (SELECT MAX(cnt) FROM eligible_customers) AS all_cust_cnt,
           (SELECT MAX(cnt) FROM top_customers)      AS top_cust_cnt,
           (SELECT MAX(cnt) FROM eligible_suppliers) AS sup_cnt
),
gen AS (
    SELECT n,
           ABS(HASH(n,'po_cust'))  AS h_cust,
           ABS(HASH(n,'po_sup'))   AS h_sup,
           ABS(HASH(n,'po_day'))   AS h_day,
           ABS(HASH(n,'po_prio'))  AS h_prio,
           ABS(HASH(n,'po_chan'))  AS h_chan,
           ABS(HASH(n,'po_lead'))  AS h_lead,
           ABS(HASH(n,'po_stat'))  AS h_stat
    FROM seq
),
dated AS (
    SELECT g.*,
        -- Seasonal weighting: pull ~18% of orders into the Mar/Sep/Oct peaks
        -- and push them out of the Jan/Jul/Aug troughs.
        DATEADD(day,
            CASE WHEN MOD(g.h_day, 100) < 18
                 THEN DECODE(MOD(g.h_day, 6), 0, 60, 1, 75, 2, 250,
                                              3, 270, 4, 425, 635)
                      + MOD(g.h_day, 30)
                 ELSE MOD(g.h_day, 730) END,
            $win_start)                                             AS raw_order_date
    FROM gen g
),
business_dated AS (
    SELECT d.*,
        -- Shift Saturday (+2) and Sunday (+1) forward onto a business day
        DATEADD(day,
            DECODE(DAYOFWEEKISO(d.raw_order_date), 6, 2, 7, 1, 0),
            d.raw_order_date)                                       AS order_date
    FROM dated d
),
-- Pareto target: 60% of orders land on the top-200 customer cohort,
-- 55% on the first 150 eligible suppliers.
keyed AS (
    SELECT b.*,
           ps.all_cust_cnt, ps.top_cust_cnt, ps.sup_cnt,
           (MOD(b.h_cust, 100) < 60)                                AS use_top_cohort,
           1 + MOD(b.h_cust, ps.top_cust_cnt)                       AS top_cust_rn,
           1 + MOD(b.h_cust, ps.all_cust_cnt)                       AS all_cust_rn,
           1 + MOD(IFF(MOD(b.h_sup, 100) < 55, MOD(b.h_sup, 150), b.h_sup),
                   ps.sup_cnt)                                      AS sup_rn
    FROM business_dated b
    CROSS JOIN pool_sizes ps
),
assigned AS (
    SELECT k.*,
           COALESCE(tc.customer_id, ec.customer_id)                 AS customer_id,
           es.supplier_id                                           AS supplier_id,
           DATEDIFF(day, k.order_date, $win_end)                    AS age_at_asof
    FROM keyed k
    LEFT JOIN top_customers      tc ON k.use_top_cohort AND tc.rn = k.top_cust_rn
    LEFT JOIN eligible_customers ec ON ec.rn = k.all_cust_rn
    JOIN      eligible_suppliers es ON es.rn = k.sup_rn
)
SELECT
    a.n                                                             AS order_id,
    'PO-' || TO_VARCHAR(YEAR(a.order_date))
        || '-' || LPAD(TO_VARCHAR(a.n), 7, '0')                     AS order_number,
    a.customer_id,
    a.supplier_id,
    a.order_date,
    DATEADD(day, 7 + MOD(a.h_lead, 54), a.order_date)               AS requested_delivery_date,
    -- Lifecycle status as of $win_end. Scenario 1: orders placed on the
    -- disrupted supplier after the 2025-09-01 fire are heavily cancelled.
    CASE
      WHEN a.supplier_id = 7 AND a.order_date >= '2025-09-01'
           AND MOD(a.h_stat, 100) < 45                          THEN 'Cancelled'
      WHEN a.age_at_asof > 60 THEN
           CASE WHEN MOD(a.h_stat, 100) < 80 THEN 'Closed'
                WHEN MOD(a.h_stat, 100) < 85 THEN 'Cancelled'
                ELSE 'Delivered' END
      WHEN a.age_at_asof > 15 THEN
           CASE WHEN MOD(a.h_stat, 100) < 40 THEN 'In-Transit'
                WHEN MOD(a.h_stat, 100) < 75 THEN 'Delivered'
                WHEN MOD(a.h_stat, 100) < 90 THEN 'Confirmed'
                WHEN MOD(a.h_stat, 100) < 95 THEN 'Cancelled'
                ELSE 'Open' END
      ELSE
           CASE WHEN MOD(a.h_stat, 100) < 40 THEN 'Open'
                WHEN MOD(a.h_stat, 100) < 75 THEN 'Confirmed'
                WHEN MOD(a.h_stat, 100) < 95 THEN 'In-Transit'
                ELSE 'Cancelled' END
    END                                                             AS order_status,
    CASE WHEN MOD(a.h_prio, 100) < 5  THEN 'Urgent'
         WHEN MOD(a.h_prio, 100) < 20 THEN 'High'
         WHEN MOD(a.h_prio, 100) < 85 THEN 'Normal'
         ELSE 'Low' END                                             AS order_priority,
    NULL                                                            AS total_value_usd,
    'USD'                                                           AS currency_code,
    DECODE(MOD(a.h_chan, 5), 0,'Net-30', 1,'Net-30', 2,'Net-45',
                             3,'Net-60', 'Net-90')                  AS payment_terms,
    DECODE(MOD(a.h_chan, 20),
        0,'FOB',1,'FOB',2,'FOB',3,'FOB',4,'FOB',5,'FOB',6,'FOB',
        7,'CIF',8,'CIF',9,'CIF',10,'CIF',11,'CIF',
        12,'DDP',13,'DDP',14,'DDP',15,'DDP',
        16,'EXW',17,'EXW',18,'EXW','DAP')                           AS incoterm,
    CASE WHEN MOD(a.h_chan, 100) < 50 THEN 'EDI'
         WHEN MOD(a.h_chan, 100) < 80 THEN 'Direct'
         WHEN MOD(a.h_chan, 100) < 95 THEN 'Web'
         ELSE 'Catalog' END                                         AS channel,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'PURCHASE_ORDER:' || a.n,
    ROUND(93 + MOD(a.h_stat, 7), 2), 'HIGH'
FROM assigned a;


-- =============================================================================
-- 21. ORDER_LINE_ITEM — ~200,000 rows (50,000 orders, Poisson-shaped 1–25
--     lines, mean ≈ 4.0).
--
--   INTEGRITY: every (supplier_id, part_id) is drawn from that order's
--   supplier's own SUPPLIER_CATALOG rows, so the design rule "you cannot order
--   what isn't offered" holds by construction. The line supplier therefore
--   always equals the order supplier (the strategy's optional 5% drop-ship
--   variant is intentionally not generated, because it would break that rule).
--
--   OTD-CRITICAL: promised_delivery_date is the contractual commitment and
--   actual_receipt_date is the customer's confirmed receipt. Lateness is
--   injected by three scenario windows layered on a baseline ~88% on-time.
-- =============================================================================
INSERT INTO ORDER_LINE_ITEM (
    line_item_id, order_id, line_number, part_id, supplier_id,
    quantity_ordered, unit_price_usd, extended_price_usd, discount_percent,
    tax_percent, promised_ship_date, promised_delivery_date, actual_ship_date,
    actual_receipt_date, ship_mode, line_status,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH order_shape AS (
    SELECT po.order_id, po.supplier_id, po.customer_id, po.order_date,
           po.order_status, po.order_priority,
           -- Poisson-like line count, mean ~4.0, capped at 25
           CASE WHEN MOD(ABS(HASH(po.order_id,'lc')), 100) < 20 THEN 1
                WHEN MOD(ABS(HASH(po.order_id,'lc')), 100) < 70 THEN 2 + MOD(ABS(HASH(po.order_id,'lc2')), 3)
                WHEN MOD(ABS(HASH(po.order_id,'lc')), 100) < 95 THEN 5 + MOD(ABS(HASH(po.order_id,'lc2')), 4)
                ELSE 9 + MOD(ABS(HASH(po.order_id,'lc2')), 8) END AS line_count
    FROM PURCHASE_ORDER po
    WHERE po._batch_id = $sco_batch
),
exploded AS (
    SELECT o.order_id, o.supplier_id, o.customer_id, o.order_date,
           o.order_status, o.order_priority,
           f.index + 1 AS line_number
    FROM order_shape o,
         LATERAL FLATTEN(input => ARRAY_GENERATE_RANGE(0, o.line_count)) f
),
catalog_ranked AS (
    SELECT sc.supplier_id, sc.part_id, sc.supply_cost_usd, sc.lead_time_days,
           ROW_NUMBER() OVER (PARTITION BY sc.supplier_id ORDER BY sc.part_id) AS rn,
           COUNT(*)    OVER (PARTITION BY sc.supplier_id)                      AS cnt
    FROM SUPPLIER_CATALOG sc
    WHERE sc.catalog_status = 'Active'
),
picked AS (
    SELECT e.*,
           ABS(HASH(e.order_id, e.line_number, 'oli_part')) AS h_part,
           ABS(HASH(e.order_id, e.line_number, 'oli_qty'))  AS h_qty,
           ABS(HASH(e.order_id, e.line_number, 'oli_prc'))  AS h_prc,
           ABS(HASH(e.order_id, e.line_number, 'oli_disc')) AS h_disc,
           ABS(HASH(e.order_id, e.line_number, 'oli_tax'))  AS h_tax,
           ABS(HASH(e.order_id, e.line_number, 'oli_ship')) AS h_ship,
           ABS(HASH(e.order_id, e.line_number, 'oli_late')) AS h_late,
           ABS(HASH(e.order_id, e.line_number, 'oli_tr'))   AS h_tr
    FROM exploded e
),
joined AS (
    SELECT p.*, cr.part_id, cr.supply_cost_usd, cr.lead_time_days
    FROM picked p
    JOIN catalog_ranked cr
      ON cr.supplier_id = p.supplier_id
     AND cr.rn = 1 + MOD(p.h_part, cr.cnt)
),
priced AS (
    SELECT j.*,
        -- Quantity MUST stay inversely tied to unit cost (design rule: "raw
        -- materials = higher qty; finished goods = lower"). Decoupling them
        -- yields 100k units of a $41k part, whose duties overflow
        -- SHIPMENT.duties_usd NUMBER(10,2).
        -- Demand-spike windows: Scenario 5 (Jan-Feb 2025) and November.
        ROUND(
          CASE
            -- High-value parts move in small counts
            WHEN j.supply_cost_usd >= 1000 THEN 1 + MOD(j.h_qty, 50)
            WHEN j.supply_cost_usd >= 100  THEN 1 + MOD(j.h_qty, 500)
            WHEN j.supply_cost_usd >= 10   THEN 10 + MOD(j.h_qty, 3000)
            -- Cheap commodity/raw material moves in bulk
            ELSE 50 + MOD(j.h_qty, 20000)
          END
          * IFF( (j.order_date BETWEEN '2025-01-01' AND '2025-02-15')
                 OR MONTH(j.order_date) = 11, 2.0, 1.0)
        , 2)                                                        AS quantity_ordered,
        ROUND(j.supply_cost_usd * (0.95 + MOD(j.h_prc, 11) / 100.0), 4) AS unit_price_usd,
        -- Promised ship date honours the catalog lead time +/-20%
        DATEADD(day,
            GREATEST(1, ROUND(j.lead_time_days * (0.8 + MOD(j.h_ship, 41) / 100.0))),
            j.order_date)                                           AS promised_ship_date,
        -- Planned transit, mode-dependent
        CASE WHEN MOD(j.h_tr, 100) < 30 THEN 3  + MOD(j.h_tr, 4)
             WHEN MOD(j.h_tr, 100) < 60 THEN 7  + MOD(j.h_tr, 8)
             ELSE 18 + MOD(j.h_tr, 20) END                          AS planned_transit_days
    FROM joined j
),
delayed AS (
    SELECT p.*,
        -- Lateness in days applied to the actual ship date.
        -- Baseline: 88% on time or early, 12% late.
        (CASE WHEN MOD(p.h_late, 100) < 88
              THEN -1 * MOD(p.h_late, 3)
              ELSE 1 + MOD(p.h_late, 14) END)
        -- Scenario "late supplier cluster": 5 systematically late suppliers
        + IFF(p.supplier_id IN (13, 88, 217, 455, 806), 5, 0)
        -- Scenario 2 — Trans-Pacific lane degradation, 2024-08 .. 2024-10
        + IFF(p.order_date BETWEEN '2024-08-01' AND '2024-10-31'
              AND MOD(p.h_late, 3) = 0, 9, 0)
        -- Scenario 3 — Port congestion, 2024-08 .. 2024-09
        + IFF(p.order_date BETWEEN '2024-08-01' AND '2024-09-30'
              AND MOD(p.h_late, 4) = 0, 10, 0)
        -- Scenario 1 — Supplier 7 goes dark from 2025-09-01
        + IFF(p.supplier_id = 7 AND p.order_date >= '2025-09-01', 30, 0)
            AS ship_delay_days
    FROM priced p
),
finalized AS (
    SELECT d.*,
        DATEADD(day, d.ship_delay_days, d.promised_ship_date)       AS actual_ship_date_raw,
        DATEADD(day, d.planned_transit_days, d.promised_ship_date)  AS promised_delivery_date
    FROM delayed d
),
statused AS (
    SELECT f.*,
        -- 0.85..1.05, mean ~0.95. Tuned so the governed OTD lands in the
        -- 85-92% band the strategy specifies. OTD measures RECEIPT against
        -- promised delivery, so any transit mean above 1.0 eats the ship-date
        -- slack and collapses the metric. Re-tune only against a measured OTD.
        DATEADD(day,
            GREATEST(1, ROUND(f.planned_transit_days * (0.85 + MOD(f.h_tr, 21) / 100.0))),
            f.actual_ship_date_raw)                                 AS actual_receipt_date_raw
    FROM finalized f
)
SELECT
    ROW_NUMBER() OVER (ORDER BY s.order_id, s.line_number)          AS line_item_id,
    s.order_id,
    s.line_number,
    s.part_id,
    s.supplier_id,
    s.quantity_ordered,
    s.unit_price_usd,
    ROUND(s.quantity_ordered * s.unit_price_usd, 2)                 AS extended_price_usd,
    CASE WHEN MOD(s.h_disc, 100) < 60 THEN 0
         WHEN MOD(s.h_disc, 100) < 85 THEN ROUND(1 + MOD(s.h_disc, 5), 2)
         WHEN MOD(s.h_disc, 100) < 95 THEN ROUND(6 + MOD(s.h_disc, 5), 2)
         ELSE ROUND(11 + MOD(s.h_disc, 10), 2) END                  AS discount_percent,
    CASE WHEN MOD(s.h_tax, 100) < 30 THEN 0
         WHEN MOD(s.h_tax, 100) < 80 THEN ROUND(5 + MOD(s.h_tax, 6), 2)
         ELSE ROUND(15 + MOD(s.h_tax, 11), 2) END                   AS tax_percent,
    s.promised_ship_date,
    s.promised_delivery_date,
    -- Cancelled and not-yet-released lines carry no execution dates.
    CASE WHEN s.order_status = 'Cancelled'                  THEN NULL
         WHEN s.order_status IN ('Open','Confirmed')        THEN NULL
         WHEN s.actual_ship_date_raw > $win_end             THEN NULL
         ELSE s.actual_ship_date_raw END                            AS actual_ship_date,
    CASE WHEN s.order_status = 'Cancelled'                  THEN NULL
         WHEN s.order_status IN ('Open','Confirmed')        THEN NULL
         WHEN s.order_status = 'In-Transit'                 THEN NULL
         WHEN s.actual_ship_date_raw    > $win_end          THEN NULL
         WHEN s.actual_receipt_date_raw > $win_end          THEN NULL
         ELSE s.actual_receipt_date_raw END                         AS actual_receipt_date,
    CASE WHEN MOD(s.h_tr, 100) < 30 THEN 'Air'
         WHEN MOD(s.h_tr, 100) < 45 THEN 'Parcel'
         WHEN MOD(s.h_tr, 100) < 60 THEN 'Truck'
         WHEN MOD(s.h_tr, 100) < 70 THEN 'Rail'
         ELSE 'Ocean' END                                           AS ship_mode,
    CASE WHEN s.order_status = 'Cancelled'                   THEN 'Cancelled'
         WHEN s.order_status IN ('Open','Confirmed')         THEN 'Open'
         WHEN s.actual_ship_date_raw > $win_end              THEN 'Open'
         WHEN s.order_status = 'In-Transit'                  THEN 'Shipped'
         WHEN s.actual_receipt_date_raw > $win_end           THEN 'Shipped'
         WHEN MOD(s.h_late, 100) < 8                         THEN 'Returned'
         ELSE 'Received' END                                        AS line_status,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'ORDER_LINE:' || s.order_id || ':' || s.line_number,
    ROUND(92 + MOD(s.h_qty, 8), 2), 'HIGH'
FROM statused s;


-- Back-fill the order header value so header and lines always agree.
UPDATE PURCHASE_ORDER po
SET    total_value_usd = agg.order_value,
       _updated_at     = CURRENT_TIMESTAMP()
FROM ( SELECT order_id,
              ROUND(SUM(extended_price_usd
                        * (1 - discount_percent / 100.0)
                        * (1 + tax_percent      / 100.0)), 2) AS order_value
       FROM ORDER_LINE_ITEM
       WHERE _batch_id = $sco_batch
       GROUP BY order_id ) agg
WHERE po.order_id  = agg.order_id
  AND po._batch_id = $sco_batch;


-- =============================================================================
-- 22. SHIPMENT — ~74,000 rows.
--
--   DERIVATION: shipments are derived FROM the order lines that actually
--   shipped, never invented independently. Each order's shipped lines are
--   split into up to 3 fulfilment waves, giving ~1.7 lines per shipment and
--   landing on the ~75,000 target while keeping every date consistent with the
--   lines the shipment carries.
--
--   POLYMORPHISM: origin uses origin_supplier_id / origin_plant_id /
--   origin_warehouse_id and destination uses destination_customer_id /
--   destination_plant_id / destination_warehouse_id. Exactly one column per
--   side is populated, per the approved polymorphic resolution.
--
--   ROUTE CONSISTENCY: origin_country_id and destination_country_id are taken
--   FROM the chosen route, so the documented rule "shipment countries match
--   the route's countries" always holds. Routes are matched to the supplier's
--   own country wherever such a route exists.
--
--   Weights and costs are back-filled after SHIPMENT_LINE_ITEM exists.
-- =============================================================================
CREATE OR REPLACE TEMPORARY TABLE TMP_SHIPMENT_ASSIGNMENT AS
WITH shipped_lines AS (
    SELECT oli.line_item_id, oli.order_id, oli.supplier_id, oli.part_id,
           oli.quantity_ordered, oli.actual_ship_date, oli.actual_receipt_date,
           oli.line_status, oli.ship_mode,
           po.customer_id, po.order_status
    FROM ORDER_LINE_ITEM oli
    JOIN PURCHASE_ORDER  po ON po.order_id = oli.order_id
    WHERE oli._batch_id = $sco_batch
      AND oli.actual_ship_date IS NOT NULL
),
waved AS (
    SELECT sl.*,
           MOD(ABS(HASH(sl.order_id, sl.line_item_id, 'wave')), 3) AS wave
    FROM shipped_lines sl
),
groups AS (
    SELECT order_id, wave, supplier_id, customer_id,
           MIN(actual_ship_date)                       AS grp_ship_date,
           MAX(actual_receipt_date)                    AS grp_receipt_date,
           COUNT_IF(actual_receipt_date IS NULL)       AS open_lines
    FROM waved
    GROUP BY order_id, wave, supplier_id, customer_id
),
numbered AS (
    SELECT g.*,
           ROW_NUMBER() OVER (ORDER BY g.order_id, g.wave) AS shipment_id
    FROM groups g
)
SELECT w.line_item_id, w.order_id, w.wave, n.shipment_id,
       w.part_id, w.quantity_ordered, w.line_status,
       n.grp_ship_date, n.grp_receipt_date, n.open_lines,
       n.supplier_id, n.customer_id
FROM waved w
JOIN numbered n ON n.order_id = w.order_id AND n.wave = w.wave;


INSERT INTO SHIPMENT (
    shipment_id, shipment_reference,
    origin_supplier_id, origin_plant_id, origin_warehouse_id,
    destination_customer_id, destination_plant_id, destination_warehouse_id,
    carrier_id, route_id, ship_mode, origin_port_id, destination_port_id,
    origin_country_id, destination_country_id,
    ship_date, estimated_arrival_date, actual_arrival_date, shipment_status,
    total_weight_kg, total_volume_m3, freight_cost_usd, insurance_cost_usd,
    duties_usd, handling_cost_usd, transit_days_planned, transit_days_actual,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH hdr AS (
    SELECT shipment_id, order_id, supplier_id, customer_id,
           MIN(grp_ship_date)    AS ship_date,
           MAX(grp_receipt_date) AS receipt_date,
           MAX(open_lines)       AS open_lines
    FROM TMP_SHIPMENT_ASSIGNMENT
    GROUP BY shipment_id, order_id, supplier_id, customer_id
),
seeded AS (
    SELECT h.*,
           ABS(HASH(h.shipment_id,'sh_org'))  AS h_org,
           ABS(HASH(h.shipment_id,'sh_dst'))  AS h_dst,
           ABS(HASH(h.shipment_id,'sh_rt'))   AS h_rt,
           ABS(HASH(h.shipment_id,'sh_car'))  AS h_car,
           ABS(HASH(h.shipment_id,'sh_var'))  AS h_var,
           ABS(HASH(h.shipment_id,'sh_stat')) AS h_stat
    FROM hdr h
),
-- Routes indexed by their origin country so a supplier can ship from home.
routes_by_origin AS (
    SELECT r.route_id, r.origin_country_id, r.destination_country_id,
           r.origin_port_id, r.destination_port_id, r.primary_mode,
           r.avg_transit_days,
           ROW_NUMBER() OVER (PARTITION BY r.origin_country_id ORDER BY r.route_id) AS rn,
           COUNT(*)    OVER (PARTITION BY r.origin_country_id)                      AS cnt
    FROM ROUTE r
),
routes_any AS (
    SELECT r.route_id, r.origin_country_id, r.destination_country_id,
           r.origin_port_id, r.destination_port_id, r.primary_mode,
           r.avg_transit_days,
           ROW_NUMBER() OVER (ORDER BY r.route_id) AS rn,
           COUNT(*)    OVER ()                     AS cnt
    FROM ROUTE r
),
with_supplier AS (
    SELECT s.*, sup.country_id AS supplier_country_id
    FROM seeded s
    JOIN SUPPLIER sup ON sup.supplier_id = s.supplier_id
),
routed AS (
    SELECT w.*,
           COALESCE(rmatch.route_id,              rany.route_id)              AS route_id,
           COALESCE(rmatch.origin_country_id,     rany.origin_country_id)     AS r_origin_country_id,
           COALESCE(rmatch.destination_country_id,rany.destination_country_id) AS r_dest_country_id,
           COALESCE(rmatch.origin_port_id,        rany.origin_port_id)        AS r_origin_port_id,
           COALESCE(rmatch.destination_port_id,   rany.destination_port_id)   AS r_dest_port_id,
           COALESCE(rmatch.primary_mode,          rany.primary_mode)          AS r_mode,
           COALESCE(rmatch.avg_transit_days,      rany.avg_transit_days)      AS r_transit_days
    FROM with_supplier w
    LEFT JOIN routes_by_origin rmatch
           ON rmatch.origin_country_id = w.supplier_country_id
          AND rmatch.rn = 1 + MOD(w.h_rt, rmatch.cnt)
    LEFT JOIN routes_any rany
           ON rany.rn = 1 + MOD(w.h_rt, rany.cnt)
),
-- Carrier preference: one that actually serves the chosen route.
carriers_on_route AS (
    SELECT crs.route_id, crs.carrier_id,
           ROW_NUMBER() OVER (PARTITION BY crs.route_id ORDER BY crs.carrier_id) AS rn,
           COUNT(*)    OVER (PARTITION BY crs.route_id)                          AS cnt
    FROM CARRIER_ROUTE_SERVICE crs
),
carriers_any AS (
    SELECT carrier_id,
           ROW_NUMBER() OVER (ORDER BY carrier_id) AS rn,
           COUNT(*)    OVER ()                     AS cnt
    FROM CARRIER
),
crewed AS (
    SELECT r.*,
           COALESCE(cr.carrier_id, ca.carrier_id) AS carrier_id
    FROM routed r
    LEFT JOIN carriers_on_route cr
           ON cr.route_id = r.route_id AND cr.rn = 1 + MOD(r.h_car, cr.cnt)
    LEFT JOIN carriers_any ca
           ON ca.rn = 1 + MOD(r.h_car, ca.cnt)
),
-- Origin / destination node selection (exactly one column per side).
supplier_plant AS (
    SELECT supplier_id, MIN(plant_id) AS own_plant_id
    FROM PLANT
    GROUP BY supplier_id
),
endpoints AS (
    SELECT c.*,
        MOD(c.h_org, 10)                                           AS org_pick,
        MOD(c.h_dst, 10)                                           AS dst_pick,
        sp.own_plant_id,
        1 + MOD(c.h_org, 28)                                       AS pick_warehouse_id,
        1 + MOD(c.h_dst, 28)                                       AS pick_dest_warehouse_id,
        1 + MOD(c.h_dst, 150)                                      AS pick_dest_plant_id
    FROM crewed c
    LEFT JOIN supplier_plant sp ON sp.supplier_id = c.supplier_id
)
SELECT
    e.shipment_id,
    'BOL-' || TO_VARCHAR(YEAR(e.ship_date))
        || '-' || LPAD(TO_VARCHAR(e.shipment_id), 8, '0')          AS shipment_reference,
    -- ORIGIN: exactly one of the three is non-NULL
    IFF(e.org_pick < 7 OR e.own_plant_id IS NULL, e.supplier_id, NULL)      AS origin_supplier_id,
    IFF(e.org_pick BETWEEN 7 AND 8 AND e.own_plant_id IS NOT NULL,
        e.own_plant_id, NULL)                                               AS origin_plant_id,
    IFF(e.org_pick = 9 AND e.own_plant_id IS NOT NULL,
        e.pick_warehouse_id, NULL)                                          AS origin_warehouse_id,
    -- DESTINATION: exactly one of the three is non-NULL
    IFF(e.dst_pick < 7, e.customer_id, NULL)                                AS destination_customer_id,
    IFF(e.dst_pick = 9, e.pick_dest_plant_id, NULL)                         AS destination_plant_id,
    IFF(e.dst_pick BETWEEN 7 AND 8, e.pick_dest_warehouse_id, NULL)         AS destination_warehouse_id,
    e.carrier_id,
    e.route_id,
    CASE e.r_mode WHEN 'Road' THEN 'Truck' ELSE e.r_mode END                AS ship_mode,
    -- Domestic road/rail legs do not clear a port
    IFF(e.r_mode IN ('Road','Rail'), NULL, e.r_origin_port_id)              AS origin_port_id,
    IFF(e.r_mode IN ('Road','Rail'), NULL, e.r_dest_port_id)                AS destination_port_id,
    e.r_origin_country_id                                                   AS origin_country_id,
    e.r_dest_country_id                                                     AS destination_country_id,
    e.ship_date,
    DATEADD(day, GREATEST(1, ROUND(e.r_transit_days)), e.ship_date)         AS estimated_arrival_date,
    IFF(e.open_lines > 0 OR e.receipt_date IS NULL, NULL, e.receipt_date)   AS actual_arrival_date,
    CASE WHEN e.open_lines > 0 OR e.receipt_date IS NULL THEN
              CASE WHEN MOD(e.h_stat, 100) < 55 THEN 'In-Transit'
                   WHEN MOD(e.h_stat, 100) < 70 THEN 'At-Port'
                   WHEN MOD(e.h_stat, 100) < 78 THEN 'Customs-Hold'
                   WHEN MOD(e.h_stat, 100) < 92 THEN 'Planned'
                   ELSE 'Exception' END
         ELSE 'Delivered' END                                               AS shipment_status,
    NULL AS total_weight_kg,
    NULL AS total_volume_m3,
    NULL AS freight_cost_usd,
    NULL AS insurance_cost_usd,
    NULL AS duties_usd,
    NULL AS handling_cost_usd,
    GREATEST(1, ROUND(e.r_transit_days))                                    AS transit_days_planned,
    IFF(e.open_lines > 0 OR e.receipt_date IS NULL, NULL,
        DATEDIFF(day, e.ship_date, e.receipt_date))                         AS transit_days_actual,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'SHIPMENT:' || e.shipment_id,
    ROUND(90 + MOD(e.h_var, 10), 2), 'HIGH'
FROM endpoints e;


-- =============================================================================
-- 23. SHIPMENT_LINE_ITEM — ~130,000 rows (one per shipped order line).
--
--   FILL-RATE-CRITICAL: quantity_shipped drives the governed Fill Rate metric.
--     92% full fill, 5% partial fill (50–95%), 3% stockout (zero shipped).
--   Scenario 4 (Inventory Shortages, 2025-01..2025-03) raises the stockout and
--   partial-fill rate sharply inside that window.
--   quantity_shipped never exceeds quantity_ordered.
-- =============================================================================
INSERT INTO SHIPMENT_LINE_ITEM (
    shipment_id, line_item_id, quantity_shipped, package_number,
    ship_line_status,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH base AS (
    SELECT a.shipment_id, a.line_item_id, a.quantity_ordered, a.line_status,
           a.grp_ship_date,
           ABS(HASH(a.shipment_id, a.line_item_id, 'sli_fill')) AS h_fill,
           ABS(HASH(a.shipment_id, a.line_item_id, 'sli_pkg'))  AS h_pkg
    FROM TMP_SHIPMENT_ASSIGNMENT a
),
scored AS (
    SELECT b.*,
        -- Shortage window doubles the miss rate
        IFF(b.grp_ship_date BETWEEN '2025-01-01' AND '2025-03-31', 1, 0) AS in_shortage_window
    FROM base b
)
SELECT
    s.shipment_id,
    s.line_item_id,
    ROUND(
      CASE
        WHEN s.in_shortage_window = 1 THEN
             CASE WHEN MOD(s.h_fill, 100) < 78 THEN s.quantity_ordered
                  WHEN MOD(s.h_fill, 100) < 93 THEN s.quantity_ordered * (0.50 + MOD(s.h_fill, 45) / 100.0)
                  ELSE 0 END
        ELSE
             CASE WHEN MOD(s.h_fill, 100) < 92 THEN s.quantity_ordered
                  WHEN MOD(s.h_fill, 100) < 97 THEN s.quantity_ordered * (0.50 + MOD(s.h_fill, 45) / 100.0)
                  ELSE 0 END
      END, 2)                                                       AS quantity_shipped,
    'PKG-' || LPAD(TO_VARCHAR(s.shipment_id), 8, '0')
        || '-' || LPAD(TO_VARCHAR(MOD(s.h_pkg, 999)), 3, '0')       AS package_number,
    CASE WHEN s.line_status = 'Received' THEN 'Delivered'
         WHEN s.line_status = 'Returned' THEN 'Returned'
         WHEN s.line_status = 'Shipped'  THEN 'In-Transit'
         ELSE 'Shipped' END                                         AS ship_line_status,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'SHIPMENT_LINE:' || s.shipment_id || ':' || s.line_item_id,
    ROUND(92 + MOD(s.h_fill, 8), 2), 'HIGH'
FROM scored s;


-- Back-fill shipment weights, volumes and the four landed-cost components now
-- that the shipment contents are known.
UPDATE SHIPMENT sh
SET total_weight_kg    = m.total_weight_kg,
    total_volume_m3    = m.total_volume_m3,
    freight_cost_usd   = m.freight_cost_usd,
    insurance_cost_usd = m.insurance_cost_usd,
    duties_usd         = m.duties_usd,
    handling_cost_usd  = m.handling_cost_usd,
    _updated_at        = CURRENT_TIMESTAMP()
FROM (
    SELECT
        sli.shipment_id,
        ROUND(SUM(sli.quantity_shipped * p.unit_weight_kg), 2)      AS total_weight_kg,
        ROUND(SUM(sli.quantity_shipped * p.unit_volume_m3), 4)      AS total_volume_m3,
        ROUND(GREATEST(25.00,
              SUM(sli.quantity_shipped * p.unit_weight_kg)
              * MAX(r.avg_cost_per_kg_usd)
              * (0.80 + MOD(ABS(HASH(sli.shipment_id,'frt')), 51) / 100.0)), 2)
                                                                    AS freight_cost_usd,
        -- insurance_cost_usd, duties_usd and handling_cost_usd are NUMBER(10,2):
        -- hard ceiling 99,999,999.99. The LEAST() clamps enforce that ceiling.
        --
        -- Insurance: 0.5-2.0% of goods value
        LEAST(99999999.99,
          ROUND(SUM(sli.quantity_shipped * oli.unit_price_usd)
                * (0.005 + MOD(ABS(HASH(sli.shipment_id,'ins')), 16) / 1000.0), 2))
                                                                    AS insurance_cost_usd,
        -- Duties: HS-chapter driven. Chapter 85 carries the tariff shock.
        LEAST(99999999.99,
          ROUND(SUM(sli.quantity_shipped * oli.unit_price_usd
                * CASE WHEN cm.hs_chapter = '85' AND sh2.ship_date >= '2024-07-01' THEN 0.25
                       WHEN cm.hs_chapter IN ('72','73','76')                      THEN 0.15
                       WHEN cm.hs_chapter IN ('61','62','52')                      THEN 0.12
                       WHEN cm.export_control_flag                                 THEN 0.08
                       ELSE 0.04 END), 2))                          AS duties_usd,
        -- Brokerage + warehouse handling, fixed per shipment plus per line
        LEAST(99999999.99, ROUND(150.00 + 12.50 * COUNT(*), 2))     AS handling_cost_usd
    FROM SHIPMENT_LINE_ITEM sli
    JOIN SHIPMENT        sh2 ON sh2.shipment_id = sli.shipment_id
    JOIN ORDER_LINE_ITEM oli ON oli.line_item_id = sli.line_item_id
    JOIN PART            p   ON p.part_id       = oli.part_id
    JOIN COMMODITY       cm  ON cm.commodity_id = p.commodity_id
    LEFT JOIN ROUTE      r   ON r.route_id      = sh2.route_id
    WHERE sli._batch_id = $sco_batch
    GROUP BY sli.shipment_id
) m
WHERE sh.shipment_id = m.shipment_id
  AND sh._batch_id   = $sco_batch;


-- =============================================================================
-- 24. INVENTORY_POSITION — 450,000 rows.
--     5,000 active parts x 3 warehouses x 30 daily snapshots (trailing month of
--     the synthetic window, 2025-12-02 .. 2025-12-31).
--     PK (part_id, warehouse_id, snapshot_date) is unique by construction.
--
--   DOI-CRITICAL: quantity_on_hand follows a sawtooth — it depletes at the
--   part's real average daily demand (measured from ORDER_LINE_ITEM) and
--   spikes back on a replenishment cycle of 7–30 days.
--   Scenario 4 forces ~5% of rows to zero available stock.
-- =============================================================================
INSERT INTO INVENTORY_POSITION (
    part_id, warehouse_id, snapshot_date, quantity_on_hand, quantity_reserved,
    quantity_available, quantity_in_transit, reorder_point, safety_stock_level,
    _batch_id, _source_system, _source_table, _source_key,
    _data_quality_score, _confidence_level
)
WITH days AS (
    SELECT DATEADD(day, -1 * SEQ4(), $win_end) AS snapshot_date
    FROM TABLE(GENERATOR(ROWCOUNT => 30))
),
active_parts AS (
    SELECT part_id FROM PART WHERE lifecycle_status = 'Active'
),
-- Real demand signal, straight from the generated order history.
part_demand AS (
    SELECT oli.part_id,
           SUM(oli.quantity_ordered) / 730.0 AS avg_daily_demand
    FROM ORDER_LINE_ITEM oli
    WHERE oli._batch_id = $sco_batch
    GROUP BY oli.part_id
),
-- Three stocking locations per part, drawn from the 28 operational warehouses.
part_warehouse AS (
    SELECT ap.part_id,
           1 + MOD(ap.part_id * 7  + w.slot * 9,  28) AS warehouse_id,
           w.slot
    FROM active_parts ap
    CROSS JOIN (SELECT 0 AS slot UNION ALL SELECT 1 UNION ALL SELECT 2) w
),
grid AS (
    SELECT pw.part_id, pw.warehouse_id, pw.slot, d.snapshot_date,
           COALESCE(pd.avg_daily_demand, 0) AS avg_daily_demand,
           ABS(HASH(pw.part_id, pw.warehouse_id, 'inv_cycle')) AS h_cycle,
           ABS(HASH(pw.part_id, pw.warehouse_id, 'inv_ss'))    AS h_ss,
           ABS(HASH(pw.part_id, pw.warehouse_id,
                    d.snapshot_date, 'inv_res'))               AS h_res,
           ABS(HASH(pw.part_id, pw.warehouse_id,
                    d.snapshot_date, 'inv_out'))               AS h_out
    FROM part_warehouse pw
    CROSS JOIN days d
    LEFT JOIN part_demand pd ON pd.part_id = pw.part_id
),
shaped AS (
    SELECT g.*,
        -- This location carries roughly a third of the part's total demand.
        GREATEST(1.0, g.avg_daily_demand / 3.0)                     AS loc_daily_demand,
        7 + MOD(g.h_cycle, 24)                                      AS replenish_cycle_days,
        MOD(DATEDIFF(day, $win_start, g.snapshot_date)
            + MOD(g.h_cycle, 30), 7 + MOD(g.h_cycle, 24))           AS days_since_receipt
    FROM grid g
),
levels AS (
    SELECT s.*,
        ROUND(GREATEST(1.0, s.loc_daily_demand * (3 + MOD(s.h_ss, 12))), 2) AS safety_stock_level,
        -- Sawtooth: start at 2–5x safety stock after receipt, deplete daily.
        ROUND(GREATEST(0.0,
              s.loc_daily_demand * (3 + MOD(s.h_ss, 12)) * (2 + MOD(s.h_cycle, 4))
              - s.loc_daily_demand * s.days_since_receipt), 2)              AS on_hand_raw
    FROM shaped s
),
final AS (
    SELECT l.*,
        -- Scenario 4: force ~5% of positions to a hard stockout.
        ROUND(IFF(MOD(l.h_out, 100) < 5, 0.00, l.on_hand_raw), 2)   AS quantity_on_hand
    FROM levels l
)
SELECT
    f.part_id,
    f.warehouse_id,
    f.snapshot_date,
    f.quantity_on_hand,
    ROUND(f.quantity_on_hand * (MOD(f.h_res, 31) / 100.0), 2)       AS quantity_reserved,
    ROUND(f.quantity_on_hand
          - f.quantity_on_hand * (MOD(f.h_res, 31) / 100.0), 2)     AS quantity_available,
    ROUND(IFF(MOD(f.h_cycle, 3) = 0,
              f.loc_daily_demand * (1 + MOD(f.h_out, 10)), 0), 2)   AS quantity_in_transit,
    ROUND(f.safety_stock_level * 1.5, 2)                            AS reorder_point,
    f.safety_stock_level,
    $sco_batch, 'SYNTHETIC_GENERATOR', '03_generate_synthetic_data.sql',
    'INVENTORY:' || f.part_id || ':' || f.warehouse_id
        || ':' || TO_VARCHAR(f.snapshot_date),
    ROUND(91 + MOD(f.h_res, 9), 2), 'HIGH'
FROM final f;


DROP TABLE IF EXISTS TMP_SHIPMENT_ASSIGNMENT;


-- =============================================================================
-- LOAD SUMMARY
-- =============================================================================
SELECT 'COUNTRY' AS table_name, 50     AS target_rows, COUNT(*) AS actual_rows FROM COUNTRY                   WHERE _batch_id = $sco_batch
UNION ALL SELECT 'COMMODITY',                200,     COUNT(*) FROM COMMODITY                 WHERE _batch_id = $sco_batch
UNION ALL SELECT 'COMPLIANCE_LIST',          500,     COUNT(*) FROM COMPLIANCE_LIST           WHERE _batch_id = $sco_batch
UNION ALL SELECT 'SUPPLIER',                1000,     COUNT(*) FROM SUPPLIER                  WHERE _batch_id = $sco_batch
UNION ALL SELECT 'CUSTOMER',                2000,     COUNT(*) FROM CUSTOMER                  WHERE _batch_id = $sco_batch
UNION ALL SELECT 'CARRIER',                   50,     COUNT(*) FROM CARRIER                   WHERE _batch_id = $sco_batch
UNION ALL SELECT 'PORT',                      80,     COUNT(*) FROM PORT                      WHERE _batch_id = $sco_batch
UNION ALL SELECT 'PART',                    5000,     COUNT(*) FROM PART                      WHERE _batch_id = $sco_batch
UNION ALL SELECT 'WAREHOUSE',                 30,     COUNT(*) FROM WAREHOUSE                 WHERE _batch_id = $sco_batch
UNION ALL SELECT 'PLANT',                    150,     COUNT(*) FROM PLANT                     WHERE _batch_id = $sco_batch
UNION ALL SELECT 'ROUTE',                    200,     COUNT(*) FROM ROUTE                     WHERE _batch_id = $sco_batch
UNION ALL SELECT 'SUPPLIER_CATALOG',       15000,     COUNT(*) FROM SUPPLIER_CATALOG          WHERE _batch_id = $sco_batch
UNION ALL SELECT 'PLANT_PART_ASSIGNMENT',   3000,     COUNT(*) FROM PLANT_PART_ASSIGNMENT     WHERE _batch_id = $sco_batch
UNION ALL SELECT 'CARRIER_ROUTE_SERVICE',    500,     COUNT(*) FROM CARRIER_ROUTE_SERVICE     WHERE _batch_id = $sco_batch
UNION ALL SELECT 'SUPPLIER_COMPLIANCE_MATCH',150,     COUNT(*) FROM SUPPLIER_COMPLIANCE_MATCH WHERE _batch_id = $sco_batch
UNION ALL SELECT 'CUSTOMER_COMPLIANCE_MATCH', 80,     COUNT(*) FROM CUSTOMER_COMPLIANCE_MATCH WHERE _batch_id = $sco_batch
UNION ALL SELECT 'COMMODITY_RESTRICTION',    100,     COUNT(*) FROM COMMODITY_RESTRICTION     WHERE _batch_id = $sco_batch
UNION ALL SELECT 'SUPPLIER_RISK_ASSESSMENT',4000,     COUNT(*) FROM SUPPLIER_RISK_ASSESSMENT  WHERE _batch_id = $sco_batch
UNION ALL SELECT 'ESG_SCORE',               3000,     COUNT(*) FROM ESG_SCORE                 WHERE _batch_id = $sco_batch
UNION ALL SELECT 'PURCHASE_ORDER',         50000,     COUNT(*) FROM PURCHASE_ORDER            WHERE _batch_id = $sco_batch
UNION ALL SELECT 'ORDER_LINE_ITEM',       200000,     COUNT(*) FROM ORDER_LINE_ITEM           WHERE _batch_id = $sco_batch
UNION ALL SELECT 'SHIPMENT',               75000,     COUNT(*) FROM SHIPMENT                  WHERE _batch_id = $sco_batch
UNION ALL SELECT 'SHIPMENT_LINE_ITEM',    130000,     COUNT(*) FROM SHIPMENT_LINE_ITEM        WHERE _batch_id = $sco_batch
UNION ALL SELECT 'INVENTORY_POSITION',    450000,     COUNT(*) FROM INVENTORY_POSITION        WHERE _batch_id = $sco_batch
ORDER BY table_name;

-- =============================================================================
-- END OF GENERATION
-- =============================================================================


SELECT 'INVENTORY_POSITION' t, COUNT(*) n FROM SCO_HACKATHON.SCO_SOURCE.INVENTORY_POSITION
UNION ALL SELECT 'ORDER_LINE_ITEM', COUNT(*) FROM SCO_HACKATHON.SCO_SOURCE.ORDER_LINE_ITEM
UNION ALL SELECT 'SHIPMENT', COUNT(*) FROM SCO_HACKATHON.SCO_SOURCE.SHIPMENT
UNION ALL SELECT 'PURCHASE_ORDER', COUNT(*) FROM SCO_HACKATHON.SCO_SOURCE.PURCHASE_ORDER
UNION ALL SELECT 'PART', COUNT(*) FROM SCO_HACKATHON.SCO_SOURCE.PART
UNION ALL SELECT 'SUPPLIER', COUNT(*) FROM SCO_HACKATHON.SCO_SOURCE.SUPPLIER
ORDER BY n DESC;