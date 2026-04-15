# Operation BlackVault — AGLG Breach Scenario

**Theme:** Arkanis Global Logistics Group (AGLG) — Multinational Cargo & Supply Chain Conglomerate  
**Operation Name:** OPERATION BLACKVAULT  
**Format:** Linear lateral movement chain, 5 machines, Red & Blue perspectives  
**Difficulty:** Intermediate → Intermediate-Hard → Hard → Critical  
**Platform:** Ubuntu 22.04 LTS (Jammy), OpenStack (no Docker)

---

## Quick Setup (run on each VM after cloning repo)

```bash
git clone https://github.com/hacktifytechnologies/Range5.git /opt/ctf
sudo bash /opt/ctf/machines/M1-aglg-portal/setup.sh      # M1
sudo bash /opt/ctf/machines/M2-aglg-warehouse/setup.sh   # M2
sudo bash /opt/ctf/machines/M3-aglg-hrportal/setup.sh    # M3
sudo bash /opt/ctf/machines/M4-aglg-monitor/setup.sh     # M4
sudo bash /opt/ctf/machines/M5-aglg-vault/setup.sh       # M5
# Retrieve flags from /root/ctf_setup_log.txt on each VM
```

---

## Machine Summary

| # | Hostname          | Service               | Vulnerability                          | MITRE            |
|---|-------------------|-----------------------|----------------------------------------|------------------|
| 1 | aglg-portal       | Flask/Python :80      | SQL Injection → Auth Bypass + RCE      | T1190            |
| 2 | aglg-warehouse    | Node.js/Express :3000 | IDOR / Broken Access Control           | T1078, T1087     |
| 3 | aglg-hrportal     | PHP/Apache :8080      | Unrestricted File Upload → Webshell    | T1190, T1059.004 |
| 4 | aglg-monitor      | Flask/Python :5000    | OS Command Injection (ping utility)    | T1059.004        |
| 5 | aglg-vault        | Go HTTP :8443         | LFI Path Traversal + SUID Binary       | T1083, T1548.001 |

---

## OpenStack Network Assignment

| Machine | Hostname          | Networks                         |
|---------|-------------------|----------------------------------|
| M1      | aglg-portal       | v-Pub-subnet + v-DMZ-subnet      |
| M2      | aglg-warehouse    | v-DMZ-subnet                     |
| M3      | aglg-hrportal     | v-DMZ-subnet + v-Priv-subnet     |
| M4      | aglg-monitor      | v-Priv-subnet                    |
| M5      | aglg-vault        | v-Priv-subnet                    |

---

## Credentials Chain (for CTF admin reference)

```
M1 SQLi Bypass  →  /opt/aglg/classified/hint.txt   →  "Warehouse API on DMZ:3000 | vendor_ops:V3nd0r@AGLG"
M2 IDOR         →  /api/inventory/0 internal_note   →  hr_ops : HR0ps@AGLG24  (M3 SSH)
M3 File Upload  →  /opt/aglg/hint_m4.txt            →  netops : N3t0ps@Mon1t0r  (M4 :5000)
M4 Cmd Inject   →  /opt/aglg/hint_m5.txt            →  archivist : Arch1v1st@AGLG  (M5 SSH)
M5 LFI + SUID   →  /root/flag5.txt                  →  FINAL FLAG
```

---

## TTP Usage (Caldera)

- **`ttps/red/`** — Run on target VMs to configure the vulnerable environment (alternative to setup.sh)
- **`ttps/blue/`** — Run on compromised VMs to simulate attacker actions and generate detectable logs
