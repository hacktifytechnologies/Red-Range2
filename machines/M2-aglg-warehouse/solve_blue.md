# M2 — Blue Team Detection: IDOR / Broken Access Control

**Machine:** aglg-warehouse | **MITRE:** T1078, T1087 | **Log Source:** Morgan access logs

---

## Detection — IDOR Enumeration

**Log source:** `journalctl -u aglg-warehouse`

Morgan logs format: `GET /api/inventory/0 200` — look for sequential ID enumeration:
```
GET /api/inventory/0 200
GET /api/inventory/1 200
GET /api/inventory/2 200
...
```

**Alert signature:** 5+ consecutive GET requests to `/api/inventory/:id` with incrementing IDs within 10 seconds from same IP.

Auditd rule:
```bash
auditctl -w /opt/aglg/warehouse/server.js -p r -k warehouse_api
```

---

## Detection — Admin Object Access

Look for HTTP 200 on `/api/inventory/0` in logs — this is the IDOR hit on the admin record.

```bash
journalctl -u aglg-warehouse | grep 'inventory/0'
```

---

## Detection — Credential Reuse (admin login)

```bash
journalctl -u aglg-warehouse | grep 'POST /api/login' | grep 200
```
→ Multiple logins with different usernames from same source IP = cred stuffing/reuse.

---

## Remediation

1. Add ownership check: `if item.owner_id !== req.user.id → 403`
2. Remove sensitive fields (flag, internal_note, password) from API responses
3. Implement rate limiting on `/api/inventory/:id` enumeration
4. Add auth to `/.well-known/config` — remove internal network details
5. Separate admin-only user records from the same endpoint namespace
