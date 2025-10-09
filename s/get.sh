#!/data/data/com.termux/files/usr/bin/bash
# get.sh — Setup rootfs + inject tools
set -euo pipefail

ARCHROOT="/data/local/tmp/arch"
PREFIX="/data/data/com.termux/files/usr"
ROOTFS_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
ROOTFS_TAR="/data/local/tmp/arch-rootfs.tar.gz"
RAW="https://raw.githubusercontent.com/DinhQuangDoi/ChrootArch/main/s"

msg(){ echo -e "\033[1;96m[*]\033[0m $*"; }

need(){ command -v "$1" >/dev/null 2>&1 || { echo "[!] Missing $1"; exit 1; }; }
need curl; need tar; need su

mkdir -p "$ARCHROOT"
if [ ! -s "$ROOTFS_TAR" ]; then
  msg "Downloading ArchLinuxARM rootfs..."
  curl -fL "$ROOTFS_URL" -o "$ROOTFS_TAR"
else
  msg "Found existing rootfs archive, skipping download."
fi

if [ ! -x "$ARCHROOT/bin/bash" ]; then
  msg "Extracting rootfs..."
  su -c "$PREFIX/bin/tar -xzf '$ROOTFS_TAR' -C '$ARCHROOT'"
fi

msg "Injecting setup files..."
su -c "mkdir -p '$ARCHROOT/root'"
for f in first.sh launch.sh; do
  curl -fsSL "$RAW/$f" -o "/data/local/tmp/$f"
  su -c "mv /data/local/tmp/$f '$ARCHROOT/root/$f'"
  su -c "chmod 755 '$ARCHROOT/root/$f'"
done

msg "Creating /etc/resolv.conf & hosts..."
su -c "echo 'nameserver 8.8.8.8' > '$ARCHROOT/etc/resolv.conf'"
su -c "echo '127.0.0.1 localhost' > '$ARCHROOT/etc/hosts'"

msg "Creating Termux launchers..."
mkdir -p "$PREFIX/bin"
curl -fsSL "$RAW/launch.sh" -o "$PREFIX/bin/start"
chmod 755 "$PREFIX/bin/start"

msg "Launching first boot setup..."
su -c "busybox chroot '$ARCHROOT' /bin/bash /root/first.sh"

msg "✅ Installation finished. Use 'start' to enter Arch."
