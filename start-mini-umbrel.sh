#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

orig_docker_config="${DOCKER_CONFIG:-$HOME/.docker}"
orig_config_file="$orig_docker_config/config.json"

# Colima-only setups often inherit Docker Desktop credsStore entries from older installs.
# If docker-credential-desktop is missing, run with a sanitized temporary Docker config.
if [ -f "$orig_config_file" ] \
  && grep -q '"credsStore"[[:space:]]*:[[:space:]]*"desktop"' "$orig_config_file" \
  && ! command -v docker-credential-desktop >/dev/null 2>&1; then
  echo "Detected credsStore=desktop without docker-credential-desktop; using temporary Docker config for this run."

  tmp_docker_config="$(mktemp -d)"
  trap 'rm -rf "$tmp_docker_config"' EXIT

  # Keep contexts/certs from the original Docker config so non-default contexts
  # like "colima" continue to resolve.
  cp -a "$orig_docker_config/." "$tmp_docker_config/"

  jq '
    del(.credsStore)
    | if has("credHelpers") then
        .credHelpers |= with_entries(select(.value != "desktop"))
        | if (.credHelpers | length) == 0 then del(.credHelpers) else . end
      else . end
  ' "$orig_config_file" > "$tmp_docker_config/config.json.tmp"
  mv "$tmp_docker_config/config.json.tmp" "$tmp_docker_config/config.json"

  export DOCKER_CONFIG="$tmp_docker_config"
fi

docker compose up -d
