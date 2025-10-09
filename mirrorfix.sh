#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ARCHROOT="/data/local/tmp/arch"
PACMAN="$ARCHROOT/usr/bin/pacman"
MIRRORLIST="$ARCHROOT/etc/pacman.d/mirrorlist"

msg() { echo -e "\033[1;96m[*]\033[0m $*"; }
err() { echo -e "\033[1;91m[!]\033[0m $*" >&2; }

# Ensure chroot and pacman exist (check via su)
if ! su -c "[ -x '$PACMAN' ]"; then
  err "Arch chroot not found or pacman missing at $PACMAN"
  exit 1
fi

# Try current mirror
msg "Testing current mirror..."
if su -c "busybox chroot '$ARCHROOT' $PACMAN -Syy --noconfirm" >/dev/null 2>&1; then
  msg "Current mirror works fine."
  exit 0
fi

# Mirror candidates
MIRRORS=(
  "http://mirror.archlinuxarm.org"
  "http://sg.mirror.archlinuxarm.org"
  "http://us.mirror.archlinuxarm.org"
  "http://de.mirror.archlinuxarm.org"
)

msg "Current mirror failed — trying alternatives..."

for M in "${MIRRORS[@]}"; do
  msg "Testing $M ..."
  su -c "echo 'Server = $M/\$arch/\$repo' > '$MIRRORLIST'"
  if su -c "busybox chroot '$ARCHROOT' $PACMAN -Syy --noconfirm" >/dev/null 2>&1; then
    msg "✅ Mirror switched to $M"
    exit 0
  fi
done

err "No working mirror found! Please check network or wait for sync."
exit 1
