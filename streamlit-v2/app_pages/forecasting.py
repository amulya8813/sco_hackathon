"""Page 4 – Forecasting: Actual vs historical demand trends with projection.

No Cortex ML FORECAST model was found in the database. This page displays
actual demand history from GLD_DEMAND_HISTORY and allows horizon-based
simple trend projection. If a FORECAST model is created later, this page
can be extended to call it.
"""
import pandas as pd
import streamlit as st

conn = st.session_state["sf_conn"]
DB = "SCO_HACKATHON.SCO_GOLD"

st.header("Forecasting")
st.caption(
    "Actual demand history from `GLD_DEMAND_HISTORY`. "
    "No Cortex ML FORECAST model was found; a simple trend extrapolation "
    "is shown for illustration. Models should NOT be retrained from this page."
)


@st.cache_data(ttl=600)
def load_demand_history():
    return conn.query(f"""
        SELECT MONTH_START_DATE,
               SUM(TOTAL_QUANTITY) AS TOTAL_DEMAND,
               SUM(ORDER_COUNT) AS TOTAL_ORDERS
        FROM {DB}.GLD_DEMAND_HISTORY
        GROUP BY MONTH_START_DATE
        ORDER BY MONTH_START_DATE
    """)


@st.cache_data(ttl=600)
def load_demand_by_part():
    return conn.query(f"""
        SELECT p.PART_CATEGORY, d.MONTH_START_DATE,
               SUM(d.TOTAL_QUANTITY) AS DEMAND
        FROM {DB}.GLD_DEMAND_HISTORY d
        JOIN SCO_HACKATHON.SCO_SILVER.SLV_DIM_PART p ON p.PART_ID = d.PART_ID
        GROUP BY p.PART_CATEGORY, d.MONTH_START_DATE
        ORDER BY d.MONTH_START_DATE
    """)


@st.cache_data(ttl=600)
def load_inventory_risk():
    return conn.query(f"""
        SELECT PART_CATEGORY,
               COUNT_IF(STOCKOUT_FLAG) AS STOCKOUT_PARTS,
               COUNT_IF(BELOW_REORDER_FLAG) AS BELOW_REORDER,
               COUNT_IF(EXCESS_FLAG) AS EXCESS_PARTS,
               COUNT(*) AS TOTAL_POSITIONS
        FROM {DB}.GLD_INVENTORY_HEALTH
        GROUP BY PART_CATEGORY ORDER BY STOCKOUT_PARTS DESC
    """)


# ── Metric selector ──────────────────────────────────────────────────
metric = st.selectbox("Metric to forecast", ["Total Demand (units)", "Total Orders"])
horizon = st.slider("Projection horizon (months)", 1, 12, 6)

with st.spinner("Loading demand history..."):
    demand = load_demand_history()

if demand.empty:
    st.warning("No demand history data available.")
    st.stop()

demand["MONTH_START_DATE"] = pd.to_datetime(demand["MONTH_START_DATE"])

y_col = "TOTAL_DEMAND" if "Demand" in metric else "TOTAL_ORDERS"

# ── Simple linear trend projection ────────────────────────────────────
import numpy as np

actual = demand[["MONTH_START_DATE", y_col]].copy()
actual["PERIOD_NUM"] = range(len(actual))

x = actual["PERIOD_NUM"].values
y = actual[y_col].values.astype(float)
if len(x) >= 2:
    slope, intercept = np.polyfit(x, y, 1)
    last_date = actual["MONTH_START_DATE"].max()
    future_dates = pd.date_range(last_date + pd.DateOffset(months=1), periods=horizon, freq="MS")
    future_nums = range(len(actual), len(actual) + horizon)
    forecast_vals = [slope * n + intercept for n in future_nums]

    forecast_df = pd.DataFrame({
        "MONTH_START_DATE": future_dates,
        y_col: forecast_vals,
        "TYPE": "Forecast",
    })
    actual_plot = actual[["MONTH_START_DATE", y_col]].copy()
    actual_plot["TYPE"] = "Actual"
    combined = pd.concat([actual_plot, forecast_df], ignore_index=True)
else:
    combined = actual[["MONTH_START_DATE", y_col]].copy()
    combined["TYPE"] = "Actual"

# ── Chart ─────────────────────────────────────────────────────────────
st.subheader(f"{metric}: Actual vs Forecast")

chart_wide = combined.pivot_table(
    index="MONTH_START_DATE", columns="TYPE", values=y_col, aggfunc="first"
)
st.line_chart(chart_wide)

st.caption(
    "Forecast is a simple linear trend extrapolation for illustration. "
    "When a Cortex ML FORECAST model is available, this page will use its predictions and confidence intervals."
)

with st.expander("Underlying data"):
    st.dataframe(combined, use_container_width=True, hide_index=True)

# ── Demand by part category ──────────────────────────────────────────
st.markdown("---")
st.subheader("Demand by Part Category")

with st.spinner("Loading category demand..."):
    cat_demand = load_demand_by_part()

if not cat_demand.empty:
    cat_demand["MONTH_START_DATE"] = pd.to_datetime(cat_demand["MONTH_START_DATE"])
    pivot = cat_demand.pivot_table(
        index="MONTH_START_DATE", columns="PART_CATEGORY", values="DEMAND", aggfunc="sum"
    ).fillna(0)
    st.line_chart(pivot)
else:
    st.info("No category-level demand data available.")

# ── Inventory risk highlights ─────────────────────────────────────────
st.markdown("---")
st.subheader("Inventory Risk Highlights")
st.caption("Current stockout, below-reorder, and excess flags from `GLD_INVENTORY_HEALTH`.")

with st.spinner("Loading inventory risks..."):
    inv_risk = load_inventory_risk()

if not inv_risk.empty:
    with st.container(horizontal=True):
        total_stockouts = int(inv_risk["STOCKOUT_PARTS"].sum())
        total_below = int(inv_risk["BELOW_REORDER"].sum())
        total_excess = int(inv_risk["EXCESS_PARTS"].sum())
        st.metric("Stockout Positions", total_stockouts, border=True)
        st.metric("Below Reorder Point", total_below, border=True)
        st.metric("Excess Inventory", total_excess, border=True)
    st.dataframe(inv_risk, use_container_width=True, hide_index=True)
else:
    st.info("No inventory risk data available.")
