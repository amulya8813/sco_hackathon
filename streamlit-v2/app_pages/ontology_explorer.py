"""Page 6 – Ontology Explorer: entity-relationship browser for the SCO data model."""
import streamlit as st

conn = st.session_state["sf_conn"]

st.header("Ontology Explorer")
st.caption(
    "Core supply chain entities and their relationships, metrics, and source tables. "
    "Derived from the SCO_SILVER dimension/fact model and SCO_GOLD governed metrics."
)

# ── Ontology definition (static, derived from actual schema) ──────────
ONTOLOGY = {
    "Supplier": {
        "definition": "An external organization that provides parts, materials, or services under contractual terms.",
        "silver_table": "SLV_DIM_SUPPLIER",
        "gold_tables": ["GLD_SUPPLIER_SCORECARD", "GLD_METRIC_OTD", "GLD_METRIC_LANDED_COST", "GLD_RISK_EXPOSURE"],
        "key_columns": ["SUPPLIER_ID", "SUPPLIER_NAME"],
        "metrics": ["On-Time Delivery Rate", "Fill Rate", "Landed Cost/Unit", "Risk Score", "ESG Score"],
        "relationships": {
            "supplies": "Part",
            "ships via": "Route",
            "assessed by": "Risk Assessment",
            "delivers to": "Customer",
        },
    },
    "Part": {
        "definition": "A distinct item, material, or SKU that can be ordered, shipped, and inventoried.",
        "silver_table": "SLV_DIM_PART",
        "gold_tables": ["GLD_METRIC_DOI", "GLD_DEMAND_HISTORY", "GLD_INVENTORY_HEALTH"],
        "key_columns": ["PART_ID", "PART_NUMBER", "PART_NAME", "PART_CATEGORY"],
        "metrics": ["Days of Inventory", "Demand Quantity", "Stockout Flag", "Excess Flag"],
        "relationships": {
            "sourced from": "Supplier",
            "stored at": "Warehouse",
            "ordered in": "Order",
            "classified under": "Commodity",
        },
    },
    "Plant": {
        "definition": "A manufacturing or assembly facility owned by a supplier, where parts are produced or processed.",
        "silver_table": "SLV_DIM_PLANT",
        "gold_tables": [],
        "key_columns": ["PLANT_ID", "PLANT_NAME"],
        "metrics": [],
        "relationships": {
            "owned by": "Supplier",
            "located in": "Country",
            "origin for": "Shipment",
        },
    },
    "Order": {
        "definition": "A purchase order comprising one or more line items placed with a supplier for parts delivery.",
        "silver_table": "SLV_FACT_ORDER_LINE",
        "gold_tables": ["GLD_METRIC_OTD", "GLD_METRIC_FILL_RATE"],
        "key_columns": ["ORDER_ID", "LINE_ITEM_ID", "QUANTITY_ORDERED", "PROMISED_DELIVERY_DATE"],
        "metrics": ["On-Time Delivery Rate", "Fill Rate"],
        "relationships": {
            "placed with": "Supplier",
            "contains": "Part",
            "delivered to": "Customer",
            "fulfilled by": "Shipment",
        },
    },
    "Shipment": {
        "definition": "A physical transport event moving goods from an origin (supplier/plant/warehouse) to a destination.",
        "silver_table": "SLV_FACT_SHIPMENT",
        "gold_tables": ["GLD_SHIPMENT_PERFORMANCE"],
        "key_columns": ["SHIPMENT_ID", "CARRIER_ID", "ROUTE_ID", "FREIGHT_COST_USD"],
        "metrics": ["On-Time Arrival Rate", "Avg Transit Variance", "Freight Cost/Kg"],
        "relationships": {
            "carried by": "Carrier",
            "follows": "Route",
            "contains lines from": "Order",
            "originates at": "Plant / Warehouse",
        },
    },
    "Customer": {
        "definition": "An organization or entity that places demand (purchase orders) for parts from the supply chain.",
        "silver_table": "SLV_DIM_CUSTOMER",
        "gold_tables": ["GLD_METRIC_OTD", "GLD_METRIC_FILL_RATE"],
        "key_columns": ["CUSTOMER_ID", "CUSTOMER_NAME", "CUSTOMER_REGION", "SERVICE_TIER"],
        "metrics": ["OTD by Region", "Fill Rate by Service Tier"],
        "relationships": {
            "receives": "Order",
            "located in": "Country / Region",
        },
    },
    "Warehouse": {
        "definition": "A storage facility where inventory is held and from which orders may be fulfilled.",
        "silver_table": "SLV_DIM_WAREHOUSE",
        "gold_tables": ["GLD_INVENTORY_HEALTH", "GLD_METRIC_DOI", "GLD_METRIC_FILL_RATE"],
        "key_columns": ["WAREHOUSE_ID", "WAREHOUSE_NAME"],
        "metrics": ["Days of Inventory", "Fill Rate", "Stockout Count"],
        "relationships": {
            "stores": "Part",
            "fulfills": "Order",
        },
    },
    "Carrier": {
        "definition": "A logistics provider responsible for transporting shipments along defined routes.",
        "silver_table": "SLV_DIM_CARRIER",
        "gold_tables": ["GLD_SHIPMENT_PERFORMANCE"],
        "key_columns": ["CARRIER_ID", "CARRIER_NAME", "TRANSPORT_MODE"],
        "metrics": ["On-Time Arrival Rate", "Freight Cost/Kg"],
        "relationships": {
            "transports": "Shipment",
            "operates on": "Route",
        },
    },
    "Route": {
        "definition": "A defined logistics lane between an origin port/location and a destination port/location.",
        "silver_table": "SLV_DIM_ROUTE",
        "gold_tables": ["GLD_METRIC_LANDED_COST", "GLD_SHIPMENT_PERFORMANCE"],
        "key_columns": ["ROUTE_ID", "ROUTE_NAME", "ORIGIN_PORT", "DESTINATION_PORT"],
        "metrics": ["Landed Cost/Unit", "Freight Cost/Kg"],
        "relationships": {
            "connects": "Shipment",
            "used by": "Carrier",
        },
    },
    "Commodity": {
        "definition": "A Harmonized System (HS) classification for traded goods, with associated duty and compliance attributes.",
        "silver_table": "SLV_DIM_COMMODITY",
        "gold_tables": [],
        "key_columns": ["COMMODITY_ID", "HS_CODE", "DESCRIPTION"],
        "metrics": [],
        "relationships": {
            "classifies": "Part",
        },
    },
    "Country": {
        "definition": "A geographic entity with ISO codes, sanctions status, and regional assignment used for risk and logistics.",
        "silver_table": "SLV_DIM_COUNTRY",
        "gold_tables": [],
        "key_columns": ["COUNTRY_ID", "ISO_ALPHA3", "COUNTRY_NAME", "REGION"],
        "metrics": [],
        "relationships": {
            "home to": "Supplier / Plant / Warehouse",
        },
    },
}

