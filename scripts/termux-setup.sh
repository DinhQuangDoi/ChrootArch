#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
termux-change-repo
pkg update -y && pkg upgrade -y
pkg install -y x11-repo
pkg install -y root-repo
pkg install -y termux-x11-nightly
pkg install -y tsu
pkg install -y pulseaudio
pkg install -y curl
pkg install -y virglrenderer-android