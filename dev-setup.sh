#!/usr/bin/env bash

# Main orchestrator for WSL2 Ubuntu dev environment
# Usage:
#   ./dev-setup.sh all
#   ./dev-setup.sh go
#   ./dev-setup.sh docker
# Extensible: add more cases or plug-ins later.

# -e → exit on any non-zero command (prevents continuing after errors),
# -u → treat undefined variables as errors,
# -o pipefail → fail if any command in a pipeline fails (not just the last one).
set -euo pipefail

#Logging
#\033[1;32m etc. are ANSI color codes.
log()  { printf "\033[1;32m%s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m%s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m%s\033[0m\n" "$*" >&2; }

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

ensure_prereqs() {
  log "Updating apt and installing prerequisites..."
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg lsb-release
}

run_module() {
  local module="$1"
  case "$module" in
    go)
      bash "$SCRIPT_DIR/install-go.sh"
      ;;
    docker)
      bash "$SCRIPT_DIR/install-docker.sh"
      ;;
    *)
      err "Unknown module: $module"
      exit 1
      ;;
  esac
}

main() {
  local target="${1:-all}"

  ensure_prereqs

  case "$target" in
    all)
      run_module go
      run_module docker
      ;;
    go|docker)
      run_module "$target"
      ;;
    *)
      err "Usage: $0 {all|go|docker}"
      exit 2
      ;;
  esac

  log "Done."
}

main "$@"
