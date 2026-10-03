# Demo Click Path

## Pre-Demo Setup
1. Open Streamlit app: `snow://workspace/USER$DSONI.PUBLIC.SCO_HACKATHON/versions/head/streamlit-v2/streamlit_app.py`
2. Verify all 7 pages load in sidebar
3. Navigate to Executive Overview
4. Clear cache if needed (sidebar button)

## Click Sequence

### 0:00 — Business Problem
- **Screen:** Executive Overview (already showing KPI cards)
- **No clicks needed** — presenter speaks over the visible KPI dashboard

### 0:20 — Architecture
- **Option A:** Alt-tab to PowerPoint slide (`docs/Supply_Chain_Governed_Analytics_Prototype_Deck.pdf`)
- **Option B:** Stay on Streamlit, verbally describe architecture while sidebar shows layer names

### 0:40 — Ontology
1. **Click:** Sidebar → "Ontology Explorer"
2. **Wait:** Entity relationship text diagram loads
3. **Scroll:** To entity selector, select "Supplier"
4. **Show:** Relationships panel (supplies→Part, ships via→Route, etc.)

### 0:55 — Governed Metric Definition
1. **Click:** Sidebar → "Governed Metrics"
2. **Click:** Expand "Governed Metric Definitions (click to expand)"
3. **Point to:** `on_time_delivery_rate` definition and formula
4. **Show:** "SUM(lines_on_time) / NULLIF(SUM(lines_due), 0) * 100"

### 1:10 — Conversational Analytics
1. **Click:** Sidebar → "Ask Analyst"
2. **Type in chat input:** `What was our on-time delivery performance from January 2025 to December 2025?`
3. **Press Enter** — wait for response
4. **Show:** Result (expected: 82.45%), expand Generated SQL
5. **Type:** `How reliably did our suppliers deliver from January to December 2025?`
6. **Press Enter** — show same 82.45%
7. **Type:** `What percentage of due order lines reached customers on time in 2025?`
8. **Press Enter** — show same 82.45%

### 1:50 — Knowledge Graph
1. **Click:** Sidebar → "Knowledge Graph"
2. **Wait:** Summary metrics load (166,530 nodes, 932,013 edges)
3. **Scroll to:** "Risk Propagation: Supplier → Customer"
4. **Select:** First supplier in dropdown (highest risk score)
5. **Show:** Customer impact table and trace detail

### 2:05 — Carrier Performance (still on Knowledge Graph page)
1. **Scroll to:** "Carrier Performance (Graph-Derived)" section
2. **Show:** Bar chart with Globalbridge Carrier 6 at 18.8%

### 2:15 — Data Quality
1. **Click:** Sidebar → "Alerts & Data Quality"
2. **Show:** Data Quality Scorecard (pass rate, dimension summary)
3. **Show:** Failing Checks section (6 freshness failures)

### 2:35 — CoCo Evidence
1. **Verbal only** — no page switch needed
2. **Optional:** Briefly show workspace file list in sidebar or CoCo chat history

### 2:50 — Close
1. **Click:** Sidebar → "Executive Overview" (return to start)
2. **Deliver closing statement**

## Backup Click Path (if Cortex Agent is slow)
- Skip live typing, instead:
  - Show pre-validated SQL result: `SELECT ROUND(SUM(LINES_ON_TIME)/NULLIF(SUM(LINES_DUE),0)*100, 2) FROM SCO_HACKATHON.SCO_GOLD.GLD_METRIC_OTD WHERE MONTH_START_DATE BETWEEN '2025-01-01' AND '2025-12-01'`
  - Say: "We validated that all three persona questions return 82.45%"
