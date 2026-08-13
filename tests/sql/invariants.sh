#!/usr/bin/env bash
set -euo pipefail

project_name="${SPORTLFC_COMPOSE_PROJECT_NAME:-sportlfc-invariant-test}"
compose=(docker compose -p "$project_name")

cleanup() {
    "${compose[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

"${compose[@]}" up -d db
"${compose[@]}" exec -T db sh -lc \
    'until mysqladmin ping -h 127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD" --silent; do sleep 1; done'

mysql_root() {
    "${compose[@]}" exec -T db sh -lc \
        'mysql --batch --skip-column-names -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"'
}

mysql_app() {
    "${compose[@]}" exec -T db sh -lc \
        'mysql --batch --skip-column-names -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"'
}

mysql_root < sql/01_schema.sql
mysql_root < sql/02_seed.sql
mysql_root < sql/03_data_quality_checks.sql

assert_value() {
    local label="$1"
    local expected="$2"
    local sql="$3"
    local actual
    actual="$(printf '%s\n' "$sql" | mysql_root)"
    if [[ "$actual" != "$expected" ]]; then
        printf 'FAIL: %s (expected %s, got %s)\n' "$label" "$expected" "$actual" >&2
        return 1
    fi
    printf 'PASS: %s\n' "$label"
}

assert_sql_fails() {
    local label="$1"
    local expected_message="$2"
    local sql="$3"
    local error_file
    error_file="$(mktemp)"
    if printf '%s\n' "$sql" | mysql_root 2>"$error_file"; then
        printf 'FAIL: %s (mutation unexpectedly succeeded)\n' "$label" >&2
        rm -f "$error_file"
        return 1
    fi
    if ! grep -Fq "$expected_message" "$error_file"; then
        printf 'FAIL: %s (expected error containing %s)\n' "$label" "$expected_message" >&2
        sed -n '1,20p' "$error_file" >&2
        rm -f "$error_file"
        return 1
    fi
    rm -f "$error_file"
    printf 'PASS: %s\n' "$label"
}

assert_app_sql_fails() {
    local label="$1"
    local expected_message="$2"
    local sql="$3"
    local error_file
    error_file="$(mktemp)"
    if printf '%s\n' "$sql" | mysql_app 2>"$error_file"; then
        printf 'FAIL: %s (runtime mutation unexpectedly succeeded)\n' "$label" >&2
        rm -f "$error_file"
        return 1
    fi
    if ! grep -Fq "$expected_message" "$error_file"; then
        printf 'FAIL: %s (expected error containing %s)\n' "$label" "$expected_message" >&2
        sed -n '1,20p' "$error_file" >&2
        rm -f "$error_file"
        return 1
    fi
    rm -f "$error_file"
    printf 'PASS: %s\n' "$label"
}

assert_value \
    'schema contains exactly 14 base tables' \
    '14' \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_type='BASE TABLE';"

assert_value \
    'schema contains both documented derived views' \
    '2' \
    "SELECT COUNT(*) FROM information_schema.views WHERE table_schema=DATABASE() AND table_name IN ('FeesOwed','EquipmentFulfillment');"

assert_value \
    'cumulative fulfillment includes zero-order requirements' \
    '1' \
    "SELECT COUNT(*) > 0 FROM EquipmentFulfillment WHERE OrderedQuantity = 0 AND OutstandingQuantity = MinQuantity AND FulfillmentStatus = 'Incomplete';"

assert_value \
    'fictional overlapping-role demo user is Riley Bennett' \
    '1' \
    "SELECT COUNT(*) FROM Person p JOIN Player pl ON pl.PersonID=p.PersonID JOIN Coach c ON c.PersonID=p.PersonID WHERE p.FirstName='Riley' AND p.LastName='Bennett' AND p.Email='riley.bennett@example.test';"

assert_value \
    'each seeded team has exactly one head coach' \
    '0' \
    "SELECT COUNT(*) FROM (SELECT t.TeamID FROM Team t LEFT JOIN CoachesFor cf ON cf.TeamID=t.TeamID AND cf.CoachRole='Head Coach' GROUP BY t.TeamID HAVING COUNT(cf.PersonID) <> 1) failures;"

assert_value \
    'stored roster counts match memberships' \
    '0' \
    "SELECT COUNT(*) FROM (SELECT t.TeamID FROM Team t LEFT JOIN PlaysOn po ON po.TeamID=t.TeamID GROUP BY t.TeamID,t.CurrentRosterSize HAVING COUNT(po.PersonID) <> t.CurrentRosterSize) failures;"

assert_sql_fails \
    'ordered roster membership cannot be deleted with its history' \
    'fk_equipment_order_membership' \
    "DELETE FROM PlaysOn WHERE PersonID=1 AND TeamID=1;"

assert_value \
    'failed roster deletion preserves membership and order history' \
    $'1\t8' \
    "SELECT (SELECT COUNT(*) FROM PlaysOn WHERE PersonID=1 AND TeamID=1),(SELECT COUNT(*) FROM EquipmentOrder WHERE PersonID=1 AND TeamID=1);"

assert_app_sql_fails \
    'runtime principal cannot tamper with the roster counter' \
    'command denied' \
    "UPDATE Team SET CurrentRosterSize=0 WHERE TeamID=1;"

assert_sql_fails \
    'duplicate non-null uniform number is rejected within a team' \
    'uq_plays_on_team_uniform' \
    "INSERT INTO PlaysOn (PersonID,TeamID,SportID,JoinedAt,UniformNumber) VALUES (4,1,1,CURRENT_DATE,7);"

assert_sql_fails \
    'second head coach is rejected' \
    'uq_coaches_for_one_head' \
    "INSERT INTO CoachesFor (PersonID,TeamID,SportID,CoachRole) VALUES (30,1,1,'Head Coach');"

assert_sql_fails \
    'coach without sport eligibility is rejected' \
    'fk_coaches_for_eligibility' \
    "INSERT INTO CoachesFor (PersonID,TeamID,SportID,CoachRole) VALUES (29,1,1,'Assistant Coach');"

assert_sql_fails \
    'unregistered player cannot join a team' \
    'fk_plays_on_registration' \
    "INSERT INTO PlaysOn (PersonID,TeamID,SportID,JoinedAt,UniformNumber) VALUES (5,1,1,CURRENT_DATE,NULL);"

assert_sql_fails \
    'order for an item not required by the sport is rejected' \
    'fk_equipment_order_requirement' \
    "INSERT INTO EquipmentOrder (PersonID,TeamID,SportID,ItemID,SizeLabel,Quantity,OrderedAt) VALUES (1,1,1,6,'Standard',1,CURRENT_DATE);"

assert_sql_fails \
    'nonmember cannot place an otherwise valid required-item order' \
    'fk_equipment_order_membership' \
    "INSERT INTO EquipmentOrder (PersonID,TeamID,SportID,ItemID,SizeLabel,Quantity,OrderedAt) VALUES (1,2,1,1,'YM',1,CURRENT_DATE);"

assert_sql_fails \
    'capacity cannot be lowered below current occupancy' \
    'roster_capacity_below_occupancy' \
    "UPDATE Sport SET MaxRosterSize=1 WHERE SportID=1;"

printf '%s\n' \
    "INSERT INTO PlaysOn (PersonID,TeamID,SportID,JoinedAt,UniformNumber) VALUES (13,2,1,CURRENT_DATE,0),(14,2,1,CURRENT_DATE,99),(15,2,1,CURRENT_DATE,NULL),(22,2,1,CURRENT_DATE,NULL);" \
    | mysql_root

assert_value \
    'uniform range accepts 0 and 99 and permits multiple nulls' \
    $'1\t1\t2' \
    "SELECT SUM(UniformNumber=0),SUM(UniformNumber=99),SUM(UniformNumber IS NULL) FROM PlaysOn WHERE TeamID=2 AND PersonID IN (13,14,15,22);"

assert_sql_fails \
    'uniform number below zero is rejected' \
    'constraint' \
    "INSERT INTO PlaysOn (PersonID,TeamID,SportID,JoinedAt,UniformNumber) VALUES (1,2,1,CURRENT_DATE,-1);"

assert_sql_fails \
    'uniform number above 99 is rejected' \
    'constraint' \
    "INSERT INTO PlaysOn (PersonID,TeamID,SportID,JoinedAt,UniformNumber) VALUES (2,2,1,CURRENT_DATE,100);"

assert_value \
    'Riley starts with an unfulfilled two-unit socks requirement' \
    $'0\t2\tIncomplete' \
    "SELECT OrderedQuantity,OutstandingQuantity,FulfillmentStatus FROM EquipmentFulfillment WHERE PersonID=32 AND TeamID=1 AND ItemID=5;"

printf '%s\n' "INSERT INTO EquipmentOrder (PersonID,TeamID,SportID,ItemID,SizeLabel,Quantity,OrderedAt) VALUES (32,1,1,5,'M',1,'2026-05-01');" | mysql_root
assert_value \
    'one historical order leaves one unit outstanding' \
    $'1\t1\tIncomplete' \
    "SELECT OrderedQuantity,OutstandingQuantity,FulfillmentStatus FROM EquipmentFulfillment WHERE PersonID=32 AND TeamID=1 AND ItemID=5;"

printf '%s\n' "INSERT INTO EquipmentOrder (PersonID,TeamID,SportID,ItemID,SizeLabel,Quantity,OrderedAt) VALUES (32,1,1,5,'L',1,'2026-05-02');" | mysql_root
assert_value \
    'two order rows cumulatively complete the requirement' \
    $'2\t0\tComplete' \
    "SELECT OrderedQuantity,OutstandingQuantity,FulfillmentStatus FROM EquipmentFulfillment WHERE PersonID=32 AND TeamID=1 AND ItemID=5;"

printf '%s\n' "INSERT INTO EquipmentOrder (PersonID,TeamID,SportID,ItemID,SizeLabel,Quantity,OrderedAt) VALUES (32,1,1,5,'S',3,'2026-05-03');" | mysql_root
assert_value \
    'over-fulfillment preserves history and floors outstanding at zero' \
    $'5\t0\tComplete\t3' \
    "SELECT ef.OrderedQuantity,ef.OutstandingQuantity,ef.FulfillmentStatus,COUNT(eo.OrderID) FROM EquipmentFulfillment ef JOIN EquipmentOrder eo ON eo.PersonID=ef.PersonID AND eo.TeamID=ef.TeamID AND eo.SportID=ef.SportID AND eo.ItemID=ef.ItemID WHERE ef.PersonID=32 AND ef.TeamID=1 AND ef.ItemID=5 GROUP BY ef.OrderedQuantity,ef.OutstandingQuantity,ef.FulfillmentStatus;"

printf 'Club Operations System approved database contract passed.\n'
