"""Public, read-only Streamlit companion for the Club Operations System."""

from __future__ import annotations

import pandas as pd
import streamlit as st

from streamlit_data import (
    equipment_fulfillment_rows,
    fee_summary,
    filter_snapshot,
    load_snapshot,
    overview_metrics,
    roster_capacity_rows,
    staffing_rows,
)


BOUNDARY_LABEL = "Interactive Python demo — fixture-backed; not the PHP/MySQL runtime."

st.set_page_config(
    page_title="Club Operations System | Interactive Python demo",
    page_icon="📊",
    layout="wide",
)


@st.cache_data(show_spinner=False)
def cached_snapshot():
    return load_snapshot()


try:
    snapshot = cached_snapshot()
except (OSError, ValueError) as error:
    st.error(f"The demo fixture could not be loaded: {error}")
    st.stop()

st.info(BOUNDARY_LABEL)
st.title("Club Operations System")
st.write(
    "Explore the same fictional seed data that powers the repository's local PHP/MySQL reference system. "
    "This companion is read-only: filters recalculate views in Python and never write to a database."
)

sport_names = [row["SportName"] for row in snapshot["sports"]]
with st.sidebar:
    st.header("Explore the fixture")
    selected_sport = st.selectbox("Sport filter", ["All sports", *sport_names])
    sport_name = None if selected_sport == "All sports" else selected_sport
    st.caption("Choose a sport to focus the roster, equipment, staffing, and fee views.")

active_snapshot = filter_snapshot(snapshot, sport_name)
metrics = overview_metrics(active_snapshot)
metric_columns = st.columns(4)
metric_columns[0].metric("People in fixture", metrics["people"])
metric_columns[1].metric("Players", metrics["players"])
metric_columns[2].metric("Teams in view", metrics["teams"])
metric_columns[3].metric("Equipment orders", metrics["equipment_orders"])

st.caption(f"Current view: {selected_sport}. Source: `demo/fixture_snapshot.json`.")

st.subheader("Roster capacity")
roster_rows = roster_capacity_rows(active_snapshot)
if roster_rows:
    roster_frame = pd.DataFrame(roster_rows)
    st.bar_chart(
        roster_frame.set_index("TeamName")[["CurrentRosterSize", "MaxRosterSize"]],
        use_container_width=True,
    )
    st.dataframe(
        roster_frame,
        hide_index=True,
        use_container_width=True,
        column_config={
            "UtilizationPercent": st.column_config.ProgressColumn(
                "Utilization",
                format="%.1f%%",
                min_value=0,
                max_value=100,
            )
        },
    )
else:
    st.warning("No roster rows are available for this view.")

st.subheader("Equipment fulfillment")
fulfillment_rows = equipment_fulfillment_rows(active_snapshot)
if fulfillment_rows:
    fulfillment_frame = pd.DataFrame(fulfillment_rows)
    st.bar_chart(
        fulfillment_frame.set_index("ItemName")[["RequiredUnits", "OrderedUnits"]],
        use_container_width=True,
    )
    st.dataframe(fulfillment_frame, hide_index=True, use_container_width=True)
else:
    st.warning("No equipment requirements are available for this view.")

st.subheader("Staffing coverage")
staffing_rows_for_view = staffing_rows(active_snapshot)
if staffing_rows_for_view:
    st.dataframe(pd.DataFrame(staffing_rows_for_view), hide_index=True, use_container_width=True)
else:
    st.warning("No staffing rows are available for this view.")

st.subheader("Fee summary")
fees = fee_summary(active_snapshot)
fee_columns = st.columns(3)
fee_columns[0].metric("Player-team fee rows", fees["FeeRows"])
fee_columns[1].metric("Total amount owed", f"${fees['TotalAmountOwed']:,.2f}")
fee_columns[2].metric("Average amount owed", f"${fees['AverageAmountOwed']:,.2f}")

st.divider()
st.markdown(
    "Source files: [fixture snapshot](https://github.com/MahmmodAbuhani/club-operations-system/blob/main/demo/fixture_snapshot.json), "
    "[Python transformations](https://github.com/MahmmodAbuhani/club-operations-system/blob/main/demo/streamlit_data.py), "
    "and [SQL seed](https://github.com/MahmmodAbuhani/club-operations-system/blob/main/sql/02_seed.sql)."
)
st.caption(
    "All names, dates, and values are fictional. The PHP/MySQL runtime remains available for local execution in the repository."
)
