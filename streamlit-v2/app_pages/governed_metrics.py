"""Page 2 – Governed Metrics Dashboard: trends, breakdowns, and metric definitions."""
import pandas as pd
import streamlit as st

conn = st.session_state["sf_conn"]
DB = "SCO_HACKATHON.SCO_GOLD"

st.header("Governed Metrics Dashboard")
st.caption(
    "Every chart below is computed from governed Gold tables using ratio-of-sums. "
    "The Metric Definition panel documents the authoritative calculation."
)


@st.cache_data(ttl=600)
def load_metric_definitions():
    return conn.query(f"SELECT * FROM {DB}.GLD_METRIC_DEFINITIONS ORDER BY METRIC_NAME")


@st.cache_data(ttl=600)
def load_monthly_otd():
    return conn.query(f"""
        SELECT MONTH_START_DATE,
               SUM(LINES_ON_TIME) / NULLIF(SUM(LINES_DUE), 0) * 100 AS OTD_PCT
        FROM {DB}.GLD_METRIC_OTD
        WHERE MONTH_START_DATE <= '2025-12-01'
        GROUP BY MONTH_START_DATE ORDER BY MONTH_START_DATE
    """)


@st.cache_data(ttl=600)
def load_monthly_fill():
    return conn.query(f"""
        SELECT MONTH_START_DATE,
               SUM(UNITS_FULFILLED) / NULLIF(SUM(UNITS_ORDERED), 0) * 100 AS FILL_PCT
        FROM {DB}.GLD_METRIC_FILL_RATE
        GROUP BY MONTH_START_DATE ORDER BY MONTH_START_DATE
    """)


@st.cache_data(ttl=600)
def load_monthly_landed():
    return conn.query(f"""
        SELECT MONTH_START_DATE,
               SUM(LANDED_COST_PER_UNIT_USD * TOTAL_UNITS) / NULLIF(SUM(TOTAL_UNITS), 0) AS LANDED_CPU
        FROM {DB}.GLD_METRIC_LANDED_COST
        GROUP BY MONTH_START_DATE ORDER BY MONTH_START_DATE
    """)


@st.cache_data(ttl=600)
def load_monthly_doi():
    return conn.query(f"""
        SELECT SNAPSHOT_DATE,
               SUM(QUANTITY_ON_HAND) / NULLIF(SUM(AVG_DAILY_DEMAND), 0) AS DOI_DAYS
        FROM {DB}.GLD_METRIC_DOI
        WHERE AGGREGATION_LEVEL = 'PART_WAREHOUSE'
        GROUP BY SNAPSHOT_DATE ORDER BY SNAPSHOT_DATE
    """)


@st.cache_data(ttl=600)
def load_otd_by_supplier():
    return conn.query(f"""
        SELECT SUPPLIER_NAME,
               SUM(LINES_ON_TIME) / NULLIF(SUM(LINES_DUE), 0) * 100 AS OTD_PCT
        FROM {DB}.GLD_METRIC_OTD
        WHERE MONTH_START_DATE <= '2025-12-01'
        GROUP BY SUPPLIER_NAME ORDER BY OTD_PCT ASC LIMIT 15
    """)


@st.cache_data(ttl=600)
def load_otd_by_region():
    return conn.query(f"""
        SELECT CUSTOMER_REGION,
               SUM(LINES_ON_TIME) / NULLIF(SUM(LINES_DUE), 0) * 100 AS OTD_PCT
        FROM {DB}.GLD_METRIC_OTD
        WHERE MONTH_START_DATE <= '2025-12-01'
        GROUP BY CUSTOMER_REGION ORDER BY OTD_PCT
    """)


@st.cache_data(ttl=600)
def load_fill_by_tier():
    return conn.query(f"""
        SELECT CUSTOMER_SERVICE_TIER,
               SUM(UNITS_FULFILLED) / NULLIF(SUM(UNITS_ORDERED), 0) * 100 AS FILL_PCT
        FROM {DB}.GLD_METRIC_FILL_RATE
        GROUP BY CUSTOMER_SERVICE_TIER ORDER BY FILL_PCT
    """)


@st.cache_data(ttl=600)
def load_landed_by_supplier():
    return conn.query(f"""
        SELECT SUPPLIER_NAME,
               SUM(LANDED_COST_PER_UNIT_USD * TOTAL_UNITS) / NULLIF(SUM(TOTAL_UNITS), 0) AS LANDED_CPU
        FROM {DB}.GLD_METRIC_LANDED_COST
        GROUP BY SUPPLIER_NAME ORDER BY LANDED_CPU DESC LIMIT 15
    """)


