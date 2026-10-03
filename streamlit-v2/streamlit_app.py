"""
Supply Chain Ontology & Governed Conversational Analytics
Six-page Streamlit-in-Snowflake app backed by SCO_HACKATHON.SCO_GOLD
"""
import os
import streamlit as st

st.set_page_config(
    page_title="SCO | Supply Chain Analytics",
    page_icon=":material/inventory_2:",
    layout="wide",
)

# ── Snowflake connection (shared across all pages via session_state) ──
conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))
st.session_state["sf_conn"] = conn
st.session_state["sf_session"] = conn.session()

# ── Navigation ────────────────────────────────────────────────────────
page = st.navigation(
    [
        st.Page("app_pages/executive_overview.py", title="Executive Overview", icon=":material/dashboard:"),
        st.Page("app_pages/governed_metrics.py", title="Governed Metrics", icon=":material/monitoring:"),
        st.Page("app_pages/conversational_analytics.py", title="Ask Analyst", icon=":material/forum:"),
        st.Page("app_pages/forecasting.py", title="Forecasting", icon=":material/trending_up:"),
        st.Page("app_pages/alerts_data_quality.py", title="Alerts & Data Quality", icon=":material/verified:"),
        st.Page("app_pages/ontology_explorer.py", title="Ontology Explorer", icon=":material/account_tree:"),
        st.Page("app_pages/knowledge_graph.py", title="Knowledge Graph", icon=":material/hub:"),
    ],
    position="sidebar",
)

with st.sidebar:
    st.markdown("---")
    st.caption("SCO Hackathon 2026")
    st.caption("Database: `SCO_HACKATHON`")
    st.caption("Semantic View: `SV_SUPPLY_CHAIN`")
    st.caption("All metrics governed via SCO_GOLD layer.")
    if st.button("Clear cache", help="Force-refresh all cached data"):
        st.cache_data.clear()

page.run()
