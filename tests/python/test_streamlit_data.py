import math
import unittest
from pathlib import Path

from demo.streamlit_data import (
    equipment_fulfillment_rows,
    fee_summary,
    filter_snapshot,
    load_snapshot,
    overview_metrics,
    roster_capacity_rows,
    staffing_rows,
)


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT_PATH = PROJECT_ROOT / "demo" / "fixture_snapshot.json"


class StreamlitDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.snapshot = load_snapshot(SNAPSHOT_PATH)
        cls.soccer = filter_snapshot(cls.snapshot, "Soccer")

    def test_overview_metrics_are_fixture_backed(self):
        self.assertEqual(
            overview_metrics(self.snapshot),
            {
                "people": 32,
                "players": 23,
                "teams": 10,
                "equipment_orders": 92,
            },
        )

    def test_filter_keeps_catalog_and_reduces_operational_rows(self):
        self.assertEqual([row["SportName"] for row in self.soccer["sports"]], ["Soccer"])
        self.assertEqual(
            [row["TeamName"] for row in self.soccer["teams"]],
            ["Lions FC", "River City FC", "Southside Strikers"],
        )
        self.assertTrue(all(row["SportID"] == 1 for row in self.soccer["equipment_orders"]))
        self.assertEqual(len(self.soccer["people"]), 32)

    def test_roster_capacity_rows_are_sorted_and_calculated(self):
        rows = roster_capacity_rows(self.soccer)
        self.assertEqual([row["TeamName"] for row in rows], ["Lions FC", "River City FC", "Southside Strikers"])
        self.assertEqual(rows[0]["CurrentRosterSize"], 4)
        self.assertEqual(rows[0]["MaxRosterSize"], 18)
        self.assertTrue(math.isclose(rows[0]["UtilizationPercent"], 22.2, abs_tol=0.01))

    def test_equipment_fulfillment_uses_roster_requirements_and_orders(self):
        rows = equipment_fulfillment_rows(self.soccer)
        jersey = next(row for row in rows if row["ItemName"] == "Jersey")
        socks = next(row for row in rows if row["ItemName"] == "Socks")
        self.assertEqual(jersey["RequiredUnits"], 9)
        self.assertEqual(jersey["OrderedUnits"], 11)
        self.assertEqual(jersey["OutstandingUnits"], 0)
        self.assertEqual(jersey["FulfillmentStatus"], "Complete")
        self.assertEqual(socks["RequiredUnits"], 18)
        self.assertEqual(socks["OutstandingUnits"], 10)
        self.assertEqual(socks["FulfillmentStatus"], "Incomplete")

    def test_staffing_rows_include_named_head_coach_and_counts(self):
        rows = staffing_rows(self.soccer)
        lions = next(row for row in rows if row["TeamName"] == "Lions FC")
        self.assertEqual(lions["HeadCoach"], "Mike Torres")
        self.assertEqual(lions["AssistantCoaches"], 1)
        self.assertEqual(lions["TotalCoaches"], 2)

    def test_fee_summary_is_reconciled_to_snapshot(self):
        summary = fee_summary(self.snapshot)
        self.assertEqual(summary["FeeRows"], 27)
        self.assertEqual(summary["TotalAmountOwed"], 3791.0)
        self.assertTrue(math.isclose(summary["AverageAmountOwed"], 140.41, abs_tol=0.01))


if __name__ == "__main__":
    unittest.main()
