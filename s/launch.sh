#!/data/data/com.termux/files/usr/bin/bash
# start — launcher for Arch chroot
set -e

mnt="/data/local/tmp/arch"
BB="$(command -v busybox || echo /system/bin/busybox)"
[ -x "$BB" ] || { echo "[!] BusyBox not found"; exit 1; }

# basic mounts
for d in proc sys dev dev/pts; do
  $BB mountpoint -q "$mnt/$d" || su -c "$BB mount -t ${d%/*} ${d%/*} '$mnt/$d'" || true
done

ARCH_USER="$(su -c "$BB cat $mnt/etc/arch-user.conf 2>/dev/null" || echo root)"
su -c "$BB chroot '$mnt' /bin/su - $ARCH_USER"
