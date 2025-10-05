#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ARCH_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
ROOT_TMP="/data/local/tmp"
ARCHROOT="${ROOT_TMP}/arch"
PREFIX="/data/data/com.termux/files/usr"

CURL_BIN="${PREFIX}/bin/curl"
TAR_BIN="${PREFIX}/bin/tar"
MV_BIN="${PREFIX}/bin/mv"
MKDIR_BIN="${PREFIX}/bin/mkdir"
CAT_BIN="${PREFIX}/bin/cat"

# 1) Create path for chroot-arch
su -c "${MKDIR_BIN} -p '${ROOT_TMP}'"
su -c "'${CURL_BIN}' -L '${ARCH_URL}' -o '${ROOT_TMP}/arch-rootfs.tar.gz'"

# 2) Extract rootfs
su -c "${MKDIR_BIN} -p '${ARCHROOT}'"
su -c "'${TAR_BIN}' -xzf '${ROOT_TMP}/arch-rootfs.tar.gz' -C '${ARCHROOT}'"

# 3) Create subfolder
su -c "${MKDIR_BIN} -p '${ARCHROOT}/media' '${ARCHROOT}/media/sdcard' '${ARCHROOT}/dev/shm'"

# 4) Create resolv.conf and paste to etc/resolv.conf
su -c "'${MKDIR_BIN}' -p '${ARCHROOT}/etc'"
su -c "'${CAT_BIN}' > '${ROOT_TMP}/resolv.conf' <<'EOF_RESOLV'
# Content
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF_RESOLV"
su -c "'${MV_BIN}' -vf '${ROOT_TMP}/resolv.conf' '${ARCHROOT}/etc/resolv.conf'"

# 5) Create hosts and paste to etc/hosts
su -c "'${CAT_BIN}' > '${ROOT_TMP}/hosts' <<'EOF_HOSTS'
# Content
127.0.0.1 localhost
EOF_HOSTS"
su -c "'${MV_BIN}' -vf '${ROOT_TMP}/hosts' '${ARCHROOT}/etc/hosts'"

echo "[✓] Arch rootfs setup complete!, path chroot-arch in: ${ARCHROOT}"