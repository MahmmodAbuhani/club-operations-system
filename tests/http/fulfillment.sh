#!/usr/bin/env bash
set -euo pipefail

project_name="${SPORTLFC_COMPOSE_PROJECT_NAME:-sportlfc-http-fulfillment}"
port="${SPORTLFC_TEST_PORT:-18081}"
compose=(docker compose -p "$project_name")
cookie_jar="$(mktemp)"
response_file="$(mktemp)"

cleanup() {
    rm -f "$cookie_jar" "$response_file"
    "${compose[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

SPORTLFC_WEB_PORT="$port" "${compose[@]}" up --build -d

base_url="http://127.0.0.1:${port}"
for _ in {1..60}; do
    if curl --fail --silent --show-error "$base_url/?page=login" >"$response_file"; then
        break
    fi
    sleep 1
done

curl --fail --silent --show-error -c "$cookie_jar" "$base_url/?page=login" >"$response_file"
csrf_token="$(sed -n 's/.*name="csrf_token" value="\([^"]*\)".*/\1/p' "$response_file" | head -n 1)"
[[ -n "$csrf_token" ]]

curl --fail --silent --show-error -L -b "$cookie_jar" -c "$cookie_jar" \
    --data-urlencode 'page=login' \
    --data-urlencode "csrf_token=$csrf_token" \
    --data-urlencode 'email=riley.bennett@example.test' \
    --data-urlencode 'password=demo123' \
    "$base_url/" >"$response_file"

grep -Fq 'Riley Bennett' "$response_file"

curl --fail --silent --show-error -b "$cookie_jar" \
    "$base_url/?page=player-order-equipment" >"$response_file"

grep -Fq 'Equipment Fulfillment' "$response_file"
grep -Fq 'Socks' "$response_file"
grep -Fq 'Outstanding quantity' "$response_file"
grep -Fq '>2<' "$response_file"

printf 'PASS: Riley sees cumulative equipment fulfillment and outstanding quantity.\n'
