"""Page 3 – Conversational Analytics: Cortex Analyst chat via SV_SUPPLY_CHAIN."""
import json
from typing import Any, Dict, List

import pandas as pd
import streamlit as st

conn = st.session_state["sf_conn"]
session = st.session_state["sf_session"]
SEMANTIC_VIEW = "SCO_HACKATHON.SCO_GOLD.SV_SUPPLY_CHAIN"

PERSONA_QUESTIONS = {
    "Procurement": [
        "What is the average landed cost per unit by supplier?",
        "Which suppliers have the highest landed cost this quarter?",
        "Show me the landed cost trend by month",
    ],
    "Logistics": [
        "What was the overall on-time delivery rate?",
        "Show on-time delivery by month",
        "Which region has the worst OTD?",
    ],
    "Inventory Planning": [
        "What are the days of inventory by part category?",
        "Fill rate by customer service tier",
        "Which warehouse has the lowest fill rate?",
    ],
}

st.header("Conversational Analytics")
st.caption(
    "Ask natural-language questions about supply chain metrics. "
    "Cortex Analyst translates them to SQL against the governed semantic view "
    f"`{SEMANTIC_VIEW}` — one definition, one number, every user."
)


# ── Cortex Analyst bridge ─────────────────────────────────────────────
def send_message(messages: List[Dict]) -> Dict[str, Any]:
    request_body = {
        "messages": messages,
        "semantic_view": SEMANTIC_VIEW,
    }
    try:
        import _snowflake
        resp = _snowflake.send_snow_api_request(
            "POST",
            "/api/v2/cortex/analyst/message",
            {},
            {},
            request_body,
            None,
            30000,
        )
        if resp["status"] < 400:
            return json.loads(resp["content"])
        else:
            raise Exception(f"Cortex Analyst request failed: {resp['status']}")
    except ImportError:
        import requests, os
        token_path = os.environ.get("SNOWFLAKE_TOKEN_FILE_PATH", "/snowflake/session/token")
        with open(token_path) as f:
            token = f.read().strip()
        host = os.environ.get("SNOWFLAKE_HOST", "")
        if not host:
            raise Exception("SNOWFLAKE_HOST not set and _snowflake unavailable")
        url = f"https://{host}/api/v2/cortex/analyst/message"
        resp = requests.post(
            url,
            json=request_body,
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
                "Accept": "application/json",
                "X-Snowflake-Authorization-Token-Type": "OAUTH",
            },
            timeout=30,
        )
        if resp.status_code >= 400:
            raise Exception(f"{resp.status_code}: {resp.text[:500]}")
        return resp.json()


def run_sql(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()


def display_content(content: List[Dict[str, str]]):
    for block in content:
        btype = block.get("type", "")
        if btype == "text":
            st.markdown(block["text"])
        elif btype == "sql":
            sql_stmt = block["statement"]
            with st.expander("Generated SQL", expanded=False):
                st.code(sql_stmt, language="sql")
            try:
                df = run_sql(sql_stmt)
                st.dataframe(df, use_container_width=True, hide_index=True)
                _try_chart(df)
            except Exception as e:
                st.error(f"Error executing SQL: {e}")
        elif btype == "suggestions":
            st.info("Cortex Analyst suggested alternatives:")
            for s in block.get("suggestions", []):
                st.markdown(f"- {s}")


def _try_chart(df: pd.DataFrame):
    if df.empty or len(df.columns) < 2:
        return
    dim_col = df.columns[0]
    num_cols = [c for c in df.columns[1:] if pd.api.types.is_numeric_dtype(df[c])]
    if not num_cols:
        return
    is_temporal = pd.api.types.is_datetime64_any_dtype(df[dim_col])
    if not is_temporal:
        try:
            pd.to_datetime(df[dim_col].astype(str).str.strip('"'))
            is_temporal = True
        except Exception:
            pass
    chart_df = df[[dim_col] + num_cols].copy().set_index(dim_col)
    if is_temporal:
        try:
            chart_df.index = pd.to_datetime(chart_df.index.astype(str).str.strip('"'))
            chart_df = chart_df.sort_index()
        except Exception:
            pass
        st.line_chart(chart_df)
    elif len(df) <= 30:
        st.bar_chart(chart_df)


def process_message(prompt: str):
    st.session_state.chat_messages.append(
        {"role": "user", "content": [{"type": "text", "text": prompt}]}
    )
    with st.chat_message("user"):
        st.markdown(prompt)
    with st.chat_message("assistant", avatar=":material/smart_toy:"):
        with st.spinner("Asking Cortex Analyst..."):
            try:
                response = send_message(
                    [{"role": "user", "content": [{"type": "text", "text": prompt}]}]
                )
                content = response["message"]["content"]
                display_content(content)
                st.caption(f"Source: `{SEMANTIC_VIEW}` (governed semantic view)")
            except Exception as e:
                content = [{"type": "text", "text": f"Error: {e}"}]
                st.error(f"Could not get a response: {e}")
    st.session_state.chat_messages.append({"role": "analyst", "content": content})


# ── Session state ─────────────────────────────────────────────────────
if "chat_messages" not in st.session_state:
    st.session_state.chat_messages = []

# ── Replay history ────────────────────────────────────────────────────
for msg in st.session_state.chat_messages:
    role = "user" if msg["role"] == "user" else "assistant"
    avatar = None if role == "user" else ":material/smart_toy:"
    with st.chat_message(role, avatar=avatar):
        display_content(msg["content"])

# ── Persona sample questions ──────────────────────────────────────────
if not st.session_state.chat_messages:
    st.markdown("### Sample Questions by Persona")
    st.markdown(
        "Differently-worded questions return the **same governed metric** "
        "because they all resolve against `SV_SUPPLY_CHAIN`."
    )
    for persona, questions in PERSONA_QUESTIONS.items():
        with st.expander(f":material/person: {persona}", expanded=True):
            for q in questions:
                if st.button(q, key=f"q_{persona}_{q[:20]}"):
                    process_message(q)

# ── Chat input ────────────────────────────────────────────────────────
if prompt := st.chat_input("Ask a supply chain question..."):
    process_message(prompt)
