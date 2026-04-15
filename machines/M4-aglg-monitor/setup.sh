#!/bin/bash
# Operation BlackVault — M4: aglg-monitor  (OS Command Injection)
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[*] M4 aglg-monitor setup"

# ── dependencies ──────────────────────────────────────────────────────────────
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip python3-venv \
    nmap net-tools iputils-ping traceroute openssh-server 2>/dev/null

# ── create operator user ───────────────────────────────────────────────────────
id netops &>/dev/null || useradd -m -s /bin/bash netops
echo "netops:N3t0ps@Mon1t0r" | chpasswd
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh 2>/dev/null || true

# ── virtualenv + app ──────────────────────────────────────────────────────────
mkdir -p /opt/aglg/monitor
python3 -m venv /opt/aglg/monitor/venv
/opt/aglg/monitor/venv/bin/pip install --quiet flask gunicorn 2>/dev/null

cp -r "$SCRIPT_DIR/app/." /opt/aglg/monitor/app/
chown -R netops:netops /opt/aglg/monitor/

# ── flag ───────────────────────────────────────────────────────────────────────
FLAG="FLAG{$(openssl rand -hex 8)_cmdi_netops}"
echo "$FLAG" > /opt/aglg/flag4.txt
chmod 644 /opt/aglg/flag4.txt

cat > /opt/aglg/hint_m5.txt <<'EOF'
[AGLG INTERNAL — VAULT OPERATIONS MEMO]
Classified document vault deployed on private network — port 8443 (Go HTTP).
Archivist credential: archivist / Arch1v1st@AGLG
SSH access available on port 22.
Scan 195.0.0.0/8 on port 8443.
EOF
chmod 644 /opt/aglg/hint_m5.txt

# ── systemd service ────────────────────────────────────────────────────────────
cat > /etc/systemd/system/aglg-monitor.service <<'UNIT'
[Unit]
Description=AGLG Infrastructure Monitoring Dashboard
After=network.target
[Service]
User=netops
WorkingDirectory=/opt/aglg/monitor/app
ExecStart=/opt/aglg/monitor/venv/bin/gunicorn -w 2 -b 0.0.0.0:5000 \
    --access-logfile /var/log/aglg_monitor.log app:app
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
UNIT

touch /var/log/aglg_monitor.log
chown netops:netops /var/log/aglg_monitor.log
chmod 644 /var/log/aglg_monitor.log

systemctl daemon-reload && systemctl enable aglg-monitor && systemctl start aglg-monitor

echo "========================================" >> /root/ctf_setup_log.txt
echo "M4 (aglg-monitor) Flag: $FLAG"           >> /root/ctf_setup_log.txt
echo "Setup: $(date)"                           >> /root/ctf_setup_log.txt
echo "[ok] M4 done — port 5000"
