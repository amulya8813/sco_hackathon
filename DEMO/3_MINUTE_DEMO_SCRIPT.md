# Five-Minute Demo Script — SCO Hackathon 2026

**Team:** Fab4CoCo | **Leader:** Dhanushree Soni | **Timer:** 5:00
**Deck:** `docs/Fab4Coco_CoCo_Hackathon_Final.pptx` (8 slides)
**Streamlit:** `snow://workspace/USER$DSONI.PUBLIC.SCO_HACKATHON/versions/head/streamlit-v2/streamlit_app.py`

---

## 0:00–0:30 — TITLE & HOOK (Slide 1)

**Share:** PowerPoint Slide 1 (Team title slide)

**Say:**

> "Hi everyone, we are Fab4CoCo. Our problem statement is Supply Chain Ontology and Governed Conversational Analytics.
>
> Here is the core question we set out to solve: When Planning asks 'What is our on-time delivery rate?' and Procurement asks the exact same question in different words — why do they sometimes get different answers?
>
> The answer is that the metric was defined and calculated differently. Our solution fixes that permanently."

**Action:** Advance to Slide 2.

---

## 0:30–1:10 — THE GOVERNANCE PROMISE (Slide 2)

**Share:** PowerPoint Slide 2 ("One Question. One Definition. One Answer.")

**Say:**

> "This is our value proposition. Three personas — Planning, Procurement, and Logistics — each ask about On-Time Delivery using their own language.
>
> Planning asks: 'What was our on-time delivery performance?'
> Procurement asks: 'How reliably did our suppliers deliver?'
> Logistics asks: 'What percentage of due lines arrived on time?'
>
> All three resolve to the same governed metric definition: the sum of lines on time, divided by the sum of lines due, times one hundred. This is a ratio of sums — not an average of pre-computed percentages. That distinction matters because averaging percentages across groups of different sizes gives you the wrong number.
>
> In our data, the correct ratio-of-sums gives 74.26 percent. The wrong average-of-percentages method gives 74.13 percent. That is a real discrepancy — and in supply chain, decisions are made on these numbers."

**Action:** Advance to Slide 3.

---

## 1:10–1:40 — PROBLEM BRIEF (Slide 3)

**Share:** PowerPoint Slide 3 (Problem Brief)

**Say:**

> "The problem: supply-chain data is scattered across ERP, logistics, inventory, and risk systems. Different teams build their own SQL, their own spreadsheets, and their own definitions. The result is conflicting numbers and delayed decisions.
>
> Who needs this? Planning, Procurement, Logistics, Finance — anyone who needs to trust a metric before acting on it.
>
> Our solution creates one governed ontology with one sanctioned definition per metric. The canonical flow is Supplier to Part to Plant to Order to Shipment to Customer. This supports traceability, impact analysis, quality validation, and operational action.
>
> Let me show you how we built this."

**Action:** Advance to Slide 4 (architecture diagram).

---

## 1:40–2:10 — ARCHITECTURE (Slides 4 & 5)

**Share:** PowerPoint Slide 4 (architecture diagram), then Slide 5

**Say:**

> "Here is the architecture. Twenty-four source tables with over one million rows of synthetic supply-chain data flow through four governed layers.
>
> Bronze mirrors the source using Dynamic Tables. Silver conforms eighteen business entities — dimensions like Supplier, Part, Customer, and facts like Orders, Shipments, and Inventory. Gold produces the four governed metrics: On-Time Delivery, Fill Rate, Days of Inventory, and Landed Cost.
>
> On top of Gold, a Semantic View called SV_SUPPLY_CHAIN powers Cortex Analyst for natural-language analytics. A knowledge graph with over 166,000 nodes and 932,000 edges maps every supply-chain relationship. Data Metric Functions and 80 quality checks validate trust. And Jira MCP automates exception handling.
>
> The entire solution — 28 SQL scripts, 7 Streamlit pages, 5 custom DMFs, all documentation — was built using CoCo CLI end to end.
>
> Now let me switch to the live application."

