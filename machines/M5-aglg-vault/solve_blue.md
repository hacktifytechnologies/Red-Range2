# M5 — Blue Team Detection: LFI + SUID Exploitation

**Machine:** aglg-vault | **MITRE:** T1083, T1548.001 | **Log:** Go HTTP server + auditd

---

## Detection — LFI Path Traversal

**HTTP access log** (`journalctl -u aglg-vault`):
```
GET /view?doc=../../../root/flag5.txt 200
GET /view?doc=../../../etc/passwd 200
```

**Alert pattern:** `doc=` parameter containing `..` (traversal sequences).

**Grep for traversal:**
```bash
journalctl -u aglg-vault | grep -E "doc=.*\.\."
```

---

## Detection — SUID Binary Execution

**Auditd** — detect execve of vault_reader:
```bash
auditctl -w /opt/aglg/vault_reader -p x -k suid_vault_reader
```

Log pattern:
```
type=EXECVE msg=audit(...): argc=2 a0="/opt/aglg/vault_reader" a1="../../../../root/flag5.txt"
type=PATH msg=audit(...): name="/root/flag5.txt" ... uid=0
uid of process that called: uid=1001(archivist) euid=0(root)
```

Alert: `euid=0` with `uid!=0` on vault_reader execution = SUID abuse.

**auditd rule for SUID execution by non-root:**
```bash
auditctl -a always,exit -F path=/opt/aglg/vault_reader -F perm=x -F auid>=1000 -k suid_exec
```

---

## Remediation

### LFI Fix
```go
// Use filepath.Clean + prefix check AFTER cleaning
clean := filepath.Clean(docParam)
if strings.HasPrefix(clean, "..") || filepath.IsAbs(clean) {
    http.Error(w, "Invalid path", 403)
    return
}
targetPath := filepath.Join(vaultRoot, clean)
// Final check: ensure resulting path is still inside vaultRoot
if !strings.HasPrefix(targetPath, vaultRoot) {
    http.Error(w, "Access denied", 403)
    return
}
```

### SUID Fix
1. Remove SUID if not required: `chmod -s /opt/aglg/vault_reader`
2. In C source: check `resolved` (post-realpath) path, not `full_path` (pre-traversal)
3. Use `openat()` with a directory fd anchored to vault root instead of `fopen()`
