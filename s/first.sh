#!/bin/bash
# first.sh — First boot tasks inside Arch chroot
set -euo pipefail

log(){ printf "\033[1;96m[*]\033[0m %s\n" "$*"; }
ok(){  printf "\033[1;92m[✓]\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;93m[!]\033[0m %s\n" "$*"; }
err(){ printf "\033[1;91m[!]\033[0m %s\n" "$*"; }

# 0) Ensure basic DNS/hosts
echo "nameserver 8.8.8.8" >/etc/resolv.conf || true
echo "nameserver 1.1.1.1" >>/etc/resolv.conf || true
echo "127.0.0.1 localhost" >/etc/hosts || true

# 1) Keyring (idempotent)
log "Initializing pacman keys..."
pacman-key --init >/dev/null 2>&1 || true
pacman-key --populate archlinuxarm >/dev/null 2>&1 || true
ok  "Keys ready."

# 2) Mirrorlist (HTTPS first; will fallback if needed)
log "Writing mirrorlist (HTTPS first)..."
cat > /etc/pacman.d/mirrorlist <<'EOF'
Server = https://mirror.archlinuxarm.org/$arch/$repo
Server = https://sg.mirror.archlinuxarm.org/$arch/$repo
Server = https://us.mirror.archlinuxarm.org/$arch/$repo
Server = https://de.mirror.archlinuxarm.org/$arch/$repo
EOF

# Helpers to toggle XferCommand fallback
PACMAN_CONF="/etc/pacman.conf"
backup_conf(){
  [ -f "${PACMAN_CONF}.orig" ] || cp -f "$PACMAN_CONF" "${PACMAN_CONF}.orig"
}
set_insecure_http(){
  backup_conf
  # Use curl with --insecure and allow HTTP fallback
  if ! grep -q '^XferCommand' "$PACMAN_CONF"; then
    sed -i '1i XferCommand = /usr/bin/curl -fsSL --insecure -C - -o %o %u' "$PACMAN_CONF"
  else
    sed -i 's|^XferCommand.*|XferCommand = /usr/bin/curl -fsSL --insecure -C - -o %o %u|' "$PACMAN_CONF"
  fi
  # Switch mirrors to HTTP (many ISPs proxy HTTPS badly)
  sed -i 's|https://|http://|g' /etc/pacman.d/mirrorlist
}
restore_secure_https(){
  # Remove XferCommand override
  if grep -q '^XferCommand' "$PACMAN_CONF"; then
    # restore full original if we backed it up
    if [ -f "${PACMAN_CONF}.orig" ]; then
      cp -f "${PACMAN_CONF}.orig" "$PACMAN_CONF"
    else
      sed -i '/^XferCommand/d' "$PACMAN_CONF"
    fi
  fi
  # Back to HTTPS mirrors
  sed -i 's|http://|https://|g' /etc/pacman.d/mirrorlist
}

try_sync(){
  pacman -Syy --noconfirm
}

# 3) Try HTTPS sync first
log "Updating system (HTTPS)..."
if try_sync; then
  ok "Mirror sync over HTTPS OK."
else
  warn "HTTPS sync failed — falling back to HTTP + --insecure temporarily."
  set_insecure_http
  if try_sync; then
    ok "Mirror sync via HTTP fallback OK. Installing CA/curl to recover HTTPS..."
    # Install CA and SSL stack to stabilize HTTPS
    pacman -S --noconfirm --needed ca-certificates ca-certificates-utils openssl curl
    update-ca-trust || true
    # Restore HTTPS and test again
    restore_secure_https
    if try_sync; then
      ok "HTTPS restored successfully."
    else
      warn "HTTPS still problematic — will proceed; you can keep HTTP temporarily."
      set_insecure_http
    fi
  else
    err "Both HTTPS and HTTP fallback failed. Check network/ISP/VPN."
    exit 1
  fi
fi

# 4) (Optional) System update minimal core
# pacman -Su --noconfirm || true

# 5) Create default sudo user interactively (kept as before if bạn đã có đoạn này)
if [ ! -f /etc/arch-user.conf ]; then
  echo
  echo "=== Create Arch user (will be used by launchers) ==="
  read -rp "Username: " NEWUSER
  : "${NEWUSER:=arch}"
  useradd -m -s /bin/bash "$NEWUSER" || true
  echo "Set password for $NEWUSER:"
  passwd "$NEWUSER" || true
  pacman -S --noconfirm --needed sudo
  echo "$NEWUSER ALL=(ALL:ALL) ALL" >/etc/sudoers.d/10-$NEWUSER
  chmod 440 /etc/sudoers.d/10-$NEWUSER
  echo "ARCH_USER=$NEWUSER" >/etc/arch-user.conf
  ok "User $NEWUSER created and configured for sudo."
fi

echo
ok "First boot completed."