# ── Metric definition panel ───────────────────────────────────────────
with st.expander("Governed Metric Definitions (click to expand)", expanded=False):
    defs = load_metric_definitions()
    if not defs.empty:
        for _, row in defs.iterrows():
            st.markdown(f"**{row['METRIC_NAME']}**")
            st.markdown(f"> {row['GOVERNED_DEFINITION']}")
            st.markdown(
                f"Formula: `{row['FORMULA']}`  |  Grain: {row['GRAIN']}  |  "
                f"Unit: {row['UNIT']}  |  Target: {row['TARGET_RANGE']}  |  "
                f"Domain: {row['OWNING_DOMAIN']}"
            )
            st.markdown("---")
    else:
        st.warning("Could not load metric definitions.")

# ── Monthly trends ────────────────────────────────────────────────────
st.subheader("Monthly Trends")
metric_choice = st.selectbox(
    "Select metric", ["On-Time Delivery", "Fill Rate", "Days of Inventory", "Landed Cost"]
)

with st.spinner("Loading trend..."):
    if metric_choice == "On-Time Delivery":
        df = load_monthly_otd()
        if not df.empty:
            df["MONTH_START_DATE"] = pd.to_datetime(df["MONTH_START_DATE"])
            st.line_chart(df.set_index("MONTH_START_DATE"), y="OTD_PCT")
            st.caption("Source: GLD_METRIC_OTD | Governed formula: SUM(lines_on_time) / NULLIF(SUM(lines_due), 0) * 100")
    elif metric_choice == "Fill Rate":
        df = load_monthly_fill()
        if not df.empty:
            df["MONTH_START_DATE"] = pd.to_datetime(df["MONTH_START_DATE"])
            st.line_chart(df.set_index("MONTH_START_DATE"), y="FILL_PCT")
            st.caption("Source: GLD_METRIC_FILL_RATE | Governed formula: SUM(units_fulfilled) / NULLIF(SUM(units_ordered), 0) * 100")
    elif metric_choice == "Days of Inventory":
        df = load_monthly_doi()
        if not df.empty:
            df["SNAPSHOT_DATE"] = pd.to_datetime(df["SNAPSHOT_DATE"])
            st.line_chart(df.set_index("SNAPSHOT_DATE"), y="DOI_DAYS")
            st.caption("Source: GLD_METRIC_DOI | Governed formula: SUM(qty_on_hand) / NULLIF(SUM(avg_daily_demand), 0)")
    else:
        df = load_monthly_landed()
        if not df.empty:
            df["MONTH_START_DATE"] = pd.to_datetime(df["MONTH_START_DATE"])
            st.line_chart(df.set_index("MONTH_START_DATE"), y="LANDED_CPU")
            st.caption("Source: GLD_METRIC_LANDED_COST | Governed formula: SUM(landed_cost * units) / NULLIF(SUM(units), 0)")

# ── Breakdowns ────────────────────────────────────────────────────────
st.markdown("---")
st.subheader("Breakdowns")

col1, col2 = st.columns(2)

with col1:
    with st.container(border=True):
        st.markdown("**OTD by Region**")
        region_df = load_otd_by_region()
        if not region_df.empty:
            st.bar_chart(region_df.set_index("CUSTOMER_REGION"), y="OTD_PCT")
        else:
            st.info("No regional OTD data available.")

    with st.container(border=True):
        st.markdown("**Fill Rate by Service Tier**")
        tier_df = load_fill_by_tier()
        if not tier_df.empty:
            st.bar_chart(tier_df.set_index("CUSTOMER_SERVICE_TIER"), y="FILL_PCT")
        else:
            st.info("No fill rate tier data available.")

with col2:
    with st.container(border=True):
        st.markdown("**Bottom 15 Suppliers by OTD**")
        sup_df = load_otd_by_supplier()
        if not sup_df.empty:
            st.bar_chart(sup_df.set_index("SUPPLIER_NAME"), y="OTD_PCT")
        else:
            st.info("No supplier OTD data available.")

    with st.container(border=True):
        st.markdown("**Top 15 Suppliers by Landed Cost**")
        lc_df = load_landed_by_supplier()
        if not lc_df.empty:
            st.bar_chart(lc_df.set_index("SUPPLIER_NAME"), y="LANDED_CPU")
        else:
            st.info("No landed cost supplier data available.")

st.markdown("---")
st.info(
    "All results come from governed Gold table definitions. "
    "OTD is calculated as SUM(lines_on_time) / NULLIF(SUM(lines_due), 0) * 100 — "
    "never as an average of pre-computed percentages."
)
