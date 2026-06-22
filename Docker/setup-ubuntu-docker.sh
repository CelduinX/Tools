#!/usr/bin/env bash
set -Eeuo pipefail

# Set this to skip the interactive prompt, for example:
# DOCKER_BASE_DIR="/opt/docker"
DOCKER_BASE_DIR="${DOCKER_BASE_DIR:-}"

# Set DRY_RUN=1 to print actions without changing the system.
DRY_RUN="${DRY_RUN:-0}"

# Internal test hook. Leave unchanged for real installations.
OS_RELEASE_FILE="${OS_RELEASE_FILE:-/etc/os-release}"

SCRIPT_NAME="Ubuntu Docker Bootstrap"
STEP=0

log() {
  printf '  %s\n' "$*"
}

info() {
  printf '  -> %s\n' "$*"
}

ok() {
  printf '  OK %s\n' "$*"
}

section() {
  STEP=$((STEP + 1))
  printf '\n[%02d] %s\n' "$STEP" "$*"
  printf '%s\n' '------------------------------------------------------------'
}

banner() {
  printf '\n'
  printf '%s\n' '============================================================'
  printf ' %s\n' "$SCRIPT_NAME"
  printf '%s\n' '============================================================'
  if [[ "$DRY_RUN" == "1" ]]; then
    printf ' Mode: DRY RUN - no system changes will be made\n'
  else
    printf ' Mode: LIVE - system changes will be applied\n'
  fi
  printf '\n'
}

die() {
  printf '\nERROR: %s\n' "$*" >&2
  exit 1
}

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '  DRY '
    printf '%q ' "$@"
    printf '\n'
  else
    printf '  RUN '
    printf '%q ' "$@"
    printf '\n'
    "$@"
  fi
}

run_shell() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '  DRY bash -c %q\n' "$1"
  else
    printf '  RUN bash -c %q\n' "$1"
    bash -c "$1"
  fi
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "Please run this script as root."
}

require_ubuntu() {
  [[ -r "$OS_RELEASE_FILE" ]] || die "$OS_RELEASE_FILE not found."
  # shellcheck disable=SC1091
  . "$OS_RELEASE_FILE"
  [[ "${ID:-}" == "ubuntu" ]] || die "This script is intended for Ubuntu Server. Detected ID=${ID:-unknown}."
  [[ -n "${VERSION_CODENAME:-}" ]] || die "Ubuntu VERSION_CODENAME not found in /etc/os-release."
  UBUNTU_CODENAME="$VERSION_CODENAME"
}

