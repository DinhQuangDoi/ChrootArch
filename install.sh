#!/data/data/com.termux/files/usr/bin/bash
# ChrootArch :: install.sh  — RAW bootstrap (non-interactive until first-boot)
# Repo: https://github.com/DinhQuangDoi/ChrootArch
set -euo pipefail

# ---- Config (you can change these if needed) ---------------------------------
RAW_BASE="https://raw.githubusercontent.com/DinhQuangDoi/ChrootArch/main"
ARCHROOT="/data/local/tmp/arch"                  # Arch rootfs path on Android
BIN_DIR="${HOME}/.local/bin"                     # Termux launchers go here
PAYLOAD_DIR="${HOME}/.local/share/arch-chroot"   # Downloaded scripts live here
CONF_DIR="${HOME}/.config/arch-chroot"           # User config (optional)
TERMUX_PREFIX="/data/data/com.termux/files/usr"

# ---- Helpers -----------------------------------------------------------------
need() { command -v "$1" >/dev/null 2>&1 || { echo "[!] Missing: $1"; exit 1; }; }
fetch() { curl -fsSL "$1" -o "$2"; }
ensure_dir() { mkdir -p "$@"; }

# ---- Preflight ---------------------------------------------------------------
need curl
ensure_dir "$BIN_DIR" "$PAYLOAD_DIR" "$CONF_DIR"

# auto-yes for pkg/apt inside any setup scripts we run
export DEBIAN_FRONTEND=noninteractive

# ---- Pull scripts from repo --------------------------------------------------
echo "[i] Fetching scripts from $RAW_BASE …"
SCRIPTS=(termux-setup.sh arch-setup.sh arch-first-boot.sh)
for f in "${SCRIPTS[@]}"; do
  fetch "${RAW_BASE}/scripts/${f}" "${PAYLOAD_DIR}/${f}"
  chmod +x "${PAYLOAD_DIR}/${f}"
done

# default config if missing
if [ ! -f "${CONF_DIR}/config" ]; then
  cat > "${CONF_DIR}/config" <<EOF
ARCHROOT=${ARCHROOT}
GDK_SCALE=1
GDK_DPI_SCALE=1.0
EOF
fi

# ---- 1) Termux setup (packages needed for X11 bridge etc.) -------------------
echo "[i] Running termux-setup.sh …"
bash "${PAYLOAD_DIR}/termux-setup.sh"

# ---- 2) Download & unpack Arch rootfs, seed minimal network files ------------
echo "[i] Running arch-setup.sh …"
bash "${PAYLOAD_DIR}/arch-setup.sh"

# ---- 3) Stage first-boot into rootfs & run it inside chroot ------------------
echo "[i] Staging arch-first-boot.sh into ${ARCHROOT}/root …"
su -c "mkdir -p '${ARCHROOT}/root'"
su -c "cp '${PAYLOAD_DIR}/arch-first-boot.sh' '${ARCHROOT}/root/arch-first-boot.sh'"
su -c "chmod 700 '${ARCHROOT}/root/arch-first-boot.sh'"

echo "[i] Entering chroot to run first-boot (this step is INTERACTIVE) …"
su -c "sh -s" <<'ROOT'
set -eu
mnt="/data/local/tmp/arch"
BB="$(command -v busybox || echo /system/bin/busybox)"
[ -x "$BB" ] || { echo "[!] System busybox not found"; exit 1; }

ismounted(){ grep -q " $1 " /proc/mounts 2>/dev/null; }

# Minimal mounts for first-boot
mkdir -p "$mnt/proc" "$mnt/sys" "$mnt/dev" "$mnt/dev/pts"
ismounted "$mnt/proc"    || $BB mount -t proc  proc "$mnt/proc"
ismounted "$mnt/sys"     || $BB mount -t sysfs sysfs "$mnt/sys"
ismounted "$mnt/dev"     || $BB mount -o bind /dev "$mnt/dev"
ismounted "$mnt/dev/pts" || $BB mount -t devpts devpts "$mnt/dev/pts"

# Run first-boot (prompts for user/pass, timezone, locale…)
$BB chroot "$mnt" /bin/bash -lc "/root/arch-first-boot.sh || true"
ROOT

