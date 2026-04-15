# M1 — Blue Team Detection: SQL Injection + RCE

**Machine:** aglg-portal | **MITRE:** T1190, T1059.004 | **Log Source:** Gunicorn + auditd

---

## Detection — SQL Injection

**Log source:** `/var/log/aglg_portal.log` (Gunicorn access log)

Look for POST `/login` with `400` preceded by rapid auth attempts, or `302` redirect after suspicious username.

**SQLite audit:** Enable query logging in Flask and look for:
```
WHERE username='' OR 1=1--'
```

**Gunicorn log pattern:**
```
POST /login HTTP/1.1" 302 - (immediate redirect = auth bypass succeeded)
```

**Auditd rule to add:**
```bash
auditctl -w /opt/aglg/portal/app/aglg.db -p r -k sqli_db_read
```

---

## Detection — RCE via Report Generator

**Auditd:** Watch for `www-data` spawning subprocesses:
```bash
auditctl -a always,exit -F arch=b64 -S execve -F uid=33 -k www_data_exec
```

**Log pattern (journalctl):**
```
journalctl -u aglg-portal | grep "report"
```
→ Look for `POST /report` followed by non-standard output in response (cat, id, whoami)

---

## Remediation

1. Replace raw string formatting with parameterized queries (`?` placeholders)
2. Use `shlex.quote()` and avoid `shell=True` in `subprocess.run()`
3. Implement rate limiting on `/login` (flask-limiter)
4. Enable WAF rule: block SQLi character sequences in POST body
