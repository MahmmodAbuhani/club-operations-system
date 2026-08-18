import json
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT_PATH = PROJECT_ROOT / "demo" / "fixture_snapshot.json"


class FixtureSnapshotContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with SNAPSHOT_PATH.open(encoding="utf-8") as handle:
            cls.snapshot = json.load(handle)

    def test_snapshot_declares_sql_sources_and_required_collections(self):
        self.assertEqual(
            self.snapshot["source_files"],
            ["sql/01_schema.sql", "sql/02_seed.sql"],
        )
        self.assertEqual(
            set(self.snapshot),
            {
                "source_files",
                "sports",
                "teams",
                "people",
                "players",
                "coaches",
                "registrations",
                "coach_assignments",
                "items",
                "requirements",
                "equipment_orders",
                "fees",
            },
        )

    def test_snapshot_matches_known_fixture_counts(self):
        expected_counts = {
            "sports": 6,
            "teams": 10,
            "people": 32,
            "players": 23,
            "coaches": 8,
            "registrations": 27,
            "coach_assignments": 19,
            "items": 12,
            "equipment_orders": 92,
        }
        for collection, expected_count in expected_counts.items():
            with self.subTest(collection=collection):
                self.assertEqual(len(self.snapshot[collection]), expected_count)

    def test_snapshot_excludes_sensitive_fixture_fields(self):
        serialized = json.dumps(self.snapshot)
        for forbidden_field in ("PasswordHash", "Phone", "GuardianName", "BirthDate"):
            with self.subTest(forbidden_field=forbidden_field):
                self.assertNotIn(forbidden_field, serialized)


if __name__ == "__main__":
    unittest.main()
