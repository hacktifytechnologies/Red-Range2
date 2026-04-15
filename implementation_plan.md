# Range-5 — Operation BlackVault | Proposal

**Theme:** Arkanis Global Logistics Group (AGLG) — Multinational Cargo & Supply Chain Conglomerate  
**Operation Name:** OPERATION BLACKVAULT  
**Format:** Linear lateral movement chain, 5 machines, Red & Blue perspectives  
**Difficulty:** Intermediate → Hard → Critical  
**Platform:** Ubuntu 22.04 LTS (Jammy), OpenStack (no Docker)  
**Tech Stack:** Python/Flask, Go, Node.js/Express, PHP, Bash — Rich GUI web apps on each  

---

## Architecture (Mirrors Range4 Exactly)

```
Range-5/
├── README.md
├── NETWORK_DIAGRAM.md
├── STORYLINE.md
├── machines/
│   ├── M1-aglg-portal/
│   │   ├── app/
│   │   │   ├── app.py
│   │   │   ├── templates/   (base.html, index.html, login.html, track.html, report.html, ...)
│   │   │   └── static/css/style.css
│   │   ├── setup.sh
│   │   ├── solve_red.md
│   │   └── solve_blue.md
│   ├── M2-aglg-warehouse/
│   │   ├── app/
│   │   │   ├── server.js
│   │   │   ├── package.json
│   │   │   └── public/index.html
│   │   ├── setup.sh
│   │   ├── solve_red.md
│   │   └── solve_blue.md
│   ├── M3-aglg-hrportal/
│   │   ├── app/
│   │   │   ├── index.php
│   │   │   ├── upload.php
│   │   │   └── static/style.css
│   │   ├── setup.sh
│   │   ├── solve_red.md
│   │   └── solve_blue.md
│   ├── M4-aglg-monitor/
│   │   ├── app/
│   │   │   ├── app.py
│   │   │   └── templates/
│   │   ├── setup.sh
│   │   ├── solve_red.md
│   │   └── solve_blue.md
│   └── M5-aglg-vault/
│       ├── app/
│       │   ├── main.go
│       │   └── templates/
│       ├── vault_reader.c        (SUID binary source)
│       ├── setup.sh
│       ├── solve_red.md
│       └── solve_blue.md
└── ttps/
    ├── red/
    │   ├── red_01_sqli_setup.yml
    │   ├── red_02_idor_setup.yml
    │   ├── red_03_fileupload_setup.yml
    │   ├── red_04_cmdi_setup.yml
    │   └── red_05_lfi_suid_setup.yml
    └── blue/
        ├── blue_01_sqli_exploit.yml
        ├── blue_02_idor_exploit.yml
        ├── blue_03_fileupload_exploit.yml
        ├── blue_04_cmdi_exploit.yml
        └── blue_05_lfi_suid_exploit.yml
```

---

## OpenStack Network Topology

```
         [Player — WireGuard VPN]
                   │
         [Floating IP 172.24.4.0/24]  ← M1 only
                   │
      ┌────────────▼─────────────────┐
      │  v-Pub-subnet  203.0.0.0/8   │
      │  ┌──────────────────────┐    │
      │  │  M1: aglg-portal     │    │
      │  │  Flask :80           │    │
      │  │  SQLi Login Bypass   │    │
      │  │  [Pub NIC + DMZ NIC] │    │
      │  └──────────┬───────────┘    │
      └─────────────┼────────────────┘
                    │
      ┌─────────────▼────────────────┐
      │  v-DMZ-subnet  11.0.0.0/8    │
      │  ┌──────────────────────┐    │
      │  │  M2: aglg-warehouse  │    │
      │  │  Node.js/Express:3000│    │
      │  │  IDOR / BAC          │    │
      │  └──────────────────────┘    │
      │  ┌──────────────────────┐    │
      │  │  M3: aglg-hrportal   │    │
      │  │  PHP Apache :8080    │    │
      │  │  Unrestricted Upload │    │
      │  │  [DMZ NIC + Priv NIC]│    │
      │  └──────────┬───────────┘    │
      └─────────────┼────────────────┘
                    │
      ┌─────────────▼────────────────┐
      │  v-Priv-subnet 195.0.0.0/8   │
      │  ┌──────────────────────┐    │
      │  │  M4: aglg-monitor    │    │
      │  │  Python Flask :5000  │    │
      │  │  Command Injection   │    │
      │  └──────────────────────┘    │
      │  ┌──────────────────────┐    │
      │  │  M5: aglg-vault      │    │
      │  │  Go HTTP :8443       │    │
      │  │  LFI + SUID binary   │    │
      │  └──────────────────────┘    │
      └──────────────────────────────┘
```

