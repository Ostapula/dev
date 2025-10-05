#!/usr/bin/env bash
# Idempotent Go installer for WSL2 Ubuntu.
# Installs latest stable Go if not present.

set -euo pipefail

log()  { printf "\033[1;32m%s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m%s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m%s\033[0m\n" "$*" >&2; }

arch_map() {
  case "$(uname -m)" in
    x86_64)  echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) err "Unsupported architecture: $(uname -m)"; exit 1 ;;
  esac
}

if command -v go >/dev/null 2>&1; then
  log "Go already installed: $(go version)"
  exit 0
fi

GOARCH="$(arch_map)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

log "Fetching latest stable Go version metadata..."
curl -fsSL "https://go.dev/dl/?mode=json" -o "$TMPDIR/go.json"

GOVERSION="$(sed -n 's/.*"version":"go\([0-9.]\+\)".*/\1/p' "$TMPDIR/go.json" | head -n1)"
[[ -n "${GOVERSION:-}" ]] || { err "Could not determine latest Go version"; exit 1; }

TARBALL="go${GOVERSION}.linux-$(arch_map).tar.gz"
URL="https://go.dev/dl/${TARBALL}"

log "Latest Go detected: ${GOVERSION} ($(arch_map))"
log "Downloading ${TARBALL}..."
curl -fsSL "$URL" -o "$TMPDIR/$TARBALL"

SHA256_EXPECTED="$(tr -d '\n' < "$TMPDIR/go.json" | sed -n "s/.*\"filename\":\"${TARBALL}\"[^{]*{\"kind\":\"archive\"[^}]*\"sha256\":\"\([a-f0-9]\{64\}\)\".*/\1/p")"
if [[ -n "${SHA256_EXPECTED:-}" ]]; then
  log "Verifying checksum..."
  echo "${SHA256_EXPECTED}  $TMPDIR/$TARBALL" | sha256sum -c -
else
  warn "Checksum not found in JSON; skipping verification."
fi

if [[ -d /usr/local/go ]]; then
  warn "/usr/local/go exists; removing to install fresh Go ${GOVERSION}."
  sudo rm -rf /usr/local/go
fi

log "Installing Go to /usr/local/go..."
sudo tar -C /usr/local -xzf "$TMPDIR/$TARBALL"

if [[ ! -f /etc/profile.d/go.sh ]]; then
  log "Configuring PATH in /etc/profile.d/go.sh..."
  sudo bash -c 'cat >/etc/profile.d/go.sh' <<'EOF'
export GOROOT=/usr/local/go
export GOPATH="$HOME/go"
export PATH="$PATH:$GOROOT/bin:$GOPATH/bin"
EOF
fi

# Export for current shell session
export GOROOT=/usr/local/go
export GOPATH="$HOME/go"
export PATH="$PATH:$GOROOT/bin:$GOPATH/bin"

log "Go installed: $(go version)"
