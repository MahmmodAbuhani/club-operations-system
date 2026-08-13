#!/usr/bin/env bash
set -euo pipefail

project_name="${SPORTLFC_COMPOSE_PROJECT_NAME:-sportlfc-http-security}"
port="${SPORTLFC_TEST_PORT:-18082}"
compose=(docker compose -p "$project_name")
cookie_jar="$(mktemp)"
body="$(mktemp)"
headers="$(mktemp)"
stale_jar="$(mktemp)"

cleanup() {
    rm -f "$cookie_jar" "$body" "$headers" "$stale_jar"
    "${compose[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

SPORTLFC_WEB_PORT="$port" "${compose[@]}" up --build -d
base_url="http://127.0.0.1:${port}"

for _ in {1..60}; do
    if curl --silent --show-error -D "$headers" -o "$body" "$base_url/?page=login" 2>/dev/null; then
        break
    fi
    sleep 1
done

grep -Ei '^Set-Cookie: .*HttpOnly' "$headers" >/dev/null
grep -Ei '^Set-Cookie: .*SameSite=Lax' "$headers" >/dev/null

mysql_value() {
    local sql="$1"
    printf '%s\n' "$sql" | "${compose[@]}" exec -T db sh -lc \
        'mysql --batch --skip-column-names -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"'
}

curl --silent --show-error -c "$cookie_jar" "$base_url/?page=login" >"$body"
session_before="$(awk '$6 == "sportlfc_session" { print $7 }' "$cookie_jar" | tail -n 1)"
csrf_token="$(sed -n 's/.*name="csrf_token" value="\([^"]*\)".*/\1/p' "$body" | head -n 1)"
curl --silent --show-error -L -b "$cookie_jar" -c "$cookie_jar" \
    --data-urlencode 'page=login' \
    --data-urlencode "csrf_token=$csrf_token" \
    --data-urlencode 'email=riley.bennett@example.test' \
    --data-urlencode 'password=demo123' \
    "$base_url/" >"$body"
session_after="$(awk '$6 == "sportlfc_session" { print $7 }' "$cookie_jar" | tail -n 1)"
[[ -n "$session_before" && -n "$session_after" && "$session_before" != "$session_after" ]]

status="$(curl --silent --show-error -o "$body" -w '%{http_code}' -b "$cookie_jar" "$base_url/?page=logout")"
[[ "$status" == '405' ]]

status="$(curl --silent --show-error -o "$body" -w '%{http_code}' -b "$cookie_jar" "$base_url/?page=not-a-route")"
[[ "$status" == '404' ]]

status="$(curl --silent --show-error -o "$body" -w '%{http_code}' -b "$cookie_jar" "$base_url/?page=admin-reports")"
[[ "$status" == '403' ]]

membership_before="$(mysql_value 'SELECT COUNT(*) FROM PlaysOn WHERE PersonID=32 AND TeamID=1;')"
status="$(curl --silent --show-error -o "$body" -w '%{http_code}' -b "$cookie_jar" \
    --data-urlencode 'page=player-leave-team' \
    --data-urlencode 'csrf_token=invalid' \
    --data-urlencode 'team_id=1' \
    "$base_url/")"
[[ "$status" == '403' ]]
[[ "$(mysql_value 'SELECT COUNT(*) FROM PlaysOn WHERE PersonID=32 AND TeamID=1;')" == "$membership_before" ]]

curl --silent --show-error -b "$cookie_jar" "$base_url/?page=home" >"$body"
csrf_token="$(sed -n 's/.*name="csrf_token" value="\([^"]*\)".*/\1/p' "$body" | head -n 1)"
teams_before="$(mysql_value 'SELECT COUNT(*) FROM Team;')"
status="$(curl --silent --show-error -o "$body" -w '%{http_code}' -b "$cookie_jar" \
    --data-urlencode 'page=admin-create-team' \
    --data-urlencode "csrf_token=$csrf_token" \
    --data-urlencode 'team_name=Forbidden Team' \
    --data-urlencode 'sport_id=1' \
    --data-urlencode 'age_group=Test' \
    --data-urlencode 'season=Test' \
    "$base_url/")"
[[ "$status" == '403' ]]
[[ "$(mysql_value 'SELECT COUNT(*) FROM Team;')" == "$teams_before" ]]

mysql_value 'RENAME TABLE Sport TO SportUnavailable;'
status="$(curl --silent --show-error -o "$body" -w '%{http_code}' -b "$cookie_jar" "$base_url/?page=player-search")"
mysql_value 'RENAME TABLE SportUnavailable TO Sport;'
[[ "$status" == '500' ]]
grep -Eq 'Reference: [0-9a-f]{16}' "$body"
if grep -Eq 'SQLSTATE|PDOException|repository\.php|/var/www' "$body"; then
    printf 'FAIL: generic error response leaked implementation details.\n' >&2
    exit 1
fi

curl --silent --show-error -b "$cookie_jar" "$base_url/?page=home" >"$body"
csrf_token="$(sed -n 's/.*name="csrf_token" value="\([^"]*\)".*/\1/p' "$body" | head -n 1)"
cp "$cookie_jar" "$stale_jar"
status="$(curl --silent --show-error -o "$body" -w '%{http_code}' -b "$cookie_jar" -c "$cookie_jar" \
    --data-urlencode 'page=logout' \
    --data-urlencode "csrf_token=$csrf_token" \
    "$base_url/")"
[[ "$status" == '303' ]]

status="$(curl --silent --show-error -o "$body" -w '%{http_code}' -b "$cookie_jar" "$base_url/?page=player-teams")"
[[ "$status" == '303' ]]

status="$(curl --silent --show-error -o "$body" -w '%{http_code}' -b "$stale_jar" "$base_url/?page=player-teams")"
[[ "$status" == '303' ]]

printf 'PASS: session regeneration, cookie flags, methods, authorization, state-safe CSRF, generic errors, routes, and logout are hardened.\n'
