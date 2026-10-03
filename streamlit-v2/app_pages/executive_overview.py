"""Page 1 – Executive Overview: KPI cards with period comparison and filters."""
import pandas as pd
import streamlit as st

conn = st.session_state["sf_conn"]
session = st.session_state["sf_session"]

DB = "SCO_HACKATHON.SCO_GOLD"

# ── Sidebar filters ──────────────────────────────────────────────────
with st.sidebar:
    st.markdown("### Filters")
    date_range = st.date_input(
        "Period",
        value=(pd.Timestamp("2024-07-01"), pd.Timestamp("2025-12-01")),
        min_value=pd.Timestamp("2024-01-01"),
        max_value=pd.Timestamp("2025-12-31"),
    )
    if isinstance(date_range, tuple) and len(date_range) == 2:
        start_dt, end_dt = date_range
    else:
        start_dt, end_dt = pd.Timestamp("2024-07-01"), pd.Timestamp("2025-12-01")


@st.cache_data(ttl=600)
def _distinct_values(col: str, table: str):
    return [
        r[0]
        for r in session.sql(
            f"SELECT DISTINCT {col} FROM {DB}.{table} ORDER BY 1"
        ).collect()
    ]


SUPPLIERS = _distinct_values("SUPPLIER_NAME", "GLD_METRIC_OTD")
REGIONS = _distinct_values("CUSTOMER_REGION", "GLD_METRIC_OTD")
CATEGORIES = _distinct_values("PART_CATEGORY", "GLD_METRIC_OTD")

with st.sidebar:
    sel_suppliers = st.multiselect("Supplier", SUPPLIERS, default=[])
    sel_regions = st.multiselect("Region", REGIONS, default=[])
    sel_categories = st.multiselect("Part Category", CATEGORIES, default=[])


def _where_clause(date_col="MONTH_START_DATE", has_supplier=True, has_region=True, has_category=True):
    clauses = [f"{date_col} >= '{start_dt}'", f"{date_col} <= '{end_dt}'"]
    if sel_suppliers and has_supplier:
        vals = "','".join(sel_suppliers)
        clauses.append(f"SUPPLIER_NAME IN ('{vals}')")
    if sel_regions and has_region:
        vals = "','".join(sel_regions)
        clauses.append(f"CUSTOMER_REGION IN ('{vals}')")
    if sel_categories and has_category:
        vals = "','".join(sel_categories)
        clauses.append(f"PART_CATEGORY IN ('{vals}')")
    return " AND ".join(clauses)


def _prev_period_clause(date_col="MONTH_START_DATE", has_supplier=True, has_region=True, has_category=True):
    duration = (end_dt - start_dt).days
    prev_start = start_dt - pd.Timedelta(days=duration)
    prev_end = start_dt - pd.Timedelta(days=1)
    clauses = [f"{date_col} >= '{prev_start}'", f"{date_col} <= '{prev_end}'"]
    if sel_suppliers and has_supplier:
        vals = "','".join(sel_suppliers)
        clauses.append(f"SUPPLIER_NAME IN ('{vals}')")
    if sel_regions and has_region:
        vals = "','".join(sel_regions)
        clauses.append(f"CUSTOMER_REGION IN ('{vals}')")
    if sel_categories and has_category:
        vals = "','".join(sel_categories)
        clauses.append(f"PART_CATEGORY IN ('{vals}')")
    return " AND ".join(clauses)


# ── KPI loaders ───────────────────────────────────────────────────────
def _kpi_otd(where):
    return conn.query(f"""
        SELECT SUM(LINES_ON_TIME) / NULLIF(SUM(LINES_DUE), 0) * 100 AS VAL
        FROM {DB}.GLD_METRIC_OTD WHERE {where}
    """)


def _kpi_fill(where):
    return conn.query(f"""
        SELECT SUM(UNITS_FULFILLED) / NULLIF(SUM(UNITS_ORDERED), 0) * 100 AS VAL
        FROM {DB}.GLD_METRIC_FILL_RATE WHERE {where}
    """)


def _kpi_doi(where):
    w = (where
         .replace("SUPPLIER_NAME", "xxx_no_col")
         .replace("CUSTOMER_REGION", "xxx_no_col")
         .replace("MONTH_START_DATE", "SNAPSHOT_DATE"))
    safe_where = " AND ".join(
        c for c in w.split(" AND ") if "xxx_no_col" not in c
    )
    safe_where = safe_where if safe_where else "1=1"
    return conn.query(f"""
        SELECT SUM(QUANTITY_ON_HAND) / NULLIF(SUM(AVG_DAILY_DEMAND), 0) AS VAL
        FROM {DB}.GLD_METRIC_DOI
        WHERE AGGREGATION_LEVEL = 'PART_WAREHOUSE'
          AND {safe_where}
    """)


def _kpi_landed(where):
    w = where.replace("CUSTOMER_REGION", "xxx_no_col")
    safe_where = " AND ".join(
        c for c in w.split(" AND ") if "xxx_no_col" not in c
    )
    safe_where = safe_where if safe_where else "1=1"
    return conn.query(f"""
        SELECT SUM(LANDED_COST_PER_UNIT_USD * TOTAL_UNITS) / NULLIF(SUM(TOTAL_UNITS), 0) AS VAL
        FROM {DB}.GLD_METRIC_LANDED_COST WHERE {safe_where}
    """)


