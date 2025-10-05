#!/bin/bash
# /root/firstboot-arch.sh
set -euo pipefail
clear
echo -e "\n=== Chroot Arch ===\n"

# --- 0) Chặn chạy lại nếu đã thiết lập ---
if [ -f /etc/arch-user.conf ]; then
  echo "[i] First-boot seems completed. /etc/arch-user.conf exists."
  echo "[i] To re-run, remove that file then run this script again."
  exit 0
fi

# --- Helper nhỏ ---
prompt_default() { # $1=message  $2=default
  read -rp "$1 [$2]: " _ans; echo "${_ans:-$2}"
}

# --- 1) Pacman chuẩn bị khoá & đồng bộ DB (ARM) ---
if command -v pacman >/dev/null 2>&1; then
  echo "[*] Initializing pacman keyring…"
  pacman-key --init || true
  pacman-key --populate archlinuxarm || true
  echo "[*] Sync package databases…"
  pacman -Sy --noconfirm
else
  echo "[!] pacman not found—are you inside a valid Arch Linux ARM rootfs?"
  exit 1
fi

# --- 2) Hỏi thông tin cơ bản ---
DEF_USER="root"
USER_NAME="$(prompt_default 'New username' "$DEF_USER")"

while true; do
  read -srp "Password for ${USER_NAME}: " P1; echo
  read -srp "Re-enter password: " P2; echo
  [ "$P1" = "$P2" ] && break || echo "Passwords do not match. Try again."
done

read -srp "Root password (empty = skip): " RPW; echo

DEF_TZ="Asia/Ho_Chi_Minh"
TZ_CHOICE="$(prompt_default 'Timezone (Region/City)' "$DEF_TZ")"

DEF_LANG="en_US.UTF-8"
DEF_LANG2="vi_VN.UTF-8"
LANG_CHOICE="$(prompt_default 'Primary locale (UTF-8)' "$DEF_LANG")"
LANG2_CHOICE="$(prompt_default 'Secondary locale (UTF-8)' "$DEF_LANG2")"

# --- 3) Tạo user + sudo cơ bản ---
echo "[*] Installing sudo & basics…"
pacman -S --noconfirm --needed sudo bash-completion which

if ! id "$USER_NAME" >/dev/null 2>&1; then
  useradd -m -G wheel -s /bin/bash "$USER_NAME"
fi
echo "${USER_NAME}:${P1}" | chpasswd
[ -n "${RPW}" ] && echo "root:${RPW}" | chpasswd || true

# Cho wheel sudo
if ! grep -qE '^\s*%wheel\s+ALL=\(ALL(:ALL)?\)\s+ALL' /etc/sudoers; then
  echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers
fi

# --- 4) Timezone + Locale ---
if [ -f "/usr/share/zoneinfo/${TZ_CHOICE}" ]; then
  ln -sf "/usr/share/zoneinfo/${TZ_CHOICE}" /etc/localtime
  hwclock --systohc --utc || true
else
  echo "[!] Timezone '${TZ_CHOICE}' not found; skipping link."
fi

# Bật 2 locale (nếu có trong /etc/locale.gen)
sed -i "s/^#\s*${LANG_CHOICE//\//\\/}\s\+UTF-8/${LANG_CHOICE} UTF-8/" /etc/locale.gen || true
sed -i "s/^#\s*${LANG2_CHOICE//\//\\/}\s\+UTF-8/${LANG2_CHOICE} UTF-8/" /etc/locale.gen || true
locale-gen
cat >/etc/locale.conf <<EOF
LANG=${LANG_CHOICE}
LC_ALL=
EOF

# --- 5) Cấu hình bridge Termux-X11 (giữ tối giản, bạn có thể sửa thêm) ---
install -d -m 755 /etc/profile.d
cat >/etc/profile.d/zzz-android-bridge.sh <<'EOP'
export DISPLAY=:0
export PULSE_SERVER=127.0.0.1
export XDG_RUNTIME_DIR=/run/termux-tmp
export QT_QPA_PLATFORM=xcb
: "${GDK_SCALE:=1}"
: "${GDK_DPI_SCALE:=1.0}"
export GDK_SCALE GDK_DPI_SCALE
EOP

# --- 6) (Tùy chọn) Autostart XFCE khi có DISPLAY ---
# Bạn có thể tắt nếu không muốn.
if ! grep -q 'startxfce4' "/home/${USER_NAME}/.bash_profile" 2>/dev/null; then
  install -d -m 755 "/home/${USER_NAME}"
  cat >>"/home/${USER_NAME}/.bash_profile" <<'EOBP'
if [ -n "$DISPLAY" ] && ! pgrep -x xfce4-session >/dev/null 2>&1; then
  nohup startxfce4 >/tmp/xfce.log 2>&1 &
fi
EOBP
  chown -R "${USER_NAME}:${USER_NAME}" "/home/${USER_NAME}"
fi

# --- 7) Lưu username để start script ngoài Android đọc ---
echo "ARCH_USER=${USER_NAME}" > /etc/arch-user.conf

echo -e "\n[✓] Config DONE."
echo "User: ${USER_NAME}"
echo "Locale: ${LANG_CHOICE} (+ ${LANG2_CHOICE})"
echo "Timezone: ${TZ_CHOICE}"
echo "Config saved: /etc/arch-user.conf"
