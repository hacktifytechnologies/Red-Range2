# M4 — Blue Team Detection: OS Command Injection

**Machine:** aglg-monitor | **MITRE:** T1059.004, T1552 | **Log:** Gunicorn + auditd

---

## Detection — Command Injection in POST Body

**Log source:** `journalctl -u aglg-monitor`

```
POST /tools/ping HTTP/1.1" 200 ...
```
followed immediately by non-standard output (flag content, /etc/passwd, bash output).

**Auditd — detect subprocess execution by netops:**
```bash
auditctl -a always,exit -F arch=b64 -S execve -F uid=$(id -u netops) -k netops_exec
```

Suspicious syscall pattern:
```
execve "/bin/sh" args: ["-c", "ping -c 2 -W 2 127.0.0.1; cat /opt/aglg/flag4.txt"]
```

Look for `;`, `&&`, `||`, `|`, backticks in POST request body:
```bash
# Check Gunicorn access log args (if logging POST data):
journalctl -u aglg-monitor | grep -E "(;|&&|\|\|)"
```

---

## Detection — Bash History Anomaly

If attacker SSH'd in:
```bash
cat /home/netops/.bash_history | grep -E "(cat|id|whoami|curl|bash|nc)"
```

---

## Remediation

1. Use `subprocess.run()` with a list (`["ping", "-c", "2", host]`) — never `shell=True`
2. Validate host input against IP regex: `^(\d{1,3}\.){3}\d{1,3}$`
3. Implement input allow-listing — reject any character outside `[a-zA-Z0-9.\-]`
4. Use dedicated network diagnostic libraries (not raw shell)
5. Principle of least privilege — `netops` should not have access to `/opt/aglg/flag4.txt`
