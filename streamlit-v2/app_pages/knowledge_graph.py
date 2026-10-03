"""Knowledge Graph Explorer — Interactive graph browser for the SCO supply chain ontology."""
import streamlit as st

conn = st.session_state["sf_conn"]
GRAPH = "SCO_HACKATHON.SCO_GRAPH"

st.header("Knowledge Graph Explorer")
st.caption(
    "Interactive browser for the governed supply-chain knowledge graph. "
    "Explore entities, relationships, and multi-hop traversals across SCO_GRAPH."
)

# ── Graph summary ──────────────────────────────────────────────────────
@st.cache_data(ttl=600)
def load_graph_summary():
    nodes = conn.query(f"""
        SELECT NODE_TYPE, COUNT(*) AS NODE_COUNT, ROUND(AVG(DATA_QUALITY_SCORE),1) AS AVG_DQ
        FROM {GRAPH}.V_ALL_NODES GROUP BY NODE_TYPE ORDER BY NODE_COUNT DESC
    """)
    edges = conn.query(f"""
        SELECT EDGE_TYPE, SOURCE_TYPE, TARGET_TYPE, COUNT(*) AS EDGE_COUNT
        FROM {GRAPH}.V_ALL_EDGES GROUP BY EDGE_TYPE, SOURCE_TYPE, TARGET_TYPE ORDER BY EDGE_COUNT DESC
    """)
    return nodes, edges

with st.spinner("Loading graph summary..."):
    node_summary, edge_summary = load_graph_summary()

total_nodes = int(node_summary["NODE_COUNT"].sum())
total_edges = int(edge_summary["EDGE_COUNT"].sum())

with st.container(horizontal=True):
    st.metric("Total Nodes", f"{total_nodes:,}", border=True)
    st.metric("Node Types", len(node_summary), border=True)
    st.metric("Total Edges", f"{total_edges:,}", border=True)
    st.metric("Edge Types", len(edge_summary), border=True)

# ── Node & Edge summary tables ─────────────────────────────────────────
col1, col2 = st.columns(2)
with col1:
    st.subheader("Node Types")
    st.dataframe(node_summary, use_container_width=True, hide_index=True)
with col2:
    st.subheader("Edge Types")
    st.dataframe(edge_summary, use_container_width=True, hide_index=True)

st.markdown("---")

# ── Entity Explorer ────────────────────────────────────────────────────
st.subheader("Entity Explorer")
st.caption("Select a node type and entity to see its neighborhood (1-hop connections).")

node_types = node_summary["NODE_TYPE"].tolist()
sel_type = st.selectbox("Node type", node_types)

@st.cache_data(ttl=300)
def load_entities(node_type):
    return conn.query(f"""
        SELECT NODE_ID, NODE_LABEL, ENTITY_ID, DATA_QUALITY_SCORE, IS_ACTIVE
        FROM {GRAPH}.V_ALL_NODES WHERE NODE_TYPE = '{node_type}'
        ORDER BY NODE_LABEL LIMIT 500
    """)

entities = load_entities(sel_type)
if entities.empty:
    st.warning(f"No {sel_type} nodes found.")
    st.stop()

entity_options = dict(zip(entities["NODE_LABEL"], entities["NODE_ID"]))
sel_entity_label = st.selectbox("Entity", list(entity_options.keys()))
sel_node_id = entity_options[sel_entity_label]

# ── 1-hop neighborhood ────────────────────────────────────────────────
@st.cache_data(ttl=300)
def load_neighborhood(node_id):
    outbound = conn.query(f"""
        SELECT e.EDGE_TYPE, e.TARGET_TYPE AS NEIGHBOR_TYPE,
               n.NODE_LABEL AS NEIGHBOR, e.BUSINESS_MEANING
        FROM {GRAPH}.V_ALL_EDGES e
        JOIN {GRAPH}.V_ALL_NODES n ON n.NODE_ID = e.TARGET_NODE_ID
        WHERE e.SOURCE_NODE_ID = '{node_id}' AND e.DIRECTION <> 'SELF'
        LIMIT 200
    """)
    inbound = conn.query(f"""
        SELECT e.EDGE_TYPE, e.SOURCE_TYPE AS NEIGHBOR_TYPE,
               n.NODE_LABEL AS NEIGHBOR, e.BUSINESS_MEANING
        FROM {GRAPH}.V_ALL_EDGES e
        JOIN {GRAPH}.V_ALL_NODES n ON n.NODE_ID = e.SOURCE_NODE_ID
        WHERE e.TARGET_NODE_ID = '{node_id}' AND e.DIRECTION <> 'SELF'
        LIMIT 200
    """)
    return outbound, inbound

with st.spinner("Loading neighborhood..."):
    outbound, inbound = load_neighborhood(sel_node_id)

col_out, col_in = st.columns(2)
with col_out:
    st.markdown(f"**Outbound edges** ({len(outbound)})")
    if not outbound.empty:
        st.dataframe(outbound, use_container_width=True, hide_index=True)
    else:
        st.info("No outbound edges.")

