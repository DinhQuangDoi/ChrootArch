#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ARCHROOT="/data/local/tmp/arch"
PREFIX="/data/data/com.termux/files/usr"
ROOTFS_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
ROOTFS_TAR="/data/local/tmp/arch-rootfs.tar.gz"
RAW="https://raw.githubusercontent.com/DinhQuangDoi/ChrootArch/main/s"

msg(){ echo -e "\033[1;96m[*]\033[0m $*"; }

need(){ command -v "$1" >/dev/null 2>&1 || { echo "[!] Missing $1"; exit 1; }; }
need curl; need tar; need su

msg "Preparing rootfs path..."
su -c "mkdir -p '$ARCHROOT' || true"
su -c "chmod 755 '$ARCHROOT'"

if [ ! -s "$ROOTFS_TAR" ]; then
  msg "Downloading ArchLinuxARM rootfs..."
  curl -fL "$ROOTFS_URL" -o "$ROOTFS_TAR"
else
  msg "Found existing rootfs archive, skipping download."
fi

if [ ! -x "$ARCHROOT/bin/bash" ]; then
  msg "Extracting rootfs (requires root)..."
  su -c "$PREFIX/bin/tar -xzf '$ROOTFS_TAR' -C '$ARCHROOT'"
else
  msg "Rootfs already extracted, skipping."
fi
