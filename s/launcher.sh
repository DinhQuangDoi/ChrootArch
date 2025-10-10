#!/data/data/com.termux/files/usr/bin/bash
# launcher.sh — start-arch (CLI)
set -euo pipefail
mnt="/data/local/tmp/arch"
BB="$(command -v busybox || echo /system/bin/busybox)"
[ -x "$BB" ] || { echo "[!] BusyBox not found"; exit 1; }

# Prepare and bind mounts every run
su -c "sh -s" <<'ROOT'
set -eu
mnt="/data/local/tmp/arch"
BB="$(command -v busybox || echo /system/bin/busybox)"

mkdir -p "$mnt/dev" "$mnt/proc" "$mnt/sys" "$mnt/dev/pts" "$mnt/dev/shm" \
         "$mnt/var/cache" "$mnt/tmp" "$mnt/media/sdcard" "$mnt/sys/class/net"

$BB mount -o remount,dev,suid /data || true

mountpoint -q "$mnt/dev"      || $BB mount -o bind /dev "$mnt/dev"
mountpoint -q "$mnt/proc"     || $BB mount -t proc  proc "$mnt/proc"
mountpoint -q "$mnt/sys"      || $BB mount -t sysfs sysfs "$mnt/sys"
mountpoint -q "$mnt/dev/pts"  || $BB mount -t devpts devpts "$mnt/dev/pts"
mountpoint -q "$mnt/sys/class/net" || $BB mount --bind /sys/class/net "$mnt/sys/class/net"
mountpoint -q "$mnt/media/sdcard"  || $BB mount -o bind /sdcard "$mnt/media/sdcard"

mountpoint -q "$mnt/var/cache" || $BB mount -t tmpfs -o mode=1777 tmpfs "$mnt/var/cache"
mountpoint -q "$mnt/dev/shm"   || $BB mount -t tmpfs -o size=256M,mode=1777 tmpfs "$mnt/dev/shm"
chmod 1777 "$mnt/tmp" "$mnt/dev/shm" "$mnt/var/cache" || true
ROOT

# Resolve user
ARCH_USER="root"
if su -c "[ -f '$mnt/etc/arch-user.conf' ]"; then
  ARCH_USER="$(su -c "awk -F= '/^ARCH_USER=/{print \$2}' '$mnt/etc/arch-user.conf' | tr -d '\r\n'")"
  [ -n "$ARCH_USER" ] || ARCH_USER="root"
fi

# Enter chroot
exec su -c "$BB chroot '$mnt' /bin/su - '$ARCH_USER'"
