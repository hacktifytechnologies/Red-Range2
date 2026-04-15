# Network Diagram — Operation BlackVault (AGLG)

```
             [Player — WireGuard VPN]
                       │
             [Floating IP 172.24.4.0/24]  ← Assigned to M1 only
                       │
          ┌────────────▼───────────────────┐
          │  v-Pub-subnet  203.0.0.0/8     │
          │                                │
          │  ┌──────────────────────────┐  │
          │  │  M1: aglg-portal         │  │
          │  │  Flask/Python   :80      │  │
          │  │  SQLi — /login           │  │
          │  │  [Pub NIC + DMZ NIC]     │  │
          │  └─────────────┬────────────┘  │
          └────────────────┼───────────────┘
                           │
          ┌────────────────▼───────────────┐
          │  v-DMZ-subnet  11.0.0.0/8      │
          │                                │
          │  ┌──────────────────────────┐  │
          │  │  M2: aglg-warehouse      │  │
          │  │  Node.js/Express  :3000  │  │
          │  │  IDOR / BAC              │  │
          │  └──────────────────────────┘  │
          │                                │
          │  ┌──────────────────────────┐  │
          │  │  M3: aglg-hrportal       │  │
          │  │  PHP/Apache  :8080       │  │
          │  │  File Upload → Webshell  │  │
          │  │  [DMZ NIC + Priv NIC]    │  │
          │  └─────────────┬────────────┘  │
          └────────────────┼───────────────┘
                           │
          ┌────────────────▼───────────────┐
          │  v-Priv-subnet  195.0.0.0/8    │
          │                                │
          │  ┌──────────────────────────┐  │
          │  │  M4: aglg-monitor        │  │
          │  │  Flask/Python  :5000     │  │
          │  │  Command Injection       │  │
          │  └──────────────────────────┘  │
          │                                │
          │  ┌──────────────────────────┐  │
          │  │  M5: aglg-vault          │  │
          │  │  Go HTTP  :8443          │  │
          │  │  LFI + SUID binary       │  │
          │  └──────────────────────────┘  │
          └────────────────────────────────┘
```

## Port Reference

| Machine | Hostname          | Exposed Port      | Vulnerability                       |
|---------|-------------------|-------------------|-------------------------------------|
| M1      | aglg-portal       | 80/tcp (HTTP)     | SQL Injection on /login             |
| M2      | aglg-warehouse    | 3000/tcp (HTTP)   | IDOR on /api/inventory/:id          |
| M3      | aglg-hrportal     | 8080/tcp (HTTP)   | Unrestricted file upload → webshell |
| M4      | aglg-monitor      | 5000/tcp (HTTP)   | OS command injection /tools/ping    |
| M5      | aglg-vault        | 8443/tcp (HTTP)   | LFI /view?doc= + SUID vault_reader  |

## Discovery (No Static IPs)

- Entry: M1 floating IP (player VPN)
- M1→M2: hint.txt says "Warehouse API on DMZ:3000 | vendor_ops:V3nd0r@AGLG" — scan `nmap -p 3000 11.0.0.0/8`
- M2→M3: IDOR admin record reveals SSH creds — scan `nmap -p 22 11.0.0.0/8`
- M3→M4: hint_m4.txt reveals monitor service — scan `nmap -p 5000 195.0.0.0/8`
- M4→M5: hint_m5.txt reveals vault service — scan `nmap -p 8443 195.0.0.0/8`
- All machines use DHCP — IPs differ per provisioning / per team
