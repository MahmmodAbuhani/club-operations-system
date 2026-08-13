#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec node "$root_dir/scripts/scan_public_surface.mjs" "$root_dir"
