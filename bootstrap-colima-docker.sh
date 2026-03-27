#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROFILE="${COLIMA_PROFILE:-default}"
CPU="${COLIMA_CPU:-8}"
MEMORY_GIB="${COLIMA_MEMORY_GIB:-96}"
DISK_GIB_INPUT="${COLIMA_DISK_GIB:-auto}"
DISK_GIB=""
DISK_RESERVE_GIB="${COLIMA_DISK_RESERVE_GIB:-30}"
DISK_SOURCE_PATH="${COLIMA_DISK_SOURCE_PATH:-$HOME}"
ARCH="${COLIMA_ARCH:-x86_64}"
RUNTIME="${COLIMA_RUNTIME:-docker}"
VM_TYPE="${COLIMA_VM_TYPE:-qemu}"
MOUNT_TYPE="${COLIMA_MOUNT_TYPE:-sshfs}"
START_STACK="${START_STACK:-1}"

COLIMA_PROFILE_DIR="$HOME/.colima/${PROFILE}"
COLIMA_PROFILE_CONFIG="${COLIMA_PROFILE_DIR}/colima.yaml"
LIMA_HOME_DIR="$HOME/.colima/_lima"
if [ "$PROFILE" = "default" ]; then
  INSTANCE_NAME="colima"
else
  INSTANCE_NAME="colima-${PROFILE}"
fi
LIMA_INSTANCE_DIR="${LIMA_HOME_DIR}/${INSTANCE_NAME}"

log() {
  printf '[bootstrap] %s\n' "$*"
}

warn() {
  printf '[bootstrap] WARN: %s\n' "$*" >&2
}

die() {
  printf '[bootstrap] ERROR: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Command '$1' not found."
}

run_colima() {
  (cd / && colima "$@")
}

is_non_negative_int() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

is_positive_int() {
  is_non_negative_int "$1" && [ "$1" -gt 0 ]
}

host_fs_value_kib() {
  local path="$1"
  local column="$2"
  df -Pk "$path" 2>/dev/null | awk -v col="$column" 'NR==2 {print $col; exit}'
}

resolve_disk_target_gib() {
  local mode total_kib avail_kib total_gib avail_gib computed
  mode="$DISK_GIB_INPUT"

  if ! is_non_negative_int "$DISK_RESERVE_GIB"; then
    die "COLIMA_DISK_RESERVE_GIB must be a non-negative integer. Got '$DISK_RESERVE_GIB'."
  fi

  case "$mode" in
    auto|free)
      [ -d "$DISK_SOURCE_PATH" ] || die "COLIMA_DISK_SOURCE_PATH does not exist: $DISK_SOURCE_PATH"

      total_kib="$(host_fs_value_kib "$DISK_SOURCE_PATH" 2 || true)"
      avail_kib="$(host_fs_value_kib "$DISK_SOURCE_PATH" 4 || true)"
      [ -n "$total_kib" ] || die "Unable to read filesystem total size for '$DISK_SOURCE_PATH'."
      [ -n "$avail_kib" ] || die "Unable to read filesystem free space for '$DISK_SOURCE_PATH'."

      total_gib="$((total_kib / 1024 / 1024))"
      avail_gib="$((avail_kib / 1024 / 1024))"

      if [ "$mode" = "auto" ]; then
        computed="$((total_gib - DISK_RESERVE_GIB))"
      else
        computed="$((avail_gib - DISK_RESERVE_GIB))"
      fi

      if [ "$computed" -lt 20 ]; then
        die "Resolved Colima disk size (${computed}GiB) is too small. Adjust COLIMA_DISK_RESERVE_GIB or COLIMA_DISK_GIB."
      fi

      DISK_GIB="$computed"
      log "Resolved COLIMA_DISK_GIB=${mode} from '$DISK_SOURCE_PATH': total=${total_gib}GiB free=${avail_gib}GiB reserve=${DISK_RESERVE_GIB}GiB => disk=${DISK_GIB}GiB."
      ;;
    *)
      if ! is_positive_int "$mode"; then
        die "COLIMA_DISK_GIB must be a positive integer, 'auto', or 'free'. Got '$mode'."
      fi

      DISK_GIB="$mode"
      log "Using explicit Colima disk size: ${DISK_GIB}GiB."
      ;;
  esac
}

