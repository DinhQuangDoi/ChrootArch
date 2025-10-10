#!/bin/bash
# first.sh — First boot inside chroot (keyring, pacman sync, sudo, user)
set -euo pipefail

log(){ echo -e "\033[1;96m[*]\033[0m $*"; }
ok(){  echo -e "\033[1;92m[✓]\033[0m $*"; }
warn(){ echo -e "\033[1;93m[!]\033[0m $*"; }

# 1) Initialize pacman keys (idempotent)
log "Initialize pacman keys..."
pacman-key --init >/dev/null 2>&1 || true
pacman-key --populate archlinuxarm >/dev/null 2>&1 || true
ok "Keys ready."

# 2) Sync DB (try HTTPS; if fail, fallback to HTTP + curl XferCommand)
log "Synchronizing package databases..."
if pacman -Syy --noconfirm; then
  ok "Pacman sync OK (HTTPS)."
else
  warn "HTTPS sync failed — fallback to HTTP temporarily."
  # Switch mirrorlist to HTTP and set XferCommand with --insecure
  sed -i 's|https://|http://|g' /etc/pacman.d/mirrorlist
  if ! grep -q '^XferCommand' /etc/pacman.conf; then
    sed -i '1i XferCommand = /usr/bin/curl -fsSL --insecure -C - -o %o %u' /etc/pacman.conf
  else
    sed -i 's|^XferCommand.*|XferCommand = /usr/bin/curl -fsSL --insecure -C - -o %o %u|' /etc/pacman.conf
  fi
  if pacman -Syy --noconfirm; then
    ok "Pacman sync OK via HTTP fallback."
  else
    warn "HTTP fallback still failing — continue anyway (you can re-run later)."
  fi
fi

# 3) Minimal tools
log "Installing sudo and basics..."
pacman -S --noconfirm --needed sudo curl nano || true

# 4) Create default user interactively (store for launcher)
if [ ! -f /etc/arch-user.conf ]; then
  echo
  echo "=== Create Arch user (used by launcher) ==="
  read -rp "Username [arch]: " NEWUSER
  : "${NEWUSER:=arch}"
  useradd -m -s /bin/bash "$NEWUSER" || true
  echo "Set password for $NEWUSER:"
  passwd "$NEWUSER" || true
  echo "$NEWUSER ALL=(ALL:ALL) ALL" >/etc/sudoers.d/10-$NEWUSER
  chmod 440 /etc/sudoers.d/10-$NEWUSER
  echo "ARCH_USER=$NEWUSER" >/etc/arch-user.conf
  ok "User $NEWUSER created."
fi

ok "First boot complete."
