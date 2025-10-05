#!/data/data/com.termux/files/usr/bin/bash
# ChrootArch :: install.sh — full auto bootstrap (non-interactive until first boot)
set -euo pipefail

# ====== 0. CONFIG ======
RAW_BASE="https://raw.githubusercontent.com/DinhQuangDoi/ChrootArch/main"
ARCHROOT="/data/local/tmp/arch"
BIN_DIR="${HOME}/.local/bin"
PAYLOAD_DIR="${HOME}/.local/share/arch-chroot"
CONF_DIR="${HOME}/.config/arch-chroot"
TERMUX_PREFIX="/data/data/com.termux/files/usr"
SCRIPTS=(termux-setup.sh arch-setup.sh arch-first-boot.sh)

# ====== 1. PRECHECK ======
need() { command -v "$1" >/dev/null 2>&1 || { echo "[!] Missing: $1"; exit 1; }; }
ensure_dir() { mkdir -p "$@"; }
need curl
ensure_dir "$BIN_DIR" "$PAYLOAD_DIR" "$CONF_DIR"

export DEBIAN_FRONTEND=noninteractive

# ====== 2. FETCH SCRIPTS ======
echo "[i] Fetching scripts from $RAW_BASE …"
for f in "${SCRIPTS[@]}"; do
  curl -fsSL "${RAW_BASE}/scripts/${f}" -o "${PAYLOAD_DIR}/${f}"
  chmod +x "${PAYLOAD_DIR}/${f}"
done

# Default config
if [ ! -f "${CONF_DIR}/config" ]; then
  cat > "${CONF_DIR}/config" <<EOF
ARCHROOT=${ARCHROOT}
GDK_SCALE=1
GDK_DPI_SCALE=1.0
EOF
fi

# ====== 3. INSTALL BASE DEPENDENCIES ======
echo "[i] Running termux-setup.sh …"
bash "${PAYLOAD_DIR}/termux-setup.sh"

# ====== 4. SETUP ARCH ROOTFS ======
echo "[i] Running arch-setup.sh …"
bash "${PAYLOAD_DIR}/arch-setup.sh"

# ====== 5. STAGE FIRST-BOOT ======
echo "[i] Copying arch-first-boot.sh into chroot…"
su -c "mkdir -p '${ARCHROOT}/root'"
su -c "cp '${PAYLOAD_DIR}/arch-first-boot.sh' '${ARCHROOT}/root/arch-first-boot.sh'"
su -c "chmod 700 '${ARCHROOT}/root/arch-first-boot.sh'"

# ====== 6. RUN FIRST-BOOT ======
echo "[i] Running first boot (interactive setup)…"
su -c "sh -s" <<'ROOT'
set -eu
mnt="/data/local/tmp/arch"
BB="$(command -v busybox || echo /data/adb/ksu/bin/busybox || echo /system/bin/busybox || echo busybox)"

ismounted(){ grep -q " $1 " /proc/mounts 2>/dev/null; }

mkdir -p "$mnt/proc" "$mnt/sys" "$mnt/dev" "$mnt/dev/pts"
ismounted "$mnt/proc"    || $BB mount -t proc  proc "$mnt/proc"
ismounted "$mnt/sys"     || $BB mount -t sysfs sysfs "$mnt/sys"
ismounted "$mnt/dev"     || $BB mount -o bind /dev "$mnt/dev"
ismounted "$mnt/dev/pts" || $BB mount -t devpts devpts "$mnt/dev/pts"

$BB chroot "$mnt" /bin/bash -lc "/root/arch-first-boot.sh || true"
ROOT

# ====== 7. CREATE LAUNCHERS ======
echo "[i] Creating launchers in ${BIN_DIR} …"

# --- CLI ---
cat > "${BIN_DIR}/start-arch" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
ARCH_DEBUG=0
[ "$ARCH_DEBUG" = "1" ] && set -x
MNT="/data/local/tmp/arch"
SUCMD="$(command -v su || echo /system/bin/su)"
BB="$($SUCMD -c 'command -v busybox || echo /data/adb/ksu/bin/busybox || echo /system/bin/busybox || echo busybox')"

