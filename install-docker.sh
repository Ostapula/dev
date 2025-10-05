#!/usr/bin/env bash
# Installs Docker Engine from Docker's official repo on Ubuntu (WSL2-friendly).

set -euo pipefail

log()  { printf "\033[1;32m%s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m%s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m%s\033[0m\n" "$*" >&2; }

is_systemd() { [[ -d /run/systemd/system ]]; }

if command -v docker >/dev/null 2>&1; then
  log "Docker already installed: $(docker --version)"
  exit 0
fi

log "Adding Docker’s official GPG key and repository..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

UBUNTU_CODENAME="$(. /etc/os-release; echo "${VERSION_CODENAME}")"
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" \
| sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

log "Installing Docker Engine + CLI + Compose plugin..."
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

if is_systemd; then
  log "Enabling and starting Docker with systemd..."
  sudo systemctl enable --now docker
else
  warn "systemd not detected in WSL. You can:"
  warn "  - Enable systemd in /etc/wsl.conf and restart WSL, or"
  warn "  - Start Docker per session with: sudo service docker start"
fi

# Add the current user to docker group (no sudo needed for docker cmds)
if ! getent group docker >/dev/null; then
  sudo groupadd docker
fi
if id -nG "$USER" | grep -qw docker; then
  log "User '$USER' is already in the 'docker' group."
else
  log "Adding user '$USER' to 'docker' group..."
  sudo usermod -aG docker "$USER"
  warn "Open a new shell or run: newgrp docker"
fi

log "Docker installed. Test with: docker run --rm hello-world"
