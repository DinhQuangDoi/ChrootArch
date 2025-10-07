#!/data/data/com.termux/files/usr/bin/bash
# ChrootArch :: install.sh — full bootstrap installer
set -euo pipefail

# ====== CONFIG ======
RAW_BASE="https://raw.githubusercontent.com/DinhQuangDoi/ChrootArch/main"
ARCHROOT="/data/local/tmp/arch"
BIN_DIR="${HOME}/.local/bin"
PAYLOAD_DIR="${HOME}/.local/share/arch-chroot"
CONF_DIR="${HOME}/.config/arch-chroot"
TERMUX_PREFIX="/data/data/com.termux/files/usr"

SCRIPTS=(termux-setup.sh arch-setup.sh arch-first-boot.sh)

# ====== PRECHECK ======
need() { command -v "$1" >/dev/null 2>&1 || { echo "[!] Missing: $1"; exit 1; }; }
ensure_dir() { mkdir -p "$@"; }
need curl
ensure_dir "$BIN_DIR" "$PAYLOAD_DIR" "$CONF_DIR"

export DEBIAN_FRONTEND=noninteractive

# ====== FETCH SCRIPTS ======
echo "[i] Fetching scripts from $RAW_BASE …"
for f in "${SCRIPTS[@]}"; do
  curl -fsSL "${RAW_BASE}/scripts/${f}" -o "${PAYLOAD_DIR}/${f}"
  chmod +x "${PAYLOAD_DIR}/${f}"
done

# default config
if [ ! -f "${CONF_DIR}/config" ]; then
  cat > "${CONF_DIR}/config" <<EOF
ARCHROOT=${ARCHROOT}
GDK_SCALE=1
GDK_DPI_SCALE=1.0
EOF
fi

# ====== RUN SCRIPTS ======
echo "[i] Running termux-setup.sh …"
bash "${PAYLOAD_DIR}/termux-setup.sh"

echo "[i] Running arch-setup.sh …"
bash "${PAYLOAD_DIR}/arch-setup.sh"

echo "[i] Staging arch-first-boot.sh into chroot …"
su -c "mkdir -p '${ARCHROOT}/root'"
su -c "cp '${PAYLOAD_DIR}/arch-first-boot.sh' '${ARCHROOT}/root/arch-first-boot.sh'"
su -c "chmod 700 '${ARCHROOT}/root/arch-first-boot.sh'"

# ====== RUN FIRST-BOOT (interactive) ======
echo "[i] Running first-boot (interactive) …"
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

# ====== CREATE LAUNCHERS ======
echo "[i] Creating launchers in ${BIN_DIR} …"

# ---- start-arch ----
{
cat > "${BIN_DIR}/start-arch" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
[ "${ARCH_DEBUG:-0}" = "1" ] && set -x

MNT="/data/local/tmp/arch"
SUCMD="$(command -v su || echo /system/bin/su)"
BB="$($SUCMD -c 'command -v busybox || echo /data/adb/ksu/bin/busybox || echo /system/bin/busybox || echo busybox')"

# --- mount stage ---
"$SUCMD" -c "sh -s" <<'ROOT'
set -eu
mnt="/data/local/tmp/arch"
BB="$(command -v busybox || echo /data/adb/ksu/bin/busybox || echo /system/bin/busybox || echo busybox)"
if [ ! -x "$mnt/bin/bash" ]; then
  echo "[!] $mnt/bin/bash not found — extract rootfs first."
  exit 1
fi
ismounted(){ grep -q " $1 " /proc/mounts 2>/dev/null; }
mkdir -p "$mnt/dev" "$mnt/proc" "$mnt/sys" "$mnt/dev/pts" "$mnt/dev/shm" "$mnt/tmp" "$mnt/var/cache" "$mnt/media/sdcard"
$BB mount -o remount,dev,suid /data || true
ismounted "$mnt/dev" || $BB mount -o bind /dev "$mnt/dev"
ismounted "$mnt/proc" || $BB mount -t proc proc "$mnt/proc"
ismounted "$mnt/sys" || $BB mount -t sysfs sysfs "$mnt/sys"
ismounted "$mnt/dev/pts" || $BB mount -t devpts devpts "$mnt/dev/pts"
ismounted "$mnt/media/sdcard" || $BB mount -o bind /sdcard "$mnt/media/sdcard"
ismounted "$mnt/var/cache" || $BB mount -t tmpfs -o mode=1777 tmpfs "$mnt/var/cache"
ismounted "$mnt/dev/shm" || $BB mount -t tmpfs -o size=256M,mode=1777 tmpfs "$mnt/dev/shm"
chmod 1777 "$mnt/tmp" "$mnt/dev/shm" "$mnt/var/cache" || true
ROOT

# --- chroot stage ---
ARCH_USER="root"
USER_FROM_CONF="$($SUCMD -c "$BB awk -F= '/^ARCH_USER=/{print \$2}' $MNT/etc/arch-user.conf 2>/dev/null | tr -d '\r\n' || true")"
[ -n "$USER_FROM_CONF" ] && ARCH_USER="$USER_FROM_CONF"

if $SUCMD -c "$BB chroot $MNT /usr/bin/which su >/dev/null 2>&1"; then
  $SUCMD -c "$BB chroot $MNT /bin/su - $ARCH_USER" || $SUCMD -c "$BB chroot $MNT /bin/bash -l"
else
  $SUCMD -c "$BB chroot $MNT /bin/bash -l"
fi
EOF
} || {
  echo "[!] Failed to create launcher locally, fetching from repo…"
  curl -fsSL "${RAW_BASE}/scripts/launchers/start-arch" -o "${BIN_DIR}/start-arch"
}
chmod +x "${BIN_DIR}/start-arch"

# ---- start-arch-x11 (giữ nguyên bản cũ, chỉ tải fallback nếu lỗi) ----
{
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
} || {
  echo "[!] Failed to create X11 launcher locally, fetching from repo…"
  curl -fsSL "${RAW_BASE}/scripts/launchers/start-arch-x11" -o "${BIN_DIR}/start-arch-x11"
}
chmod +x "${BIN_DIR}/start-arch-x11"

# ✅ Ensure ~/.local/bin is in PATH for current and future sessions
echo "[i] Adding ~/.local/bin to PATH..."
for shellrc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
  grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' "$shellrc" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shellrc"
done

# ✅ Add to current session PATH
export PATH="$HOME/.local/bin:$PATH"
hash -r

# ✅ Check if command now resolves
if ! command -v start-arch >/dev/null 2>&1; then
  echo "[!] PATH chưa nhận launcher — dùng lệnh đầy đủ: ~/.local/bin/start-arch"
fi

# ====== SELF-TEST ======
echo "[✓] Install completed!"
echo "• Run 'start-arch' for CLI chroot"
echo "• Run 'start-arch-x11' for XFCE + Termux-X11"
echo "[i] Launching start-arch for initial test..."
~/.local/bin/start-arch || true

# ====== SELF-TEST ======
echo "[✓] Install completed!"
echo "• Run 'start-arch' for CLI chroot"
echo "• Run 'start-arch-x11' for XFCE + Termux-X11"
echo "[i] Launching start-arch for initial test..."
start-arch