"$SUCMD" -c "sh -s" <<'ROOT'
set -eu
mnt="/data/local/tmp/arch"
BB="$(command -v busybox || echo /data/adb/ksu/bin/busybox || echo /system/bin/busybox || echo busybox)"
ismounted(){ grep -q " $1 " /proc/mounts 2>/dev/null; }
mkdir -p "$mnt/dev" "$mnt/proc" "$mnt/sys" "$mnt/dev/pts" "$mnt/dev/shm" "$mnt/tmp" "$mnt/var/cache"
$BB mount -o remount,dev,suid /data || true
ismounted "$mnt/dev" || $BB mount -o bind /dev "$mnt/dev"
ismounted "$mnt/proc" || $BB mount -t proc proc "$mnt/proc"
ismounted "$mnt/sys" || $BB mount -t sysfs sysfs "$mnt/sys"
ismounted "$mnt/dev/pts" || $BB mount -t devpts devpts "$mnt/dev/pts"

ARCH_USER="root"
[ -f "$mnt/etc/arch-user.conf" ] && ARCH_USER="$($BB awk -F= '/^ARCH_USER=/{print $2}' "$mnt/etc/arch-user.conf" | $BB tr -d '\r\n')"
[ -z "$ARCH_USER" ] && ARCH_USER="root"

if $BB chroot "$mnt" /usr/bin/which su >/dev/null 2>&1; then
  exec $BB chroot "$mnt" /bin/su - "$ARCH_USER"
else
  exec $BB chroot "$mnt" /bin/bash -l
fi
ROOT
EOF
chmod +x "${BIN_DIR}/start-arch"

# --- X11 ---
cat > "${BIN_DIR}/start-arch-x11" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
PREFIX="/data/data/com.termux/files/usr"
pkill -f com.termux.x11 >/dev/null 2>&1 || true
killall -9 termux-x11 Xwayland pulseaudio virgl_test_server_android termux-wake-lock >/dev/null 2>&1 || true
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || true
chmod 1777 "$PREFIX/tmp" || true
XDG_RUNTIME_DIR="${TMPDIR:-$PREFIX/tmp}" termux-x11 :0 -ac >/dev/null 2>&1 &
sleep 4
pulseaudio --kill >/dev/null 2>&1 || true
pulseaudio --start --exit-idle-time=-1 --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" >/dev/null 2>&1 || true
command -v virgl_test_server_android >/dev/null 2>&1 && virgl_test_server_android >/dev/null 2>&1 &
termux-wake-lock || true

su -c "sh -s" <<'ROOT'
set -eu
mnt="/data/local/tmp/arch"
tp="/data/data/com.termux/files/usr"
xsock="$tp/tmp/.X11-unix"
BB="$(command -v busybox || echo /data/adb/ksu/bin/busybox || echo /system/bin/busybox || echo busybox)"
ismounted(){ grep -q " $1 " /proc/mounts 2>/dev/null; }
mkdir -p "$mnt/dev" "$mnt/proc" "$mnt/sys" "$mnt/dev/pts" "$mnt/tmp/.X11-unix" "$mnt/dev/shm"
$BB mount -o remount,dev,suid /data || true
ismounted "$mnt/dev" || $BB mount -o bind /dev "$mnt/dev"
ismounted "$mnt/proc" || $BB mount -t proc proc "$mnt/proc"
ismounted "$mnt/sys" || $BB mount -t sysfs sysfs "$mnt/sys"
ismounted "$mnt/dev/pts" || $BB mount -t devpts devpts "$mnt/dev/pts"
[ -d "$xsock" ] && ismounted "$mnt/tmp/.X11-unix" || $BB mount -o bind "$xsock" "$mnt/tmp/.X11-unix"
ARCH_USER="root"
[ -f "$mnt/etc/arch-user.conf" ] && ARCH_USER="$($BB awk -F= '/^ARCH_USER=/{print $2}' "$mnt/etc/arch-user.conf" | $BB tr -d '\r\n')"
[ -z "$ARCH_USER" ] && ARCH_USER="root"

if $BB chroot "$mnt" /usr/bin/which su >/dev/null 2>&1; then
  exec $BB chroot "$mnt" /bin/su - "$ARCH_USER"
else
  exec $BB chroot "$mnt" /bin/bash -l
fi
ROOT
EOF
chmod +x "${BIN_DIR}/start-arch-x11"

# ====== 8. ENSURE PATH ======
if ! grep -q '\.local/bin' "${HOME}/.bashrc" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.bashrc"
fi
export PATH="$HOME/.local/bin:$PATH"
hash -r

echo "[✓] Install completed!"
echo "• Run 'start-arch' for CLI chroot"
echo "• Run 'start-arch-x11' for XFCE + Termux-X11"
