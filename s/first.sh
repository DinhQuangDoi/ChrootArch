#!/bin/bash
# first.sh — Runs INSIDE ArchLinuxARM chroot
set -euo pipefail

echo "[*] Initializing pacman keys..."
pacman-key --init
pacman-key --populate archlinuxarm

echo "[*] Updating system..."
pacman -Syu --noconfirm
echo "[*] Installing essentials..."
pacman -S --noconfirm sudo vim nano base-devel

echo
read -rp "→ Nhập tên người dùng mới: " NEWUSER
useradd -m -G wheel -s /bin/bash "$NEWUSER"
echo "[*] Đặt mật khẩu cho $NEWUSER:"
passwd "$NEWUSER"

echo "$NEWUSER" > /etc/arch-user.conf

echo "[*] Bật quyền sudo cho nhóm wheel..."
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/00-wheel
chmod 440 /etc/sudoers.d/00-wheel

echo
echo "[✓] Thiết lập hoàn tất!"
echo "Từ giờ dùng: start (CLI) hoặc startx (GUI, nếu cài XFCE sau)."