**Action:** Switch screen share from PowerPoint to the Streamlit app browser tab.

---

## 2:10–2:50 — LIVE DEMO: ONTOLOGY + GOVERNED METRIC (Streamlit)

**Share:** Streamlit app — click "Ontology Explorer" in sidebar

**Say:**

> "This is our Ontology Explorer. You can see the core entity relationship map: Supplier supplies Part, Part is stored at Warehouse, Order contains Part, Shipment fulfills Order, Carrier transports Shipment, and Customer receives Order."

**Click:** Select "Supplier" in the entity dropdown

> "Each entity shows its definition, Silver and Gold source tables, key columns, relationships, and supported metrics. This is a live view over the actual SCO_SILVER and SCO_GOLD data."

**Click:** Sidebar → "Governed Metrics" page
**Click:** Expand "Governed Metric Definitions (click to expand)"

> "Here are the governed metric definitions. On-Time Delivery: the percentage of order lines where goods arrived on or before the committed date. Formula: SUM of lines on time divided by SUM of lines due times one hundred. Target: 95 to 100 percent. This definition is shared by the Gold table, the Semantic View, and every Streamlit chart. One formula everywhere."

**Action:** Stay on Streamlit, click "Ask Analyst" in sidebar.

---

## 2:50–3:40 — LIVE DEMO: CONVERSATIONAL ANALYTICS (Streamlit)

**Share:** Streamlit app — "Ask Analyst" page

**Say:**

> "Now the key moment. Three personas, three questions, one answer."

**Type in chat box:** `What was the overall on-time delivery rate?`
**Wait for response**

> "Planning asks their way. Cortex Analyst translates this to SQL against the governed Semantic View SV_SUPPLY_CHAIN. The result: 74.26 percent."

**Expand:** "Generated SQL" to show the query

> "Notice the SQL uses SUM of LINES_ON_TIME divided by NULLIF SUM of LINES_DUE — the governed ratio-of-sums formula."

**Type:** `How reliably did our suppliers deliver?`
**Wait for response**

> "Procurement asks differently. Same answer: 74.26 percent. Same source table. Same formula."

**Type:** `What percentage of due order lines reached customers on time?`
**Wait for response**

> "Logistics asks in their language. 74.26 percent. Three personas, three phrasings, one trusted number. That is governance in action."

**Action:** Click "Knowledge Graph" in sidebar.

---

## 3:40–4:10 — LIVE DEMO: KNOWLEDGE GRAPH (Streamlit)

**Share:** Streamlit app — "Knowledge Graph" page

**Say:**

> "The knowledge graph has 13 entity types and 25 relationship types, built from verified foreign-key joins in Silver — no inferred relationships."

**Point to:** Summary metrics at top (166,530 nodes, 932,013 edges, 13 node types, 25 edge types)

**Scroll to:** "Risk Propagation: Supplier → Customer" section
**Select:** The first supplier in the dropdown

> "When we select a supplier, the graph traces the full impact chain. This supplier connects to multiple parts, which appear in hundreds of orders, shipped in hundreds of shipments, reaching hundreds of customers. If this supplier is disrupted, we see the blast radius instantly."

**Scroll to:** "Carrier Performance (Graph-Derived)" bar chart

> "We can also see carrier performance derived directly from graph edges. Globalbridge Carrier 6 has an 18.8 percent on-time rate — the worst in the network. Every shipment on its routes is a delay risk."

**Action:** Click "Alerts & Data Quality" in sidebar.

---

## 4:10–4:40 — LIVE DEMO: DATA QUALITY + JIRA MCP (Streamlit)

**Share:** Streamlit app — "Alerts & Data Quality" page

**Say:**

