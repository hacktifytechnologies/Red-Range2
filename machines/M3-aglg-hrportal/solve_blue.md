# M3 — Blue Team Detection: Unrestricted File Upload + Webshell Execution

**Machine:** aglg-hrportal | **MITRE:** T1190, T1059.004 | **Log:** Apache2 + PHP-FPM

---

## Detection — Suspicious Upload

**Log source:** `/var/log/apache2/aglg-hr-access.log`

```
POST /upload.php HTTP/1.1" 200 ...
```
Then immediately:
```
GET /uploads/shell.php?cmd=id HTTP/1.1" 200 ...
```

**Alert:** A `.php` file appearing in `/var/www/aglg-hr/uploads/` is a critical IOC.

**File system watch:**
```bash
auditctl -w /var/www/aglg-hr/uploads/ -p w -k webshell_upload
```

---

## Detection — Webshell Execution

PHP-FPM logs for system() calls:
```bash
grep -i "php" /var/log/apache2/aglg-hr-access.log | grep "cmd="
```

auditd for www-data spawning suspicious processes:
```bash
auditctl -a always,exit -F arch=b64 -S execve -F uid=33 -k php_rce
```

Expected syscall log:
```
execve("/bin/sh", ["sh","-c","cat /opt/aglg/flag3.txt"], ...)
  uid=33 (www-data)
```

---

## Remediation

1. Validate file extension server-side: whitelist `[pdf|doc|docx|jpg|png|zip]`
2. Check MIME type with `mime_content_type()` — not just extension
3. **Critically:** Add `php_admin_flag[engine] = Off` to Apache for the uploads directory, or add:
   ```apache
   <Directory /var/www/aglg-hr/uploads>
       php_admin_flag engine Off
   </Directory>
   ```
4. Rename uploaded files to random UUIDs — prevent predictable URL access
5. Move uploads directory outside web root
