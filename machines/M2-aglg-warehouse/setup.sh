#!/bin/bash
# Operation BlackVault — M2: aglg-warehouse  (IDOR / Broken Access Control)
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[*] M2 aglg-warehouse setup"

# ── dependencies ──────────────────────────────────────────────────────────────
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs npm nmap 2>/dev/null
npm install -g pm2 2>/dev/null

# ── app deployment ─────────────────────────────────────────────────────────────
mkdir -p /opt/aglg/warehouse
cp -r "$SCRIPT_DIR/app/." /opt/aglg/warehouse/
cd /opt/aglg/warehouse && npm install --silent 2>/dev/null
useradd -r -s /bin/false warehousesvc 2>/dev/null || true
chown -R warehousesvc:warehousesvc /opt/aglg/warehouse/

# ── flag ───────────────────────────────────────────────────────────────────────
FLAG="FLAG{$(openssl rand -hex 8)_idor_bac}"
mkdir -p /opt/aglg
echo "$FLAG" > /opt/aglg/flag2.txt
chmod 600 /opt/aglg/flag2.txt

# Inject flag and next-hop creds into the running app's data store
# The app reads FLAG2 and credentials from environment on start
sed -i "s|FLAG2_PLACEHOLDER|$FLAG|g" /opt/aglg/warehouse/server.js
sed -i "s|CRED_M3_PLACEHOLDER|hr_ops : HR0ps@AGLG24|g" /opt/aglg/warehouse/server.js

# ── systemd service ────────────────────────────────────────────────────────────
cat > /etc/systemd/system/aglg-warehouse.service <<'UNIT'
[Unit]
Description=AGLG Warehouse Inventory API
After=network.target
[Service]
User=warehousesvc
WorkingDirectory=/opt/aglg/warehouse
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=3
Environment=PORT=3000 NODE_ENV=production
[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload && systemctl enable aglg-warehouse && systemctl start aglg-warehouse

echo "========================================" >> /root/ctf_setup_log.txt
echo "M2 (aglg-warehouse) Flag: $FLAG"         >> /root/ctf_setup_log.txt
echo "Setup: $(date)"                           >> /root/ctf_setup_log.txt
echo "[ok] M2 done — port 3000"