with col_in:
    st.markdown(f"**Inbound edges** ({len(inbound)})")
    if not inbound.empty:
        st.dataframe(inbound, use_container_width=True, hide_index=True)
    else:
        st.info("No inbound edges.")

st.markdown("---")

# ── Multi-hop: Supplier → Customer risk trace ──────────────────────────
st.subheader("Risk Propagation: Supplier → Customer")
st.caption(
    "Select a supplier to trace risk through parts, orders, and shipments "
    "to exposed customers (4-hop traversal)."
)

@st.cache_data(ttl=300)
def load_suppliers():
    return conn.query(f"""
        SELECT ENTITY_ID, NODE_LABEL, OVERALL_RISK_SCORE, RISK_CATEGORY
        FROM {GRAPH}.V_NODE_SUPPLIER
        WHERE OVERALL_RISK_SCORE IS NOT NULL
        ORDER BY OVERALL_RISK_SCORE DESC LIMIT 100
    """)

suppliers = load_suppliers()
sup_options = dict(zip(
    suppliers.apply(lambda r: f"{r['NODE_LABEL']} (risk: {r['OVERALL_RISK_SCORE']})", axis=1),
    suppliers["ENTITY_ID"]
))
sel_sup_label = st.selectbox("Supplier", list(sup_options.keys()))
sel_sup_id = int(sup_options[sel_sup_label])

@st.cache_data(ttl=300)
def trace_supplier_to_customer(supplier_id):
    return conn.query(f"""
        SELECT
            s.NODE_LABEL  AS SUPPLIER,
            s.OVERALL_RISK_SCORE,
            p.NODE_LABEL  AS PART,
            p.PART_CATEGORY,
            c.NODE_LABEL  AS EXPOSED_CUSTOMER,
            c.SERVICE_LEVEL_TIER
        FROM {GRAPH}.V_NODE_SUPPLIER s
        JOIN {GRAPH}.V_EDGE_SUPPLIER_SUPPLIES_PART sp ON sp.SOURCE_NODE_ID = s.NODE_ID
        JOIN {GRAPH}.V_NODE_PART p ON p.NODE_ID = sp.TARGET_NODE_ID
        JOIN {GRAPH}.V_EDGE_ORDER_CONTAINS_PART oc ON oc.TARGET_NODE_ID = p.NODE_ID
        JOIN {GRAPH}.V_EDGE_ORDER_PLACED_BY_CUSTOMER opc ON opc.SOURCE_NODE_ID = oc.SOURCE_NODE_ID
        JOIN {GRAPH}.V_NODE_CUSTOMER c ON c.NODE_ID = opc.TARGET_NODE_ID
        WHERE s.ENTITY_ID = {supplier_id}
        LIMIT 200
    """)

with st.spinner("Tracing risk propagation..."):
    risk_trace = trace_supplier_to_customer(sel_sup_id)

if not risk_trace.empty:
    st.markdown(f"**{len(risk_trace)} risk paths found**")

    customer_impact = risk_trace.groupby("EXPOSED_CUSTOMER").agg(
        PARTS_AT_RISK=("PART", "nunique"),
        SERVICE_TIER=("SERVICE_LEVEL_TIER", "first")
    ).reset_index().sort_values("PARTS_AT_RISK", ascending=False)
    st.dataframe(customer_impact.head(20), use_container_width=True, hide_index=True)

    with st.expander("Full trace detail"):
        st.dataframe(risk_trace, use_container_width=True, hide_index=True)
else:
    st.info("No downstream customer exposure found for this supplier.")

st.markdown("---")

# ── Carrier Performance via Graph ──────────────────────────────────────
st.subheader("Carrier Performance (Graph-Derived)")

@st.cache_data(ttl=600)
def load_carrier_performance():
    return conn.query(f"""
        SELECT car.NODE_LABEL AS CARRIER, car.PRIMARY_MODE,
            COUNT(*) AS TOTAL_SHIPMENTS,
            COUNT_IF(sh.ON_TIME_ARRIVAL_FLAG) AS ON_TIME,
            ROUND(100.0 * COUNT_IF(sh.ON_TIME_ARRIVAL_FLAG) / NULLIF(COUNT(*), 0), 1) AS ON_TIME_PCT
        FROM {GRAPH}.V_EDGE_SHIPMENT_TRANSPORTED_BY_CARRIER stc
        JOIN {GRAPH}.V_NODE_SHIPMENT sh ON sh.NODE_ID = stc.SOURCE_NODE_ID
        JOIN {GRAPH}.V_NODE_CARRIER car ON car.NODE_ID = stc.TARGET_NODE_ID
        GROUP BY car.NODE_LABEL, car.PRIMARY_MODE
        ORDER BY ON_TIME_PCT ASC
    """)

with st.spinner("Loading carrier performance..."):
    carrier_perf = load_carrier_performance()

if not carrier_perf.empty:
    st.bar_chart(carrier_perf.set_index("CARRIER"), y="ON_TIME_PCT")
    st.dataframe(carrier_perf, use_container_width=True, hide_index=True)

st.markdown("---")
st.info(
    "All graph data sourced from governed SCO_GRAPH views over SCO_SILVER. "
    "No relationships are inferred — every edge represents an explicit FK join."
)
