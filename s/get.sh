#!/data/data/com.termux/files/usr/bin/bash
# get.sh — Setup ArchLinuxARM chroot automatically (with network fix)
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

# Prepare rootfs dir (as root)
msg "Preparing ${ARCHROOT} ..."
su -c "mkdir -p '${ARCHROOT}' && chmod 755 '${ARCHROOT}'" || {
  echo "[!] Failed to create ${ARCHROOT} (check root access)"; exit 1;
}

# Download rootfs if missing
if [ ! -s "$ROOTFS_TAR" ]; then
  msg "Downloading ArchLinuxARM rootfs (≈ 500 MB)..."
  curl -fL "$ROOTFS_URL" -o "$ROOTFS_TAR"
else
  msg "Found existing rootfs archive — skipping download."
fi

# Extract once (as root)
if ! su -c "[ -x '${ARCHROOT}/bin/bash' ]"; then
  msg "Extracting rootfs (requires root)..."
  su -c "'${PREFIX}/bin/tar' -xzf '${ROOTFS_TAR}' -C '${ARCHROOT}'"
else
  msg "Rootfs already extracted — skipping."
fi

# Seed network: resolv.conf, hosts, HTTPS mirror; bind /sys/class/net
msg "Configuring basic network inside chroot..."
su -c "mkdir -p '${ARCHROOT}/etc' '${ARCHROOT}/proc' '${ARCHROOT}/sys' '${ARCHROOT}/dev' '${ARCHROOT}/dev/pts' '${ARCHROOT}/sys/class/net'"
# Always bind core mounts once here (first setup)
su -c "mountpoint -q '${ARCHROOT}/proc' || mount -t proc proc '${ARCHROOT}/proc'"
su -c "mountpoint -q '${ARCHROOT}/sys'  || mount -t sysfs sysfs '${ARCHROOT}/sys'"
su -c "mountpoint -q '${ARCHROOT}/dev'  || mount -o bind /dev '${ARCHROOT}/dev'"
su -c "mountpoint -q '${ARCHROOT}/dev/pts' || mount -t devpts devpts '${ARCHROOT}/dev/pts'"
su -c "mountpoint -q '${ARCHROOT}/sys/class/net' || mount --bind /sys/class/net '${ARCHROOT}/sys/class/net'"

TMPDIR="${PREFIX}/tmp"
mkdir -p "$TMPDIR"
cat > "${TMPDIR}/resolv.conf" <<'EOF_RESOLV'
# Content
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF_RESOLV
cat > "${TMPDIR}/hosts" <<'EOF_HOSTS'
# Content
127.0.0.1 localhost
EOF_HOSTS
su -c "mv -vf '${TMPDIR}/resolv.conf' '${ARCHROOT}/etc/resolv.conf'"
su -c "mv -vf '${TMPDIR}/hosts'       '${ARCHROOT}/etc/hosts'"

# Force HTTPS ARM mirrors
su -c "mkdir -p '${ARCHROOT}/etc/pacman.d'"
su -c "bash -lc \"echo 'Server = https://mirror.archlinuxarm.org/\\$arch/\\$repo' > '${ARCHROOT}/etc/pacman.d/mirrorlist'\""
for M in https://sg.mirror.archlinuxarm.org https://us.mirror.archlinuxarm.org https://de.mirror.archlinuxarm.org; do
  su -c "bash -lc \"echo 'Server = ${M}/\\$arch/\\$repo' >> '${ARCHROOT}/etc/pacman.d/mirrorlist'\""
done

# Inject setup scripts (download to PREFIX/tmp, then move as root)
msg "Injecting setup scripts..."
su -c "mkdir -p '${ARCHROOT}/root'"
TMP_SCRIPT_DIR="${PREFIX}/tmp/scripts"
mkdir -p "${TMP_SCRIPT_DIR}"
for f in first.sh launch.sh; do
  curl -fL "${RAW}/${f}" -o "${TMP_SCRIPT_DIR}/${f}"
  su -c "mv -f '${TMP_SCRIPT_DIR}/${f}' '${ARCHROOT}/root/${f}' && chmod 755 '${ARCHROOT}/root/${f}'"
done

# Create Termux launcher(s)
msg "Creating Termux launcher(s)..."
mkdir -p "${PREFIX}/bin"
curl -fL "${RAW}/launch.sh" -o "${PREFIX}/bin/start"
chmod 755 "${PREFIX}/bin/start"

# Smoke test: ping + pacman -Syy (over HTTPS)
msg "Testing network inside chroot (ping)..."
if ! su -c "busybox chroot '${ARCHROOT}' /usr/bin/ping -c1 -W2 8.8.8.8 >/dev/null 2>&1"; then
  echo "[!] Ping failed inside chroot (routing/SELinux may restrict ICMP). Continuing..."
fi

msg "Running first boot setup (inside chroot)..."
su -c "busybox chroot '${ARCHROOT}' /bin/bash /root/first.sh"

echo
echo "[✓] Installation finished!"
echo "Use 'start' to enter Arch chroot."
