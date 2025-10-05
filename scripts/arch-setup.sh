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
STAT_BIN="${PREFIX}/bin/stat"

# 1) Create path for chroot-arch
su -c "${MKDIR_BIN} -p '${ROOT_TMP}'"

# 📦 Kiểm tra file rootfs đã có chưa
if [ -f "${ARCH_TAR}" ]; then
    size="$(${STAT_BIN} -c%s "${ARCH_TAR}" 2>/dev/null || echo 0)"
    if [ "${size}" -gt 300000000 ]; then
        echo "[✓] Found existing rootfs (~$((size/1024/1024)) MB), skip download."
    else
        echo "[!] Incomplete rootfs ($((size/1024/1024)) MB) → resume download…"
        su -c "'${CURL_BIN}' -C - -L '${ARCH_URL}' -o '${ARCH_TAR}'"
    fi
else
    echo "[i] Downloading rootfs..."
    su -c "'${CURL_BIN}' -L '${ARCH_URL}' -o '${ARCH_TAR}'"
fi

# 2) Extract rootfs (chỉ giải nén nếu chưa có)
if su -c "[ -d '${ARCHROOT}/bin' ] && [ -d '${ARCHROOT}/etc' ]"; then
    echo "[✓] Rootfs already extracted — skipping extraction."
else
    su -c "${MKDIR_BIN} -p '${ARCHROOT}'"
    echo "[i] Extracting rootfs..."
    su -c "'${TAR_BIN}' -xzf '${ARCH_TAR}' -C '${ARCHROOT}'"
fi

# 3) Create subfolders
su -c "${MKDIR_BIN} -p '${ARCHROOT}/media' '${ARCHROOT}/media/sdcard' '${ARCHROOT}/dev/shm' '${ARCHROOT}/var/cache'"

# 4) Create resolv.conf nếu chưa có
su -c "'${MKDIR_BIN}' -p '${ARCHROOT}/etc'"
if su -c "[ -f '${ARCHROOT}/etc/resolv.conf' ]"; then
    echo "[i] resolv.conf already exists — skip."
else
    su -c "'${CAT_BIN}' > '${ROOT_TMP}/resolv.conf' <<'EOF_RESOLV'
# Content
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF_RESOLV"
    su -c "'${MV_BIN}' -vf '${ROOT_TMP}/resolv.conf' '${ARCHROOT}/etc/resolv.conf'"
fi

# 5) Create hosts nếu chưa có
if su -c "[ -f '${ARCHROOT}/etc/hosts' ]"; then
    echo "[i] hosts already exists — skip."
else
    su -c "'${CAT_BIN}' > '${ROOT_TMP}/hosts' <<'EOF_HOSTS'
# Content
127.0.0.1 localhost
EOF_HOSTS"
    su -c "'${MV_BIN}' -vf '${ROOT_TMP}/hosts' '${ARCHROOT}/etc/hosts'"
fi

echo "[✓] Arch rootfs setup complete! Path: ${ARCHROOT}"