choose_base_dir() {
  if [[ -z "$DOCKER_BASE_DIR" ]]; then
    read -r -p "Docker target directory [/opt/docker]: " DOCKER_BASE_DIR
    DOCKER_BASE_DIR="${DOCKER_BASE_DIR:-/opt/docker}"
  fi

  [[ "$DOCKER_BASE_DIR" = /* ]] || die "DOCKER_BASE_DIR must be an absolute path."
  [[ "$DOCKER_BASE_DIR" != "/" ]] || die "DOCKER_BASE_DIR must not be /."
  [[ "$DOCKER_BASE_DIR" != "/var/lib/docker" ]] || die "Choose a parent directory, not /var/lib/docker."
  [[ "$DOCKER_BASE_DIR" != "/var/lib/containerd" ]] || die "Choose a parent directory, not /var/lib/containerd."

  DOCKER_DATA_ROOT="${DOCKER_BASE_DIR%/}/data"
  CONTAINERD_ROOT="${DOCKER_BASE_DIR%/}/containerd"
  STACKS_DIR="${DOCKER_BASE_DIR%/}/stacks"
}

install_updates() {
  section "Update Ubuntu packages"
  export DEBIAN_FRONTEND=noninteractive
  run apt-get update
  run apt-get full-upgrade -y
  run apt-get autoremove --purge -y
  run apt-get autoclean -y
  ok "Package update phase complete"
}

install_docker_from_official_repo() {
  section "Install Docker from official apt repository"
  export DEBIAN_FRONTEND=noninteractive

  run apt-get install -y ca-certificates curl gnupg
  run install -m 0755 -d /etc/apt/keyrings

  if [[ "$DRY_RUN" == "1" ]]; then
    info "Would download Docker GPG key to /etc/apt/keyrings/docker.asc"
  else
    info "Downloading Docker GPG key"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
  fi

  local arch
  arch="$(dpkg --print-architecture)"
  local source_line
  source_line="deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable"
  run_shell "printf '%s\n' '${source_line}' > /etc/apt/sources.list.d/docker.list"

  run apt-get update
  run apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  run systemctl enable docker.service
  run systemctl enable containerd.service
  ok "Docker installation phase complete"
}

write_json_file() {
  local path="$1"
  local content="$2"

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '  DRY write %s\n' "$path"
    printf '%s\n' "$content" | sed 's/^/      /'
  else
    printf '  RUN write %s\n' "$path"
    install -m 0644 /dev/null "$path"
    printf '%s\n' "$content" > "$path"
  fi
}

dir_has_entries() {
  local dir="$1"
  [[ -d "$dir" && -n "$(find "$dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]
}

move_state_dir() {
  local source_dir="$1"
  local target_dir="$2"

  if [[ -e "$target_dir" && ! -d "$target_dir" ]]; then
    die "$target_dir exists and is not a directory."
  fi

  if dir_has_entries "$source_dir"; then
    if [[ -e "$target_dir" ]]; then
      if dir_has_entries "$target_dir"; then
        die "Both $source_dir and $target_dir contain data. Refusing to merge automatically."
      fi
      run rmdir "$target_dir"
    fi
    run mv "$source_dir" "$target_dir"
    run mkdir -p "$source_dir"
  else
    run mkdir -p "$source_dir" "$target_dir"
  fi
}

configure_docker_paths() {
  section "Move Docker state to target directory"
  info "Docker base: ${DOCKER_BASE_DIR}"
  info "Docker data-root: ${DOCKER_DATA_ROOT}"
  info "containerd root: ${CONTAINERD_ROOT}"
  info "Stacks directory: ${STACKS_DIR}"

  run mkdir -p "$DOCKER_BASE_DIR" "$STACKS_DIR"
  run systemctl stop docker.service docker.socket containerd.service

  move_state_dir /var/lib/docker "$DOCKER_DATA_ROOT"
  move_state_dir /var/lib/containerd "$CONTAINERD_ROOT"

  run mkdir -p /etc/docker /etc/containerd

  write_json_file /etc/docker/daemon.json "{
  \"data-root\": \"${DOCKER_DATA_ROOT}\"
}"

  if [[ ! -f /etc/containerd/config.toml ]]; then
    if [[ "$DRY_RUN" == "1" ]]; then
      info "Would generate default /etc/containerd/config.toml"
    else
      info "Generating default /etc/containerd/config.toml"
      containerd config default > /etc/containerd/config.toml
    fi
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    info "Would set containerd root in /etc/containerd/config.toml to ${CONTAINERD_ROOT}"
  else
    info "Setting containerd root in /etc/containerd/config.toml"
    if grep -qE '^[[:space:]]*#?[[:space:]]*root[[:space:]]*=' /etc/containerd/config.toml; then
      sed -i -E "s|^[[:space:]]*#?[[:space:]]*root[[:space:]]*=.*|root = \"${CONTAINERD_ROOT}\"|" /etc/containerd/config.toml
    else
      sed -i "1iroot = \"${CONTAINERD_ROOT}\"" /etc/containerd/config.toml
    fi
  fi

  run systemctl daemon-reload
  run systemctl start containerd.service
  run systemctl start docker.socket docker.service
  ok "Docker state path phase complete"
}

verify_installation() {
  section "Verify installation"

  if [[ "$DRY_RUN" == "1" ]]; then
    info "Skipping live Docker verification in dry-run mode"
    return
  fi

  systemctl is-active --quiet containerd.service || die "containerd.service is not active."
  systemctl is-active --quiet docker.service || die "docker.service is not active."

  local actual_root
  actual_root="$(docker info --format '{{.DockerRootDir}}')"
  [[ "$actual_root" == "$DOCKER_DATA_ROOT" ]] || die "DockerRootDir is $actual_root, expected $DOCKER_DATA_ROOT."

  docker run --rm hello-world >/dev/null

  ok "Docker service is active"
  ok "containerd service is active"
  ok "hello-world test container ran successfully"
  info "DockerRootDir: $actual_root"
  info "containerd root: $CONTAINERD_ROOT"
  info "stacks directory: $STACKS_DIR"
}

summary() {
  section "Summary"
  printf '  Ubuntu codename : %s\n' "$UBUNTU_CODENAME"
  printf '  Docker base     : %s\n' "$DOCKER_BASE_DIR"
  printf '  Docker data     : %s\n' "$DOCKER_DATA_ROOT"
  printf '  containerd data : %s\n' "$CONTAINERD_ROOT"
  printf '  Stack files     : %s\n' "$STACKS_DIR"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '  Result          : dry-run completed, no changes made\n'
  else
    printf '  Result          : installation completed\n'
  fi
}

main() {
  banner
  require_root
  require_ubuntu
  choose_base_dir

  section "Plan"
  info "Ubuntu codename: ${UBUNTU_CODENAME}"
  info "Docker base directory: ${DOCKER_BASE_DIR}"
  info "Docker data-root will be: ${DOCKER_DATA_ROOT}"
  info "containerd root will be: ${CONTAINERD_ROOT}"
  info "Stacks directory will be: ${STACKS_DIR}"

  install_updates
  install_docker_from_official_repo
  configure_docker_paths
  verify_installation
  summary

  printf '\nDone.\n'
}

main "$@"
