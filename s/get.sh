#!/data/data/com.termux/files/usr/bin/bash
# get.sh — Setup ArchLinuxARM chroot automatically (with built-in network fix)
set -euo pipefail

ARCHROOT="/data/local/tmp/arch"
PREFIX="/data/data/com.termux/files/usr"
ROOTFS_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
ROOTFS_TAR="/data/local/tmp/arch-rootfs.tar.gz"
RAW="https://raw.githubusercontent.com/DinhQuangDoi/ChrootArch/main/s"

msg() { echo -e "\033[1;96m[*]\033[0m $*"; }
ok()  { echo -e "\033[1;92m[✓]\033[0m $*"; }
err() { echo -e "\033[1;91m[!]\033[0m $*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || err "Missing command: $1"; }

need curl
need tar
need su

# Step 1: Prepare rootfs directory
msg "Preparing ${ARCHROOT} ..."
su -c "mkdir -p '${ARCHROOT}' && chmod 755 '${ARCHROOT}'" || err "Cannot create ${ARCHROOT}"

# Step 2: Download rootfs if missing
if [ ! -s "$ROOTFS_TAR" ]; then
  msg "Downloading ArchLinuxARM rootfs (≈500 MB)..."
  curl -fL "$ROOTFS_URL" -o "$ROOTFS_TAR"
else
  msg "Found existing rootfs archive — skipping download."
fi

# Step 3: Extract rootfs (as root)
if ! su -c "[ -x '${ARCHROOT}/bin/bash' ]"; then
  msg "Extracting rootfs..."
  su -c "'${PREFIX}/bin/tar' -xzf '${ROOTFS_TAR}' -C '${ARCHROOT}'"
else
  msg "Rootfs already extracted — skipping."
fi

# Step 4: Basic network setup inside chroot
msg "Configuring basic network inside chroot..."
su -c "
mkdir -p '${ARCHROOT}/etc' '${ARCHROOT}/proc' '${ARCHROOT}/sys' '${ARCHROOT}/dev' \
         '${ARCHROOT}/dev/pts' '${ARCHROOT}/sys/class/net'
mountpoint -q '${ARCHROOT}/proc' || mount -t proc proc '${ARCHROOT}/proc'
mountpoint -q '${ARCHROOT}/sys'  || mount -t sysfs sysfs '${ARCHROOT}/sys'
mountpoint -q '${ARCHROOT}/dev'  || mount -o bind /dev '${ARCHROOT}/dev'
mountpoint -q '${ARCHROOT}/dev/pts' || mount -t devpts devpts '${ARCHROOT}/dev/pts'
mountpoint -q '${ARCHROOT}/sys/class/net' || mount --bind /sys/class/net '${ARCHROOT}/sys/class/net'
"

# Create temporary network files in Termux then move to Arch
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

# Create HTTPS mirrorlist safely (no variable expansion)
su -c "mkdir -p '${ARCHROOT}/etc/pacman.d'"
su -c "cat > '${ARCHROOT}/etc/pacman.d/mirrorlist' <<'EOF_MIRROR'
Server = https://mirror.archlinuxarm.org/$arch/$repo
Server = https://sg.mirror.archlinuxarm.org/$arch/$repo
Server = https://us.mirror.archlinuxarm.org/$arch/$repo
Server = https://de.mirror.archlinuxarm.org/$arch/$repo
EOF_MIRROR"

# Step 5: Inject setup scripts
msg "Injecting setup scripts..."
su -c "mkdir -p '${ARCHROOT}/root'"
TMP_SCRIPT_DIR="${PREFIX}/tmp/scripts"
mkdir -p "${TMP_SCRIPT_DIR}"

for f in first.sh launch.sh; do
  curl -fL "${RAW}/${f}" -o "${TMP_SCRIPT_DIR}/${f}"
  su -c "mv -f '${TMP_SCRIPT_DIR}/${f}' '${ARCHROOT}/root/${f}' && chmod 755 '${ARCHROOT}/root/${f}'"
done

# Step 6: Create Termux launcher
msg "Creating Termux launcher..."
mkdir -p "${PREFIX}/bin"
curl -fL "${RAW}/launch.sh" -o "${PREFIX}/bin/start"
chmod 755 "${PREFIX}/bin/start"

# Step 7: Quick connectivity test
msg "Testing network inside chroot (ping)..."
if su -c "busybox chroot '${ARCHROOT}' /usr/bin/ping -c1 -W2 8.8.8.8 >/dev/null 2>&1"; then
  ok "Network reachable inside chroot."
else
  echo "[!] Ping failed inside chroot — may be ICMP-blocked. Continue anyway."
fi

# Step 8: First boot (sudo + user setup)
msg "Running first boot setup inside chroot..."
su -c "busybox chroot '${ARCHROOT}' /bin/bash /root/first.sh"

echo
ok "Installation finished!"
echo "Use 'start' to enter Arch chroot."
