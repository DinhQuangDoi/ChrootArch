#!/bin/bash
# pacmanfix.sh — Disable CheckSpace, reset gnupg, add Android AID groups
set -euo pipefail

log(){ echo -e "\033[1;96m[*]\033[0m $*"; }
ok(){  echo -e "\033[1;92m[✓]\033[0m $*"; }

PACMAN_CONF="/etc/pacman.conf"

log "Disable CheckSpace in pacman.conf..."
sed -i 's/^CheckSpace/#CheckSpace/' "$PACMAN_CONF" || true

log "Reset pacman keyring directory..."
rm -rf /etc/pacman.d/gnupg || true

log "Create Android AID groups if missing..."
declare -A AID=([aid_inet]=3003 [aid_net_raw]=3004 [aid_graphics]=1003)
for name in "${!AID[@]}"; do
  gid="${AID[$name]}"
  getent group "$name" >/dev/null 2>&1 || groupadd -g "$gid" "$name" || true
done

log "Add root to aid_inet (network sockets)..."
usermod -G 3003 -a root || true

ok "pacmanfix applied."
