#!/usr/bin/env bash
# =============================================================================
#  DECOY SETUP — M5: aglg-vault  (Operation BlackVault / Range 2)
#  Challenge : LFI Path Traversal + SUID vault_reader — Port 8443
#  Network   : v-Priv
#  NEVER TOUCH: Port 8443 (real Go HTTP server, archivist user)
#               Port 22   (SSH, archivist user)
#               /opt/aglg/vault/    (real vault docs)
#               /opt/aglg/vault-app/ (compiled Go binary)
#               /opt/aglg/vault_reader (SUID binary — 4755)
#               /root/flag5.txt (final flag, mode 400)
#  Run as    : sudo bash M5-decoy-aglg-vault.sh
# =============================================================================

set -euo pipefail
LOG="/root/decoy_setup_log_R2M5.txt"
exec > >(tee -a "$LOG") 2>&1

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
section() { echo -e "\n${CYAN}[===] $* [===]${NC}\n"; }

[[ $EUID -ne 0 ]] && { echo "Run as root."; exit 1; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

pkg_install() {
    local to_install=()
    for p in "$@"; do dpkg -s "$p" &>/dev/null || to_install+=("$p"); done
    if [[ ${#to_install[@]} -gt 0 ]]; then apt-get install -y -qq "${to_install[@]}"; fi
}

nginx_prepare() {
    pkg_install nginx
    systemctl stop nginx 2>/dev/null || true
    systemctl reset-failed nginx 2>/dev/null || true
    rm -f /etc/nginx/sites-enabled/default
    rm -f /etc/nginx/conf.d/*.conf 2>/dev/null || true
}

apache_prepare() {
    pkg_install apache2
    systemctl stop apache2 2>/dev/null || true
    systemctl reset-failed apache2 2>/dev/null || true
    a2dissite 000-default 2>/dev/null || true
    a2enmod headers rewrite 2>/dev/null || true
    sed -i '/^Listen 80\s*$/d'  /etc/apache2/ports.conf
    sed -i '/^Listen 443\s*$/d' /etc/apache2/ports.conf
}

# =============================================================================
# PREFLIGHT
# =============================================================================
section "Preflight — Confirming Real Vault Is Intact"

[[ -f /opt/aglg/vault_reader ]] && \
    info "SUID vault_reader present — UNTOUCHED" || \
    warn "vault_reader NOT found — run real M5 setup.sh first"

[[ -f /root/flag5.txt ]] && \
    info "/root/flag5.txt present — UNTOUCHED" || \
    warn "/root/flag5.txt NOT found — run real M5 setup.sh first"

# =============================================================================
# 1. NGINX — Decoy AGLG Cargo Portal (Port 80)
#    A second web surface that looks like an entry point
# =============================================================================
section "Nginx — AGLG Cargo Portal (Port 80)"

nginx_prepare

mkdir -p /var/www/html/cargo-portal/api/shipment
mkdir -p /var/www/html/cargo-portal/api/docs
mkdir -p /var/www/html/cargo-portal/login

cat > /var/www/html/cargo-portal/index.html << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>AGLG — Cargo Operations Portal</title>
  <style>
    *{margin:0;padding:0;box-sizing:border-box}
    body{background:#0a0e1a;color:#c9cdd7;font-family:'Segoe UI',sans-serif}
    header{background:#0f1626;border-bottom:2px solid #0d4f8c;
           padding:14px 28px;display:flex;justify-content:space-between;
           align-items:center}
    .logo-text h1{font-size:.9rem;color:#e2e8f0;letter-spacing:1px}
    .logo-text p{font-size:.68rem;color:#6b7280}
    nav a{color:#94a3b8;font-size:.82rem;margin-left:20px;text-decoration:none}
    nav a:hover{color:#38bdf8}
    .hero{padding:48px 28px;background:linear-gradient(135deg,#0f1626 0%,#0a1929 100%);
          border-bottom:1px solid #1a2035}
    .hero h2{font-size:1.8rem;color:#e2e8f0;margin-bottom:12px}
    .hero p{color:#6b7280;font-size:.95rem;max-width:600px;line-height:1.6}
    .cta{display:inline-block;margin-top:20px;padding:12px 24px;
         background:#0d4f8c;color:#fff;text-decoration:none;
         border-radius:4px;font-weight:600}
    .grid{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;padding:28px}
    .card{background:#0f1626;border:1px solid #1e2845;border-radius:6px;padding:20px;
          text-align:center}
    .card .num{font-size:1.8rem;font-weight:300;color:#38bdf8;margin:8px 0}
    .card p{font-size:.78rem;color:#6b7280}
    footer{text-align:center;padding:14px;font-size:.7rem;color:#3a4a5a;
           border-top:1px solid #1e2845}
  </style>
</head>
<body>
<header>
  <div class="logo-text">
    <h1>ARKANIS GLOBAL LOGISTICS — CARGO OPERATIONS</h1>
    <p>Internal Cargo Portal — Private Network Access Only</p>
  </div>
  <nav>
    <a href="/login/">Operator Login</a>
    <a href="/api/docs/endpoints">API Docs</a>
    <a href="/api/shipment/status">Status</a>
  </nav>
</header>
<div class="hero">
  <h2>Cargo Operations Command Centre</h2>
  <p>Manage active shipments, clearance queues, and freight schedules
     across all 47 AGLG operational regions.</p>
  <a href="/login/" class="cta">Operator Sign In</a>
</div>
<div class="grid">
  <div class="card">
    <div class="num">1,847</div>
    <p>Active Shipments</p>
  </div>
  <div class="card">
    <div class="num">23</div>
    <p>Customs Holds</p>
  </div>
  <div class="card">
    <div class="num">47</div>
    <p>Countries</p>
  </div>
  <div class="card">
    <div class="num">99.7%</div>
    <p>Service Uptime</p>
  </div>
</div>
<footer>AGLG Cargo Operations — Internal Network — cargo-ops@aglg-logistics.com</footer>
</body>
</html>
HTML

cat > /var/www/html/cargo-portal/login/index.html << 'HTML'
<!DOCTYPE html><html><head><title>AGLG Cargo Ops — Login</title>
<style>body{background:#0a0e1a;display:flex;justify-content:center;
  align-items:center;height:100vh;margin:0;font-family:sans-serif}
.box{background:#0f1626;border:1px solid #1e2845;padding:40px;
     width:360px;border-radius:6px}
h2{color:#e2e8f0;margin-bottom:4px}p{color:#6b7280;font-size:.85rem;margin-bottom:24px}
input{width:100%;padding:10px;background:#0a0e1a;border:1px solid #1e2845;
      color:#c9cdd7;border-radius:4px;margin:6px 0;box-sizing:border-box}
button{width:100%;padding:10px;background:#0d4f8c;border:none;color:#fff;
       border-radius:4px;cursor:pointer;font-weight:600;margin-top:8px}
small{display:block;text-align:center;margin-top:14px;color:#444;font-size:.75rem}
</style></head><body>
<div class="box">
  <h2>Cargo Ops Portal</h2>
  <p>Internal operator access — private network only</p>
  <input type="text" placeholder="Operator Username">
  <input type="password" placeholder="Access Code">
  <button>Authenticate</button>
  <small>All logins are audited. Unauthorized access is prohibited.</small>
</div></body></html>
HTML

cat > /var/www/html/cargo-portal/api/shipment/status << 'JSON'
{"service":"cargo-ops-api","version":"3.2.0","status":"operational",
 "active_shipments":1847,"clearance_queue":23}
JSON

cat > /var/www/html/cargo-portal/api/docs/endpoints << 'JSON'
{
  "api": "AGLG Cargo Operations API",
  "version": "3.2.0",
  "endpoints": [
    "POST /api/auth/login",
    "GET  /api/shipment/status",
    "GET  /api/shipment/list   (auth)",
    "POST /api/shipment/update (auth)",
    "GET  /api/docs/endpoints"
  ],
  "auth": "Bearer token — contact ops-it@aglg-logistics.com"
}
JSON

cat > /etc/nginx/sites-available/cargo-portal << 'NGINX'
server {
    listen 80 default_server;
    root /var/www/html/cargo-portal;
    index index.html;
    server_name _;
    add_header X-Powered-By "AGLG-CargoOps/3.2" always;
    location /api/ {
        default_type application/json;
        try_files $uri $uri/ =404;
    }
    location / { try_files $uri $uri/index.html =404; }
    access_log /var/log/nginx/cargo-portal-access.log;
    error_log  /var/log/nginx/cargo-portal-error.log;
}
NGINX

ln -sf /etc/nginx/sites-available/cargo-portal \
       /etc/nginx/sites-enabled/cargo-portal

# =============================================================================
# 2. NGINX — Decoy Document Index Portal (Port 8080)
#    Adds a second "document viewer" surface to create path-traversal ambiguity
# =============================================================================
section "Nginx — AGLG Document Index (Port 8080)"

mkdir -p /var/www/html/doc-index/api
mkdir -p /var/www/html/doc-index/view
mkdir -p /opt/aglg/decoy-docs/contracts
mkdir -p /opt/aglg/decoy-docs/manifests
mkdir -p /opt/aglg/decoy-docs/reports

# Decoy docs — not in /opt/aglg/vault/ (real vault path)
cat > /opt/aglg/decoy-docs/contracts/AGLG-SLA-2025-Q1.txt << 'TXT'
AGLG SERVICE LEVEL AGREEMENT — Q1 2025
========================================
Client: Logistics Partner A
Region: MENA
Service: Freight Forwarding & Customs Clearance
Uptime SLA: 99.5%
Response Time: 24-hour customs processing
Status: ACTIVE
TXT

cat > /opt/aglg/decoy-docs/manifests/FREIGHT-MANIFEST-APR-2025.txt << 'TXT'
AGLG FREIGHT MANIFEST — April 2025
=====================================
Route: Dubai → Hamburg
Cargo: Mixed General (247 CBM)
Seal: AGX-SL-20250401-00142
Customs Status: Cleared
TXT

cat > /opt/aglg/decoy-docs/reports/OPS-REPORT-Q1-2025.txt << 'TXT'
AGLG OPERATIONS REPORT — Q1 2025
===================================
Total Shipments: 14,203
On-time Delivery: 96.4%
Customs Clearance Average: 18.2 hours
Incidents: 3 minor delays (weather)
TXT

cat > /var/www/html/doc-index/index.html << 'HTML'
<!DOCTYPE html><html><head><title>AGLG Document Index</title>
<style>body{background:#1a1a2e;color:#e0e0e0;font-family:monospace;margin:0}
nav{background:#0f1626;padding:12px 20px;border-bottom:2px solid #0d4f8c}
nav span{color:#38bdf8;font-weight:bold}
.content{padding:24px}
.folder{background:#141928;border:1px solid #1e2845;border-radius:4px;
        padding:14px;margin:10px 0}
.folder h3{color:#38bdf8;font-size:.9rem;margin-bottom:8px}
.folder ul li{margin:4px 0;font-size:.82rem}
.folder ul li a{color:#94a3b8;text-decoration:none}
.folder ul li a:hover{color:#38bdf8}
</style></head><body>
<nav><span>AGLG DOCUMENT INDEX</span> — Internal Operations</nav>
<div class="content">
  <h2 style="margin-bottom:16px">Document Repository</h2>
  <div class="folder"><h3>&#128194; Contracts</h3><ul>
    <li><a href="/view/contracts/AGLG-SLA-2025-Q1.txt">AGLG-SLA-2025-Q1.txt</a></li>
  </ul></div>
  <div class="folder"><h3>&#128194; Manifests</h3><ul>
    <li><a href="/view/manifests/FREIGHT-MANIFEST-APR-2025.txt">FREIGHT-MANIFEST-APR-2025.txt</a></li>
  </ul></div>
  <div class="folder"><h3>&#128194; Reports</h3><ul>
    <li><a href="/view/reports/OPS-REPORT-Q1-2025.txt">OPS-REPORT-Q1-2025.txt</a></li>
  </ul></div>
  <div class="folder"><h3>&#128274; Classified Vault</h3>
    <p style="font-size:.8rem;color:#6b7280">Classified contracts accessible via vault service on :8443 only.</p>
  </div>
</div></body></html>
HTML

cat > /var/www/html/doc-index/api/status << 'JSON'
{"service":"doc-index","version":"1.0.0","status":"operational","docs_indexed":42}
JSON

cat > /etc/nginx/sites-available/doc-index << 'NGINX'
server {
    listen 8080 default_server;
    root /var/www/html/doc-index;
    index index.html;
    server_name _;
    add_header X-Powered-By "AGLG-DocIndex/1.0" always;

    # Serve decoy document files
    location /view/ {
        alias /opt/aglg/decoy-docs/;
        default_type text/plain;
        try_files $uri =404;
    }
    location /api/ {
        default_type application/json;
        try_files $uri $uri/ =404;
    }
    location / { try_files $uri $uri/ =404; }
    access_log /var/log/nginx/doc-index-access.log;
    error_log  /var/log/nginx/doc-index-error.log;
}
NGINX

ln -sf /etc/nginx/sites-available/doc-index \
       /etc/nginx/sites-enabled/doc-index

nginx -t
systemctl enable nginx --quiet
systemctl start nginx
info "Nginx cargo-portal :80, doc-index :8080"

# =============================================================================
# 3. APACHE — AGLG Admin Backend (Port 9000)
# =============================================================================
section "Apache — AGLG Admin Backend (Port 9000)"

apache_prepare

grep -q "Listen 9000" /etc/apache2/ports.conf || echo "Listen 9000" >> /etc/apache2/ports.conf

mkdir -p /var/www/html/aglg-backend

cat > /var/www/html/aglg-backend/index.html << 'HTML'
<!DOCTYPE html><html><head><title>AGLG Vault Admin Backend</title>
<style>body{font-family:sans-serif;background:#111;color:#ccc;margin:0}
.hdr{background:#1a1a2e;border-bottom:1px solid #333;padding:14px 20px}
.hdr h1{color:#38bdf8;font-size:1rem}
.content{padding:20px}
.panel{border:1px solid #333;padding:15px;margin:10px 0;border-radius:4px;background:#1a1a2e}
</style></head><body>
<div class="hdr"><h1>AGLG Vault Administration Backend</h1></div>
<div class="content">
  <div class="panel"><h3>Vault Status</h3>
    <p>Vault service: <span style="color:#4caf50">RUNNING</span> on :8443</p>
    <p>Documents indexed: 42</p></div>
  <div class="panel"><h3>Admin Actions</h3>
    <ul><li>Reindex vault documents</li>
        <li>Audit log review</li>
        <li>User session management</li></ul></div>
  <div class="panel"><h3>System</h3>
    <p>API backend requires authentication token.</p>
    <p>Contact: vault-ops@aglg-logistics.com</p></div>
</div></body></html>
HTML

cat > /etc/apache2/sites-available/aglg-backend.conf << 'APACHECONF'
<VirtualHost *:9000>
    DocumentRoot /var/www/html/aglg-backend
    DirectoryIndex index.html
    Options -Indexes
    Header always set X-Powered-By "AGLG-VaultAdmin/1.0"
    ErrorLog  ${APACHE_LOG_DIR}/aglg-backend-error.log
    CustomLog ${APACHE_LOG_DIR}/aglg-backend-access.log combined
</VirtualHost>
APACHECONF

a2ensite aglg-backend.conf 2>/dev/null || true
systemctl enable apache2 --quiet
systemctl start apache2
info "Apache vault admin backend :9000"

# =============================================================================
# 4. VSFTPD — Vault Document Archive FTP (Port 21)
# =============================================================================
section "vsftpd — Vault Archive FTP (Port 21)"
pkg_install vsftpd

useradd -m -s /bin/false vault-ftp 2>/dev/null || true
echo "vault-ftp:VaultFtp2024Aglg" | chpasswd

mkdir -p /srv/ftp/vault-exports
mkdir -p /srv/ftp/vault-backups
chown -R nobody:nogroup /srv/ftp 2>/dev/null || true

cat > /srv/ftp/vault-exports/export-manifest-2025-04.txt << 'TXT'
AGLG Vault Export Manifest — April 2025
=========================================
Exported: 2025-04-17T23:00:00Z
Documents: 42 files, 18.4 MB
Export format: Encrypted ZIP
Destination: aglg-backup.aglg-logistics.com:/vault-backups/
Status: COMPLETE
TXT

cat > /srv/ftp/vault-backups/README.txt << 'TXT'
Vault Backup Storage
=====================
Encrypted vault backups stored here.
Decryption key is NOT stored on this server.
Contact: vault-ops@aglg-logistics.com
TXT

mkdir -p /var/run/vsftpd/empty

cat > /etc/vsftpd.conf << 'VSFTPD'
listen=YES
listen_ipv6=NO
anonymous_enable=YES
local_enable=YES
write_enable=NO
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
ftpd_banner=AGLG Classified Vault Archive FTP — Authorized Personnel Only
anon_root=/srv/ftp
local_root=/srv/ftp
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
VSFTPD

systemctl enable vsftpd --quiet
systemctl restart vsftpd 2>/dev/null || systemctl start vsftpd
info "vsftpd vault FTP :21"

# =============================================================================
# 5. REDIS — Vault Cache (Port 6379)
# =============================================================================
section "Redis — Vault Session Cache (Port 6379)"
pkg_install redis-server

REDIS_PASS="VaultCache2024Aglg"

sed -i 's/^bind .*/bind 0.0.0.0/' /etc/redis/redis.conf
sed -i '/^requirepass /d' /etc/redis/redis.conf
echo "requirepass ${REDIS_PASS}" >> /etc/redis/redis.conf
sed -i 's/^protected-mode .*/protected-mode no/' /etc/redis/redis.conf

systemctl enable redis-server --quiet
systemctl restart redis-server 2>/dev/null || systemctl start redis-server
sleep 2

redis-cli -a "${REDIS_PASS}" SET "session:vault-ops-001" \
    '{"user":"vault_operator","role":"operator"}' 2>/dev/null || true
redis-cli -a "${REDIS_PASS}" SET "cache:docs_indexed" "42" 2>/dev/null || true

info "Redis vault cache :6379"

# =============================================================================
# 6. SNMP (Port 161 UDP)
# =============================================================================
section "SNMP — Vault Node (Port 161)"
pkg_install snmpd snmp

cat > /etc/snmp/snmpd.conf << 'SNMP'
agentAddress udp:161,tcp:161
rocommunity public default
rocommunity aglg_vault 195.0.0.0/8
sysLocation "AGLG Private Network — Classified Vault Node — Rack V-01"
sysContact  "Vault Ops <vault-ops@aglg-logistics.com>"
sysName     "aglg-vault.aglg-logistics.com"
sysDescr    "AGLG Classified Document Vault — Ubuntu 22.04 LTS"
sysServices 76
SNMP

systemctl enable snmpd --quiet
systemctl restart snmpd 2>/dev/null || systemctl start snmpd
info "SNMP :161"

# =============================================================================
# 7. DECOY CONFIG FILES
# =============================================================================
section "Decoy Config Files"

mkdir -p /opt/vault-agent/conf
mkdir -p /opt/vault-agent/pki

cat > /opt/vault-agent/conf/config.json << 'JSON'
{
  "service":   "vault-agent",
  "version":   "1.0.3",
  "listen_port": 3100,
  "vault_root": "/opt/aglg/decoy-docs",
  "redis": {
    "host":     "127.0.0.1",
    "port":     6379,
    "password": "VaultCache2024Aglg"
  },
  "api_token": "AGLG-VAULT-AGENT-XXXXXXXXXXXXXXXXXXXXXXXX",
  "_note": "Vault-agent token — NOT for SUID binary or SSH"
}
JSON
chmod 640 /opt/vault-agent/conf/config.json

cat > /opt/vault-agent/pki/vault_service_token.txt << 'TXT'
# AGLG vault-agent service token
# Scope: local vault-agent management only
# DOES NOT grant shell access or SUID privilege
# Issued: 2025-01-10
VAULT-SVC-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
TXT
chmod 600 /opt/vault-agent/pki/vault_service_token.txt

mkdir -p /var/log/vault-agent
cat > /var/log/vault-agent/agent.log << 'LOG'
2025-04-18 03:00:01 [INFO]  vault-agent started v1.0.3
2025-04-18 03:00:03 [INFO]  Redis connected
2025-04-18 03:00:04 [INFO]  Vault service on :8443 — reachable
2025-04-18 04:00:00 [INFO]  Heartbeat OK — 42 documents indexed
LOG

info "Decoy configs in /opt/vault-agent"

# =============================================================================
# 8. SOCAT (Ports 9100, 3100)
# =============================================================================
section "Socat Decoy Listeners (Ports 9100, 3100)"
pkg_install socat

declare -A DECOYS
DECOYS[9100]='HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\n\r\n# HELP node_cpu_seconds_total CPU\nnode_cpu_seconds_total{mode="idle"} 9.4e+07\n'
DECOYS[3100]='HTTP/1.0 200 OK\r\nContent-Type: application/json\r\n\r\n{"status":"ok","service":"vault-agent","version":"1.0.3"}\r\n'

for PORT in "${!DECOYS[@]}"; do
    BANNER="${DECOYS[$PORT]}"
    cat > /usr/local/bin/decoy-r2m5-${PORT}.sh << SOCAT
#!/bin/bash
while true; do
    printf '${BANNER}' | socat TCP-LISTEN:${PORT},reuseaddr,fork STDIN 2>/dev/null \
        || sleep 2
done
SOCAT
    chmod +x /usr/local/bin/decoy-r2m5-${PORT}.sh
    cat > /etc/systemd/system/decoy-r2m5-${PORT}.service << SVC
[Unit]
Description=R2M5 Decoy Listener Port ${PORT}
After=network.target
[Service]
ExecStart=/usr/local/bin/decoy-r2m5-${PORT}.sh
Restart=always
RestartSec=3
User=nobody
[Install]
WantedBy=multi-user.target
SVC
done

systemctl daemon-reload
for PORT in "${!DECOYS[@]}"; do
    systemctl enable  decoy-r2m5-${PORT}.service --quiet
    systemctl restart decoy-r2m5-${PORT}.service 2>/dev/null \
        || systemctl start decoy-r2m5-${PORT}.service
done
info "Socat decoys :9100 :3100"

# =============================================================================
# 9. UFW
# =============================================================================
section "UFW — Allow Ports"
if command -v ufw &>/dev/null; then
    ufw allow 22   &>/dev/null || true   # SSH — archivist user
    ufw allow 8443 &>/dev/null || true   # real Go vault (LFI + SUID challenge)
    ufw --force enable &>/dev/null || true
    for PORT in 21 80 161/udp 3100 6379 8080 9000 9100; do
        ufw allow "$PORT" &>/dev/null || true
    done
    info "UFW rules added (22 + 8443 + decoy ports)"
fi

# =============================================================================
# SUMMARY
# =============================================================================
section "M5 Decoy Setup Complete — aglg-vault"
cat << 'SUMMARY'
================================================================
  M5: aglg-vault — Decoy Services (Range 2)
  Challenge: LFI + SUID vault_reader (Port 8443 — UNTOUCHED)
             /opt/aglg/vault/ — UNTOUCHED
             /opt/aglg/vault_reader (SUID 4755) — UNTOUCHED
             /root/flag5.txt (mode 400) — UNTOUCHED
----------------------------------------------------------------
  Nginx  :80    AGLG Cargo Operations Portal
  Nginx  :8080  Document Index (decoy docs in /opt/aglg/decoy-docs/)
  Apache :9000  Vault Admin Backend
  vsftpd :21    Vault Archive FTP
  Redis  :6379  Vault session cache
  SNMP   :161   communities: public, aglg_vault
  Socat  :9100  node-exporter
  Socat  :3100  vault-agent

  Decoy docs at /opt/aglg/decoy-docs/ (NOT /opt/aglg/vault/)
  SSH  :22    — UNTOUCHED
  App  :8443  — UNTOUCHED
  SUID vault_reader — UNTOUCHED
================================================================
SUMMARY