| Machine | Hostname          | Networks                    |
|---------|-------------------|-----------------------------|
| M1      | aglg-portal       | v-Pub-subnet + v-DMZ-subnet |
| M2      | aglg-warehouse    | v-DMZ-subnet                |
| M3      | aglg-hrportal     | v-DMZ-subnet + v-Priv-subnet|
| M4      | aglg-monitor      | v-Priv-subnet               |
| M5      | aglg-vault        | v-Priv-subnet               |

---

## The 5 Machines — Full Design

### M1 — aglg-portal (Entry Point)
**Application:** AGLG Cargo Tracking & Shipment Portal (Flask/Python)  
**Vulnerability:** SQL Injection → Authentication Bypass → RCE via SQLite write  
**MITRE ATT&CK:** T1190, T1505  
**Port:** 80/tcp  
**Difficulty:** Intermediate  

**Web App Description:**  
A fully-featured, dark-themed shipment intelligence platform for AGLG operators. Pages include:
- `/` — Sign-in page with corporate branding
- `/dashboard` — Cargo tracking dashboard with live status widgets
- `/track` — Shipment search (vulnerable parameter: `shipment_id`)
- `/report` — Internal logistics report generator (accessible post-auth)
- `/inquiry` — Vendor inquiry form (used post-login)

**Exploit Chain:**
1. SQLi on `/login` → `username: admin'--` → bypass authentication
2. Post-auth: enumerated session grants access to `/report`
3. The report generator calls a Python `subprocess` with shipment ID (secondary RCE path)
4. RCE reads `/opt/aglg/classified/flag1.txt` and `hint.txt` pointing to `aglg-warehouse:3000`

**GUI:** Corporate dark navy + orange accent, animated cargo tracker with live route map SVG, glassmorphism cards

---

### M2 — aglg-warehouse (Pivot 1)
**Application:** AGLG Warehouse Inventory Management API + SPA (Node.js/Express)  
**Vulnerability:** Insecure Direct Object Reference (IDOR) — Broken Access Control  
**MITRE ATT&CK:** T1078, T1087  
**Port:** 3000/tcp  
**Difficulty:** Intermediate  

**Web App Description:**  
A modern single-page React-style inventory dashboard served on Express. Endpoints:
- `/` — Interactive inventory dashboard SPA
- `/api/login` — Vendor login (uses JSON body)
- `/api/inventory/:id` — Fetch item by ID (IDOR: no ownership check)
- `/api/shipment/mine` — Own shipments
- `/api/admin/secrets` — Admin-only endpoint exposed  
- `/.well-known/config` — Leaks internal network info and admin user ID

