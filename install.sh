#!/data/data/com.termux/files/usr/bin/bash
# ChrootArch — Minimal Installer (RAW entrypoint)
set -euo pipefail

RAW_BASE="https://raw.githubusercontent.com/DinhQuangDoi/ChrootArch/main/s"

echo "[*] Downloading bootstrap script..."
curl -fsSL "$RAW_BASE/get.sh" -o get.sh
chmod +x get.sh
exec bash get.sh