# ---- 4) Create Termux launchers ----------------------------------------------
echo "[i] Creating launchers in ${BIN_DIR} …"

# CLI (no X11)
cat > "${BIN_DIR}/start-arch" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
su -c "sh -s" <<'ROOT'
set -eu
mnt="/data/local/tmp/arch"
BB="$(command -v busybox || echo /system/bin/busybox)"
[ -x "$BB" ] || { echo "[!] busybox not found"; exit 1; }

ismounted(){ grep -q " $1 " /proc/mounts 2>/dev/null; }

mkdir -p "$mnt" "$mnt/dev" "$mnt/proc" "$mnt/sys" "$mnt/dev/pts" \
         "$mnt/dev/shm" "$mnt/tmp" "$mnt/var/cache" "$mnt/media/sdcard"

$BB mount -o remount,dev,suid /data || true
ismounted "$mnt/dev"      || $BB mount -o bind /dev "$mnt/dev"
ismounted "$mnt/proc"     || $BB mount -t proc  proc "$mnt/proc"
ismounted "$mnt/sys"      || $BB mount -t sysfs sysfs "$mnt/sys"
ismounted "$mnt/dev/pts"  || $BB mount -t devpts devpts "$mnt/dev/pts"
ismounted "$mnt/media/sdcard" || $BB mount -o bind /sdcard "$mnt/media/sdcard"
ismounted "$mnt/var/cache" || $BB mount -t tmpfs -o mode=1777 tmpfs "$mnt/var/cache"
ismounted "$mnt/dev/shm"   || $BB mount -t tmpfs -o size=256M,mode=1777 tmpfs "$mnt/dev/shm"
chmod 1777 "$mnt/tmp" "$mnt/dev/shm" "$mnt/var/cache" || true

ARCH_USER="root"
if [ -f "$mnt/etc/arch-user.conf" ]; then
  ARCH_USER="$($BB awk -F= '/^ARCH_USER=/{print $2}' "$mnt/etc/arch-user.conf" | $BB tr -d '\r\n')"
  [ -n "$ARCH_USER" ] || ARCH_USER="root"
  $BB chroot "$mnt" /usr/bin/id "$ARCH_USER" >/dev/null 2>&1 || ARCH_USER="root"
fi

exec $BB chroot "$mnt" /bin/su - "$ARCH_USER"
ROOT
EOF
chmod +x "${BIN_DIR}/start-arch"

# X11 (Termux-X11 + Pulse + VirGL)
cat > "${BIN_DIR}/start-arch-x11" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
PREFIX="/data/data/com.termux/files/usr"
# Termux-side: X11 + audio + renderer
pkill -f com.termux.x11 >/dev/null 2>&1 || true
killall -9 termux-x11 Xwayland pulseaudio virgl_test_server_android termux-wake-lock >/dev/null 2>&1 || true
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || true
chmod 1777 "$PREFIX/tmp" || true
XDG_RUNTIME_DIR="${TMPDIR:-$PREFIX/tmp}" termux-x11 :0 -ac >/dev/null 2>&1 &
sleep 4
pulseaudio --kill >/dev/null 2>&1 || true
pulseaudio --start --exit-idle-time=-1 \
  --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" >/dev/null 2>&1 || true
pacmd load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 >/dev/null 2>&1 || true
command -v virgl_test_server_android >/dev/null 2>&1 && virgl_test_server_android >/dev/null 2>&1 & || true
termux-wake-lock || true

# Root-side: mounts + X11 bridge + chroot
su -c "sh -s" <<'ROOT'
set -eu
mnt="/data/local/tmp/arch"
tp="/data/data/com.termux/files/usr"
xsock="$tp/tmp/.X11-unix"

BB="$(command -v busybox || echo /system/bin/busybox)"
[ -x "$BB" ] || { echo "[!] busybox not found"; exit 1; }

ismounted(){ grep -q " $1 " /proc/mounts 2>/dev/null; }

mkdir -p "$mnt/dev" "$mnt/proc" "$mnt/sys" "$mnt/dev/pts" "$mnt/dev/shm" \
         "$mnt/tmp/.X11-unix" "$mnt/var/cache" "$mnt/media/sdcard" "$mnt/run/termux-tmp"

