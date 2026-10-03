# Prompts Used for Streamlit Application

## PROMPTS_streamlit.md

### Prompt 1: Infrastructure Discovery
```
Inspect the current workspace files. Inspect the available SCO_GOLD tables,
semantic views, Cortex Agent, forecasting objects, and data-quality result tables.
Do not invent tables or columns.
```
**Tools used:** `SHOW TABLES`, `SHOW VIEWS`, `SHOW SEMANTIC VIEWS`, `SHOW ALERTS`, `SHOW SNOWFLAKE.ML.FORECAST`, `INFORMATION_SCHEMA.COLUMNS`, `GET_DDL('SEMANTIC VIEW', ...)`, `cortex search object`

### Prompt 2: Application Generation
```
Design and build a production-quality Streamlit in Snowflake application for
supply-chain analytics with 6 pages: Executive Overview, Governed Metrics Dashboard,
Conversational Analytics, Forecasting, Alerts & Data Quality, Ontology Explorer.
```
**Tools used:** Streamlit-in-workspaces skill, multipage-apps reference, dashboards reference, chat-ui reference, snowflake-connection reference, performance reference

### Prompt 3: Governance Validation
```
Validate: All referenced tables and columns exist. Dashboard calculations match
direct SQL results. OTD is calculated as a ratio of sums. Persona-equivalent
questions return identical governed results.
```
**Tools used:** SQL validation queries in `tests/test_streamlit_queries.sql`

## Key Design Decisions

1. **st.navigation with sidebar** — 6 pages warrant sidebar navigation over top nav
2. **st.connection("snowflake")** — platform-managed identity, no `get_active_session()`
3. **_snowflake.send_snow_api_request** — Cortex Analyst API for governed conversational analytics
4. **@st.cache_data(ttl=600)** — 10-minute cache for dashboard queries
5. **Linear trend projection** — no FORECAST model found; documented fallback
6. **Text-based ontology diagram** — interactive graph components not available in SiS
7. **Ratio-of-sums everywhere** — OTD, Fill Rate, DOI, Landed Cost never average pre-computed %