**Exploit Chain:**
1. Login with leaked vendor credentials from M1's hint.txt (`vendor_ops / V3nd0r@AGLG`)
2. Enumerate `/api/inventory/1` through `/api/inventory/999` — ID 0 returns admin object with `internal_note` containing SSH creds for M3
3. Flag embedded in `/api/admin/secrets` (accessible by hitting admin user's ID on IDOR)

**GUI:** Professional warehouse SPA with animated search, inventory grid cards, dark teal + gold palette

---

### M3 — aglg-hrportal (Pivot 2)
**Application:** AGLG Human Resources Self-Service Portal (PHP 8.x + Apache)  
**Vulnerability:** Unrestricted File Upload → Webshell RCE  
**MITRE ATT&CK:** T1190, T1059.004  
**Port:** 8080/tcp  
**Difficulty:** Intermediate-Hard  

**Web App Description:**  
A corporate HR self-service portal for AGLG staff. Features:
- `/` — Employee login with SSO branding
- `/dashboard.php` — HR dashboard with payroll widgets, leave balance, org chart
- `/profile.php` — Employee profile editor
- `/upload.php` — "Document Upload" for contracts/IDs (vulnerable, no extension validation, only client-side check)
- Uploaded files land in `/var/www/aglg-hr/uploads/` (web-accessible)

**Exploit Chain:**
1. SSH into M3 using creds from M2 (`hr_ops : HR0ps@AGLG24`)
2. Or, directly exploit the upload: PHP webshell upload bypassing MIME check
3. Webshell at `/uploads/shell.php?cmd=id` → escalate to www-data → find creds in `/var/www/aglg-hr/config.php`
4. Flag at `/opt/aglg/flag3.txt`, hint.txt points to `aglg-monitor:5000`

**GUI:** Clean enterprise HR portal with blue/white corporate theme, animated sidebar, profile cards, upload progress bar, dark glassmorphism cards

---

### M4 — aglg-monitor (Pivot 3)
**Application:** AGLG Infrastructure Monitoring Dashboard (Python/Flask)  
**Vulnerability:** OS Command Injection via unsanitized ping/traceroute utility  
**MITRE ATT&CK:** T1059.004, T1552  
**Port:** 5000/tcp  
**Difficulty:** Hard  

**Web App Description:**  
A Grafana-inspired network operations center (NOC) dashboard for AGLG's infrastructure team. Features:
- `/` — NOC dashboard with animated uptime graphs, latency heatmaps, live alert ticker
- `/login` — Operator login (static cred from M3 hint)
- `/tools/ping` — Network diagnostic tool: `ping -c 1 <host>` — **injection point**
- `/tools/traceroute` — Traceroute utility — secondary injection
- `/alerts` — Active alert management panel

**Exploit Chain:**
1. Login with creds from M3's hint (`netops : N3t0ps@Mon1t0r`)
2. Inject into the ping utility: `127.0.0.1; cat /opt/aglg/flag4.txt`
3. Escalate: use command injection to add SSH key → SSH as `netops` → sudo enumeration
4. Flag at `/opt/aglg/flag4.txt`, hint.txt reveals vault service on `aglg-vault:8443`

**GUI:** Grafana-style NOC with real-time pseudo-animated line charts (D3.js or CSS animation), terminal-style output pane, dark theme with green/red status LEDs

---

### M5 — aglg-vault (Final)
**Application:** AGLG Classified Assets Vault (Go HTTP server)  
**Vulnerability:** Local File Inclusion (LFI) via path traversal + SUID binary privilege escalation  
**MITRE ATT&CK:** T1083, T1548.001  
**Port:** 8443/tcp  
**Difficulty:** Critical  

**Web App Description:**  
A classified document retrieval portal for senior AGLG executives. Features:
- `/` — Vault login with biometric-style UI
- `/dashboard` — Classified document index (PDF thumbnails)
- `/view?doc=contracts/Q1_2024.pdf` — Document viewer (path traversal: `?doc=../../etc/passwd`)
- `/api/status` — Vault health endpoint

Additionally, a SUID binary `/opt/aglg/vault_reader` that:
- Reads "allowed" files from `/opt/aglg/vault/`
- Uses `strncmp()` with a bypassed length check
- Can be abused: `./vault_reader '../../../../root/flag5.txt'`

**Exploit Chain:**
1. Access via SSH creds from M4's hint (`archivist : Arch1v1st@AGLG`)
2. Exploit LFI: `GET /view?doc=../../../opt/aglg/flag5.txt` to read the flag
3. Alternative full privesc path: exploit SUID `vault_reader` binary
4. **FINAL FLAG** at `/root/flag5.txt`

**GUI:** Premium dark vault interface — deep charcoal + gold, animated lock/unlock transitions, document grid with PDF-style thumbnails, biometric-style progress ring on login

---

## Credentials Chain

```
M1 SQLi Bypass    →  /opt/aglg/classified/hint.txt  →  "Warehouse API at DMZ:3000 | vendor_ops:V3nd0r@AGLG"
M2 IDOR           →  /api/inventory/0 internal_note →  hr_ops : HR0ps@AGLG24  (M3 SSH :22)
M3 File Upload    →  /opt/aglg/hint_m4.txt          →  netops : N3t0ps@Mon1t0r  (M4 :5000)
M4 Cmd Injection  →  /opt/aglg/hint_m5.txt          →  archivist : Arch1v1st@AGLG  (M5 SSH)
M5 LFI + SUID     →  /root/flag5.txt                →  FINAL FLAG
```

---

## Machine Summary Table

| # | Hostname         | Service              | Vulnerability                         | MITRE       | Difficulty   |
|---|------------------|----------------------|---------------------------------------|-------------|--------------|
| 1 | aglg-portal      | Flask/Python :80     | SQL Injection → Auth Bypass + RCE     | T1190       | Intermediate |
| 2 | aglg-warehouse   | Node.js/Express:3000 | IDOR / Broken Access Control          | T1078       | Intermediate |
| 3 | aglg-hrportal    | PHP/Apache :8080     | Unrestricted File Upload → Webshell   | T1190       | Int-Hard     |
| 4 | aglg-monitor     | Flask/Python :5000   | OS Command Injection (ping utility)   | T1059.004   | Hard         |
| 5 | aglg-vault       | Go HTTP :8443        | LFI Path Traversal + SUID Binary      | T1083/T1548 | Critical     |

---

## Red Team Storyline — PHANTOM CIRCUIT APT

You are an operator for **PHANTOM CIRCUIT**, a nation-state threat actor targeting AGLG's supply chain intelligence infrastructure. AGLG's internal logistics data contains classified shipment routes for restricted defense cargo.

**Objectives:**
1. Breach the external cargo tracking portal and establish initial foothold
2. Pivot into the DMZ warehouse inventory system and exfiltrate operator credentials
3. Infiltrate the HR portal via unauthorized file upload and drop a persistent webshell
4. Reach the internal monitoring infrastructure and exploit command injection for lateral movement
5. Penetrate the classified vault and capture the final operational flag

**ROE:** No destructive actions. Credentials flow through the chain — do not brute-force. Operate below the noise floor of AGLG's SOC.

---

## Blue Team Briefing — AGLG SOC

You are part of AGLG's Security Operations Center. PHANTOM CIRCUIT has been observed targeting supply chain infrastructure. Reconstruct the kill chain.

**Key Log Sources:**
- M1: `journalctl -u aglg-portal`, SQLite query logs, auditd execve
- M2: `journalctl -u aglg-warehouse`, Express morgan logs, API access anomalies
- M3: `/var/log/apache2/access.log`, file upload events, webshell execution in PHP-FPM logs
- M4: `journalctl -u aglg-monitor`, auditd subprocess calls, bash history for `netops`
- M5: auditd execve for `vault_reader`, file access logs for `/root/`, `/opt/aglg/vault/`

---

## TTP Files (Caldera-Compatible YAML)

Each machine ships:
- `ttps/red/red_0X_<vuln>_setup.yml` — configures the vulnerable state (idempotent, alternative to setup.sh)
- `ttps/blue/blue_0X_<vuln>_exploit.yml` — simulates the attacker action, generates detectable log artifacts

---

## Flag Format

```
FLAG{<random_hex>_<vuln_tag>}
```

Examples:
- `FLAG{a3f89c12d4e67b01_sqli_auth_bypass}`
- `FLAG{b7d2e441fa908c33_idor_bac}`
- `FLAG{c1a9f3e27b456d88_webshell_rce}`
- `FLAG{d4e8a219c7f03b55_cmdi_netops}`
- `FLAG{e9c1b37f2a048d64_lfi_vault_final}`

Generated dynamically via `openssl rand -hex 8` at setup time and logged to `/root/ctf_setup_log.txt`.

---

## Setup Quick Start

```bash
git clone https://github.com/hacktifytechnologies/Range5.git /opt/ctf
sudo bash /opt/ctf/machines/M1-aglg-portal/setup.sh      # M1
sudo bash /opt/ctf/machines/M2-aglg-warehouse/setup.sh   # M2
sudo bash /opt/ctf/machines/M3-aglg-hrportal/setup.sh    # M3
sudo bash /opt/ctf/machines/M4-aglg-monitor/setup.sh     # M4
sudo bash /opt/ctf/machines/M5-aglg-vault/setup.sh       # M5
# Retrieve flags: cat /root/ctf_setup_log.txt (on each VM)
```
