"""Pure transformations for the fixture-backed Streamlit companion demo."""

from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any


SNAPSHOT_PATH = Path(__file__).with_name("fixture_snapshot.json")


def load_snapshot(path: Path = SNAPSHOT_PATH) -> dict[str, Any]:
    """Load the sanitized, committed fixture snapshot used by the demo."""

    with path.open(encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict):
        raise ValueError("fixture snapshot must be a JSON object")
    return payload


def filter_snapshot(snapshot: dict[str, Any], sport_name: str | None) -> dict[str, Any]:
    """Return a copy whose operational rows are limited to one sport."""

    filtered = copy.deepcopy(snapshot)
    if sport_name is None:
        return filtered

    sport_rows = [row for row in snapshot["sports"] if row["SportName"] == sport_name]
    if not sport_rows:
        raise ValueError(f"unknown sport: {sport_name}")
    sport_ids = {row["SportID"] for row in sport_rows}
    team_ids = {row["TeamID"] for row in snapshot["teams"] if row["SportID"] in sport_ids}

    filtered["sports"] = sport_rows
    filtered["teams"] = [row for row in snapshot["teams"] if row["TeamID"] in team_ids]
    filtered["registrations"] = [row for row in snapshot["registrations"] if row["SportID"] in sport_ids]
    filtered["coach_assignments"] = [row for row in snapshot["coach_assignments"] if row["TeamID"] in team_ids]
    filtered["requirements"] = [row for row in snapshot["requirements"] if row["SportID"] in sport_ids]
    filtered["equipment_orders"] = [row for row in snapshot["equipment_orders"] if row["TeamID"] in team_ids]
    filtered["fees"] = [row for row in snapshot["fees"] if row["TeamID"] in team_ids]
    return filtered


def overview_metrics(snapshot: dict[str, Any]) -> dict[str, int]:
    """Return the compact counts shown above the analytical views."""

    return {
        "people": len(snapshot["people"]),
        "players": len(snapshot["players"]),
        "teams": len(snapshot["teams"]),
        "equipment_orders": len(snapshot["equipment_orders"]),
    }


def roster_capacity_rows(snapshot: dict[str, Any]) -> list[dict[str, Any]]:
    sport_names = {row["SportID"]: row["SportName"] for row in snapshot["sports"]}
    max_rosters = {row["SportID"]: row["MaxRosterSize"] for row in snapshot["sports"]}
    rows = []
    for team in snapshot["teams"]:
        maximum = max_rosters[team["SportID"]]
        current = team["CurrentRosterSize"]
        rows.append(
            {
                "TeamName": team["TeamName"],
                "SportName": sport_names[team["SportID"]],
                "CurrentRosterSize": current,
                "MaxRosterSize": maximum,
                "UtilizationPercent": round((current / maximum) * 100, 1),
            }
        )
    return sorted(rows, key=lambda row: (row["SportName"], row["TeamName"]))


def equipment_fulfillment_rows(snapshot: dict[str, Any]) -> list[dict[str, Any]]:
    sport_names = {row["SportID"]: row["SportName"] for row in snapshot["sports"]}
    item_names = {row["ItemID"]: row["ItemName"] for row in snapshot["items"]}
    roster_sizes: dict[int, int] = {}
    for team in snapshot["teams"]:
        roster_sizes[team["SportID"]] = roster_sizes.get(team["SportID"], 0) + team["CurrentRosterSize"]

    ordered_units: dict[tuple[int, int], int] = {}
    for order in snapshot["equipment_orders"]:
        key = (order["SportID"], order["ItemID"])
        ordered_units[key] = ordered_units.get(key, 0) + order["Quantity"]

    rows = []
    for requirement in snapshot["requirements"]:
        sport_id = requirement["SportID"]
        item_id = requirement["ItemID"]
        required = roster_sizes.get(sport_id, 0) * requirement["MinQuantity"]
        ordered = ordered_units.get((sport_id, item_id), 0)
        outstanding = max(required - ordered, 0)
        rows.append(
            {
                "SportName": sport_names[sport_id],
                "ItemName": item_names[item_id],
                "RequiredUnits": required,
                "OrderedUnits": ordered,
                "OutstandingUnits": outstanding,
                "FulfillmentStatus": "Complete" if outstanding == 0 else "Incomplete",
            }
        )
    return sorted(rows, key=lambda row: (row["SportName"], row["ItemName"]))


def staffing_rows(snapshot: dict[str, Any]) -> list[dict[str, Any]]:
    sport_names = {row["SportID"]: row["SportName"] for row in snapshot["sports"]}
    people_names = {row["PersonID"]: row["DisplayName"] for row in snapshot["people"]}
    assignments: dict[int, list[dict[str, Any]]] = {}
    for assignment in snapshot["coach_assignments"]:
        assignments.setdefault(assignment["TeamID"], []).append(assignment)

    rows = []
    for team in snapshot["teams"]:
        team_assignments = assignments.get(team["TeamID"], [])
        heads = sorted(
            people_names[row["PersonID"]]
            for row in team_assignments
            if row["CoachRole"] == "Head Coach"
        )
        assistants = sum(row["CoachRole"] == "Assistant Coach" for row in team_assignments)
        rows.append(
            {
                "TeamName": team["TeamName"],
                "SportName": sport_names[team["SportID"]],
                "HeadCoach": ", ".join(heads) if heads else "Unassigned",
                "AssistantCoaches": assistants,
                "TotalCoaches": len(team_assignments),
            }
        )
    return sorted(rows, key=lambda row: (row["SportName"], row["TeamName"]))


def fee_summary(snapshot: dict[str, Any]) -> dict[str, float | int]:
    amounts = [float(row["AmountOwed"]) for row in snapshot["fees"]]
    total = round(sum(amounts), 2)
    return {
        "FeeRows": len(amounts),
        "TotalAmountOwed": total,
        "AverageAmountOwed": round(total / len(amounts), 2) if amounts else 0.0,
    }