> "Trust requires validation. We run quality checks across ten dimensions: completeness, uniqueness, referential integrity, business rules, freshness, validity, metric reconciliation, graph quality, and pipeline health.
>
> The scorecard shows 42 checks from the governance layer. 36 pass. The 6 failures are all freshness checks — expected because this is static demo data, not a live pipeline.
>
> Beyond that, we ran 80 extended checks in our DQ framework. All four metric reconciliation checks passed — OTD, Fill Rate, Days of Inventory, and Landed Cost all match their governed formulas row by row. All five graph-quality checks passed — zero orphan edges, zero invalid types."

> "When a check fails, it flows into our Jira MCP integration. The system detected over 1,800 open alerts, each with a deduplication key to prevent duplicate tickets. In dry-run mode, we generate the exact Jira payload — summary, severity, affected entity, investigation steps — without creating real issues until approved."

**Action:** Switch screen share back to PowerPoint Slide 6.

---

## 4:40–4:55 — IMPACT & RESULTS (Slide 6)

**Share:** PowerPoint Slide 6 (Impact & Results)

**Say:**

> "To summarize the results: 74.26 percent governed OTD — one consistent result across all personas. 42 data-quality checks covering every quality dimension. Self-service analytics where natural language becomes a governed answer with SQL, a chart, and the metric definition attached.
>
> Why it matters: business teams make trusted decisions using shared definitions. The knowledge graph connects an exception to every affected entity. And validated alerts flow to Jira with deduplication and safe dry-run — moving from insight to action."

**Action:** Advance to Slide 7.

---

## 4:55–5:00 — CLOSE (Slide 7)

**Share:** PowerPoint Slide 7 (Demo Story summary)

**Say:**

> "One ontology. One governed definition. One trusted answer. From insight to action.
>
> Thank you."

---

## SCREEN-SHARING SUMMARY

| Time | What to Share |
|------|---------------|
| 0:00–2:10 | PowerPoint (Slides 1–5) |
| 2:10–2:30 | Streamlit → Ontology Explorer |
| 2:30–2:50 | Streamlit → Governed Metrics |
| 2:50–3:40 | Streamlit → Ask Analyst (type 3 questions) |
| 3:40–4:10 | Streamlit → Knowledge Graph |
| 4:10–4:40 | Streamlit → Alerts & Data Quality |
| 4:40–5:00 | PowerPoint (Slides 6–7) |

## VALIDATED NUMBERS (use these exact values)

| Fact | Value |
|------|-------|
| OTD (correct, ratio-of-sums) | **74.26%** |
| OTD (wrong, avg of pct) | **74.13%** |
| Numerator | 138,797 lines on time |
| Denominator | 186,918 lines due |
| Graph nodes | 166,530 |
| Graph edges | 932,013 |
| Node types | 13 |
| Edge types | 25 |
| Worst carrier on-time | 18.8% (Globalbridge Carrier 6) |
| DQ checks (governance) | 42 total, 36 pass, 6 freshness fail |
| DQ checks (extended) | 80 total, 74 pass |
| Metric reconciliations | 4/4 pass |
| Open alerts | 1,816 |
| SQL scripts | 28 |
| Streamlit pages | 7 |
| Total files generated | 74 |
| Database objects | ~142 |

## BACKUP PLAN

If **Cortex Analyst is slow**: Skip typing, say "We validated pre-demo that all three personas return 74.26%" and show the backup SQL query result.

If **Streamlit won't load**: Stay on PowerPoint, run `DEMO_SQL_QUERIES.sql` in a Snowsight worksheet tab.

If **Knowledge Graph page is slow**: Say the numbers verbally: "166,000 nodes, 932,000 edges, 25 relationship types — all from verified FK joins."

## DO NOT MENTION
- Cortex ML Forecasting
- Forecast models, predictions, or training
- The Forecasting Streamlit page
- Live Jira ticket creation (dry-run only)
- 100% DQ pass rate (6 failures exist, expected)

**TOTAL TIME: 5:00**
**Cortex ML Forecasting: EXCLUDED from all sections**
