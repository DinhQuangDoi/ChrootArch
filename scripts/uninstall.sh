#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ARCHROOT="/data/local/tmp/arch"
ARCH_TAR="/data/local/tmp/arch-rootfs.tar.gz"
LAUNCHERS="$HOME/.local/bin"

echo "=== 🧹 Uninstall Chroot Arch ==="

# 1️⃣ Dừng tất cả tiến trình liên quan
echo "[*] Killing related processes..."
pkill -f termux-x11 || true
pkill -f Xwayland || true
pkill -f pulseaudio || true
pkill -f virgl_test_server_android || true

# 2️⃣ Gỡ mount bind nếu còn tồn tại
echo "[*] Unmounting bind mounts..."
su -c "umount -lf ${ARCHROOT}/proc || true"
su -c "umount -lf ${ARCHROOT}/sys || true"
su -c "umount -lf ${ARCHROOT}/dev/pts || true"
su -c "umount -lf ${ARCHROOT}/dev || true"
su -c "umount -lf ${ARCHROOT}/media/sdcard || true"
su -c "umount -lf ${ARCHROOT}/var/cache || true"
su -c "umount -lf ${ARCHROOT}/dev/shm || true"

# 3️⃣ Xoá toàn bộ rootfs và file tar
echo "[*] Removing rootfs and tarball..."
su -c "rm -rf ${ARCHROOT} || true"
su -c "rm -f ${ARCH_TAR} || true"

# 4️⃣ Xoá launcher đã tạo
echo "[*] Removing launcher scripts..."
rm -f "${LAUNCHERS}/start-arch" || true
rm -f "${LAUNCHERS}/start-arch-x11" || true

# 5️⃣ Xoá cache script nếu có
echo "[*] Removing cached scripts..."
rm -rf "$HOME/.local/share/arch-chroot" || true

echo "[✓] Uninstall complete!"
echo "➡️  Bạn có thể chạy lại quá trình cài đặt bằng lệnh:"
echo "    curl -fsSL https://raw.githubusercontent.com/DinhQuangDoi/ChrootArch/main/install.sh | bash"
