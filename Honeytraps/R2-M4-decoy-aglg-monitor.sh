#!/usr/bin/env bash
# =============================================================================
#  DECOY SETUP — M4: aglg-monitor  (Operation BlackVault / Range 2)
#  Challenge : OS Command Injection in Flask NOC Dashboard — Port 5000
#  Network   : v-Priv
#  NEVER TOUCH: Port 5000 (real Flask/gunicorn, netops user)
#               Port 22 (SSH, netops user)
#               /opt/aglg/monitor/, /opt/aglg/flag4.txt,
#               /opt/aglg/hint_m5.txt, /var/log/aglg_monitor.log
#  Run as    : sudo bash M4-decoy-aglg-monitor.sh
# =============================================================================

set -euo pipefail
LOG="/root/decoy_setup_log_R2M4.txt"
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

mariadb_wait() {
    local tries=0
    while ! mysqladmin ping --silent 2>/dev/null && [[ $tries -lt 15 ]]; do
        sleep 2; tries=$((tries + 1))
    done
}

# =============================================================================
# 1. NGINX — Grafana NOC Dashboard Lookalike (Port 3000)
# =============================================================================
section "Nginx — NOC Grafana Dashboard (Port 3000)"

nginx_prepare

mkdir -p /var/www/html/noc-grafana/api
mkdir -p /var/www/html/noc-grafana/dashboards

