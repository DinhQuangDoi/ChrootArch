#!/data/data/com.termux/files/usr/bin/bash
# get.sh — Download & unpack ArchLinuxARM, then apply fixes and run first boot
set -euo pipefail

ARCHROOT="/data/local/tmp/arch"
PREFIX="/data/data/com.termux/files/usr"
ROOTFS_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
ROOTFS_TAR="/data/local/tmp/arch-rootfs.tar.gz"
RAW="https://raw.githubusercontent.com/DinhQuangDoi/ChrootArch/main/s"

msg(){ echo -e "\033[1;96m[*]\033[0m $*"; }
ok(){  echo -e "\033[1;92m[✓]\033[0m $*"; }
die(){ echo -e "\033[1;91m[!]\033[0m $*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }

need curl; need su; need tar

# 1) Prepare rootfs dir
msg "Prepare ${ARCHROOT}..."
su -c "mkdir -p '${ARCHROOT}' && chmod 755 '${ARCHROOT}'" || die "Cannot create ${ARCHROOT}"

# 2) Download rootfs if missing
if ! su -c "[ -s '${ROOTFS_TAR}' ]"; then
  msg "Downloading ArchLinuxARM rootfs (~500MB)..."
  curl -fL "$ROOTFS_URL" -o "$ROOTFS_TAR"
else
  msg "Found existing rootfs archive — skip download."
fi

# 3) Extract rootfs if not yet extracted
if ! su -c "[ -x '${ARCHROOT}/bin/bash' ]"; then
  msg "Extracting rootfs..."
  su -c "'${PREFIX}/bin/tar' -xzf '${ROOTFS_TAR}' -C '${ARCHROOT}'"
else
  msg "Rootfs already extracted — skip."
fi

# 4) Create essential dirs (as per masterdroid)
msg "Create aux directories..."
su -c "mkdir -p '${ARCHROOT}/media/sdcard' '${ARCHROOT}/dev/shm' '${ARCHROOT}/var/cache' '${ARCHROOT}/tmp'"

# 5) Download helper scripts locally then move into place
TMPD="${PREFIX}/tmp/chrootarch.$$"
mkdir -p "$TMPD"
for f in networkfix.sh pacmanfix.sh first.sh launcher.sh; do
  curl -fsSL "${RAW}/${f}" -o "${TMPD}/${f}"
done
su -c "mkdir -p '${ARCHROOT}/root'"
su -c "mv -f '${TMPD}/first.sh' '${ARCHROOT}/root/first.sh' && chmod 755 '${ARCHROOT}/root/first.sh'"
su -c "mv -f '${TMPD}/networkfix.sh' '${ARCHROOT}/root/networkfix.sh' && chmod 755 '${ARCHROOT}/root/networkfix.sh'"
su -c "mv -f '${TMPD}/pacmanfix.sh' '${ARCHROOT}/root/pacmanfix.sh' && chmod 755 '${ARCHROOT}/root/pacmanfix.sh'"

# 6) Create Termux launcher(s)
msg "Install Termux launcher(s)..."
mkdir -p "${PREFIX}/bin"
mv -f "${TMPD}/launcher.sh" "${PREFIX}/bin/start-arch"
chmod 755 "${PREFIX}/bin/start-arch"

# 7) Minimal mounts for running fixes & first boot
msg "Bind minimal mounts..."
su -c "mkdir -p '${ARCHROOT}/proc' '${ARCHROOT}/sys' '${ARCHROOT}/dev' '${ARCHROOT}/dev/pts'"
su -c "mountpoint -q '${ARCHROOT}/proc' || mount -t proc  proc  '${ARCHROOT}/proc'"
su -c "mountpoint -q '${ARCHROOT}/sys'  || mount -t sysfs sysfs '${ARCHROOT}/sys'"
su -c "mountpoint -q '${ARCHROOT}/dev'  || mount -o bind /dev '${ARCHROOT}/dev'"
su -c "mountpoint -q '${ARCHROOT}/dev/pts' || mount -t devpts devpts '${ARCHROOT}/dev/pts'"

# 8) Network+Pacman fixes (run inside chroot, non-interactive)
msg "Apply network fix inside chroot..."
su -c "busybox chroot '${ARCHROOT}' /bin/bash -lc '/root/networkfix.sh'"

msg "Apply pacman fix inside chroot (CheckSpace, AID, gnupg)..."
su -c "busybox chroot '${ARCHROOT}' /bin/bash -lc '/root/pacmanfix.sh'"

# 9) First boot (interactive for user create, etc.)
msg "Run first boot (interactive)..."
su -c "busybox chroot '${ARCHROOT}' /bin/bash -lc '/root/first.sh'"

ok "Install finished!"
echo "• Use 'start-arch' to enter Arch chroot (CLI)."