def _safe_val(df):
    try:
        v = df.iloc[0, 0]
        return float(v) if v is not None else None
    except Exception:
        return None


# ── Header ────────────────────────────────────────────────────────────
st.header("Executive Overview")
st.caption(
    "All KPIs calculated from governed Gold tables using ratio-of-sums. "
    "OTD = SUM(lines_on_time) / SUM(lines_due). Never averages of pre-computed percentages."
)

# ── Metric definitions reference ──────────────────────────────────────
METRIC_META = {
    "OTD": {"target": "95-100%", "domain": "Logistics", "unit": "%"},
    "Fill Rate": {"target": "92-100%", "domain": "Inventory Planning", "unit": "%"},
    "DOI": {"target": "15-45 days", "domain": "Inventory Planning", "unit": "days"},
    "Landed Cost": {"target": "Benchmark", "domain": "Procurement", "unit": "$/unit"},
}

cur_w = _where_clause()
prev_w = _prev_period_clause()

with st.spinner("Loading KPIs..."):
    otd_cur = _safe_val(_kpi_otd(cur_w))
    otd_prev = _safe_val(_kpi_otd(prev_w))
    fill_cur = _safe_val(_kpi_fill(
        _where_clause(has_supplier=False, has_region=False)
    ))
    fill_prev = _safe_val(_kpi_fill(
        _prev_period_clause(has_supplier=False, has_region=False)
    ))
    doi_cur = _safe_val(_kpi_doi(cur_w))
    doi_prev = _safe_val(_kpi_doi(prev_w))
    landed_cur = _safe_val(_kpi_landed(cur_w))
    landed_prev = _safe_val(_kpi_landed(prev_w))


def _delta(cur, prev):
    if cur is not None and prev is not None and prev != 0:
        return f"{cur - prev:+.1f}"
    return None


# ── KPI cards ─────────────────────────────────────────────────────────
with st.container(horizontal=True):
    with st.container(border=True):
        val_str = f"{otd_cur:.1f}%" if otd_cur is not None else "N/A"
        st.metric("On-Time Delivery", val_str, delta=_delta(otd_cur, otd_prev))
        st.caption(f"Target: {METRIC_META['OTD']['target']} | {METRIC_META['OTD']['domain']}")

    with st.container(border=True):
        val_str = f"{fill_cur:.1f}%" if fill_cur is not None else "N/A"
        st.metric("Fill Rate", val_str, delta=_delta(fill_cur, fill_prev))
        st.caption(f"Target: {METRIC_META['Fill Rate']['target']} | {METRIC_META['Fill Rate']['domain']}")

    with st.container(border=True):
        val_str = f"{doi_cur:.1f}" if doi_cur is not None else "N/A"
        st.metric("Days of Inventory", val_str, delta=_delta(doi_cur, doi_prev))
        st.caption(f"Target: {METRIC_META['DOI']['target']} | {METRIC_META['DOI']['domain']}")

    with st.container(border=True):
        val_str = f"${landed_cur:.2f}" if landed_cur is not None else "N/A"
        st.metric("Landed Cost/Unit", val_str, delta=_delta(landed_cur, landed_prev), delta_color="inverse")
        st.caption(f"Target: {METRIC_META['Landed Cost']['target']} | {METRIC_META['Landed Cost']['domain']}")


# ── Monthly OTD trend ─────────────────────────────────────────────────
st.markdown("---")
st.subheader("Monthly On-Time Delivery Trend")

otd_monthly = conn.query(f"""
    SELECT MONTH_START_DATE,
           SUM(LINES_ON_TIME) / NULLIF(SUM(LINES_DUE), 0) * 100 AS OTD_PCT
    FROM {DB}.GLD_METRIC_OTD
    WHERE {_where_clause()}
    GROUP BY MONTH_START_DATE ORDER BY MONTH_START_DATE
""")

if not otd_monthly.empty:
    otd_monthly["MONTH_START_DATE"] = pd.to_datetime(otd_monthly["MONTH_START_DATE"])
    st.line_chart(otd_monthly.set_index("MONTH_START_DATE"), y="OTD_PCT", use_container_width=True)
else:
    st.warning("No OTD data for the selected filters.")

# ── Supplier scorecard snapshot ───────────────────────────────────────
st.subheader("Supplier Scorecard (Latest Period)")
sc_where = _where_clause()
sc = conn.query(f"""
    SELECT SUPPLIER_NAME,
           ON_TIME_DELIVERY_RATE_PCT,
           FILL_RATE_PCT,
           AVG_LANDED_COST_PER_UNIT_USD,
           RISK_SCORE,
           ESG_SCORE,
           SPEND_USD
    FROM {DB}.GLD_SUPPLIER_SCORECARD
    WHERE {sc_where}
    ORDER BY SPEND_USD DESC
    LIMIT 20
""")
if not sc.empty:
    st.dataframe(sc, use_container_width=True, hide_index=True)
else:
    st.info("No supplier scorecard data for the selected filters.")
