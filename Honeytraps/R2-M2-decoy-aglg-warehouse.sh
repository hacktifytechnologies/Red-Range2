#!/usr/bin/env bash
# =============================================================================
#  DECOY SETUP — M2: aglg-warehouse  (Operation BlackVault / Range 2)
#  Challenge : IDOR on Node.js Inventory API — Port 3000
#  Network   : v-DMZ
#  NEVER TOUCH: Port 3000 (real Node.js app, warehousesvc)
#               /opt/aglg/warehouse/, /opt/aglg/flag2.txt
#  Run as    : sudo bash M2-decoy-aglg-warehouse.sh
# =============================================================================

set -euo pipefail
LOG="/root/decoy_setup_log_R2M2.txt"
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
# 1. NGINX — Grafana Lookalike :3001 (Warehouse Metrics)
#    Port 3000 is taken by real Node.js — use 3001
# =============================================================================
section "Nginx — Warehouse Grafana Dashboard (Port 3001)"

nginx_prepare

mkdir -p /var/www/html/wh-grafana/api
mkdir -p /var/www/html/wh-grafana/dashboards

cat > /var/www/html/wh-grafana/index.html << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Grafana — AGLG Warehouse Metrics</title>
  <style>
    *{margin:0;padding:0;box-sizing:border-box}
    body{background:#111217;color:#d8d9da;font-family:-apple-system,sans-serif}
    .sidenav{width:56px;position:fixed;top:0;left:0;height:100%;
             background:#181b1f;border-right:1px solid #22252b;
             display:flex;flex-direction:column;align-items:center;
             padding:12px 0;gap:20px}
    .sidenav span{font-size:18px;cursor:pointer;color:#6e9fff}
    .topbar{margin-left:56px;background:#181b1f;border-bottom:1px solid #22252b;
            padding:10px 20px;display:flex;justify-content:space-between;
            align-items:center}
    .topbar h2{font-size:.95rem;color:#d8d9da}
    .topbar small{font-size:.75rem;color:#6c7280}
    .panels{margin-left:56px;padding:20px;display:grid;
            grid-template-columns:repeat(2,1fr);gap:16px}
    .panel{background:#1c1f26;border:1px solid #22252b;border-radius:4px;padding:16px}
    .panel h3{font-size:.8rem;color:#8e9cb2;text-transform:uppercase;
              letter-spacing:1px;margin-bottom:12px}
    .metric{font-size:2.2rem;font-weight:300;color:#73bf69}
    .sub{font-size:.75rem;color:#6c7280;margin-top:4px}
    footer{margin-left:56px;padding:10px 20px;font-size:.7rem;color:#444;
           border-top:1px solid #22252b}
  </style>
</head>
<body>
<div class="sidenav">
  <span>&#8862;</span><span>&#9889;</span><span>&#128202;</span><span>&#9881;</span>
</div>
<div class="topbar">
  <h2>&#128201; AGLG Warehouse — Inventory &amp; Operations Metrics</h2>
  <small>Datasource: Prometheus | Refresh: 30s</small>
</div>
<div class="panels">
  <div class="panel">
    <h3>Inventory Items Active</h3>
    <div class="metric">8,247</div>
    <div class="sub">&#8593; 142 new items today</div>
  </div>
  <div class="panel">
    <h3>Storage Utilisation</h3>
    <div class="metric" style="color:#ff9830">74.2%</div>
    <div class="sub">Zone A: 82% | Zone B: 67% | Zone H: 41%</div>
  </div>
  <div class="panel">
    <h3>API Request Rate</h3>
    <div class="metric" style="color:#5794f2">1,284/min</div>
    <div class="sub">p95 latency: 38ms</div>
  </div>
  <div class="panel">
    <h3>Shipments Processed Today</h3>
    <div class="metric" style="color:#73bf69">142</div>
    <div class="sub">On-time: 96.4%</div>
  </div>
</div>
<footer>Grafana v10.1.2 | Org: AGLG Warehouse | Prometheus:9090</footer>
</body>
</html>
HTML

cat > /var/www/html/wh-grafana/api/health << 'JSON'
{"status":"ok","version":"10.1.2","database":"ok"}
JSON

cat > /etc/nginx/sites-available/wh-grafana << 'NGINX'
server {
    listen 3001 default_server;
    root /var/www/html/wh-grafana;
    index index.html;
    server_name _;
    add_header X-Grafana-Version "10.1.2" always;
    location /api/ {
        default_type application/json;
        try_files $uri $uri/ =404;
    }
    location / { try_files $uri $uri/ =404; }
    access_log /var/log/nginx/wh-grafana-access.log;
    error_log  /var/log/nginx/wh-grafana-error.log;
}
NGINX

ln -sf /etc/nginx/sites-available/wh-grafana \
       /etc/nginx/sites-enabled/wh-grafana
nginx -t
systemctl enable nginx --quiet
systemctl start nginx
info "Nginx Grafana lookalike on :3001"

# =============================================================================
# 2. PYTHON — Prometheus Lookalike (Port 9090)
# =============================================================================
section "Python — Prometheus Lookalike (Port 9090)"
pkg_install python3

mkdir -p /usr/local/lib/decoy-services

cat > /usr/local/lib/decoy-services/wh_prometheus.py << 'PYEOF'
#!/usr/bin/env python3
"""Decoy Prometheus for AGLG Warehouse."""
import json
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

METRICS = b"""\
# HELP node_cpu_seconds_total CPU
# TYPE node_cpu_seconds_total counter
node_cpu_seconds_total{cpu="0",mode="idle"} 2.1e+08
# HELP node_memory_MemAvailable_bytes Memory
# TYPE node_memory_MemAvailable_bytes gauge
node_memory_MemAvailable_bytes 3.2e+09
# HELP warehouse_inventory_items Inventory count
# TYPE warehouse_inventory_items gauge
warehouse_inventory_items{zone="A"} 3412
warehouse_inventory_items{zone="B"} 2840
warehouse_inventory_items{zone="H"} 617
"""

TARGETS = json.dumps({"status":"success","data":{"activeTargets":[
    {"labels":{"instance":"warehouse:9100","job":"node"},"health":"up"},
    {"labels":{"instance":"warehouse:3000","job":"api"},"health":"up"}
]}}).encode()

INDEX = b"""<!DOCTYPE html><html><head><title>Prometheus</title></head>
<body><h1>Prometheus</h1><p>Version 2.47.0 | AGLG Warehouse</p>
<a href="/metrics">Metrics</a> |
<a href="/api/v1/targets">Targets</a></body></html>"""

ROUTES = {
    "/":               (200,"text/html",              INDEX),
    "/metrics":        (200,"text/plain; version=0.0.4",METRICS),
    "/api/v1/targets": (200,"application/json",       TARGETS),
}

class PromHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlparse(self.path).path
        code, ctype, body = ROUTES.get(path,
            (404,"application/json",b'{"status":"error"}'))
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a): pass

if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 9090), PromHandler).serve_forever()
PYEOF

chmod +x /usr/local/lib/decoy-services/wh_prometheus.py

cat > /etc/systemd/system/decoy-wh-prometheus.service << 'SVC'
[Unit]
Description=Decoy Warehouse Prometheus
After=network.target
[Service]
ExecStart=/usr/bin/python3 /usr/local/lib/decoy-services/wh_prometheus.py
Restart=always
RestartSec=3
User=nobody
[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl enable  decoy-wh-prometheus.service --quiet
systemctl restart decoy-wh-prometheus.service 2>/dev/null \
    || systemctl start decoy-wh-prometheus.service
info "Prometheus lookalike on :9090"

# =============================================================================
# 3. APACHE — Alertmanager :9093 + Log Viewer :5601
# =============================================================================
section "Apache — Alertmanager :9093 + Log Viewer :5601"

apache_prepare

grep -q "Listen 9093" /etc/apache2/ports.conf || echo "Listen 9093" >> /etc/apache2/ports.conf
grep -q "Listen 5601" /etc/apache2/ports.conf || echo "Listen 5601" >> /etc/apache2/ports.conf

mkdir -p /var/www/html/wh-alertmgr
mkdir -p /var/www/html/wh-logviewer

cat > /var/www/html/wh-alertmgr/index.html << 'HTML'
<!DOCTYPE html><html><head><title>Alertmanager — AGLG Warehouse</title>
<style>body{background:#fff;font-family:sans-serif;margin:0}
nav{background:#e8592c;color:#fff;padding:12px 20px;font-weight:bold}
.content{padding:20px}
table{width:100%;border-collapse:collapse;font-size:.87em}
th{background:#f0f0f0;padding:9px;text-align:left;border-bottom:2px solid #ddd}
td{padding:9px;border-bottom:1px solid #eee}
.crit{color:#e53e3e}.warn{color:#d69e2e}.info{color:#3182ce}
</style></head><body>
<nav>&#128276; Alertmanager — AGLG Warehouse Operations</nav>
<div class="content">
  <h2 style="margin-bottom:16px">Active Alerts (3)</h2>
  <table>
    <tr><th>Severity</th><th>Alert</th><th>Host</th><th>Since</th></tr>
    <tr><td class="warn">Warning</td><td>HighMemoryUsage</td>
        <td>warehouse-worker</td><td>8m</td></tr>
    <tr><td class="info">Info</td><td>InventoryThreshold</td>
        <td>zone-H</td><td>22m</td></tr>
    <tr><td class="info">Info</td><td>APILatencyHigh</td>
        <td>aglg-warehouse</td><td>3m</td></tr>
  </table>
</div></body></html>
HTML

cat > /var/www/html/wh-logviewer/index.html << 'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
<title>AGLG Warehouse Log Viewer</title>
<style>
body{background:#1a1c21;color:#d1d5db;font-family:monospace;margin:0}
header{background:#111318;padding:12px 20px;border-bottom:1px solid #2a2d35}
header span{color:#60a5fa;font-weight:bold}
.log-area{padding:16px;font-size:.8rem;line-height:1.7}
.log-line:hover{background:#2a2d35}
.ts{color:#6b7280}.inf{color:#34d399}.wrn{color:#fbbf24}.svc{color:#818cf8}
</style></head><body>
<header><span>&#128203; AGLG Warehouse Log Viewer</span></header>
<div class="log-area">
  <div class="log-line">
    <span class="ts">2025-04-18 04:00:01</span>
    <span class="inf"> [INFO]</span>
    <span class="svc"> aglg-warehouse</span> API health check OK</div>
  <div class="log-line">
    <span class="ts">2025-04-18 03:58:44</span>
    <span class="wrn"> [WARN]</span>
    <span class="svc"> warehouse-worker</span> Memory >85% on worker PID 4412</div>
  <div class="log-line">
    <span class="ts">2025-04-18 03:44:11</span>
    <span class="inf"> [INFO]</span>
    <span class="svc"> aglg-warehouse</span> 142 shipments processed today</div>
  <div class="log-line">
    <span class="ts">2025-04-18 03:00:00</span>
    <span class="inf"> [INFO]</span>
    <span class="svc"> aglg-warehouse</span> Service started on :3000</div>
</div></body></html>
HTML

cat > /etc/apache2/sites-available/wh-decoy.conf << 'APACHECONF'
<VirtualHost *:9093>
    DocumentRoot /var/www/html/wh-alertmgr
    DirectoryIndex index.html
    Options -Indexes
    Header always set X-Alertmanager-Version "0.26.0"
    ErrorLog  ${APACHE_LOG_DIR}/wh-alertmgr-error.log
    CustomLog ${APACHE_LOG_DIR}/wh-alertmgr-access.log combined
</VirtualHost>
<VirtualHost *:5601>
    DocumentRoot /var/www/html/wh-logviewer
    DirectoryIndex index.html
    Options -Indexes
    Header always set X-Powered-By "AGLG-Logview/1.0"
    ErrorLog  ${APACHE_LOG_DIR}/wh-logviewer-error.log
    CustomLog ${APACHE_LOG_DIR}/wh-logviewer-access.log combined
</VirtualHost>
APACHECONF

a2ensite wh-decoy.conf 2>/dev/null || true
systemctl enable apache2 --quiet
systemctl start apache2
info "Apache Alertmanager :9093, Log Viewer :5601"

# =============================================================================
# 4. REDIS — Warehouse Session Cache (Port 6379)
# =============================================================================
section "Redis — Warehouse Session Cache (Port 6379)"
pkg_install redis-server

REDIS_PASS="WhCache2024Aglg"

sed -i 's/^bind .*/bind 0.0.0.0/' /etc/redis/redis.conf
sed -i '/^requirepass /d' /etc/redis/redis.conf
echo "requirepass ${REDIS_PASS}" >> /etc/redis/redis.conf
sed -i 's/^protected-mode .*/protected-mode no/' /etc/redis/redis.conf

systemctl enable redis-server --quiet
systemctl restart redis-server 2>/dev/null || systemctl start redis-server
sleep 2

redis-cli -a "${REDIS_PASS}" SET "session:wh-ops-001" \
    '{"user":"wh_operator","role":"operator"}' 2>/dev/null || true
redis-cli -a "${REDIS_PASS}" SET "cache:inventory_count" "8247" 2>/dev/null || true
redis-cli -a "${REDIS_PASS}" LPUSH "queue:shipments" \
    "AGX-20250418-001" "AGX-20250418-002" 2>/dev/null || true

info "Redis warehouse cache on :6379"

# =============================================================================
# 5. SNMP (Port 161 UDP)
# =============================================================================
section "SNMP — Warehouse Node (Port 161)"
pkg_install snmpd snmp

cat > /etc/snmp/snmpd.conf << 'SNMP'
agentAddress udp:161,tcp:161
rocommunity public default
rocommunity aglg_warehouse 11.0.0.0/8
sysLocation "AGLG DMZ — Warehouse Cluster — Rack W-04"
sysContact  "Warehouse Ops <wh-ops@aglg-logistics.com>"
sysName     "aglg-warehouse.aglg-logistics.com"
sysDescr    "AGLG Warehouse Inventory API — Ubuntu 22.04 LTS"
sysServices 76
SNMP

systemctl enable snmpd --quiet
systemctl restart snmpd 2>/dev/null || systemctl start snmpd
info "SNMP :161"

# =============================================================================
# 6. DECOY CONFIG FILES — Fake API tokens in wrong paths
#    Real IDOR target is the Node.js app at /opt/aglg/warehouse/
#    Decoy configs add noise with dummy tokens to slow enumeration
# =============================================================================
section "Decoy Config Files"

mkdir -p /opt/aglg-api/warehouse
mkdir -p /opt/warehouse-agent/conf

cat > /opt/aglg-api/warehouse/config.json << 'JSON'
{
  "service":     "warehouse-api-agent",
  "version":     "2.4.1",
  "port":        9200,
  "redis": {
    "host": "127.0.0.1",
    "port": 6379,
    "password": "WhCache2024Aglg"
  },
  "api_token": "AGLG-WH-AGENT-XXXXXXXXXXXXXXXXXXXXXXXX",
  "_note": "Token for warehouse-agent internal use only"
}
JSON
chmod 640 /opt/aglg-api/warehouse/config.json

cat > /opt/warehouse-agent/conf/agent.conf << 'CONF'
[agent]
service     = warehouse-inventory-agent
version     = 2.4.1
listen_port = 9200
[upstream]
inventory_api   = http://127.0.0.1:9200/api/inventory
poll_interval   = 30
[auth]
mgmt_token  = WH-MGMT-XXXXXXXXXXXXXXXXXXXXXXXX
[logging]
level = info
file  = /var/log/warehouse-agent.log
CONF
chmod 640 /opt/warehouse-agent/conf/agent.conf

# Fake HR credential file in wrong path (real creds are in M2 IDOR response)
cat > /opt/aglg-api/warehouse/hr_migration_note.txt << 'TXT'
[AGLG IT — MIGRATION NOTE — ARCHIVED]
HR Portal migration completed 2024-08-15.
This credential note is SUPERSEDED and should have been deleted.
Use the HR portal directly for current access information.
Contact: it-ops@aglg-logistics.com
TXT
chmod 640 /opt/aglg-api/warehouse/hr_migration_note.txt

info "Decoy configs in /opt/aglg-api/warehouse, /opt/warehouse-agent"

# =============================================================================
# 7. SOCAT — node-exporter :9100, warehouse-agent :3200
# =============================================================================
section "Socat Decoy Listeners (Ports 9100, 3200)"
pkg_install socat

declare -A DECOYS
DECOYS[9100]='HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\n\r\n# HELP node_cpu_seconds_total CPU\nnode_cpu_seconds_total{cpu="0",mode="idle"} 2.1e+08\n'
DECOYS[3200]='HTTP/1.0 200 OK\r\nContent-Type: application/json\r\n\r\n{"status":"ok","service":"warehouse-agent","version":"2.4.1"}\r\n'

for PORT in "${!DECOYS[@]}"; do
    BANNER="${DECOYS[$PORT]}"
    cat > /usr/local/bin/decoy-r2m2-${PORT}.sh << SOCAT
#!/bin/bash
while true; do
    printf '${BANNER}' | socat TCP-LISTEN:${PORT},reuseaddr,fork STDIN 2>/dev/null \
        || sleep 2
done
SOCAT
    chmod +x /usr/local/bin/decoy-r2m2-${PORT}.sh
    cat > /etc/systemd/system/decoy-r2m2-${PORT}.service << SVC
[Unit]
Description=R2M2 Decoy Listener Port ${PORT}
After=network.target
[Service]
ExecStart=/usr/local/bin/decoy-r2m2-${PORT}.sh
Restart=always
RestartSec=3
User=nobody
[Install]
WantedBy=multi-user.target
SVC
done

systemctl daemon-reload
for PORT in "${!DECOYS[@]}"; do
    systemctl enable  decoy-r2m2-${PORT}.service --quiet
    systemctl restart decoy-r2m2-${PORT}.service 2>/dev/null \
        || systemctl start decoy-r2m2-${PORT}.service
done
info "Socat decoys :9100 :3200"

# =============================================================================
# 8. UFW
# =============================================================================
section "UFW — Allow Ports"
if command -v ufw &>/dev/null; then
    ufw allow 22   &>/dev/null || true   # SSH
    ufw allow 3000 &>/dev/null || true   # real Node.js IDOR challenge
    ufw --force enable &>/dev/null || true
    for PORT in 161/udp 3001 3200 5601 6379 9090 9093 9100; do
        ufw allow "$PORT" &>/dev/null || true
    done
    info "UFW rules added (22 + 3000 + decoy ports)"
fi

# =============================================================================
# SUMMARY
# =============================================================================
section "M2 Decoy Setup Complete — aglg-warehouse"
cat << 'SUMMARY'
================================================================
  M2: aglg-warehouse — Decoy Services (Range 2)
  Challenge: IDOR on Node.js Inventory API (Port 3000 — UNTOUCHED)
----------------------------------------------------------------
  Nginx  :3001  Grafana warehouse metrics dashboard
  Python :9090  Prometheus lookalike
  Apache :9093  Alertmanager lookalike
  Apache :5601  Log viewer
  Redis  :6379  Warehouse session cache
  SNMP   :161   communities: public, aglg_warehouse
  Socat  :9100  node-exporter
  Socat  :3200  warehouse-agent

  SSH :22   — UNTOUCHED
  App :3000 — UNTOUCHED
  /opt/aglg/warehouse/ — UNTOUCHED
================================================================
SUMMARY
