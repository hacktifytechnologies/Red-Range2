## Threat Intelligence Brief
**Target Organization:** Arkanis Global Logistics Group (AGLG)

A multinational cargo and supply chain conglomerate founded in 1989, AGLG operates freight
forwarding, cold-chain logistics, bonded warehousing, and last-mile distribution across 47
countries. The group manages classified contracts with defense ministries for restricted
cargo movement (dual-use goods, munitions components, signals equipment). AGLG's internal
network hosts a full-stack enterprise infrastructure: external-facing cargo portals, DMZ
warehouse inventory APIs, HR self-service systems, internal NOC monitoring dashboards, and
a classified document vault storing contract archives and signatory approval chains.

---

## Red Team Briefing — PHANTOM CIRCUIT APT
You are an operator for **PHANTOM CIRCUIT**, a nation-state threat actor with a mandate to
infiltrate AGLG's internal infrastructure and exfiltrate classified logistics contracts
that detail restricted cargo routes for sanctioned dual-use commodities. Your objectives:

1. Breach the external cargo tracking portal and establish initial foothold
2. Pivot from the public-facing system into the internal DMZ warehouse inventory API
3. Leverage broken access control to extract operator credentials and move laterally
4. Infiltrate the HR self-service portal and establish persistent access via webshell
5. Reach the internal monitoring infrastructure and exploit command injection
6. Penetrate the classified document vault and capture the final operational flag

**ROE:** No destructive actions. Credentials pivot through the chain — do not brute-force.
Each machine yields access to the next. Operate below AGLG SOC noise floor.

---

## Blue Team Briefing — AGLG SOC
You are a defender on AGLG's Security Operations Center team. Threat intelligence
indicates PHANTOM CIRCUIT has been observed probing AGLG's external cargo web presence.
Your objectives:

1. Monitor all five machines for anomalous activity
2. Identify each stage of the attack chain from available logs
3. For each compromise: identify the MITRE ATT&CK technique, the log evidence, and the
   affected user/process
4. Document remediation steps for each vulnerability exploited
5. Correlate events across machines to reconstruct the full kill chain timeline

**Key Log Sources per Machine:**
- M1: `journalctl -u aglg-portal` (Gunicorn/Flask), auditd execve for www-data, SQLite query logs
- M2: `journalctl -u aglg-warehouse` (Morgan access logs), HTTP 200 on /api/inventory/0
- M3: `/var/log/apache2/access.log`, PHP-FPM logs, `/var/www/aglg-hr/uploads/` new files
- M4: `journalctl -u aglg-monitor`, auditd subprocess calls, bash_history for netops
- M5: auditd execve for vault_reader SUID, file access events on /root/, /opt/aglg/vault/

---

## Challenge Chain
```
[ Internet / WireGuard VPN ]
            │
            ▼  HTTP :80
┌───────────────────────────────┐
│  M1: aglg-portal              │  CHALLENGE 1
│  Flask Cargo Tracking Portal  │  SQL Injection → auth bypass → RCE
│  /login — username/password   │  ' OR 1=1-- / report subprocess
│  Flag: /opt/aglg/classified/  │
└──────────────┬────────────────┘
               │  hint.txt → "Warehouse API on DMZ:3000 | vendor_ops:V3nd0r@AGLG"
               ▼  HTTP :3000
┌───────────────────────────────┐
│  M2: aglg-warehouse           │  CHALLENGE 2
│  Node.js Inventory API SPA    │  IDOR on /api/inventory/:id
│  /api/inventory/0 → admin     │  Enumerate IDs → admin record → SSH creds
│  Flag: in admin API response  │
└──────────────┬────────────────┘
               │  hr_ops:HR0ps@AGLG24
               ▼  SSH :22
┌───────────────────────────────┐
│  M3: aglg-hrportal            │  CHALLENGE 3
│  PHP HR Self-Service Portal   │  Unrestricted file upload
│  /upload.php — no validation  │  Upload PHP webshell → /uploads/shell.php
│  Flag: /opt/aglg/flag3.txt    │
└──────────────┬────────────────┘
               │  netops:N3t0ps@Mon1t0r
               ▼  HTTP :5000
┌───────────────────────────────┐
│  M4: aglg-monitor             │  CHALLENGE 4
│  Flask NOC Dashboard          │  OS Command Injection via ping utility
│  /tools/ping — host field     │  127.0.0.1; cat /opt/aglg/flag4.txt
│  Flag: /opt/aglg/flag4.txt    │
└──────────────┬────────────────┘
               │  archivist:Arch1v1st@AGLG
               ▼  SSH :22 + HTTP :8443
┌───────────────────────────────┐
│  M5: aglg-vault               │  CHALLENGE 5
│  Go Classified Vault Portal   │  LFI via path traversal + SUID binary
│  /view?doc=../../root/flag5   │  vault_reader '../../../../root/flag5.txt'
│  Flag: /root/flag5.txt        │
└───────────────────────────────┘
```

---

## Difficulty Assessment

| Challenge | Technique                        | Difficulty       | Key Knowledge Required                        |
|-----------|----------------------------------|------------------|-----------------------------------------------|
| M1        | SQL Injection + RCE              | Intermediate     | SQLi auth bypass, Python subprocess injection |
| M2        | IDOR / Broken Access Control     | Intermediate     | REST API enumeration, access control flaws    |
| M3        | Unrestricted File Upload + RCE   | Intermediate-Hard| MIME bypass, webshell deployment              |
| M4        | OS Command Injection             | Hard             | Shell metacharacters, command chaining        |
| M5        | LFI + SUID Privilege Escalation  | Critical         | Path traversal, SUID binary analysis in C/Go  |
