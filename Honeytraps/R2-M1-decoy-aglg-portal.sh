#!/usr/bin/env bash
# =============================================================================
#  DECOY SETUP — M1: aglg-portal  (Operation BlackVault / Range 2)
#  Challenge : SQL Injection + RCE on Flask Cargo Tracking Portal — Port 80
#  Network   : v-Pub + v-DMZ
#  NEVER TOUCH: Port 80 (real Flask/gunicorn app, www-data via authbind)
#               /opt/aglg/portal/, /opt/aglg/classified/
#               /var/log/aglg_portal.log
#  Run as    : sudo bash M1-decoy-aglg-portal.sh
# =============================================================================

set -euo pipefail
LOG="/root/decoy_setup_log_R2M1.txt"
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
# 1. NGINX — AGLG Logistics Client Portal (Port 8443)
# =============================================================================
section "Nginx — AGLG Logistics Client Portal (Port 8443)"

nginx_prepare

mkdir -p /var/www/html/aglg-client/api/shipment
mkdir -p /var/www/html/aglg-client/api/tracking
mkdir -p /var/www/html/aglg-client/api/health
mkdir -p /var/www/html/aglg-client/portal

cat > /var/www/html/aglg-client/index.html << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>AGLG — Arkanis Global Logistics Group</title>
  <style>
    *{margin:0;padding:0;box-sizing:border-box}
    body{background:#0a0e1a;color:#c9cdd7;font-family:'Segoe UI',sans-serif}
    header{background:#0f1626;border-bottom:2px solid #1e4db7;padding:16px 28px;
           display:flex;justify-content:space-between;align-items:center}
    .logo{display:flex;align-items:center;gap:12px}
    .logo-icon{width:38px;height:38px;background:#1e4db7;border-radius:6px;
               display:flex;align-items:center;justify-content:center;
               font-size:1.1rem;font-weight:700;color:#fff}
    .logo-text h1{font-size:.95rem;color:#e2e8f0;letter-spacing:1px}
    .logo-text p{font-size:.7rem;color:#6b7280}
    nav a{color:#94a3b8;font-size:.82rem;margin-left:20px;text-decoration:none}
    nav a:hover{color:#5b8def}
    .hero{padding:48px 28px 28px;border-bottom:1px solid #1a2035}
    .hero h2{font-size:1.6rem;color:#e2e8f0;margin-bottom:8px}
    .hero p{color:#6b7280;font-size:.9rem}
    .grid{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;padding:28px}
    .card{background:#0f1626;border:1px solid #1e2a45;border-radius:6px;padding:20px}
    .card h3{font-size:.8rem;color:#5b8def;text-transform:uppercase;
             letter-spacing:1px;margin-bottom:10px}
    .card p{font-size:.82rem;color:#8899bb;line-height:1.6}
    .card a{color:#5bc0de;font-size:.8rem;text-decoration:none;display:block;margin-top:10px}
    .stat{font-size:2rem;font-weight:300;color:#e2e8f0}
    .badge{display:inline-block;padding:2px 8px;border-radius:2px;font-size:.7rem;margin-top:6px}
    .ok{background:#1a3a1a;color:#4caf50}.warn{background:#3a2a00;color:#ffc107}
    footer{text-align:center;padding:14px;font-size:.7rem;color:#3a4a5a;
           border-top:1px solid #1e2a45}
  </style>
</head>
<body>
<header>
  <div class="logo">
    <div class="logo-icon">AG</div>
    <div class="logo-text">
      <h1>ARKANIS GLOBAL LOGISTICS</h1>
      <p>Client Services Portal — v4.1</p>
    </div>
  </div>
  <nav>
    <a href="/portal/">Track Shipment</a>
    <a href="/api/tracking/status">API Status</a>
    <a href="/portal/login.html">Client Login</a>
  </nav>
</header>
<div class="hero">
  <h2>Global Cargo Management Platform</h2>
  <p>Real-time tracking, customs clearance status, and freight management for 47 countries</p>
</div>
<div class="grid">
  <div class="card">
    <h3>Active Shipments</h3>
    <div class="stat">1,847</div>
    <span class="badge ok">Nominal</span>
    <a href="/api/shipment/summary">→ Shipment API</a>
  </div>
  <div class="card">
    <h3>Customs Holds</h3>
    <div class="stat">23</div>
    <span class="badge warn">Pending Review</span>
    <a href="/api/tracking/status">→ Tracking Status</a>
  </div>
  <div class="card">
    <h3>System Health</h3>
    <div class="stat" style="color:#4caf50">OK</div>
    <span class="badge ok">All Services Up</span>
    <a href="/api/health/status">→ Health Check</a>
  </div>
  <div class="card">
    <h3>Client Portal</h3>
    <p>Vendor and cargo operator login for shipment tracking and document submission.</p>
    <a href="/portal/login.html">→ Client Login</a>
  </div>
  <div class="card">
    <h3>Freight API</h3>
    <p>REST API for automated cargo status integration. API key required.</p>
    <a href="/api/shipment/summary">→ API Docs</a>
  </div>
  <div class="card">
    <h3>Compliance</h3>
    <p>Export control and customs compliance documentation portal.</p>
    <a href="/api/health/status">→ Compliance Portal</a>
  </div>
</div>
<footer>Arkanis Global Logistics Group — Client Services — support@aglg-logistics.com</footer>
</body>
</html>
HTML

cat > /var/www/html/aglg-client/api/shipment/summary << 'JSON'
{
  "api": "AGLG Freight API",
  "version": "4.1.0",
  "active_shipments": 1847,
  "customs_holds": 23,
  "delivered_today": 142,
  "endpoints": [
    "POST /api/shipment/track",
    "GET  /api/shipment/summary",
    "GET  /api/tracking/status",
    "GET  /api/health/status"
  ],
  "auth": "API key required — contact api-support@aglg-logistics.com"
}
JSON

cat > /var/www/html/aglg-client/api/tracking/status << 'JSON'
{
  "service": "AGLG Tracking Engine",
  "status": "operational",
  "regions": ["MENA","APAC","EMEA","AMER"],
  "last_sync": "2025-04-18T04:00:00Z",
  "nodes_active": 12
}
JSON

cat > /var/www/html/aglg-client/api/health/status << 'JSON'
{"status":"healthy","db":"ok","cache":"ok","workers":4,"uptime_hours":312}
JSON

mkdir -p /var/www/html/aglg-client/portal
cat > /var/www/html/aglg-client/portal/login.html << 'HTML'
<!DOCTYPE html><html><head><title>AGLG Client Login</title>
<style>body{background:#0a0e1a;display:flex;justify-content:center;
  align-items:center;height:100vh;margin:0;font-family:sans-serif}
.box{background:#0f1626;border:1px solid #1e2a45;padding:40px;
     width:360px;border-radius:6px}
h2{color:#e2e8f0;margin-bottom:4px}p{color:#6b7280;font-size:.85rem;margin-bottom:24px}
input{width:100%;padding:10px 12px;background:#0a0e1a;border:1px solid #1e2a45;
      color:#c9cdd7;border-radius:4px;margin:6px 0;box-sizing:border-box}
button{width:100%;padding:10px;background:#1e4db7;border:none;color:#fff;
       border-radius:4px;cursor:pointer;font-weight:600;margin-top:8px}
small{display:block;text-align:center;margin-top:14px;color:#444;font-size:.75rem}
</style></head><body>
<div class="box">
  <h2>AGLG Client Portal</h2>
  <p>Vendor &amp; cargo operator access</p>
  <input type="text" placeholder="Client Username">
  <input type="password" placeholder="Access Code">
  <button>Sign In</button>
  <small>Unauthorized access violates AGLG Terms of Service</small>
</div></body></html>
HTML

cat > /etc/nginx/sites-available/aglg-client << 'NGINX'
server {
    listen 8443 default_server;
    root /var/www/html/aglg-client;
    index index.html;
    server_name _;
    add_header X-Powered-By "AGLG-Portal/4.1" always;
    location /api/ {
        default_type application/json;
        try_files $uri $uri/ =404;
    }
    location / { try_files $uri $uri/ =404; }
    access_log /var/log/nginx/aglg-client-access.log;
    error_log  /var/log/nginx/aglg-client-error.log;
}
NGINX

ln -sf /etc/nginx/sites-available/aglg-client \
       /etc/nginx/sites-enabled/aglg-client
nginx -t
systemctl enable nginx --quiet
systemctl start nginx
info "Nginx AGLG Client Portal on :8443"

# =============================================================================
# 2. APACHE — AGLG Admin Panel :8080 + Legacy Ops Dashboard :8090
# =============================================================================
section "Apache — Admin Panel :8080 + Legacy Ops :8090"

apache_prepare

grep -q "Listen 8080" /etc/apache2/ports.conf || echo "Listen 8080" >> /etc/apache2/ports.conf
grep -q "Listen 8090" /etc/apache2/ports.conf || echo "Listen 8090" >> /etc/apache2/ports.conf

mkdir -p /var/www/html/aglg-admin/api
mkdir -p /var/www/html/aglg-legacy

cat > /var/www/html/aglg-admin/index.html << 'HTML'
<!DOCTYPE html><html><head><title>AGLG Admin — Operations Control</title>
<style>body{background:#1a1a2e;color:#e0e0e0;font-family:monospace;margin:0}
nav{background:#16213e;padding:12px 20px;border-bottom:2px solid #e94560}
nav span{color:#e94560;font-weight:bold;font-size:1.1em}
.content{padding:24px}
table{width:100%;border-collapse:collapse;font-size:.85em}
th{background:#0f3460;padding:10px;text-align:left}
td{padding:9px;border-bottom:1px solid #2a2a4a}
.up{color:#4caf50}.warn{color:#ff9800}.down{color:#f44336}
</style></head><body>
<nav><span>AGLG ADMIN</span> &nbsp;|&nbsp; Operations Control
&nbsp;|&nbsp;<small style="color:#888">internal.aglg-logistics.com</small></nav>
<div class="content">
  <h2 style="color:#e94560;margin-bottom:16px">Logistics Node Status</h2>
  <table>
    <tr><th>Node</th><th>Region</th><th>Service</th><th>Status</th><th>Last Seen</th></tr>
    <tr><td>cargo-gw-01</td><td>MENA</td><td>Freight Gateway</td>
        <td class="up">UP</td><td>8s ago</td></tr>
    <tr><td>customs-api</td><td>EMEA</td><td>Customs Clearance</td>
        <td class="up">UP</td><td>12s ago</td></tr>
    <tr><td>warehouse-01</td><td>DMZ</td><td>Inventory API</td>
        <td class="up">UP</td><td>5s ago</td></tr>
    <tr><td>hr-portal</td><td>DMZ</td><td>HR Self-Service</td>
        <td class="up">UP</td><td>18s ago</td></tr>
    <tr><td>vault-node</td><td>Private</td><td>Document Vault</td>
        <td class="warn">DEGRADED</td><td>4 min ago</td></tr>
  </table>
</div></body></html>
HTML

cat > /var/www/html/aglg-admin/api/nodes.json << 'JSON'
{"nodes":["cargo-gw-01","customs-api","warehouse-01","hr-portal","vault-node"],
 "healthy":4,"degraded":1}
JSON

cat > /var/www/html/aglg-legacy/index.html << 'HTML'
<!DOCTYPE html><html><head><title>AGLG Ops Dashboard v2 (Legacy)</title>
<style>body{font-family:sans-serif;background:#fff;margin:0}
.hdr{background:#003366;color:#fff;padding:16px 20px}
.box{border:1px solid #ddd;padding:15px;margin:20px;background:#f8f8f8}
</style></head><body>
<div class="hdr"><h2>AGLG Operations Dashboard (Legacy v2)</h2>
<small>Internal use only — migrate to v4 portal</small></div>
<div class="box"><h3>Quick Links</h3><ul>
  <li><a href="/api/nodes.json">Node Status JSON</a></li>
  <li><a href="/reports/">Reports</a></li>
  <li><a href="/config/system.json">System Config</a></li>
</ul></div>
<div class="box"><p>This is a legacy interface. Please use the new client portal on port 8443.</p></div>
</body></html>
HTML

cat > /etc/apache2/sites-available/aglg-decoy.conf << 'APACHECONF'
<VirtualHost *:8080>
    DocumentRoot /var/www/html/aglg-admin
    DirectoryIndex index.html
    Options -Indexes
    Header always set Server "Apache/2.4 AGLG-Admin"
    Header always set X-Application "AGLG-AdminPanel/2.1"
    <Location /api/>
        Header set Content-Type "application/json"
    </Location>
    ErrorLog  ${APACHE_LOG_DIR}/aglg-admin-error.log
    CustomLog ${APACHE_LOG_DIR}/aglg-admin-access.log combined
</VirtualHost>
<VirtualHost *:8090>
    DocumentRoot /var/www/html/aglg-legacy
    DirectoryIndex index.html
    Options -Indexes
    Header always set Server "Apache/2.2 AGLG-Legacy"
    ErrorLog  ${APACHE_LOG_DIR}/aglg-legacy-error.log
    CustomLog ${APACHE_LOG_DIR}/aglg-legacy-access.log combined
</VirtualHost>
APACHECONF

a2ensite aglg-decoy.conf 2>/dev/null || true
systemctl enable apache2 --quiet
systemctl start apache2
info "Apache admin panel :8080, legacy dashboard :8090"

# =============================================================================
# 3. VSFTPD — Cargo Manifest FTP (Port 21)
# =============================================================================
section "vsftpd — Cargo Manifest FTP (Port 21)"
pkg_install vsftpd

useradd -m -s /bin/false cargo-ftp 2>/dev/null || true
echo "cargo-ftp:Carg0Ftp2024Aglg" | chpasswd

mkdir -p /srv/ftp/manifests
mkdir -p /srv/ftp/customs-docs
mkdir -p /srv/ftp/freight-schedules
chown -R nobody:nogroup /srv/ftp 2>/dev/null || true

cat > /srv/ftp/manifests/AGX-MANIFEST-APR-2025.txt << 'TXT'
AGLG CARGO MANIFEST — April 2025
==================================
Ref: AGX-20250401-MAN
Origin: Dubai Freight Terminal
Destination: Hamburg, Germany
Cargo: Mixed General — 247 CBM
Status: IN TRANSIT
Seal: AGX-SL-20250401-00142
TXT

cat > /srv/ftp/freight-schedules/schedule-Q2-2025.txt << 'TXT'
AGLG Freight Schedule — Q2 2025
=================================
Route 1: Dubai → Hamburg — Weekly (Mon)
Route 2: Singapore → Los Angeles — Biweekly
Route 3: Rotterdam → Mumbai — Monthly
Route 4: Jeddah → Karachi → Singapore — On-demand
Contact: freight-ops@aglg-logistics.com
TXT

cat > /srv/ftp/customs-docs/README.txt << 'TXT'
Customs Documentation Repository
==================================
Place signed customs declarations and HS code schedules here.
GPG signatures required for restricted cargo.
Contact: customs@aglg-logistics.com
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
ftpd_banner=AGLG Cargo Document FTP Server — Authorized Personnel Only
anon_root=/srv/ftp
local_root=/srv/ftp
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
VSFTPD

systemctl enable vsftpd --quiet
systemctl restart vsftpd 2>/dev/null || systemctl start vsftpd
info "vsftpd cargo FTP on :21"

# =============================================================================
# 4. SNMP (Port 161 UDP)
# =============================================================================
section "SNMP — Logistics Node Monitoring (Port 161)"
pkg_install snmpd snmp

cat > /etc/snmp/snmpd.conf << 'SNMP'
agentAddress udp:161,tcp:161
rocommunity public default
rocommunity aglg_logistics 203.0.0.0/8
sysLocation "AGLG HQ — London Data Centre — Rack L-07"
sysContact  "NOC <noc@aglg-logistics.com>"
sysName     "aglg-portal.aglg-logistics.com"
sysDescr    "AGLG Cargo Portal Node — Ubuntu 22.04 LTS"
sysServices 72
SNMP

systemctl enable snmpd --quiet
systemctl restart snmpd 2>/dev/null || systemctl start snmpd
info "SNMP :161"

# =============================================================================
# 5. POSTFIX — Alert Mailer (Ports 25, 587)
# =============================================================================
section "Postfix — Alert Mailer (Ports 25/587)"

debconf-set-selections <<< "postfix postfix/mailname string aglg-portal.aglg-logistics.com"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"

pkg_install postfix

postconf -e "myhostname = aglg-portal.aglg-logistics.com"
postconf -e "myorigin = /etc/mailname"
postconf -e "inet_interfaces = all"
postconf -e "inet_protocols = ipv4"
postconf -e "mynetworks = 127.0.0.0/8 203.0.0.0/8"
postconf -e "smtpd_banner = \$myhostname ESMTP AGLG-MAILER"
postconf -e "relayhost ="
echo "aglg-portal.aglg-logistics.com" > /etc/mailname

systemctl enable postfix --quiet
systemctl restart postfix 2>/dev/null || systemctl start postfix
info "Postfix :25/:587"

# =============================================================================
# 6. DECOY CONFIG FILES
# =============================================================================
section "Decoy Config and Credential Files"

mkdir -p /opt/aglg-api/conf
mkdir -p /opt/aglg-ops/etc

cat > /opt/aglg-api/conf/.env << 'ENV'
# AGLG Freight API — Environment
NODE_ENV=production
PORT=3100
DB_HOST=127.0.0.1
DB_NAME=aglg_freight
DB_USER=freight_api
DB_PASS=FreightApi2024Aglg
SMTP_HOST=127.0.0.1
API_KEY_INTERNAL=AGLG-FREIGHT-API-XXXXXXXXXXXXXXXXXXXX
ENV
chmod 640 /opt/aglg-api/conf/.env

cat > /opt/aglg-ops/etc/portal.conf << 'CONF'
[portal]
service      = aglg-client-portal
version      = 4.1.0
listen_port  = 3100
workers      = 4
[db]
host = 127.0.0.1
port = 5432
name = aglg_portal_db
user = portal_db
pass = PortalDb2024Aglg
[auth]
session_secret = SESS-PORTAL-XXXXXXXXXXXXXXXXXXXXXXXX
[logging]
level = info
file  = /var/log/aglg_portal.log
CONF
chmod 640 /opt/aglg-ops/etc/portal.conf

mkdir -p /var/log/aglg-ops
cat > /var/log/aglg-ops/access.log << 'LOG'
2025-04-18 03:00:01 [INFO]  aglg-portal service started v4.1
2025-04-18 03:00:04 [INFO]  DB connected — aglg_portal_db
2025-04-18 04:00:00 [INFO]  Health check passed — 1847 active shipments
2025-04-18 04:01:15 [INFO]  API request: GET /api/shipment/summary — 200
LOG

info "Decoy configs in /opt/aglg-api, /opt/aglg-ops"

# =============================================================================
# 7. SOCAT — node-exporter :9100, api-gateway :3100, webhook :4000
# =============================================================================
section "Socat Decoy Listeners (Ports 9100, 3100, 4000)"
pkg_install socat

declare -A DECOYS
DECOYS[9100]='HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\n\r\n# HELP node_cpu_seconds_total CPU\n# TYPE node_cpu_seconds_total counter\nnode_cpu_seconds_total{cpu="0",mode="idle"} 8.3e+08\n'
DECOYS[3100]='HTTP/1.0 200 OK\r\nContent-Type: application/json\r\n\r\n{"status":"ok","service":"aglg-freight-api","version":"4.1.0"}\r\n'
DECOYS[4000]='HTTP/1.0 200 OK\r\nContent-Type: application/json\r\n\r\n{"service":"aglg-webhook","ready":true,"version":"1.2.0"}\r\n'

for PORT in "${!DECOYS[@]}"; do
    BANNER="${DECOYS[$PORT]}"
    cat > /usr/local/bin/decoy-r2m1-${PORT}.sh << SOCAT
#!/bin/bash
while true; do
    printf '${BANNER}' | socat TCP-LISTEN:${PORT},reuseaddr,fork STDIN 2>/dev/null \
        || sleep 2
done
SOCAT
    chmod +x /usr/local/bin/decoy-r2m1-${PORT}.sh
    cat > /etc/systemd/system/decoy-r2m1-${PORT}.service << SVC
[Unit]
Description=R2M1 Decoy Listener Port ${PORT}
After=network.target
[Service]
ExecStart=/usr/local/bin/decoy-r2m1-${PORT}.sh
Restart=always
RestartSec=3
User=nobody
[Install]
WantedBy=multi-user.target
SVC
done

systemctl daemon-reload
for PORT in "${!DECOYS[@]}"; do
    systemctl enable  decoy-r2m1-${PORT}.service --quiet
    systemctl restart decoy-r2m1-${PORT}.service 2>/dev/null \
        || systemctl start decoy-r2m1-${PORT}.service
done
info "Socat decoys :9100 :3100 :4000"

# =============================================================================
# 8. UFW — Allow real ports FIRST, then decoy ports
# =============================================================================
section "UFW — Allow Ports"
if command -v ufw &>/dev/null; then
    ufw allow 22  &>/dev/null || true   # SSH
    ufw allow 80  &>/dev/null || true   # real Flask app
    ufw --force enable &>/dev/null || true
    for PORT in 21 25 161/udp 587 3100 4000 8080 8090 8443 9100; do
        ufw allow "$PORT" &>/dev/null || true
    done
    info "UFW rules added (22 + 80 + decoy ports)"
fi

# =============================================================================
# SUMMARY
# =============================================================================
section "M1 Decoy Setup Complete — aglg-portal"
cat << 'SUMMARY'
================================================================
  M1: aglg-portal — Decoy Services (Range 2)
  Challenge: SQL Injection + RCE on Flask (Port 80 — UNTOUCHED)
----------------------------------------------------------------
  Nginx  :8443  AGLG Logistics Client Portal
  Apache :8080  AGLG Admin Panel
  Apache :8090  Legacy Ops Dashboard
  vsftpd :21    Cargo Manifest FTP
  SNMP   :161   communities: public, aglg_logistics
  Postfix :25/587 Alert mailer
  Socat  :9100  node-exporter
  Socat  :3100  freight-api
  Socat  :4000  webhook

  SSH :22  — UNTOUCHED
  App :80  — UNTOUCHED
  /opt/aglg/portal/ /opt/aglg/classified/ — UNTOUCHED
================================================================
SUMMARY