brew_install_if_missing() {
  local pkg="$1"
  if ! brew list --versions "$pkg" >/dev/null 2>&1; then
    log "Installing $pkg via Homebrew..."
    brew install "$pkg"
  else
    log "$pkg already installed."
  fi
}

write_colima_profile_config() {
  mkdir -p "$COLIMA_PROFILE_DIR"
  cat > "$COLIMA_PROFILE_CONFIG" <<EOF
cpu: $CPU
disk: $DISK_GIB
memory: $MEMORY_GIB
arch: $ARCH
runtime: $RUNTIME
autoActivate: true
vmType: $VM_TYPE
mountType: $MOUNT_TYPE
rosetta: false
EOF
  log "Wrote profile config: $COLIMA_PROFILE_CONFIG"
}

instance_exists() {
  [ -d "$LIMA_INSTANCE_DIR" ]
}

current_vm_type() {
  local file="${LIMA_INSTANCE_DIR}/lima.yaml"
  [ -f "$file" ] || return 0
  awk -F': ' '/^vmType:/{print $2; exit}' "$file"
}

current_arch() {
  local file="${LIMA_INSTANCE_DIR}/lima.yaml"
  [ -f "$file" ] || return 0
  awk -F': ' '/^arch:/{print $2; exit}' "$file"
}

stop_colima_if_running() {
  if run_colima status -p "$PROFILE" >/dev/null 2>&1; then
    log "Stopping running Colima profile '$PROFILE'..."
    run_colima stop -p "$PROFILE"
  fi
}

current_disk_size_gib() {
  local disk_name raw value unit
  disk_name="$(current_disk_name || true)"
  [ -n "$disk_name" ] || return 0

  raw="$(LIMA_HOME="$LIMA_HOME_DIR" limactl disk list 2>/dev/null \
    | awk -v name="$disk_name" '$1==name {print $2; exit}')"
  [ -n "$raw" ] || return 0

  value="${raw%%[A-Za-z]*}"
  unit="${raw#$value}"

  case "$unit" in
    TiB)
      awk -v v="$value" 'BEGIN { print int((v * 1024) + 0.999) }'
      ;;
    GiB)
      awk -v v="$value" 'BEGIN { print int(v + 0.999) }'
      ;;
    MiB)
      awk -v v="$value" 'BEGIN { print int((v / 1024) + 0.999) }'
      ;;
    *)
      warn "Unrecognized disk size unit '$unit' from limactl value '$raw'."
      awk -v v="$value" 'BEGIN { print int(v + 0.999) }'
      ;;
  esac
}

current_disk_name() {
  LIMA_HOME="$LIMA_HOME_DIR" limactl disk list 2>/dev/null \
    | awk -v prof="$INSTANCE_NAME" 'NR>1 && $5==prof {print $1; exit}'
}

ensure_colima_shape() {
  if instance_exists; then
    local vm arch
    vm="$(current_vm_type || true)"
    arch="$(current_arch || true)"
    if [ "$vm" != "$VM_TYPE" ] || [ "$arch" != "$ARCH" ]; then
      warn "Existing profile '$PROFILE' has vmType='${vm:-unknown}', arch='${arch:-unknown}'."
      warn "Recreating instance to enforce vmType='$VM_TYPE' and arch='$ARCH' (data disk is preserved)."
      stop_colima_if_running
      run_colima delete -f -p "$PROFILE"
    fi
  fi
}

