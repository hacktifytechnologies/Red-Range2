#!/bin/bash
# Operation BlackVault — M1: aglg-portal  (SQL Injection challenge)
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[*] M1 aglg-portal setup"

# ── dependencies ──────────────────────────────────────────────────────────────
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip python3-venv \
    nmap authbind sqlite3 2>/dev/null

# ── virtualenv + app ──────────────────────────────────────────────────────────
mkdir -p /opt/aglg/portal
python3 -m venv /opt/aglg/portal/venv
/opt/aglg/portal/venv/bin/pip install --quiet flask gunicorn 2>/dev/null

cp -r "$SCRIPT_DIR/app/." /opt/aglg/portal/app/
chown -R www-data:www-data /opt/aglg/portal/

# ── SQLite database seed ───────────────────────────────────────────────────────
DB=/opt/aglg/portal/app/aglg.db
sqlite3 "$DB" <<'SQL'
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL,
    password TEXT NOT NULL,
    role TEXT DEFAULT 'operator'
);
INSERT INTO users (username, password, role) VALUES
    ('admin',       'Adm1n@BlackVault!', 'admin'),
    ('cargo_ops',   'C@rg0Ops2024',      'operator'),
    ('vendor_ops',  'V3nd0r@AGLG',       'vendor');

CREATE TABLE IF NOT EXISTS shipments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tracking_id TEXT,
    origin TEXT,
    destination TEXT,
    status TEXT,
    operator TEXT
);
INSERT INTO shipments (tracking_id, origin, destination, status, operator) VALUES
    ('AGX-20240901-001', 'Dubai, UAE',       'Hamburg, Germany',  'In Transit',   'cargo_ops'),
    ('AGX-20240901-002', 'Singapore',        'Los Angeles, USA',  'Customs Hold', 'cargo_ops'),
    ('AGX-20240901-003', 'Rotterdam, NL',    'Mumbai, India',     'Delivered',    'vendor_ops'),
    ('AGX-20240902-001', 'Jeddah, KSA',     'Karachi, Pakistan', 'Processing',   'cargo_ops'),
    ('AGX-20240902-002', 'Shanghai, China',  'Frankfurt, Germany','In Transit',   'vendor_ops');
SQL

chown www-data:www-data "$DB"
chmod 660 "$DB"

# ── classified flag ────────────────────────────────────────────────────────────
FLAG="FLAG{$(openssl rand -hex 8)_sqli_auth_bypass}"
mkdir -p /opt/aglg/classified
echo "$FLAG" > /opt/aglg/classified/flag1.txt
chmod 600 /opt/aglg/classified/flag1.txt
chown www-data:www-data /opt/aglg/classified/flag1.txt
chmod 701 /opt/aglg/classified

cat > /opt/aglg/classified/hint.txt <<'EOF'
[AGLG INTERNAL — IT OPERATIONS MEMO | CONFIDENTIAL]
Warehouse Inventory Management API is accessible on DMZ network — port 3000 (Node.js).
Default vendor credential: vendor_ops / V3nd0r@AGLG
API endpoint list exposed at /api/docs
Scan 11.0.0.0/8 on port 3000.
EOF
chmod 600 /opt/aglg/classified/hint.txt
chown www-data:www-data /opt/aglg/classified/hint.txt

# ── logging ────────────────────────────────────────────────────────────────────
touch /var/log/aglg_portal.log
chown www-data:www-data /var/log/aglg_portal.log
chmod 644 /var/log/aglg_portal.log

# ── authbind for port 80 ───────────────────────────────────────────────────────
touch /etc/authbind/byport/80
chown www-data:www-data /etc/authbind/byport/80
chmod 755 /etc/authbind/byport/80

# ── systemd service ────────────────────────────────────────────────────────────
cat > /etc/systemd/system/aglg-portal.service <<'UNIT'
[Unit]
Description=AGLG Cargo Tracking Portal
After=network.target
[Service]
User=www-data
WorkingDirectory=/opt/aglg/portal/app
ExecStart=/usr/bin/authbind --deep /opt/aglg/portal/venv/bin/gunicorn \
    --worker-tmp-dir /tmp -w 2 -b 0.0.0.0:80 \
    --access-logfile /var/log/aglg_portal.log app:app
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload && systemctl enable aglg-portal && systemctl start aglg-portal

echo "========================================" >> /root/ctf_setup_log.txt
echo "M1 (aglg-portal) Flag: $FLAG"            >> /root/ctf_setup_log.txt
echo "Setup: $(date)"                           >> /root/ctf_setup_log.txt
echo "[ok] M1 done — port 80"
