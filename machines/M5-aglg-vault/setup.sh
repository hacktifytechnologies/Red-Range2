#!/bin/bash
# Operation BlackVault — M5: aglg-vault  (LFI Path Traversal + SUID Binary)
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[*] M5 aglg-vault setup"

# ── dependencies ──────────────────────────────────────────────────────────────
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y golang-go gcc openssh-server nmap 2>/dev/null

# ── create archivist user ──────────────────────────────────────────────────────
id archivist &>/dev/null || useradd -m -s /bin/bash archivist
echo "archivist:Arch1v1st@AGLG" | chpasswd
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh 2>/dev/null || true

# ── vault document structure ──────────────────────────────────────────────────
mkdir -p /opt/aglg/vault/contracts
mkdir -p /opt/aglg/vault/manifests
mkdir -p /opt/aglg/vault/classified

cat > /opt/aglg/vault/contracts/AGX-CONTRACT-Q1-2024.txt <<'DOC'
AGLG CLASSIFIED CONTRACT — Q1 2024
Route: Jeddah → Karachi → Singapore
Cargo: Restricted dual-use electronic components
Signatory: AGLGLogistics Director
Status: ACTIVE
DOC

cat > /opt/aglg/vault/manifests/WH-MANIFEST-SEP-2024.txt <<'DOC'
WAREHOUSE MANIFEST — September 2024
Facility: AGLG Bond Store, Dubai Free Zone
Items: 847 CBM — mixed general cargo
Hazmat: Class 1.4S — exempt quantity
DOC

chown -R archivist:archivist /opt/aglg/vault/
chmod 750 /opt/aglg/vault

# ── final flag (root-owned) ───────────────────────────────────────────────────
FLAG="FLAG{$(openssl rand -hex 8)_lfi_vault_final}"
echo "$FLAG" > /root/flag5.txt
chmod 400 /root/flag5.txt

# ── build and deploy Go vault app ─────────────────────────────────────────────
mkdir -p /opt/aglg/vault-app
cp -r "$SCRIPT_DIR/app/." /opt/aglg/vault-app/
cd /opt/aglg/vault-app
go build -o vault-server . 2>/dev/null
chown archivist:archivist vault-server
chmod 755 vault-server

# ── compile and SUID vault_reader binary ──────────────────────────────────────
gcc -o /opt/aglg/vault_reader "$SCRIPT_DIR/vault_reader.c" -Wall 2>/dev/null
chown root:root /opt/aglg/vault_reader
chmod 4755 /opt/aglg/vault_reader   # SUID bit — runs as root

# ── systemd service ────────────────────────────────────────────────────────────
cat > /etc/systemd/system/aglg-vault.service <<'UNIT'
[Unit]
Description=AGLG Classified Document Vault
After=network.target
[Service]
User=archivist
WorkingDirectory=/opt/aglg/vault-app
ExecStart=/opt/aglg/vault-app/vault-server
Restart=always
RestartSec=3
Environment=VAULT_PORT=8443 VAULT_ROOT=/opt/aglg/vault
[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload && systemctl enable aglg-vault && systemctl start aglg-vault

echo "========================================" >> /root/ctf_setup_log.txt
echo "M5 (aglg-vault) Flag: $FLAG"             >> /root/ctf_setup_log.txt
echo "Setup: $(date)"                           >> /root/ctf_setup_log.txt
echo "[ok] M5 done — port 8443"
