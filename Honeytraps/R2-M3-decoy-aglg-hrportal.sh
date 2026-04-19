#!/usr/bin/env bash
# =============================================================================
#  DECOY SETUP — M3: aglg-hrportal  (Operation BlackVault / Range 2)
#  Challenge : Unrestricted File Upload → PHP Webshell — Port 8080
#  Network   : v-DMZ + v-Priv
#  NEVER TOUCH: Port 8080 (real Apache/PHP app, www-data)
#               Port 80   (Apache already bound from real setup — Listen 80 in ports.conf)
#               Port 22   (SSH, hr_ops user)
#               /var/www/aglg-hr/ (real PHP app)
#               /opt/aglg/flag3.txt, /opt/aglg/hint_m4.txt
#               Apache configuration — Apache IS the real app server
#  !!CRITICAL!! DO NOT call apache_prepare() — Apache must keep running on :8080
#               Use NGINX ONLY for all decoy web services on this machine
#  Run as    : sudo bash M3-decoy-aglg-hrportal.sh
# =============================================================================

set -euo pipefail
LOG="/root/decoy_setup_log_R2M3.txt"
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

# !! nginx_prepare() only — NEVER call apache_prepare() on M3 !!
nginx_prepare() {
    pkg_install nginx
    systemctl stop nginx 2>/dev/null || true
    systemctl reset-failed nginx 2>/dev/null || true
    rm -f /etc/nginx/sites-enabled/default
    rm -f /etc/nginx/conf.d/*.conf 2>/dev/null || true
}

# =============================================================================
# PREFLIGHT — Verify real Apache is still running before we proceed
# =============================================================================
section "Preflight — Verifying Real Apache on :8080 Is Intact"

if systemctl is-active apache2 &>/dev/null; then
    info "Apache2 is running — real HR portal is intact"
else
    warn "Apache2 is NOT running — real portal may be down. Proceeding with decoys only."
fi

# =============================================================================
# 1. NGINX — Fake AGLG HR Document Vault (Port 8443)
#    Looks like another HR-themed portal — adds upload-path ambiguity
# =============================================================================
section "Nginx — AGLG HR Document Vault Portal (Port 8443)"

nginx_prepare

mkdir -p /var/www/html/hr-vault/api
mkdir -p /var/www/html/hr-vault/login
mkdir -p /var/www/html/hr-vault/documents
mkdir -p /var/www/html/hr-vault/uploads-archive

cat > /var/www/html/hr-vault/index.html << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>AGLG HR — Employee Document Vault</title>
  <style>
    *{margin:0;padding:0;box-sizing:border-box}
    body{background:#0f1117;color:#e2e8f0;font-family:'Inter',sans-serif}
    header{background:#1a2035;border-bottom:2px solid #2d5be3;
           padding:14px 28px;display:flex;justify-content:space-between;
           align-items:center}
    .brand{display:flex;align-items:center;gap:10px}
    .brand-icon{background:#2d5be3;color:#fff;width:34px;height:34px;
                border-radius:6px;display:flex;align-items:center;
                justify-content:center;font-weight:700;font-size:.85rem}
    .brand-text h1{font-size:.9rem;color:#e2e8f0;letter-spacing:1px}
    .brand-text p{font-size:.68rem;color:#6b7280}
    .sidebar{width:220px;position:fixed;top:62px;left:0;height:calc(100% - 62px);
             background:#141928;border-right:1px solid #1e2845;padding:20px 0}
    .sidebar a{display:block;padding:10px 20px;color:#94a3b8;font-size:.82rem;
               text-decoration:none;border-left:3px solid transparent}
    .sidebar a:hover,.sidebar a.active{color:#5b8def;border-left-color:#5b8def;
                                       background:#1a2035}
    .main{margin-left:220px;padding:28px}
    .grid{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-top:20px}
    .card{background:#141928;border:1px solid #1e2845;border-radius:6px;padding:20px}
    .card h3{font-size:.8rem;color:#5b8def;text-transform:uppercase;
             letter-spacing:1px;margin-bottom:12px}
    .card p{font-size:.82rem;color:#6b7280;line-height:1.6}
    .card a{color:#38bdf8;font-size:.8rem;text-decoration:none;
            display:block;margin-top:10px}
    .stat{font-size:2rem;font-weight:300;color:#e2e8f0}
  </style>
</head>
<body>
<header>
  <div class="brand">
    <div class="brand-icon">HR</div>
    <div class="brand-text">
      <h1>AGLG HUMAN RESOURCES</h1>
      <p>Employee Document Vault — v2.3</p>
    </div>
  </div>
  <nav><a href="/login/" style="color:#94a3b8;font-size:.82rem;text-decoration:none">
    Sign In</a></nav>
</header>
<div class="sidebar">
  <a href="/documents/" class="active">&#128194; My Documents</a>
  <a href="/uploads-archive/">&#128190; Upload Archive</a>
  <a href="/api/status">&#9881; API Status</a>
  <a href="/login/">&#128274; Sign In</a>
</div>
<div class="main">
  <h2>Employee Document Vault</h2>
  <p style="color:#6b7280;font-size:.85rem;margin-top:6px">
    Submit employment documents, contracts, and compliance certificates</p>
  <div class="grid">
    <div class="card">
      <h3>My Documents</h3>
      <div class="stat">14</div>
      <p>Documents on file</p>
      <a href="/documents/">→ View Documents</a>
    </div>
    <div class="card">
      <h3>Pending Review</h3>
      <div class="stat">2</div>
      <p>Awaiting HR approval</p>
      <a href="/documents/">→ Check Status</a>
    </div>
    <div class="card">
      <h3>Submit Document</h3>
      <p>Upload a new employment document for HR review</p>
      <a href="/login/">→ Login to Upload</a>
    </div>
  </div>
</div>
</body>
</html>
HTML

cat > /var/www/html/hr-vault/login/index.html << 'HTML'
<!DOCTYPE html><html><head><title>AGLG HR Vault — Login</title>
<style>body{background:#0f1117;display:flex;justify-content:center;
  align-items:center;height:100vh;margin:0;font-family:sans-serif}
.box{background:#141928;border:1px solid #1e2845;padding:40px;
     width:360px;border-radius:6px}
h2{color:#e2e8f0;margin-bottom:4px}p{color:#6b7280;font-size:.85rem;margin-bottom:24px}
input{width:100%;padding:10px 12px;background:#0f1117;border:1px solid #1e2845;
      color:#e2e8f0;border-radius:4px;margin:6px 0;box-sizing:border-box}
button{width:100%;padding:10px;background:#2d5be3;border:none;color:#fff;
       border-radius:4px;cursor:pointer;font-weight:600;margin-top:8px}
small{display:block;text-align:center;margin-top:14px;color:#444;font-size:.75rem}
</style></head><body>
<div class="box">
  <h2>HR Document Vault</h2>
  <p>Employee self-service — authorized personnel only</p>
  <input type="text" placeholder="Employee ID">
  <input type="password" placeholder="Password">
  <button>Sign In</button>
  <small>Access restricted to AGLG employees only</small>
</div></body></html>
HTML

cat > /var/www/html/hr-vault/api/status << 'JSON'
{"service":"hr-vault","version":"2.3.0","status":"operational",
 "documents_indexed":1842,"storage_used_gb":12.4}
JSON

# Note: this /uploads-archive/ is a STATIC decoy — it's just HTML, not executable PHP
# It simulates an older upload listing page with no real file execution
cat > /var/www/html/hr-vault/uploads-archive/index.html << 'HTML'
<!DOCTYPE html><html><head><title>AGLG HR — Upload Archive</title></head><body>
<h2>Upload Archive (Read-Only)</h2>
<p>This directory contains archived submissions. Files are stored in read-only mode.</p>
<ul>
  <li>contract_emp_4821.pdf — 2025-03-14</li>
  <li>id_proof_emp_5102.jpg — 2025-03-18</li>
  <li>tax_decl_2024_emp_4821.pdf — 2025-04-01</li>
</ul>
<p><small>Contact hr-ops@aglg-logistics.com for access.</small></p>
</body></html>
HTML

cat > /etc/nginx/sites-available/hr-vault << 'NGINX'
server {
    listen 8443 default_server;
    root /var/www/html/hr-vault;
    index index.html;
    server_name _;
    add_header X-Powered-By "AGLG-HR/2.3" always;
    location /api/ {
        default_type application/json;
        try_files $uri $uri/ =404;
    }
    location / { try_files $uri $uri/index.html =404; }
    access_log /var/log/nginx/hr-vault-access.log;
    error_log  /var/log/nginx/hr-vault-error.log;
}
NGINX

ln -sf /etc/nginx/sites-available/hr-vault \
       /etc/nginx/sites-enabled/hr-vault

# =============================================================================
# 2. NGINX — AGLG Employee Directory (Port 9000)
#    Second nginx vhost — employee lookup lookalike
# =============================================================================
section "Nginx — AGLG Employee Directory (Port 9000)"

mkdir -p /var/www/html/hr-directory/api/employees
mkdir -p /var/www/html/hr-directory/api/departments

cat > /var/www/html/hr-directory/index.html << 'HTML'
<!DOCTYPE html><html><head><title>AGLG Employee Directory</title>
<style>body{background:#f5f7fa;font-family:sans-serif;margin:0}
header{background:#003366;color:#fff;padding:14px 24px}
header h1{font-size:1.1rem;margin:0}
.content{padding:24px}
.search{width:100%;max-width:400px;padding:10px;border:1px solid #ccc;
        border-radius:4px;margin-bottom:20px;font-size:.9rem}
table{width:100%;border-collapse:collapse;font-size:.87em}
th{background:#003366;color:#fff;padding:10px;text-align:left}
td{padding:9px;border-bottom:1px solid #eee}
</style></head><body>
<header><h1>AGLG Human Resources — Employee Directory</h1></header>
<div class="content">
  <input type="text" class="search" placeholder="Search by name, department, or employee ID...">
  <table>
    <tr><th>Employee ID</th><th>Name</th><th>Department</th><th>Location</th><th>Status</th></tr>
    <tr><td>EMP-4821</td><td>M. Rashid</td><td>Freight Operations</td>
        <td>Dubai</td><td>Active</td></tr>
    <tr><td>EMP-5102</td><td>S. Patel</td><td>Customs Compliance</td>
        <td>Mumbai</td><td>Active</td></tr>
    <tr><td>EMP-3310</td><td>T. Weber</td><td>IT Operations</td>
        <td>Hamburg</td><td>Active</td></tr>
    <tr><td>EMP-6044</td><td>A. Chen</td><td>HR Administration</td>
        <td>Singapore</td><td>Active</td></tr>
    <tr><td>EMP-7218</td><td>K. Al-Sayed</td><td>Logistics</td>
        <td>Jeddah</td><td>On Leave</td></tr>
  </table>
</div></body></html>
HTML

cat > /var/www/html/hr-directory/api/employees/list.json << 'JSON'
{"total":247,"departments":["Freight Ops","Customs","IT Ops","HR Admin","Logistics"],
 "endpoint_note":"Full employee list requires HR-ADMIN token"}
JSON

cat > /var/www/html/hr-directory/api/departments/list.json << 'JSON'
{"departments":[
  {"name":"Freight Operations","head":"Director-FO","headcount":84},
  {"name":"Customs Compliance","head":"Director-CC","headcount":31},
  {"name":"IT Operations","head":"Director-IT","headcount":22},
  {"name":"HR Administration","head":"Director-HR","headcount":18}
]}
JSON

# Add second server block to same nginx config file
cat > /etc/nginx/sites-available/hr-directory << 'NGINX'
server {
    listen 9000 default_server;
    root /var/www/html/hr-directory;
    index index.html;
    server_name _;
    add_header X-Powered-By "AGLG-HR-Dir/1.0" always;
    location /api/ {
        default_type application/json;
        try_files $uri $uri/ =404;
    }
    location / { try_files $uri $uri/ =404; }
    access_log /var/log/nginx/hr-directory-access.log;
    error_log  /var/log/nginx/hr-directory-error.log;
}
NGINX

ln -sf /etc/nginx/sites-available/hr-directory \
       /etc/nginx/sites-enabled/hr-directory

nginx -t
systemctl enable nginx --quiet
systemctl start nginx
info "Nginx HR vault :8443, employee directory :9000"

# =============================================================================
# 3. REDIS — HR Session Cache (Port 6379)
# =============================================================================
section "Redis — HR Session Cache (Port 6379)"
pkg_install redis-server

REDIS_PASS="HrCache2024Aglg"

sed -i 's/^bind .*/bind 0.0.0.0/' /etc/redis/redis.conf
sed -i '/^requirepass /d' /etc/redis/redis.conf
echo "requirepass ${REDIS_PASS}" >> /etc/redis/redis.conf
sed -i 's/^protected-mode .*/protected-mode no/' /etc/redis/redis.conf

systemctl enable redis-server --quiet
systemctl restart redis-server 2>/dev/null || systemctl start redis-server
sleep 2

redis-cli -a "${REDIS_PASS}" SET "session:hr-mgmt-001" \
    '{"user":"hr_manager","role":"manager"}' 2>/dev/null || true
redis-cli -a "${REDIS_PASS}" SET "cache:employee_count" "247" 2>/dev/null || true

info "Redis HR cache :6379"

# =============================================================================
# 4. VSFTPD — HR Document Archive FTP (Port 21)
# =============================================================================
section "vsftpd — HR Document FTP (Port 21)"
pkg_install vsftpd

useradd -m -s /bin/false hr-ftp 2>/dev/null || true
echo "hr-ftp:HrFtp2024Aglg" | chpasswd

mkdir -p /srv/ftp/hr-templates
mkdir -p /srv/ftp/hr-policies
mkdir -p /srv/ftp/hr-archive
chown -R nobody:nogroup /srv/ftp 2>/dev/null || true

cat > /srv/ftp/hr-templates/employment-contract-template.txt << 'TXT'
AGLG EMPLOYMENT CONTRACT TEMPLATE
====================================
[Employee Name]
[Employee ID]
[Department]
[Start Date]
[Salary Band]
This is a template. Completed contracts require HR-ADMIN signature.
Contact: contracts@aglg-logistics.com
TXT

cat > /srv/ftp/hr-policies/AGLG-IT-Policy-2025.txt << 'TXT'
AGLG IT SECURITY POLICY 2025
==============================
1. All systems require MFA for remote access.
2. Document uploads must be scanned for malware prior to submission.
3. File uploads are restricted to: PDF, DOC, DOCX, JPG, PNG, ZIP.
4. Web shells and executable scripts are STRICTLY prohibited.
Contact: security@aglg-logistics.com
TXT

cat > /srv/ftp/hr-archive/README.txt << 'TXT'
HR Archive Repository
======================
Archived HR documents. Access via hr-ftp account.
For current submissions use the HR portal on port 8080.
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
ftpd_banner=AGLG HR Document Archive FTP — Authorized Personnel Only
anon_root=/srv/ftp
local_root=/srv/ftp
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
VSFTPD

systemctl enable vsftpd --quiet
systemctl restart vsftpd 2>/dev/null || systemctl start vsftpd
info "vsftpd HR FTP :21"

# =============================================================================
# 5. SNMP (Port 161 UDP)
# =============================================================================
section "SNMP — HR Portal Node (Port 161)"
pkg_install snmpd snmp

cat > /etc/snmp/snmpd.conf << 'SNMP'
agentAddress udp:161,tcp:161
rocommunity public default
rocommunity aglg_hr 11.0.0.0/8
rocommunity aglg_hr 195.0.0.0/8
sysLocation "AGLG DMZ/Private — HR Portal Node — Rack H-02"
sysContact  "HR IT <hr-it@aglg-logistics.com>"
sysName     "aglg-hrportal.aglg-logistics.com"
sysDescr    "AGLG HR Self-Service Portal — Ubuntu 22.04 LTS"
sysServices 76
SNMP

systemctl enable snmpd --quiet
systemctl restart snmpd 2>/dev/null || systemctl start snmpd
info "SNMP :161"

# =============================================================================
# 6. DECOY CONFIG FILES
# =============================================================================
section "Decoy Config Files"

mkdir -p /opt/aglg-hr-agent/conf
mkdir -p /opt/aglg-hr-agent/keys

cat > /opt/aglg-hr-agent/conf/config.json << 'JSON'
{
  "service":   "hr-portal-agent",
  "version":   "2.3.0",
  "listen_port": 9100,
  "redis": {
    "host": "127.0.0.1",
    "port": 6379,
    "password": "HrCache2024Aglg"
  },
  "api_token": "AGLG-HR-AGENT-XXXXXXXXXXXXXXXXXXXXXXXX",
  "_note": "Token for hr-portal-agent only — not for SSH or downstream services"
}
JSON
chmod 640 /opt/aglg-hr-agent/conf/config.json

# Decoy SSH key file — wrong service context, different path from real hr_ops key
cat > /opt/aglg-hr-agent/keys/hr_deploy.pem << 'PEM'
-----BEGIN OPENSSH PRIVATE KEY-----
DECOY — HR-AGENT DEPLOY KEY — NOT VALID FOR REMOTE SSH — LOCAL CI/CD ONLY
Target: hr-portal-agent@aglg-hrportal.aglg-logistics.com (local service pipeline)
This key is for the hr-portal-agent deployment pipeline ONLY.
It cannot authenticate to any user account on this or any other host.
Issued: 2025-01-10 | DO NOT USE FOR SSH
b3BlbnNzaC1rZXktdjEAAAAA -- DECOY ONLY --
-----END OPENSSH PRIVATE KEY-----
PEM
chmod 600 /opt/aglg-hr-agent/keys/hr_deploy.pem

mkdir -p /var/log/aglg-hr-agent
cat > /var/log/aglg-hr-agent/agent.log << 'LOG'
2025-04-18 03:00:01 [INFO]  hr-portal-agent started v2.3.0
2025-04-18 03:00:03 [INFO]  Redis connected
2025-04-18 03:00:05 [INFO]  HR portal on :8080 — reachable
2025-04-18 04:00:00 [INFO]  Heartbeat OK — 247 employees indexed
LOG

info "Decoy configs in /opt/aglg-hr-agent"

# =============================================================================
# 7. SOCAT (Ports 9100, 4100)
# =============================================================================
section "Socat Decoy Listeners (Ports 9100, 4100)"
pkg_install socat

declare -A DECOYS
DECOYS[9100]='HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\n\r\n# HELP node_cpu node\nnode_cpu_seconds_total{mode="idle"} 1.2e+08\n'
DECOYS[4100]='HTTP/1.0 200 OK\r\nContent-Type: application/json\r\n\r\n{"status":"ok","service":"hr-portal-agent","version":"2.3.0"}\r\n'

for PORT in "${!DECOYS[@]}"; do
    BANNER="${DECOYS[$PORT]}"
    cat > /usr/local/bin/decoy-r2m3-${PORT}.sh << SOCAT
#!/bin/bash
while true; do
    printf '${BANNER}' | socat TCP-LISTEN:${PORT},reuseaddr,fork STDIN 2>/dev/null \
        || sleep 2
done
SOCAT
    chmod +x /usr/local/bin/decoy-r2m3-${PORT}.sh
    cat > /etc/systemd/system/decoy-r2m3-${PORT}.service << SVC
[Unit]
Description=R2M3 Decoy Listener Port ${PORT}
After=network.target
[Service]
ExecStart=/usr/local/bin/decoy-r2m3-${PORT}.sh
Restart=always
RestartSec=3
User=nobody
[Install]
WantedBy=multi-user.target
SVC
done

systemctl daemon-reload
for PORT in "${!DECOYS[@]}"; do
    systemctl enable  decoy-r2m3-${PORT}.service --quiet
    systemctl restart decoy-r2m3-${PORT}.service 2>/dev/null \
        || systemctl start decoy-r2m3-${PORT}.service
done
info "Socat decoys :9100 :4100"

# =============================================================================
# 8. UFW
# =============================================================================
section "UFW — Allow Ports"
if command -v ufw &>/dev/null; then
    ufw allow 22   &>/dev/null || true   # SSH — hr_ops user
    ufw allow 80   &>/dev/null || true   # Apache bound (Listen 80 in ports.conf)
    ufw allow 8080 &>/dev/null || true   # real Apache/PHP upload challenge
    ufw --force enable &>/dev/null || true
    for PORT in 21 161/udp 6379 8443 9000 9100 4100; do
        ufw allow "$PORT" &>/dev/null || true
    done
    info "UFW rules added (22 + 80 + 8080 + decoy ports)"
fi

# =============================================================================
# SUMMARY
# =============================================================================
section "M3 Decoy Setup Complete — aglg-hrportal"
cat << 'SUMMARY'
================================================================
  M3: aglg-hrportal — Decoy Services (Range 2)
  Challenge: File Upload → PHP Webshell (Port 8080 — UNTOUCHED)
             Apache config — UNTOUCHED
             /var/www/aglg-hr/ — UNTOUCHED
----------------------------------------------------------------
  Nginx  :8443  AGLG HR Document Vault (static — no PHP exec)
  Nginx  :9000  Employee Directory
  Redis  :6379  HR session cache
  vsftpd :21    HR document archive FTP
  SNMP   :161   communities: public, aglg_hr
  Socat  :9100  node-exporter
  Socat  :4100  hr-portal-agent

  SSH  :22    — UNTOUCHED
  App  :8080  — UNTOUCHED (Apache/PHP)
  Apache config — UNTOUCHED
================================================================
SUMMARY
