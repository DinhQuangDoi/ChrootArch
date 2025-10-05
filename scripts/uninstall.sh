#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ARCHROOT="/data/local/tmp/arch"
ARCH_TAR="/data/local/tmp/arch-rootfs.tar.gz"
LAUNCHERS="$HOME/.local/bin"

echo "=== 🧹 Uninstall Chroot Arch (safe) ==="

# 1) Dừng tiến trình liên quan (Termux-side)
pkill -f com.termux.x11 || true
pkill -f termux-x11 || true
pkill -f Xwayland || true
pkill -f pulseaudio || true
pkill -f virgl_test_server_android || true

# 2) Gỡ mount CHỈ dưới ${ARCHROOT}, theo thứ tự ngược (an toàn)
su -c "sh -s" <<'ROOT'
set -eu
mnt="/data/local/tmp/arch"
BB="$(command -v busybox || echo /data/adb/ksu/bin/busybox || echo /system/bin/busybox || echo busybox)"

# chỉ lấy các mount có đường dẫn bắt đầu bằng "$mnt/"
awk '$2 ~ /^\/data\/local\/tmp\/arch\// {print $2}' /proc/mounts \
  | sort -r \
  | while read -r mp; do
      $BB umount "$mp" 2>/dev/null || $BB umount -l "$mp" 2>/dev/null || true
    done

# cuối cùng thử các điểm chính (nếu còn)
for mp in "$mnt/dev/pts" "$mnt/dev" "$mnt/proc" "$mnt/sys"; do
  $BB umount "$mp" 2>/dev/null || $BB umount -l "$mp" 2>/dev/null || true
done
ROOT

# 3) Xóa rootfs + tarball
su -c "rm -rf '${ARCHROOT}'" || true
su -c "rm -f '${ARCH_TAR}'" || true

# 4) Xóa launchers & cache
rm -f "${LAUNCHERS}/start-arch" "${LAUNCHERS}/start-arch-x11" 2>/dev/null || true
rm -rf "$HOME/.local/share/arch-chroot" 2>/dev/null || true
rm -f  "$PREFIX/bin/start-arch" "$PREFIX/bin/start-arch-x11" 2>/dev/null || true

echo "[✓] Uninstall done."
echo "Nếu bộ nhớ trong chưa hiện lại, vui lòng REBOOT."