# ── Entity relationship diagram (Mermaid-style text) ──────────────────
MERMAID_DIAGRAM = """
```
Supplier --supplies--> Part --stored at--> Warehouse
Supplier --ships via--> Route <--follows-- Shipment
Supplier <--placed with-- Order --contains--> Part
Order --fulfilled by--> Shipment --carried by--> Carrier
Shipment --originates at--> Plant --owned by--> Supplier
Customer --receives--> Order
Part --classified under--> Commodity
Supplier / Plant / Warehouse --located in--> Country
```
"""

st.subheader("Entity Relationship Map")
st.code(
    "Supplier ──supplies──> Part ──stored at──> Warehouse\n"
    "Supplier ──ships via──> Route <──follows── Shipment\n"
    "Supplier <──placed with── Order ──contains──> Part\n"
    "Order ──fulfilled by──> Shipment ──carried by──> Carrier\n"
    "Shipment ──originates at──> Plant ──owned by──> Supplier\n"
    "Customer ──receives──> Order\n"
    "Part ──classified under──> Commodity\n"
    "Supplier / Plant / Warehouse ──located in──> Country",
    language=None,
)

# ── Entity selector ───────────────────────────────────────────────────
st.markdown("---")
st.subheader("Entity Details")

selected = st.selectbox("Select an entity", list(ONTOLOGY.keys()))
entity = ONTOLOGY[selected]

col1, col2 = st.columns(2)
with col1:
    with st.container(border=True):
        st.markdown(f"### {selected}")
        st.markdown(f"**Definition:** {entity['definition']}")
        st.markdown(f"**Silver Table:** `SCO_SILVER.{entity['silver_table']}`")
        if entity["gold_tables"]:
            gold_list = ", ".join(f"`SCO_GOLD.{t}`" for t in entity["gold_tables"])
            st.markdown(f"**Gold Tables:** {gold_list}")
        else:
            st.markdown("**Gold Tables:** None (dimension only)")
        st.markdown(f"**Key Columns:** {', '.join(f'`{c}`' for c in entity['key_columns'])}")

with col2:
    with st.container(border=True):
        st.markdown("**Relationships**")
        for rel, target in entity["relationships"].items():
            st.markdown(f"- {selected} *{rel}* **{target}**")

        if entity["metrics"]:
            st.markdown("**Supported Metrics**")
            for m in entity["metrics"]:
                st.markdown(f"- {m}")
        else:
            st.markdown("*No governed metrics directly associated.*")

# ── Live row counts ───────────────────────────────────────────────────
st.markdown("---")
st.subheader("Entity Volume")


@st.cache_data(ttl=600)
def entity_counts():
    tables = list({e["silver_table"] for e in ONTOLOGY.values()})
    results = []
    for t in sorted(tables):
        try:
            row = conn.query(
                f"SELECT '{t}' AS TABLE_NAME, COUNT(*) AS ROW_COUNT "
                f"FROM SCO_HACKATHON.SCO_SILVER.{t}"
            )
            results.append(row)
        except Exception:
            pass
    if results:
        import pandas as pd
        return pd.concat(results, ignore_index=True)
    return None


counts = entity_counts()
if counts is not None and not counts.empty:
    st.dataframe(counts, use_container_width=True, hide_index=True)
else:
    st.info("Could not retrieve entity counts.")