$BB mount -o remount,dev,suid /data || true
ismounted "$mnt/dev"      || $BB mount -o bind /dev "$mnt/dev"
ismounted "$mnt/proc"     || $BB mount -t proc  proc "$mnt/proc"
ismounted "$mnt/sys"      || $BB mount -t sysfs sysfs "$mnt/sys"
ismounted "$mnt/dev/pts"  || $BB mount -t devpts devpts "$mnt/dev/pts"
ismounted "$mnt/media/sdcard" || $BB mount -o bind /sdcard "$mnt/media/sdcard"
ismounted "$mnt/var/cache" || $BB mount -t tmpfs -o mode=1777 tmpfs "$mnt/var/cache"
ismounted "$mnt/dev/shm"   || $BB mount -t tmpfs -o size=256M,mode=1777 tmpfs "$mnt/dev/shm"

# Bridge X11 socket and runtime tmp
[ -d "$xsock" ] && ismounted "$mnt/tmp/.X11-unix" || $BB mount -o bind "$xsock" "$mnt/tmp/.X11-unix"
ismounted "$mnt/run/termux-tmp" || $BB mount -o bind "$tp/tmp" "$mnt/run/termux-tmp"

chmod 1777 "$mnt/tmp" "$mnt/dev/shm" "$mnt/var/cache" || true

ARCH_USER="root"
if [ -f "$mnt/etc/arch-user.conf" ]; then
  ARCH_USER="$($BB awk -F= '/^ARCH_USER=/{print $2}' "$mnt/etc/arch-user.conf" | $BB tr -d '\r\n')"
  [ -n "$ARCH_USER" ] || ARCH_USER="root"
  $BB chroot "$mnt" /usr/bin/id "$ARCH_USER" >/dev/null 2>&1 || ARCH_USER="root"
fi

exec $BB chroot "$mnt" /bin/su - "$ARCH_USER"
ROOT
EOF
chmod +x "${BIN_DIR}/start-arch-x11"

# --- Copy launchers into $PREFIX/bin (B) -------------------------------------
TERMUX_BIN="${TERMUX_PREFIX}/bin"
install -m 700 "${BIN_DIR}/start-arch"      "${TERMUX_BIN}/start-arch"      || true
install -m 700 "${BIN_DIR}/start-arch-x11"  "${TERMUX_BIN}/start-arch-x11"  || true

# kiểm tra nhanh
if ! command -v start-arch >/dev/null 2>&1; then
  echo "[!] Không tìm thấy start-arch trong PATH dù đã copy vào \$PREFIX/bin."
  echo "    Kiểm tra: ls -l '${TERMUX_BIN}/start-arch'"
fi
# 🔎 Tìm busybox và su khả dụng
BB="$(su -c 'command -v busybox || echo /system/bin/busybox || echo /data/adb/ksu/bin/busybox || echo busybox')"
SUCMD="$(command -v su || echo /system/bin/su)"

# --- Mount chroot ---
$SUCMD -c "sh -s" <<'ROOT'
set -eu
mnt="/data/local/tmp/arch"
BB="$(command -v busybox || echo busybox)"
ismounted(){ grep -q " $1 " /proc/mounts 2>/dev/null; }
mkdir -p "$mnt/proc" "$mnt/sys" "$mnt/dev" "$mnt/dev/pts"
ismounted "$mnt/proc"    || $BB mount -t proc  proc "$mnt/proc"
ismounted "$mnt/sys"     || $BB mount -t sysfs sysfs "$mnt/sys"
ismounted "$mnt/dev"     || $BB mount -o bind /dev "$mnt/dev"
ismounted "$mnt/dev/pts" || $BB mount -t devpts devpts "$mnt/dev/pts"
ROOT

# --- Chạy arch-first-boot.sh ---
if [ ! -f "/data/local/tmp/arch/etc/arch-user.conf" ]; then
  echo "[i] Running /root/arch-first-boot.sh (interactive)…"
  $SUCMD -c "$BB chroot /data/local/tmp/arch /bin/bash -lc /root/arch-first-boot.sh"
else
  echo "[✓] arch-first-boot đã chạy trước đó — bỏ qua."
fi
