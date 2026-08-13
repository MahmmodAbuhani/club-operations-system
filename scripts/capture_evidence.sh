#!/usr/bin/env bash
set -euo pipefail

project_name="${SPORTLFC_COMPOSE_PROJECT_NAME:-sportlfc-evidence}"
port="${SPORTLFC_TEST_PORT:-18085}"
compose=(docker compose -p "$project_name")

cleanup() {
    "${compose[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

SPORTLFC_WEB_PORT="$port" "${compose[@]}" up --build -d
for _ in {1..60}; do
    curl --silent --show-error "http://127.0.0.1:${port}/?page=login" >/dev/null && break
    sleep 1
done

SPORTLFC_BASE_URL="http://127.0.0.1:${port}" npm run evidence
npm run social-preview
