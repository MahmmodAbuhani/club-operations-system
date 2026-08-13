#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

command -v docker >/dev/null
command -v node >/dev/null
command -v npm >/dev/null

printf '[1/8] Static configuration and PHP syntax\n'
docker compose config --quiet
if [[ -n "${SPORTLFC_PHP_BIN:-}" ]]; then
    command -v "$SPORTLFC_PHP_BIN" >/dev/null
    find web -name '*.php' -print0 | xargs -0 -n1 "$SPORTLFC_PHP_BIN" -l
else
    php_image="$(sed -nE 's/^FROM[[:space:]]+(php:[^[:space:]]+).*/\1/p' web/Dockerfile)"
    if [[ -z "$php_image" ]]; then
        printf 'FAIL: pinned PHP image not found in web/Dockerfile.\n' >&2
        exit 1
    fi
    docker run --rm \
        --mount "type=bind,source=$root_dir/web,target=/src,readonly" \
        "$php_image" \
        sh -c "find /src -name '*.php' -print0 | xargs -0 -n1 php -l"
fi
find scripts tests -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
tests/release/public_surface.sh

printf '[2/8] Locked development dependencies\n'
npm ci --silent --prefer-offline
browser_path="$(node -e "process.stdout.write(require('playwright').chromium.executablePath())")"
if [[ ! -x "$browser_path" ]]; then
    npx playwright install chromium
fi
if [[ "${CI:-}" == "true" ]]; then
    npm audit --audit-level=high
else
    npm audit --audit-level=high --offline
fi
npm run test:release

printf '[3/8] Static evidence walkthrough\n'
npm run test:walkthrough

printf '[4/8] Direct SQL invariant tests\n'
tests/sql/invariants.sh

printf '[5/8] Two-session concurrency tests\n'
tests/sql/concurrency.sh

printf '[6/8] Equipment HTTP flow\n'
tests/http/fulfillment.sh

printf '[7/8] Security and role HTTP flows\n'
tests/http/security.sh
tests/http/roles.sh

printf '[8/8] Accessibility and narrow-viewport verification\n'
tests/http/accessibility.sh

printf 'Club Operations System complete verification passed.\n'
