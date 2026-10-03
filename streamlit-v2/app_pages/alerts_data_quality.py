"""Page 5 – Alerts & Data Quality: DQ scorecard, freshness, alerts, pipeline audit."""
import streamlit as st

conn = st.session_state["sf_conn"]
GOV = "SCO_HACKATHON.SCO_GOVERNANCE"
GOLD = "SCO_HACKATHON.SCO_GOLD"

st.header("Alerts & Data Quality")
st.caption(
    "Data quality checks from the SCO_GOVERNANCE layer. "
    "Business alerts from `ALRT_DATA_QUALITY_FAILURE`. "
    "Last pipeline audit from `GLD_PIPELINE_AUDIT`."
)


@st.cache_data(ttl=300)
def load_dq_scorecard():
    return conn.query(f"""
        SELECT DQ_DIMENSION, CHECK_NAME, VIOLATION_COUNT, STATUS
        FROM {GOV}.V_DQ_SCORECARD
        ORDER BY STATUS DESC, DQ_DIMENSION, CHECK_NAME
    """)


@st.cache_data(ttl=300)
def load_freshness():
    return conn.query(f"""
        SELECT TABLE_NAME, LAST_UPDATED_AT, HOURS_STALE, SLA_HOURS, STATUS
        FROM {GOV}.V_DQ_FRESHNESS
        ORDER BY HOURS_STALE DESC
    """)


@st.cache_data(ttl=300)
def load_completeness():
    return conn.query(f"""
        SELECT TABLE_NAME, COLUMN_NAME, NULL_ROWS, TOTAL_ROWS, NULL_PCT
        FROM {GOV}.V_DQ_COMPLETENESS
        ORDER BY NULL_PCT DESC
    """)


@st.cache_data(ttl=300)
def load_referential_integrity():
    return conn.query(f"""
        SELECT RELATIONSHIP, ORPHAN_ROWS
        FROM {GOV}.V_DQ_REFERENTIAL_INTEGRITY
        ORDER BY ORPHAN_ROWS DESC
    """)


@st.cache_data(ttl=300)
def load_business_rules():
    return conn.query(f"""
        SELECT RULE_NAME, VIOLATION_ROWS
        FROM {GOV}.V_DQ_BUSINESS_RULES
        ORDER BY VIOLATION_ROWS DESC
    """)


@st.cache_data(ttl=300)
def load_pipeline_audit():
    return conn.query(f"""
        SELECT AUDIT_EVENT_TS, TASK_NAME, OBJECT_NAME, AUDIT_EVENT, STATUS, ROWS_AFFECTED
        FROM {GOLD}.GLD_PIPELINE_AUDIT
        ORDER BY AUDIT_EVENT_TS DESC
        LIMIT 50
    """)


@st.cache_data(ttl=300)
def load_alert_status():
    return conn.query("""
        SELECT NAME, STATE, SCHEDULE, CONDITION, COMMENT
        FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
    """)


# ── Overall scorecard ─────────────────────────────────────────────────
st.subheader("Data Quality Scorecard")
with st.spinner("Loading DQ scorecard..."):
    dq = load_dq_scorecard()

if not dq.empty:
    total = len(dq)
    passed = int((dq["STATUS"] == "PASS").sum())
    failed = total - passed
    pass_pct = passed / total * 100 if total > 0 else 0

    with st.container(horizontal=True):
        st.metric("Total Checks", total, border=True)
        st.metric("Passed", passed, border=True)
        st.metric("Failed", failed, border=True)
        st.metric("Pass Rate", f"{pass_pct:.0f}%", border=True)

    # by dimension
    summary = (
        dq.groupby("DQ_DIMENSION")
        .agg(
            TOTAL=("STATUS", "count"),
            PASSED=("STATUS", lambda s: (s == "PASS").sum()),
            FAILED=("STATUS", lambda s: (s == "FAIL").sum()),
        )
        .reset_index()
    )
    summary["PASS_RATE"] = (summary["PASSED"] / summary["TOTAL"] * 100).round(1).astype(str) + "%"

    col1, col2 = st.columns([1, 2])
    with col1:
        st.markdown("**Summary by Dimension**")
        st.dataframe(summary, use_container_width=True, hide_index=True)
    with col2:
        failing = dq[dq["STATUS"] == "FAIL"]
        if not failing.empty:
            st.markdown("**Failing Checks**")
            st.dataframe(failing, use_container_width=True, hide_index=True)
        else:
            st.success("All data quality checks are passing.")

    with st.expander("Full check detail"):
        st.dataframe(dq, use_container_width=True, hide_index=True)
else:
    st.warning("Could not load DQ scorecard. The V_DQ_SCORECARD view may not be accessible.")

# ── Freshness ─────────────────────────────────────────────────────────
st.markdown("---")
st.subheader("Data Freshness")
st.caption("Hours since last update on high-churn source tables vs SLA thresholds.")

with st.spinner("Loading freshness..."):
    fresh = load_freshness()

if not fresh.empty:
    stale_count = int((fresh["STATUS"] == "STALE").sum())
    if stale_count > 0:
        st.warning(f"{stale_count} table(s) are STALE beyond their SLA threshold.")
    else:
        st.success("All monitored tables are FRESH within SLA.")
    st.dataframe(fresh, use_container_width=True, hide_index=True)
else:
    st.info("No freshness data available.")

# ── Completeness ──────────────────────────────────────────────────────
st.markdown("---")
col_a, col_b = st.columns(2)

with col_a:
    st.subheader("Completeness (NULLs)")
    with st.spinner("Loading completeness..."):
        comp = load_completeness()
    if not comp.empty:
        st.dataframe(comp, use_container_width=True, hide_index=True)
    else:
        st.info("No completeness data available.")

with col_b:
    st.subheader("Referential Integrity")
    with st.spinner("Loading RI..."):
        ri = load_referential_integrity()
    if not ri.empty:
        st.dataframe(ri, use_container_width=True, hide_index=True)
    else:
        st.info("No referential integrity data available.")

# ── Business rules ────────────────────────────────────────────────────
st.markdown("---")
st.subheader("Business Rule Violations")
with st.spinner("Loading business rules..."):
    br = load_business_rules()
if not br.empty:
    st.dataframe(br, use_container_width=True, hide_index=True)
else:
    st.info("No business rule violations detected.")

# ── Pipeline audit ────────────────────────────────────────────────────
st.markdown("---")
st.subheader("Pipeline Audit Trail")
st.caption("Recent entries from `GLD_PIPELINE_AUDIT` (last 50 events).")

with st.spinner("Loading audit trail..."):
    audit = load_pipeline_audit()
if not audit.empty:
    st.dataframe(audit, use_container_width=True, hide_index=True)
else:
    st.info("No pipeline audit entries recorded yet.")

# ── Alert status ──────────────────────────────────────────────────────
st.markdown("---")
st.subheader("Active Alerts")
st.caption(
    "Alert: `ALRT_DATA_QUALITY_FAILURE` monitors V_DQ_SCORECARD for FAIL status every 60 minutes. "
    "Jira MCP integration: not detected in current environment."
)
st.info(
    "Alert `ALRT_DATA_QUALITY_FAILURE` is configured in `SCO_HACKATHON.SCO_GOVERNANCE`. "
    "Current state: **suspended** (enable via `ALTER ALERT ... RESUME` when ready for production)."
)
