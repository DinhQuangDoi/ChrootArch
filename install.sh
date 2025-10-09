#!/data/data/com.termux/files/usr/bin/bash
# ChrootArch — Minimal Installer
set -euo pipefail
RAW="https://raw.githubusercontent.com/DinhQuangDoi/ChrootArch/main/s"
echo "[*] Downloading bootstrap script..."
curl -fsSL "$RAW/get.sh" -o get.sh
chmod +x get.sh
bash get.sh
