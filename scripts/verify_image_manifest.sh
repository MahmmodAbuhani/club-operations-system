#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

command -v docker >/dev/null
command -v node >/dev/null

image_ref="$(sed -nE 's/^[[:space:]]+image:[[:space:]]+(mysql:[^[:space:]]+)$/\1/p' docker-compose.yml)"
if [[ -z "$image_ref" ]]; then
    printf 'FAIL: pinned MySQL image reference not found in docker-compose.yml.\n' >&2
    exit 1
fi

manifest_file="$(mktemp)"
cleanup() {
    rm -f "$manifest_file"
}
trap cleanup EXIT

docker buildx imagetools inspect --raw "$image_ref" >"$manifest_file"
node - "$manifest_file" "$image_ref" <<'NODE'
const fs = require('fs');
const [manifestPath, imageRef] = process.argv.slice(2);
const index = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const mediaTypes = new Set([
  'application/vnd.oci.image.index.v1+json',
  'application/vnd.docker.distribution.manifest.list.v2+json'
]);
if (!mediaTypes.has(index.mediaType)) {
  throw new Error(`expected a multi-architecture index, received ${index.mediaType}`);
}
const platforms = new Set(
  (index.manifests || [])
    .filter((entry) => entry.platform?.os === 'linux')
    .map((entry) => `${entry.platform.os}/${entry.platform.architecture}${entry.platform.variant ? `/${entry.platform.variant}` : ''}`)
);
for (const expected of ['linux/amd64', 'linux/arm64/v8']) {
  if (!platforms.has(expected)) throw new Error(`missing ${expected} manifest`);
}
console.log(`PASS: ${imageRef} is a multi-architecture index for linux/amd64 and linux/arm64/v8.`);
NODE