cat > /var/www/html/noc-grafana/index.html << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Grafana — AGLG NOC Infrastructure</title>
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
    .topbar h2{font-size:.95rem}
    .topbar small{font-size:.75rem;color:#6c7280}
    .panels{margin-left:56px;padding:20px;display:grid;
            grid-template-columns:repeat(2,1fr);gap:16px}
    .panel{background:#1c1f26;border:1px solid #22252b;border-radius:4px;padding:16px}
    .panel h3{font-size:.8rem;color:#8e9cb2;text-transform:uppercase;
              letter-spacing:1px;margin-bottom:12px}
    .metric{font-size:2.2rem;font-weight:300;color:#73bf69}
    .sub{font-size:.75rem;color:#6c7280;margin-top:4px}
    .bar{height:8px;background:#2a2e3a;border-radius:4px;margin:8px 0}
    .bar-fill{height:8px;border-radius:4px;background:#5794f2}
    footer{margin-left:56px;padding:10px 20px;font-size:.7rem;color:#444;
           border-top:1px solid #22252b}
  </style>
</head>
<body>
<div class="sidenav">
  <span>&#8862;</span><span>&#9889;</span><span>&#128202;</span>
  <span>&#128276;</span><span>&#9881;</span>
</div>
<div class="topbar">
  <h2>&#127760; AGLG NOC — Infrastructure Health Overview</h2>
  <small>Datasource: Prometheus | Refresh: 30s</small>
</div>
<div class="panels">
  <div class="panel">
    <h3>Nodes Online</h3>
    <div class="metric">5 / 7</div>
    <div class="sub">aglg-backup: DOWN | aglg-db-replica: WARN</div>
  </div>
  <div class="panel">
    <h3>Avg Network Latency</h3>
    <div class="metric" style="color:#5794f2">14 ms</div>
    <div class="sub">aglg-db-replica outlier: 45ms</div>
  </div>
  <div class="panel">
    <h3>CPU (Monitor Node)</h3>
    <div class="metric" style="color:#ff9830">58.1%</div>
    <div class="bar">
      <div class="bar-fill" style="width:58%"></div>
    </div>
    <div class="sub">4 vCPU | load 2.32</div>
  </div>
  <div class="panel">
    <h3>Active Alerts</h3>
    <div class="metric" style="color:#f2cc0c">5</div>
    <div class="sub">1 critical, 2 warning, 2 info</div>
  </div>
  <div class="panel">
    <h3>Disk (Log Volume)</h3>
    <div class="metric" style="color:#73bf69">67%</div>
    <div class="bar">
      <div class="bar-fill" style="width:67%;background:#73bf69"></div>
    </div>
    <div class="sub">82 GB / 120 GB used</div>
  </div>
  <div class="panel">
    <h3>Uptime (Monitor)</h3>
    <div class="metric" style="color:#73bf69">99.7%</div>
    <div class="sub">Last restart: 14 days ago</div>
  </div>
</div>
<footer>Grafana v10.1.2 | Org: AGLG NOC | Prometheus:9090</footer>
</body>
</html>
HTML

cat > /var/www/html/noc-grafana/api/health << 'JSON'
{"status":"ok","version":"10.1.2","database":"ok"}
JSON

cat > /etc/nginx/sites-available/noc-grafana << 'NGINX'
server {
    listen 3000 default_server;
    root /var/www/html/noc-grafana;
    index index.html;
    server_name _;
    add_header X-Grafana-Version "10.1.2" always;
    location /api/ {
        default_type application/json;
        try_files $uri $uri/ =404;
    }
    location / { try_files $uri $uri/ =404; }
    access_log /var/log/nginx/noc-grafana-access.log;
    error_log  /var/log/nginx/noc-grafana-error.log;
}
NGINX

ln -sf /etc/nginx/sites-available/noc-grafana \
       /etc/nginx/sites-enabled/noc-grafana
nginx -t
systemctl enable nginx --quiet
systemctl start nginx
info "Nginx NOC Grafana on :3000"

# =============================================================================
# 2. PYTHON — Prometheus Lookalike (Port 9090)
# =============================================================================
section "Python — Prometheus Lookalike (Port 9090)"
pkg_install python3

mkdir -p /usr/local/lib/decoy-services

cat > /usr/local/lib/decoy-services/noc_prometheus.py << 'PYEOF'
#!/usr/bin/env python3
"""Decoy Prometheus — AGLG NOC."""
import json
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

METRICS = b"""\
# HELP node_cpu_seconds_total CPU
# TYPE node_cpu_seconds_total counter
node_cpu_seconds_total{cpu="0",mode="idle"} 1.84e+08
node_cpu_seconds_total{cpu="0",mode="user"} 4.1e+06
# HELP node_memory_MemAvailable_bytes Memory available
# TYPE node_memory_MemAvailable_bytes gauge
node_memory_MemAvailable_bytes 3.8e+09
# HELP aglg_nodes_up Nodes status
# TYPE aglg_nodes_up gauge
aglg_nodes_up{host="aglg-portal"} 1
aglg_nodes_up{host="aglg-warehouse"} 1
aglg_nodes_up{host="aglg-hrportal"} 1
aglg_nodes_up{host="aglg-db-primary"} 1
aglg_nodes_up{host="aglg-db-replica"} 0.5
aglg_nodes_up{host="aglg-vault"} 1
aglg_nodes_up{host="aglg-backup"} 0
"""

TARGETS = json.dumps({"status":"success","data":{"activeTargets":[
    {"labels":{"instance":"monitor:9100","job":"node"},"health":"up"},
    {"labels":{"instance":"monitor:5000","job":"noc-api"},"health":"up"}
]}}).encode()

INDEX = b"""<!DOCTYPE html><html><head><title>Prometheus — AGLG NOC</title>
</head><body><h1>Prometheus</h1>
<p>Version 2.47.0 | Cluster: aglg-noc</p>
<a href="/metrics">Metrics</a> | <a href="/api/v1/targets">Targets</a>
</body></html>"""

ROUTES = {
    "/": (200,"text/html",INDEX),
    "/metrics": (200,"text/plain; version=0.0.4",METRICS),
    "/api/v1/targets": (200,"application/json",TARGETS),
}

class PromHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlparse(self.path).path
        code, ctype, body = ROUTES.get(path,(404,"application/json",b'{}'))
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a): pass

if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 9090), PromHandler).serve_forever()
PYEOF

chmod +x /usr/local/lib/decoy-services/noc_prometheus.py

cat > /etc/systemd/system/decoy-noc-prometheus.service << 'SVC'
[Unit]
Description=Decoy NOC Prometheus
After=network.target
[Service]
ExecStart=/usr/bin/python3 /usr/local/lib/decoy-services/noc_prometheus.py
Restart=always
RestartSec=3
User=nobody
[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl enable  decoy-noc-prometheus.service --quiet
systemctl restart decoy-noc-prometheus.service 2>/dev/null \
    || systemctl start decoy-noc-prometheus.service
info "Prometheus lookalike on :9090"

# =============================================================================
# 3. APACHE — Alertmanager :9093 + Log Viewer :5601
# =============================================================================
section "Apache — Alertmanager :9093 + Log Viewer :5601"

apache_prepare

grep -q "Listen 9093" /etc/apache2/ports.conf || echo "Listen 9093" >> /etc/apache2/ports.conf
grep -q "Listen 5601" /etc/apache2/ports.conf || echo "Listen 5601" >> /etc/apache2/ports.conf

mkdir -p /var/www/html/noc-alertmgr
mkdir -p /var/www/html/noc-logviewer

cat > /var/www/html/noc-alertmgr/index.html << 'HTML'
<!DOCTYPE html><html><head><title>Alertmanager — AGLG NOC</title>
<style>body{background:#fff;font-family:sans-serif;margin:0}
nav{background:#e8592c;color:#fff;padding:12px 20px;font-weight:bold}
.content{padding:20px}
table{width:100%;border-collapse:collapse;font-size:.87em}
th{background:#f0f0f0;padding:9px;text-align:left;border-bottom:2px solid #ddd}
td{padding:9px;border-bottom:1px solid #eee}
</style></head><body>
<nav>&#128276; Alertmanager — AGLG NOC</nav>
<div class="content">
  <h2 style="margin-bottom:16px">Active Alerts (5)</h2>
  <table>
    <tr><th>Severity</th><th>Alert</th><th>Host</th><th>Since</th></tr>
    <tr style="background:#fff5f5"><td>CRITICAL</td><td>NodeDown</td>
        <td>aglg-backup</td><td>52m</td></tr>
    <tr style="background:#fffef0"><td>WARNING</td><td>HighReplicationLag</td>
        <td>aglg-db-replica</td><td>18m</td></tr>
    <tr style="background:#fffef0"><td>WARNING</td><td>HighMemory</td>
        <td>aglg-monitor</td><td>9m</td></tr>
    <tr><td>INFO</td><td>CertRenewal</td><td>aglg-hrportal</td><td>2d</td></tr>
    <tr><td>INFO</td><td>MaintenanceWindow</td><td>aglg-portal</td><td>Yesterday</td></tr>
  </table>
</div></body></html>
HTML

cat > /var/www/html/noc-logviewer/index.html << 'HTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
<title>AGLG NOC Log Viewer</title>
<style>body{background:#1a1c21;color:#d1d5db;font-family:monospace;margin:0}
header{background:#111318;padding:12px 20px;border-bottom:1px solid #2a2d35}
header span{color:#60a5fa;font-weight:bold}
.log-area{padding:16px;font-size:.8rem;line-height:1.7}
.log-line:hover{background:#2a2d35}
.ts{color:#6b7280}.inf{color:#34d399}.wrn{color:#fbbf24}
.err{color:#f87171}.svc{color:#818cf8}
</style></head><body>
<header><span>&#128203; AGLG NOC Log Viewer</span></header>
<div class="log-area">
  <div class="log-line"><span class="ts">2025-04-18 04:01:02</span>
    <span class="inf"> [INFO]</span>
    <span class="svc"> aglg-monitor</span> Node health poll — 5/7 healthy</div>
  <div class="log-line"><span class="ts">2025-04-18 04:00:48</span>
    <span class="err"> [CRIT]</span>
    <span class="svc"> aglg-backup</span> Heartbeat timeout — marking DOWN</div>
  <div class="log-line"><span class="ts">2025-04-18 03:58:11</span>
    <span class="wrn"> [WARN]</span>
    <span class="svc"> aglg-db-replica</span> Replication lag 38s (threshold: 30s)</div>
  <div class="log-line"><span class="ts">2025-04-18 03:00:00</span>
    <span class="inf"> [INFO]</span>
    <span class="svc"> aglg-monitor</span> NOC dashboard started on :5000</div>
</div></body></html>
HTML

cat > /etc/apache2/sites-available/noc-decoy.conf << 'APACHECONF'
<VirtualHost *:9093>
    DocumentRoot /var/www/html/noc-alertmgr
    DirectoryIndex index.html
    Options -Indexes
    Header always set X-Alertmanager-Version "0.26.0"
    ErrorLog  ${APACHE_LOG_DIR}/noc-alertmgr-error.log
    CustomLog ${APACHE_LOG_DIR}/noc-alertmgr-access.log combined
</VirtualHost>
<VirtualHost *:5601>
    DocumentRoot /var/www/html/noc-logviewer
    DirectoryIndex index.html
    Options -Indexes
    Header always set X-Powered-By "AGLG-NOC-Logview/1.0"
    ErrorLog  ${APACHE_LOG_DIR}/noc-logviewer-error.log
    CustomLog ${APACHE_LOG_DIR}/noc-logviewer-access.log combined
</VirtualHost>
APACHECONF

a2ensite noc-decoy.conf 2>/dev/null || true
systemctl enable apache2 --quiet
systemctl start apache2
info "Apache Alertmanager :9093, Log Viewer :5601"

# =============================================================================
# 4. REDIS — NOC Session Cache (Port 6379)
# =============================================================================
section "Redis — NOC Session Cache (Port 6379)"
pkg_install redis-server

REDIS_PASS="NocCache2024Aglg"

sed -i 's/^bind .*/bind 0.0.0.0/' /etc/redis/redis.conf
sed -i '/^requirepass /d' /etc/redis/redis.conf
echo "requirepass ${REDIS_PASS}" >> /etc/redis/redis.conf
sed -i 's/^protected-mode .*/protected-mode no/' /etc/redis/redis.conf

systemctl enable redis-server --quiet
systemctl restart redis-server 2>/dev/null || systemctl start redis-server
sleep 2

redis-cli -a "${REDIS_PASS}" SET "session:noc-ops-001" \
    '{"user":"noc_operator","role":"operator"}' 2>/dev/null || true
redis-cli -a "${REDIS_PASS}" LPUSH "queue:alerts" \
    "NodeDown:aglg-backup" "HighLag:aglg-db-replica" 2>/dev/null || true

info "Redis NOC cache :6379"

# =============================================================================
# 5. SNMP (Port 161 UDP)
# =============================================================================
section "SNMP — NOC Node (Port 161)"
pkg_install snmpd snmp

cat > /etc/snmp/snmpd.conf << 'SNMP'
agentAddress udp:161,tcp:161
rocommunity public default
rocommunity aglg_noc 195.0.0.0/8
sysLocation "AGLG Private Network — NOC Monitoring Node — Rack N-01"
sysContact  "NOC Team <noc@aglg-logistics.com>"
sysName     "aglg-monitor.aglg-logistics.com"
sysDescr    "AGLG Infrastructure Monitoring Dashboard — Ubuntu 22.04 LTS"
sysServices 76
SNMP

systemctl enable snmpd --quiet
systemctl restart snmpd 2>/dev/null || systemctl start snmpd
info "SNMP :161"

# =============================================================================
# 6. DECOY CONFIG FILES
# =============================================================================
section "Decoy Config Files"

mkdir -p /opt/noc-agent/conf
mkdir -p /opt/aglg-monitor-agent/conf

cat > /opt/noc-agent/conf/config.json << 'JSON'
{
  "service":   "noc-agent",
  "version":   "1.4.1",
  "listen_port": 3200,
  "redis": {
    "host":     "127.0.0.1",
    "port":     6379,
    "password": "NocCache2024Aglg"
  },
  "prometheus": "http://127.0.0.1:9090",
  "api_token": "AGLG-NOC-AGENT-XXXXXXXXXXXXXXXXXXXXXXXX",
  "_note": "Token scoped to noc-agent only"
}
JSON
chmod 640 /opt/noc-agent/conf/config.json

cat > /opt/aglg-monitor-agent/conf/monitor.conf << 'CONF'
[monitor]
service     = aglg-noc-monitor-agent
version     = 1.4.1
listen_port = 3200
[upstream]
grafana_url     = http://127.0.0.1:3000
prometheus_url  = http://127.0.0.1:9090
alertmanager_url= http://127.0.0.1:9093
poll_interval_s = 30
[auth]
mgmt_token  = NOC-MGMT-XXXXXXXXXXXXXXXXXXXXXXXX
[vault_hint]
# Vault service note — connection details withheld per security policy
# Contact: vault-ops@aglg-logistics.com
vault_cache_valid = false
CONF
chmod 640 /opt/aglg-monitor-agent/conf/monitor.conf

if [[ ! -f /var/log/aglg_monitor.log ]]; then
    cat > /var/log/aglg_monitor.log << 'LOG'
[2025-04-18 03:00:00] INFO  aglg-monitor service started
[2025-04-18 03:00:02] INFO  NOC dashboard on :5000 — OK
[2025-04-18 04:00:00] INFO  Health poll — 5/7 nodes healthy
LOG
fi

info "Decoy configs in /opt/noc-agent, /opt/aglg-monitor-agent"

# =============================================================================
# 7. SOCAT (Ports 9100, 3200)
# =============================================================================
section "Socat Decoy Listeners (Ports 9100, 3200)"
pkg_install socat

declare -A DECOYS
DECOYS[9100]='HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\n\r\n# HELP node_cpu_seconds_total CPU\nnode_cpu_seconds_total{mode="idle"} 1.84e+08\n'
DECOYS[3200]='HTTP/1.0 200 OK\r\nContent-Type: application/json\r\n\r\n{"status":"ok","service":"noc-agent","version":"1.4.1"}\r\n'

for PORT in "${!DECOYS[@]}"; do
    BANNER="${DECOYS[$PORT]}"
    cat > /usr/local/bin/decoy-r2m4-${PORT}.sh << SOCAT
#!/bin/bash
while true; do
    printf '${BANNER}' | socat TCP-LISTEN:${PORT},reuseaddr,fork STDIN 2>/dev/null \
        || sleep 2
done
SOCAT
    chmod +x /usr/local/bin/decoy-r2m4-${PORT}.sh
    cat > /etc/systemd/system/decoy-r2m4-${PORT}.service << SVC
[Unit]
Description=R2M4 Decoy Listener Port ${PORT}
After=network.target
[Service]
ExecStart=/usr/local/bin/decoy-r2m4-${PORT}.sh
Restart=always
RestartSec=3
User=nobody
[Install]
WantedBy=multi-user.target
SVC
done

systemctl daemon-reload
for PORT in "${!DECOYS[@]}"; do
    systemctl enable  decoy-r2m4-${PORT}.service --quiet
    systemctl restart decoy-r2m4-${PORT}.service 2>/dev/null \
        || systemctl start decoy-r2m4-${PORT}.service
done
info "Socat decoys :9100 :3200"

# =============================================================================
# 8. UFW
# =============================================================================
section "UFW — Allow Ports"
if command -v ufw &>/dev/null; then
    ufw allow 22   &>/dev/null || true   # SSH — netops user
    ufw allow 5000 &>/dev/null || true   # real Flask cmd-injection challenge
    ufw --force enable &>/dev/null || true
    for PORT in 161/udp 3000 3200 5601 6379 9090 9093 9100; do
        ufw allow "$PORT" &>/dev/null || true
    done
    info "UFW rules added (22 + 5000 + decoy ports)"
fi

# =============================================================================
# SUMMARY
# =============================================================================
section "M4 Decoy Setup Complete — aglg-monitor"
cat << 'SUMMARY'
================================================================
  M4: aglg-monitor — Decoy Services (Range 2)
  Challenge: OS Cmd Injection on Flask NOC (Port 5000 — UNTOUCHED)
             /opt/aglg/flag4.txt, /opt/aglg/hint_m5.txt — UNTOUCHED
----------------------------------------------------------------
  Nginx  :3000  Grafana NOC dashboard
  Python :9090  Prometheus lookalike
  Apache :9093  Alertmanager lookalike
  Apache :5601  NOC log viewer
  Redis  :6379  NOC session cache
  SNMP   :161   communities: public, aglg_noc
  Socat  :9100  node-exporter
  Socat  :3200  noc-agent

  SSH  :22    — UNTOUCHED
  App  :5000  — UNTOUCHED
  /opt/aglg/monitor/ — UNTOUCHED
================================================================
SUMMARY
