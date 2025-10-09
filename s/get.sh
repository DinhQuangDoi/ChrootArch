#!/data/data/com.termux/files/usr/bin/bash
# get.sh — Setup ArchLinuxARM chroot automatically
set -euo pipefail

ARCHROOT="/data/local/tmp/arch"
PREFIX="/data/data/com.termux/files/usr"
ROOTFS_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
ROOTFS_TAR="/data/local/tmp/arch-rootfs.tar.gz"
RAW="https://raw.githubusercontent.com/DinhQuangDoi/ChrootArch/main/s"

msg() { echo -e "\033[1;96m[*]\033[0m $*"; }
need() { command -v "$1" >/dev/null 2>&1 || { echo "[!] Missing $1"; exit 1; }; }

need curl
need tar
need su

# Prepare rootfs dir with root
msg "Preparing /data/local/tmp/arch ..."
su -c "mkdir -p '$ARCHROOT' && chmod 755 '$ARCHROOT'" || {
  echo "[!] Failed to create $ARCHROOT (check root access)"; exit 1;
}

# Download rootfs if missing
if [ ! -s "$ROOTFS_TAR" ]; then
  msg "Downloading ArchLinuxARM rootfs (≈ 500 MB)..."
  curl -fL "$ROOTFS_URL" -o "$ROOTFS_TAR"
else
  msg "Found existing rootfs archive — skipping download."
fi

# Extract rootfs once
if ! su -c "[ -x '$ARCHROOT/bin/bash' ]"; then
  msg "Extracting rootfs (requires root)..."
  su -c "$PREFIX/bin/tar -xzf '$ROOTFS_TAR' -C '$ARCHROOT'"
else
  msg "Rootfs already extracted — skipping."
fi

# Seed network files via temp in PREFIX/tmp, then mv as root
msg "Configuring basic network files..."
su -c "mkdir -p '$ARCHROOT/etc'"

TMPDIR="$PREFIX/tmp"
mkdir -p "$TMPDIR"

cat > "$TMPDIR/resolv.conf" <<'EOF_RESOLV'
# Content
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF_RESOLV

cat > "$TMPDIR/hosts" <<'EOF_HOSTS'
# Content
127.0.0.1 localhost
EOF_HOSTS

su -c "mv -vf '$TMPDIR/resolv.conf' '$ARCHROOT/etc/resolv.conf'"
su -c "mv -vf '$TMPDIR/hosts' '$ARCHROOT/etc/hosts'"

# Inject setup scripts safely (download to $PREFIX/tmp first)
msg "Injecting setup scripts..."
su -c "mkdir -p '$ARCHROOT/root'"

TMP_SCRIPT_DIR="$PREFIX/tmp/scripts"
mkdir -p "$TMP_SCRIPT_DIR"

for f in first.sh launch.sh; do
  FILE_PATH="$TMP_SCRIPT_DIR/$f"
  curl -fL "$RAW/$f" -o "$FILE_PATH" || { echo "[!] Failed to download $f"; exit 1; }
  su -c "mv -f '$FILE_PATH' '$ARCHROOT/root/$f' && chmod 755 '$ARCHROOT/root/$f'"
done

# Create Termux launcher
msg "Creating Termux launcher..."
mkdir -p "$PREFIX/bin"
curl -fsSL "$RAW/launch.sh" -o "$PREFIX/bin/start"
chmod 755 "$PREFIX/bin/start"

# Run first boot setup inside chroot
msg "Running first boot setup (inside chroot)..."
su -c "busybox chroot '$ARCHROOT' /bin/bash /root/first.sh"

msg "Installation finished!"
echo
echo "Use 'start' to enter Arch chroot."
