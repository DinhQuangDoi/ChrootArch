#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ARCH_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
ROOT_TMP="/data/local/tmp"
ARCHROOT="${ROOT_TMP}/arch"
ARCH_TAR="${ROOT_TMP}/arch-rootfs.tar.gz"
PREFIX="/data/data/com.termux/files/usr"

CURL_BIN="${PREFIX}/bin/curl"
TAR_BIN="${PREFIX}/bin/tar"
MV_BIN="${PREFIX}/bin/mv"
MKDIR_BIN="${PREFIX}/bin/mkdir"
CAT_BIN="${PREFIX}/bin/cat"
STAT_BIN="${PREFIX}/bin/stat"   # dùng stat của Termux để đo kích thước

# 0) Ensure base dir
su -c "${MKDIR_BIN} -p '${ROOT_TMP}'"

# 1) Download/check rootfs (tiếp tục tải nếu bị ngắt)
if [ -f "${ARCH_TAR}" ]; then
  size="$(${STAT_BIN} -c%s "${ARCH_TAR}" 2>/dev/null || echo 0)"
  if [ "${size}" -gt 300000000 ]; then
    echo "[✓] Found existing rootfs (~$((size/1024/1024)) MB), skip download."
  else
    echo "[!] Incomplete rootfs ($((size/1024/1024)) MB) → resume download…"
    su -c "'${CURL_BIN}' -C - -L '${ARCH_URL}' -o '${ARCH_TAR}'"
  fi
else
  echo "[i] Downloading rootfs…"
  su -c "'${CURL_BIN}' -L '${ARCH_URL}' -o '${ARCH_TAR}'"
fi

# 2) Extract rootfs
su -c "${MKDIR_BIN} -p '${ARCHROOT}'"
echo "[i] Extracting to ${ARCHROOT}…"
su -c "'${TAR_BIN}' -xzf '${ARCH_TAR}' -C '${ARCHROOT}'"

# 3) Create subfolders (bao gồm var/cache để tmpfs mount về sau)
su -c "${MKDIR_BIN} -p '${ARCHROOT}/media' '${ARCHROOT}/media/sdcard' '${ARCHROOT}/dev/shm' '${ARCHROOT}/var/cache'"

# 4) Create resolv.conf -> etc/resolv.conf
su -c "'${MKDIR_BIN}' -p '${ARCHROOT}/etc'"
su -c "'${CAT_BIN}' > '${ROOT_TMP}/resolv.conf' <<'EOF_RESOLV'
# Content
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF_RESOLV"
su -c "'${MV_BIN}' -vf '${ROOT_TMP}/resolv.conf' '${ARCHROOT}/etc/resolv.conf'"

# 5) Create hosts -> etc/hosts
su -c "'${CAT_BIN}' > '${ROOT_TMP}/hosts' <<'EOF_HOSTS'
# Content
127.0.0.1 localhost
EOF_HOSTS"
su -c "'${MV_BIN}' -vf '${ROOT_TMP}/hosts' '${ARCHROOT}/etc/hosts'"

echo "[✓] Arch rootfs setup complete! Path: ${ARCHROOT}"
