#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
project_name="${SPORTLFC_SNAPSHOT_COMPOSE_PROJECT_NAME:-sportlfc-fixture-snapshot}"
compose=(docker compose -p "$project_name")
tmp_dir="$(mktemp -d)"

cleanup() {
    "${compose[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
    rm -rf "$tmp_dir"
}
trap cleanup EXIT

cd "$repo_root"
"${compose[@]}" up -d db

ready=0
for _ in {1..60}; do
    if "${compose[@]}" exec -T db sh -lc \
        'mysqladmin ping -h 127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD" --silent' >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done

if [[ "$ready" != '1' ]]; then
    printf 'Fixture database did not become ready.\n' >&2
    exit 1
fi

"${compose[@]}" exec -T db sh -lc \
    'mysql --batch --raw --skip-column-names --default-character-set=utf8mb4 -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' \
    >"$tmp_dir/raw.json" <<'SQL'
SELECT JSON_OBJECT(
    'source_files', JSON_ARRAY('sql/01_schema.sql', 'sql/02_seed.sql'),
    'sports', COALESCE((SELECT JSON_ARRAYAGG(JSON_OBJECT(
        'SportID', SportID,
        'SportName', SportName,
        'MaxRosterSize', MaxRosterSize,
        'RegistrationFee', RegistrationFee
    )) FROM (SELECT SportID, SportName, MaxRosterSize, RegistrationFee FROM Sport ORDER BY SportID) ordered_sports), JSON_ARRAY()),
    'teams', COALESCE((SELECT JSON_ARRAYAGG(JSON_OBJECT(
        'TeamID', TeamID,
        'TeamName', TeamName,
        'SportID', SportID,
        'AgeGroup', AgeGroup,
        'Season', Season,
        'CurrentRosterSize', CurrentRosterSize
    )) FROM (SELECT TeamID, TeamName, SportID, AgeGroup, Season, CurrentRosterSize FROM Team ORDER BY TeamID) ordered_teams), JSON_ARRAY()),
    'people', COALESCE((SELECT JSON_ARRAYAGG(JSON_OBJECT(
        'PersonID', PersonID,
        'DisplayName', CONCAT(FirstName, CHAR(32), LastName)
    )) FROM (SELECT PersonID, FirstName, LastName FROM Person ORDER BY PersonID) ordered_people), JSON_ARRAY()),
    'players', COALESCE((SELECT JSON_ARRAYAGG(JSON_OBJECT('PersonID', PersonID)) FROM (SELECT PersonID FROM Player ORDER BY PersonID) ordered_players), JSON_ARRAY()),
    'coaches', COALESCE((SELECT JSON_ARRAYAGG(JSON_OBJECT('PersonID', PersonID)) FROM (SELECT PersonID FROM Coach ORDER BY PersonID) ordered_coaches), JSON_ARRAY()),
    'registrations', COALESCE((SELECT JSON_ARRAYAGG(JSON_OBJECT(
        'PersonID', PersonID,
        'SportID', SportID,
        'RegistrationDate', RegistrationDate
    )) FROM (SELECT PersonID, SportID, RegistrationDate FROM Registers ORDER BY PersonID, SportID) ordered_registrations), JSON_ARRAY()),
    'coach_assignments', COALESCE((SELECT JSON_ARRAYAGG(JSON_OBJECT(
        'PersonID', PersonID,
        'TeamID', TeamID,
        'SportID', SportID,
        'CoachRole', CoachRole
    )) FROM (SELECT PersonID, TeamID, SportID, CoachRole FROM CoachesFor ORDER BY TeamID, PersonID) ordered_assignments), JSON_ARRAY()),
    'items', COALESCE((SELECT JSON_ARRAYAGG(JSON_OBJECT(
        'ItemID', ItemID,
        'ItemName', ItemName,
        'UnitPrice', UnitPrice
    )) FROM (SELECT ItemID, ItemName, UnitPrice FROM UniformItem ORDER BY ItemID) ordered_items), JSON_ARRAY()),
    'requirements', COALESCE((SELECT JSON_ARRAYAGG(JSON_OBJECT(
        'SportID', SportID,
        'ItemID', ItemID,
        'MinQuantity', MinQuantity
    )) FROM (SELECT SportID, ItemID, MinQuantity FROM Requires ORDER BY SportID, ItemID) ordered_requirements), JSON_ARRAY()),
    'equipment_orders', COALESCE((SELECT JSON_ARRAYAGG(JSON_OBJECT(
        'OrderID', OrderID,
        'PersonID', PersonID,
        'TeamID', TeamID,
        'SportID', SportID,
        'ItemID', ItemID,
        'SizeLabel', SizeLabel,
        'Quantity', Quantity,
        'OrderedAt', OrderedAt
    )) FROM (SELECT OrderID, PersonID, TeamID, SportID, ItemID, SizeLabel, Quantity, OrderedAt FROM EquipmentOrder ORDER BY OrderID) ordered_orders), JSON_ARRAY()),
    'fees', COALESCE((SELECT JSON_ARRAYAGG(JSON_OBJECT(
        'PersonID', PersonID,
        'TeamID', TeamID,
        'PlayerName', PlayerName,
        'TeamName', TeamName,
        'AmountOwed', AmountOwed
    )) FROM (SELECT PersonID, TeamID, PlayerName, TeamName, ROUND(AmountOwed, 2) AS AmountOwed FROM FeesOwed ORDER BY PersonID, TeamID) ordered_fees), JSON_ARRAY())
);
SQL

python3 - "$tmp_dir/raw.json" "$repo_root/demo/fixture_snapshot.json" <<'PY'
import json
import sys
from pathlib import Path

raw_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
payload = json.loads(raw_path.read_text(encoding="utf-8").strip())

sort_keys = {
    "sports": lambda row: (row["SportID"],),
    "teams": lambda row: (row["TeamID"],),
    "people": lambda row: (row["PersonID"],),
    "players": lambda row: (row["PersonID"],),
    "coaches": lambda row: (row["PersonID"],),
    "registrations": lambda row: (row["PersonID"], row["SportID"]),
    "coach_assignments": lambda row: (row["TeamID"], row["PersonID"], row["CoachRole"]),
    "items": lambda row: (row["ItemID"],),
    "requirements": lambda row: (row["SportID"], row["ItemID"]),
    "equipment_orders": lambda row: (row["OrderID"],),
    "fees": lambda row: (row["PersonID"], row["TeamID"]),
}
for collection, key in sort_keys.items():
    payload[collection] = sorted(payload[collection], key=key)

output_path.write_text(
    json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=False) + "\n",
    encoding="utf-8",
)
print(f"Wrote {output_path}")
PY
