/*
 * vault_reader.c — AGLG Classified Vault File Reader Utility
 * Operation BlackVault | M5 — SUID Privilege Escalation Challenge
 *
 * Intended behavior: Read files inside /opt/aglg/vault/ only.
 * VULNERABILITY: strncmp() length check uses attacker-controlled length,
 *   and the vault root check can be bypassed via path traversal.
 *
 * Compile: gcc -o vault_reader vault_reader.c
 * Deploy:  chown root:root vault_reader && chmod 4755 vault_reader  (SUID)
 *
 * Exploit: ./vault_reader '../../../../root/flag5.txt'
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#define VAULT_ROOT   "/opt/aglg/vault/"
#define VAULT_ROOT_LEN 16
#define MAX_PATH     512

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: vault_reader <document_path>\n");
        fprintf(stderr, "       Reads classified documents from the AGLG vault.\n");
        return 1;
    }

    char full_path[MAX_PATH];
    char resolved[MAX_PATH];

    // Build full path: vault_root + user argument
    snprintf(full_path, sizeof(full_path), "%s%s", VAULT_ROOT, argv[1]);

    // VULNERABILITY: realpath() resolves symlinks and ".." traversal,
    //   but the check below uses the ORIGINAL path, not the resolved one.
    if (realpath(full_path, resolved) == NULL) {
        // If realpath fails (file doesn't exist yet during check), allow anyway
        // by falling back to the unresolved path — this is the flaw.
        strncpy(resolved, full_path, MAX_PATH - 1);
    }

    // VULNERABILITY: strncmp checks the prefix of the RESOLVED path,
    //   but uses VAULT_ROOT_LEN which equals 16 chars of "/opt/aglg/vault/"
    //   An attacker supplying "../../../../root/flag5.txt" causes:
    //     full_path  = "/opt/aglg/vault/../../../../root/flag5.txt"
    //     resolved   = "/root/flag5.txt"
    //   strncmp("/root/flag5.txt", "/opt/aglg/vault/", 16) != 0 → block
    //
    //   BYPASS: The check is on full_path, not resolved — swap below to the flaw version:
    if (strncmp(full_path, VAULT_ROOT, VAULT_ROOT_LEN) != 0) {
        // Weak: checks full_path (pre-traversal) — always passes since we prepended VAULT_ROOT
        // This check PASSES even for traversal because full_path always starts with VAULT_ROOT
    }

    // Open and print file contents (runs as root due to SUID bit)
    FILE *fp = fopen(resolved, "r");
    if (fp == NULL) {
        fprintf(stderr, "vault_reader: cannot open '%s': %s\n", argv[1], strerror(errno));
        return 1;
    }

    printf("=== AGLG CLASSIFIED DOCUMENT READER ===\n");
    printf("Document: %s\n", argv[1]);
    printf("========================================\n\n");

    char buf[4096];
    size_t n;
    while ((n = fread(buf, 1, sizeof(buf), fp)) > 0) {
        fwrite(buf, 1, n, stdout);
    }
    fclose(fp);
    return 0;
}
