#!/bin/bash
# Operation BlackVault — M3: aglg-hrportal  (Unrestricted File Upload → Webshell)
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[*] M3 aglg-hrportal setup"

# ── dependencies ──────────────────────────────────────────────────────────────
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y apache2 php8.1 libapache2-mod-php8.1 \
    php8.1-sqlite3 nmap openssh-server 2>/dev/null

# ── deploy app ────────────────────────────────────────────────────────────────
mkdir -p /var/www/aglg-hr/uploads
cp -r "$SCRIPT_DIR/app/." /var/www/aglg-hr/
chown -R www-data:www-data /var/www/aglg-hr/
chmod 755 /var/www/aglg-hr/uploads

# ── Apache vhost on port 8080 ─────────────────────────────────────────────────
cat > /etc/apache2/ports.conf <<'PORTS'
Listen 80
Listen 8080
PORTS

cat > /etc/apache2/sites-available/aglg-hr.conf <<'VHOST'
<VirtualHost *:8080>
    ServerName aglg-hrportal
    DocumentRoot /var/www/aglg-hr
    <Directory /var/www/aglg-hr>
        AllowOverride All
        Require all granted
    </Directory>
    <Directory /var/www/aglg-hr/uploads>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
        # VULNERABILITY: No PHP execution restriction on uploads dir
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/aglg-hr-error.log
    CustomLog ${APACHE_LOG_DIR}/aglg-hr-access.log combined
</VirtualHost>
VHOST

a2ensite aglg-hr.conf
a2dissite 000-default.conf 2>/dev/null || true
systemctl restart apache2

# ── create HR user + SSH creds ────────────────────────────────────────────────
id hr_ops &>/dev/null || useradd -m -s /bin/bash hr_ops
echo "hr_ops:HR0ps@AGLG24" | chpasswd
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh

# ── flag ───────────────────────────────────────────────────────────────────────
FLAG="FLAG{$(openssl rand -hex 8)_webshell_rce}"
mkdir -p /opt/aglg
echo "$FLAG" > /opt/aglg/flag3.txt
chmod 644 /opt/aglg/flag3.txt   # readable after file upload RCE

cat > /opt/aglg/hint_m4.txt <<'EOF'
[AGLG INTERNAL — NETWORK OPERATIONS MEMO]
Infrastructure monitoring dashboard deployed on private network — port 5000 (Python/Flask).
Operator credential: netops / N3t0ps@Mon1t0r
Scan 195.0.0.0/8 on port 5000.
EOF
chmod 644 /opt/aglg/hint_m4.txt

echo "========================================" >> /root/ctf_setup_log.txt
echo "M3 (aglg-hrportal) Flag: $FLAG"          >> /root/ctf_setup_log.txt
echo "Setup: $(date)"                           >> /root/ctf_setup_log.txt
echo "[ok] M3 done — port 8080"
