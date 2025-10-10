#!/bin/bash
# networkfix.sh — Write basic network files and ARM mirrorlist
set -euo pipefail

echo -e "\033[1;96m[*]\033[0m Writing /etc/resolv.conf and /etc/hosts..."
cat > /etc/resolv.conf <<'EOF'
# DNS
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF

cat > /etc/hosts <<'EOF'
127.0.0.1 localhost
::1 localhost
EOF

echo -e "\033[1;96m[*]\033[0m Writing ARM mirrorlist (HTTPS first)..."
mkdir -p /etc/pacman.d
cat > /etc/pacman.d/mirrorlist <<'EOF'
Server = https://mirror.archlinuxarm.org/$arch/$repo
Server = https://sg.mirror.archlinuxarm.org/$arch/$repo
Server = https://us.mirror.archlinuxarm.org/$arch/$repo
Server = https://de.mirror.archlinuxarm.org/$arch/$repo
EOF

echo -e "\033[1;92m[✓]\033[0m Network seed complete."
