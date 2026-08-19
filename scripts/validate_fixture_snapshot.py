#!/usr/bin/env python3
import json
import sys
from pathlib import Path


EXPECTED_COUNTS = {
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

REQUIRED_FIELDS = {
    "sports": {"SportID", "SportName", "MaxRosterSize", "RegistrationFee"},
    "teams": {"TeamID", "TeamName", "SportID", "AgeGroup", "Season", "CurrentRosterSize"},
    "people": {"PersonID", "DisplayName"},
    "players": {"PersonID"},
    "coaches": {"PersonID"},
    "registrations": {"PersonID", "SportID", "RegistrationDate"},
    "coach_assignments": {"PersonID", "TeamID", "SportID", "CoachRole"},
    "items": {"ItemID", "ItemName", "UnitPrice"},
    "requirements": {"SportID", "ItemID", "MinQuantity"},
    "equipment_orders": {"OrderID", "PersonID", "TeamID", "SportID", "ItemID", "SizeLabel", "Quantity", "OrderedAt"},
    "fees": {"PersonID", "TeamID", "PlayerName", "TeamName", "AmountOwed"},
}

FORBIDDEN_FIELDS = {"PasswordHash", "Phone", "GuardianName", "BirthDate"}

SORT_KEYS = {
    "sports": lambda row: (row["SportID"],),
    "teams": lambda row: (row["TeamID"],),
    "people": lambda row: (row["PersonID"],),
    "players": lambda row: (row["PersonID"],),
    "coaches": lambda row: (row["PersonID"],),
    "registrations": lambda row: (row["PersonID"], row["SportID"]),
    "coach_assignments": lambda row: (row["TeamID"], row["PersonID"]),
    "items": lambda row: (row["ItemID"],),
    "requirements": lambda row: (row["SportID"], row["ItemID"]),
    "equipment_orders": lambda row: (row["OrderID"],),
    "fees": lambda row: (row["PersonID"], row["TeamID"]),
}


def validate(path: Path) -> list[str]:
    errors: list[str] = []
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return [f"cannot load snapshot: {error}"]

    expected_keys = {"source_files", *REQUIRED_FIELDS}
    if set(payload) != expected_keys:
        errors.append(f"top-level keys differ: {sorted(payload)}")
    if payload.get("source_files") != ["sql/01_schema.sql", "sql/02_seed.sql"]:
        errors.append("source_files must identify the schema and seed SQL files")

    serialized = json.dumps(payload, ensure_ascii=False)
    for field in FORBIDDEN_FIELDS:
        if field in serialized:
            errors.append(f"forbidden field present: {field}")

    for collection, required_fields in REQUIRED_FIELDS.items():
        rows = payload.get(collection, [])
        if not isinstance(rows, list):
            errors.append(f"{collection} must be a list")
            continue
        expected_count = EXPECTED_COUNTS.get(collection)
        if expected_count is not None and len(rows) != expected_count:
            errors.append(f"{collection} count is {len(rows)}, expected {expected_count}")
        for index, row in enumerate(rows):
            if not isinstance(row, dict):
                errors.append(f"{collection}[{index}] must be an object")
                continue
            missing = required_fields - set(row)
            if missing:
                errors.append(f"{collection}[{index}] is missing {sorted(missing)}")
        key = SORT_KEYS[collection]
        try:
            if rows != sorted(rows, key=key):
                errors.append(f"{collection} is not deterministically ordered")
        except (KeyError, TypeError):
            pass
    return errors


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate_fixture_snapshot.py SNAPSHOT", file=sys.stderr)
        return 2
    errors = validate(Path(sys.argv[1]))
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print("Fixture snapshot contract passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
