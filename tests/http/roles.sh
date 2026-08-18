#!/usr/bin/env bash
set -euo pipefail

project_name="${SPORTLFC_COMPOSE_PROJECT_NAME:-sportlfc-http-roles}"
port="${SPORTLFC_TEST_PORT:-18083}"
compose=(docker compose -p "$project_name")
tmp_dir="$(mktemp -d)"

cleanup() {
    rm -rf "$tmp_dir"
    "${compose[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

SPORTLFC_WEB_PORT="$port" "${compose[@]}" up --build -d
base_url="http://127.0.0.1:${port}"
for _ in {1..60}; do
    curl --silent --show-error "$base_url/?page=login" >"$tmp_dir/ready" && break
    sleep 1
done

login() {
    local email="$1"
    local jar="$2"
    curl --silent --show-error -c "$jar" "$base_url/?page=login" >"$tmp_dir/login"
    local token
    token="$(sed -n 's/.*name="csrf_token" value="\([^"]*\)".*/\1/p' "$tmp_dir/login" | head -n 1)"
    curl --silent --show-error -L -b "$jar" -c "$jar" \
        --data-urlencode 'page=login' \
        --data-urlencode "csrf_token=$token" \
        --data-urlencode "email=$email" \
        --data-urlencode 'password=demo123' \
        "$base_url/" >"$tmp_dir/body"
}

csrf_for() {
    local jar="$1"
    local page="$2"
    curl --silent --show-error -b "$jar" "$base_url/?page=$page" >"$tmp_dir/body"
    sed -n 's/.*name="csrf_token" value="\([^"]*\)".*/\1/p' "$tmp_dir/body" | head -n 1
}

status_for() {
    local jar="$1"
    local page="$2"
    curl --silent --show-error -o "$tmp_dir/body" -w '%{http_code}' -b "$jar" "$base_url/?page=$page"
}

mysql_value() {
    local sql="$1"
    printf '%s\n' "$sql" | "${compose[@]}" exec -T db sh -lc \
        'mysql --batch --skip-column-names -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"'
}

player_jar="$tmp_dir/player.cookies"
login 'james.walker@example.test' "$player_jar"
[[ "$(status_for "$player_jar" player-teams)" == '200' ]]
[[ "$(status_for "$player_jar" coach-teams)" == '403' ]]
[[ "$(status_for "$player_jar" admin-reports)" == '403' ]]
printf 'PASS: player role flow and cross-role denials.\n'

token="$(csrf_for "$player_jar" player-join-sport)"
duplicate_before="$(mysql_value 'SELECT COUNT(*) FROM Registers WHERE PersonID=1 AND SportID=1;')"
curl --silent --show-error -L -b "$player_jar" -c "$player_jar" \
    --data-urlencode 'page=player-join-sport' \
    --data-urlencode "csrf_token=$token" \
    --data-urlencode 'sport_id=1' \
    "$base_url/" >"$tmp_dir/body"
duplicate_after="$(mysql_value 'SELECT COUNT(*) FROM Registers WHERE PersonID=1 AND SportID=1;')"
[[ "$duplicate_after" == "$duplicate_before" ]]
grep -Fq 'already registered for this sport' "$tmp_dir/body"
printf 'PASS: duplicate sport registration reports an unchanged state without a write.\n'

riley_jar="$tmp_dir/riley.cookies"
login 'riley.bennett@example.test' "$riley_jar"
[[ "$(status_for "$riley_jar" player-teams)" == '200' ]]
[[ "$(status_for "$riley_jar" coach-teams)" == '200' ]]

token="$(csrf_for "$riley_jar" player-order-equipment)"
before="$(mysql_value 'SELECT COUNT(*) FROM EquipmentOrder WHERE PersonID=32 AND TeamID=1 AND ItemID=5;')"
curl --silent --show-error -L -b "$riley_jar" -c "$riley_jar" \
    --data-urlencode 'page=player-order-equipment' \
    --data-urlencode "csrf_token=$token" \
    --data-urlencode 'team_id=1' \
    --data-urlencode 'sport_id=1' \
    --data-urlencode 'item_id=5' \
    --data-urlencode 'size_label=M' \
    --data-urlencode 'quantity=1' \
    "$base_url/" >"$tmp_dir/body"
after="$(mysql_value 'SELECT COUNT(*) FROM EquipmentOrder WHERE PersonID=32 AND TeamID=1 AND ItemID=5;')"
[[ "$after" == "$((before + 1))" ]]
grep -Fq 'Equipment order saved' "$tmp_dir/body"
printf 'PASS: player mutation appends one equipment history row.\n'

token="$(csrf_for "$riley_jar" player-order-equipment)"
before="$(mysql_value 'SELECT COUNT(*) FROM EquipmentOrder WHERE PersonID=32 AND TeamID=1 AND ItemID=6;')"
curl --silent --show-error -L -b "$riley_jar" -c "$riley_jar" \
    --data-urlencode 'page=player-order-equipment' \
    --data-urlencode "csrf_token=$token" \
    --data-urlencode 'team_id=1' \
    --data-urlencode 'sport_id=1' \
    --data-urlencode 'item_id=6' \
    --data-urlencode 'size_label=Standard' \
    --data-urlencode 'quantity=1' \
    "$base_url/" >"$tmp_dir/body"
after="$(mysql_value 'SELECT COUNT(*) FROM EquipmentOrder WHERE PersonID=32 AND TeamID=1 AND ItemID=6;')"
[[ "$before" == "$after" ]]
grep -Fq 'Order blocked' "$tmp_dir/body"
printf 'PASS: overlapping roles work and a tampered equipment mutation changes no data.\n'

token="$(csrf_for "$riley_jar" player-order-equipment)"
before="$(mysql_value 'SELECT COUNT(*) FROM EquipmentOrder WHERE PersonID=32 AND TeamID=2 AND ItemID=1;')"
curl --silent --show-error -L -b "$riley_jar" -c "$riley_jar" \
    --data-urlencode 'page=player-order-equipment' \
    --data-urlencode "csrf_token=$token" \
    --data-urlencode 'team_id=2' \
    --data-urlencode 'sport_id=1' \
    --data-urlencode 'item_id=1' \
    --data-urlencode 'size_label=S' \
    --data-urlencode 'quantity=1' \
    "$base_url/" >"$tmp_dir/body"
after="$(mysql_value 'SELECT COUNT(*) FROM EquipmentOrder WHERE PersonID=32 AND TeamID=2 AND ItemID=1;')"
[[ "$before" == "$after" ]]
grep -Fq 'Order blocked' "$tmp_dir/body"
printf 'PASS: nonmember equipment mutation changes no data.\n'

token="$(csrf_for "$riley_jar" player-teams)"
membership_before="$(mysql_value 'SELECT COUNT(*) FROM PlaysOn WHERE PersonID=32 AND TeamID=1;')"
orders_before="$(mysql_value 'SELECT COUNT(*) FROM EquipmentOrder WHERE PersonID=32 AND TeamID=1;')"
curl --silent --show-error -L -b "$riley_jar" -c "$riley_jar" \
    --data-urlencode 'page=player-leave-team' \
    --data-urlencode "csrf_token=$token" \
    --data-urlencode 'team_id=1' \
    "$base_url/" >"$tmp_dir/body"
[[ "$(mysql_value 'SELECT COUNT(*) FROM PlaysOn WHERE PersonID=32 AND TeamID=1;')" == "$membership_before" ]]
[[ "$(mysql_value 'SELECT COUNT(*) FROM EquipmentOrder WHERE PersonID=32 AND TeamID=1;')" == "$orders_before" ]]
grep -Fq 'membership retained because equipment order history exists' "$tmp_dir/body"
printf 'PASS: player leave flow preserves related equipment history.\n'

coach_jar="$tmp_dir/coach.cookies"
login 'mike.torres@example.test' "$coach_jar"
[[ "$(status_for "$coach_jar" coach-add-player)" == '200' ]]
[[ "$(status_for "$coach_jar" admin-reports)" == '403' ]]

curl --silent --show-error -b "$coach_jar" \
    "$base_url/?page=coach-add-player" >"$tmp_dir/body"
grep -Fq 'Player for Lions FC' "$tmp_dir/body"
grep -Fq 'Ava King' "$tmp_dir/body"
if grep -Fq 'Player PersonID' "$tmp_dir/body" || grep -Fq 'TeamID' "$tmp_dir/body"; then
    printf 'FAIL: coach add-player form exposes raw database identifiers.\n' >&2
    exit 1
fi
printf 'PASS: coach add-player form uses names and owned-team context.\n'

token="$(csrf_for "$coach_jar" coach-add-player)"
curl --silent --show-error -L -b "$coach_jar" -c "$coach_jar" \
    --data-urlencode 'page=coach-add-player' \
    --data-urlencode "csrf_token=$token" \
    --data-urlencode 'player_id=13' \
    --data-urlencode 'team_id=1' \
    "$base_url/" >"$tmp_dir/body"
[[ "$(mysql_value 'SELECT COUNT(*) FROM PlaysOn WHERE PersonID=13 AND TeamID=1;')" == '1' ]]
grep -Fq 'Player added' "$tmp_dir/body"
printf 'PASS: coach mutation adds a registered player to an owned team.\n'

token="$(csrf_for "$coach_jar" coach-add-player)"
curl --silent --show-error -L -b "$coach_jar" -c "$coach_jar" \
    --data-urlencode 'page=coach-add-player' \
    --data-urlencode "csrf_token=$token" \
    --data-urlencode 'player_id=5' \
    --data-urlencode 'team_id=1' \
    "$base_url/" >"$tmp_dir/body"
[[ "$(mysql_value 'SELECT COUNT(*) FROM PlaysOn WHERE PersonID=5 AND TeamID=1;')" == '0' ]]
grep -Fq 'must register for the team sport' "$tmp_dir/body"
printf 'PASS: coach mutation enforces sport registration.\n'

token="$(csrf_for "$coach_jar" coach-add-player)"
curl --silent --show-error -L -b "$coach_jar" -c "$coach_jar" \
    --data-urlencode 'page=coach-add-player' \
    --data-urlencode "csrf_token=$token" \
    --data-urlencode 'player_id=13' \
    --data-urlencode 'team_id=2' \
    "$base_url/" >"$tmp_dir/body"
[[ "$(mysql_value 'SELECT COUNT(*) FROM PlaysOn WHERE PersonID=13 AND TeamID=2;')" == '0' ]]
grep -Fq 'only add players to teams you coach' "$tmp_dir/body"
printf 'PASS: coach ownership authorization blocks negative mutation.\n'

mysql_value 'UPDATE Sport s JOIN Team t ON t.SportID=s.SportID SET s.MaxRosterSize=t.CurrentRosterSize WHERE t.TeamID=1;'
token="$(csrf_for "$coach_jar" coach-add-player)"
curl --silent --show-error -L -b "$coach_jar" -c "$coach_jar" \
    --data-urlencode 'page=coach-add-player' \
    --data-urlencode "csrf_token=$token" \
    --data-urlencode 'player_id=14' \
    --data-urlencode 'team_id=1' \
    "$base_url/" >"$tmp_dir/body"
[[ "$(mysql_value 'SELECT COUNT(*) FROM PlaysOn WHERE PersonID=14 AND TeamID=1;')" == '0' ]]
grep -Fq 'Roster cap reached for this team' "$tmp_dir/body"
printf 'PASS: full roster returns the application UX message without a write.\n'

mysql_value 'UPDATE Sport s JOIN Team t ON t.SportID=s.SportID SET s.MaxRosterSize=t.CurrentRosterSize + 1 WHERE t.TeamID=1;'
mysql_value "CREATE TRIGGER test_roster_capacity_conflict BEFORE INSERT ON PlaysOn FOR EACH ROW PRECEDES plays_on_before_insert_capacity SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='roster_capacity_exceeded';"
before_conflict="$(mysql_value 'SELECT COUNT(*) FROM PlaysOn WHERE PersonID=14 AND TeamID=1;')"
token="$(csrf_for "$coach_jar" coach-add-player)"
conflict_status="$(curl --silent --show-error -L -o "$tmp_dir/body" -w '%{http_code}' -b "$coach_jar" -c "$coach_jar" \
    --data-urlencode 'page=coach-add-player' \
    --data-urlencode "csrf_token=$token" \
    --data-urlencode 'player_id=14' \
    --data-urlencode 'team_id=1' \
    "$base_url/")"
[[ "$conflict_status" == '200' ]]
[[ "$(mysql_value 'SELECT COUNT(*) FROM PlaysOn WHERE PersonID=14 AND TeamID=1;')" == "$before_conflict" ]]
grep -Fq 'Roster cap reached for this team' "$tmp_dir/body"
mysql_value 'DROP TRIGGER test_roster_capacity_conflict;'
printf 'PASS: named roster-capacity trigger conflict returns the friendly message without a write.\n'

mysql_value "CREATE TRIGGER test_unrelated_database_failure BEFORE INSERT ON PlaysOn FOR EACH ROW PRECEDES plays_on_before_insert_capacity SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='unrelated_test_failure';"
before_unrelated="$(mysql_value 'SELECT COUNT(*) FROM PlaysOn WHERE PersonID=14 AND TeamID=1;')"
token="$(csrf_for "$coach_jar" coach-add-player)"
unrelated_status="$(curl --silent --show-error -L -o "$tmp_dir/body" -w '%{http_code}' -b "$coach_jar" -c "$coach_jar" \
    --data-urlencode 'page=coach-add-player' \
    --data-urlencode "csrf_token=$token" \
    --data-urlencode 'player_id=14' \
    --data-urlencode 'team_id=1' \
    "$base_url/")"
[[ "$unrelated_status" == '500' ]]
[[ "$(mysql_value 'SELECT COUNT(*) FROM PlaysOn WHERE PersonID=14 AND TeamID=1;')" == "$before_unrelated" ]]
grep -Fq 'Reference:' "$tmp_dir/body"
if grep -Fq 'Roster cap reached for this team' "$tmp_dir/body"; then
    printf 'FAIL: unrelated trigger failure was translated as a roster-capacity conflict.\n' >&2
    exit 1
fi
mysql_value 'DROP TRIGGER test_unrelated_database_failure;'
printf 'PASS: unrelated trigger failure retains the generic error response.\n'

admin_jar="$tmp_dir/admin.cookies"
login 'priya.nair@example.test' "$admin_jar"
[[ "$(status_for "$admin_jar" admin-reports)" == '200' ]]
[[ "$(status_for "$admin_jar" player-teams)" == '403' ]]

curl --silent --show-error -b "$admin_jar" \
    "$base_url/?page=admin-assign-coach" >"$tmp_dir/body"
grep -Fq 'Coach for Lions FC' "$tmp_dir/body"
grep -Fq 'Mike Torres' "$tmp_dir/body"
if grep -Fq 'Coach PersonID' "$tmp_dir/body" || grep -Fq 'TeamID' "$tmp_dir/body"; then
    printf 'FAIL: admin coach-assignment form exposes raw database identifiers.\n' >&2
    exit 1
fi
printf 'PASS: admin coach-assignment form uses names and team context.\n'

token="$(csrf_for "$admin_jar" admin-assign-coach)"
curl --silent --show-error -L -b "$admin_jar" -c "$admin_jar" \
    --data-urlencode 'page=admin-assign-coach' \
    --data-urlencode "csrf_token=$token" \
    --data-urlencode 'coach_id=30' \
    --data-urlencode 'team_id=1' \
    --data-urlencode 'coach_role=Assistant Coach' \
    "$base_url/" >"$tmp_dir/body"
[[ "$(mysql_value "SELECT COUNT(*) FROM CoachesFor WHERE PersonID=30 AND TeamID=1 AND CoachRole='Assistant Coach';")" == '1' ]]
grep -Fq 'Coach assignment saved' "$tmp_dir/body"
printf 'PASS: admin mutation saves an eligible assistant assignment.\n'

token="$(csrf_for "$admin_jar" admin-assign-coach)"
curl --silent --show-error -L -b "$admin_jar" -c "$admin_jar" \
    --data-urlencode 'page=admin-assign-coach' \
    --data-urlencode "csrf_token=$token" \
    --data-urlencode 'coach_id=29' \
    --data-urlencode 'team_id=1' \
    --data-urlencode 'coach_role=Assistant Coach' \
    "$base_url/" >"$tmp_dir/body"
[[ "$(mysql_value 'SELECT COUNT(*) FROM CoachesFor WHERE PersonID=29 AND TeamID=1;')" == '0' ]]
grep -Fq 'not eligible for this sport' "$tmp_dir/body"
printf 'PASS: admin mutation enforces coach eligibility.\n'

token="$(csrf_for "$admin_jar" admin-assign-coach)"
curl --silent --show-error -L -b "$admin_jar" -c "$admin_jar" \
    --data-urlencode 'page=admin-assign-coach' \
    --data-urlencode "csrf_token=$token" \
    --data-urlencode 'coach_id=30' \
    --data-urlencode 'team_id=1' \
    --data-urlencode 'coach_role=Head Coach' \
    "$base_url/" >"$tmp_dir/body"
head_count="$(mysql_value "SELECT COUNT(*) FROM CoachesFor WHERE TeamID=1 AND CoachRole='Head Coach';")"
[[ "$head_count" == '1' ]]
[[ "$(mysql_value 'SELECT CoachRole FROM CoachesFor WHERE PersonID=30 AND TeamID=1;')" == 'Assistant Coach' ]]
grep -Fq 'already has a head coach' "$tmp_dir/body"
printf 'PASS: admin flow respects the database head-coach invariant.\n'

printf 'Club Operations System HTTP role and negative mutation contract passed.\n'