resize_disk_if_needed() {
  local current
  current="$(current_disk_size_gib || true)"

  if [ -z "$current" ]; then
    log "No existing Colima disk found yet (fresh setup expected)."
    return
  fi

  if [ "$current" -lt "$DISK_GIB" ]; then
    local disk_name
    disk_name="$(current_disk_name || true)"
    [ -n "$disk_name" ] || die "Could not resolve Colima disk name for profile '$PROFILE'."

    stop_colima_if_running
    log "Resizing Colima disk '$disk_name' from ${current}GiB to ${DISK_GIB}GiB..."
    LIMA_HOME="$LIMA_HOME_DIR" limactl disk resize "$disk_name" --size "${DISK_GIB}GiB"
  else
    log "Colima disk already >= ${DISK_GIB}GiB (${current}GiB)."
  fi
}

start_colima() {
  log "Starting Colima profile '$PROFILE'..."
  run_colima start -p "$PROFILE" \
    --runtime "$RUNTIME" \
    --cpu "$CPU" \
    --memory "$MEMORY_GIB" \
    --disk "$DISK_GIB" \
    --arch "$ARCH" \
    --vm-type "$VM_TYPE" \
    --mount-type "$MOUNT_TYPE"
}

apply_compose_stability_tunings() {
  local compose_file="${PROJECT_DIR}/docker-compose.yml"
  [ -f "$compose_file" ] || die "Missing ${compose_file}"

  sed -i '' -E \
    's|^([[:space:]]*BITCOIND_EXTRA_ARGS:[[:space:]]*).*$|\1"-deprecatedrpc=create_bdb,-dbcache=96,-maxmempool=64,-maxconnections=40,-par=1"|' \
    "$compose_file"

  sed -i '' -E \
    's|^([[:space:]]*NODE_OPTIONS:[[:space:]]*).*$|\1"--max-old-space-size=512"|' \
    "$compose_file"

  if ! grep -q 'BITCOIND_EXTRA_ARGS: "-deprecatedrpc=create_bdb,-dbcache=96,-maxmempool=64,-maxconnections=40,-par=1"' "$compose_file"; then
    warn "BITCOIND_EXTRA_ARGS tuning was not found in docker-compose.yml after patch attempt."
  fi

  if ! grep -q 'NODE_OPTIONS: "--max-old-space-size=512"' "$compose_file"; then
    warn "NODE_OPTIONS tuning was not found in docker-compose.yml after patch attempt."
  fi

  log "Applied Docker compose stability tunings in docker-compose.yml."
}

ensure_docker_context() {
  if docker context ls --format '{{.Name}}' | grep -qx 'colima'; then
    docker context use colima >/dev/null
  fi
}

verify_runtime() {
  log "Runtime verification:"
  docker info --format 'Name={{.Name}} CPUs={{.NCPU}} MemBytes={{.MemTotal}}'

  if ! run_colima ssh -p "$PROFILE" -- sh -lc 'df -h /var/lib/docker'; then
    warn "Could not read /var/lib/docker usage via colima ssh (likely missing host-path mount in VM)."
  fi
}

start_stack() {
  if [ "$START_STACK" = "1" ]; then
    log "Starting project services..."
    "$PROJECT_DIR/start-mini-umbrel.sh"
    (cd "$PROJECT_DIR" && docker compose ps)
  else
    log "Skipping stack startup because START_STACK=$START_STACK."
  fi
}

main() {
  cd "$PROJECT_DIR"

  need_cmd brew
  brew_install_if_missing docker
  brew_install_if_missing colima
  brew_install_if_missing qemu
  brew_install_if_missing jq

  need_cmd docker
  need_cmd colima
  need_cmd limactl
  need_cmd jq

  if ! docker compose version >/dev/null 2>&1; then
    brew_install_if_missing docker-compose
  fi

  resolve_disk_target_gib
  write_colima_profile_config
  ensure_colima_shape
  resize_disk_if_needed
  start_colima
  apply_compose_stability_tunings
  ensure_docker_context
  verify_runtime
  start_stack

  log "Done. Colima/Docker crash-prevention settings are applied."
}

main "$@"
