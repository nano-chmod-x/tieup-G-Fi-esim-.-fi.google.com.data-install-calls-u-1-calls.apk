#!/usr/bin/env bash

# [STRICT ARCHITECTURE]
set -euo pipefail
IFS=$'\n\t'

# [CLEANUP TRAP]
trap 'echo -e "\n[!] Interrupt received. Cleaning up..."; exit 1' SIGINT SIGTERM

# [DEPENDENCY CHECK]
REQUIRED_PKGS=("tor" "proxychains-ng" "curl")
echo "[*] Checking system dependencies..."
for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! command -v "$pkg" &> /dev/null; then
        echo "[-] Error: $pkg is not installed. Injecting dependency fix..."
        sudo apt update && sudo apt install -y tor proxychains-ng curl || {
            echo "[-] FATAL: Failed to install dependencies. Manual intervention required."
            exit 1
        }
    fi
done

echo "--- T.I.E. ANONYMITY DEPLOYMENT CONFIGURATION ---"

TOR_PORT=9050
PROXY_CONF=./proxychains.conf
DNS_HOOK=yes
CHAIN_TYPE=strict

# [LOGIC: CONFIGURATION GENERATION]
echo "[*] Generating hardened Proxychains configuration..."

cat <<EOF > "$PROXY_CONF"
# T.I.E. Generated Hardened Config
${CHAIN_TYPE}_chain
proxy_dns
remote_dns_res_ok
tcp_read_time_out 15000
tcp_connect_time_out 8000
[ProxyList]
socks5  127.0.0.1  $TOR_PORT
EOF

# [LOGIC: TOR SERVICE VERIFICATION]
echo "[*] Initializing Tor service in background..."
if lsof -Pi :"$TOR_PORT" -sTCP:LISTEN -t >/dev/null ; then
    echo "[!] Port $TOR_PORT is already occupied. Assuming Tor is active."
else
    tor --SocksPort "$TOR_PORT" --DataDirectory /tmp/tor_data --RunAsDaemon 1
    echo "[*] Tor launched. Waiting for circuit establishment..."
    sleep 5
fi

# [LOGIC: CONNECTIVITY VERIFICATION]
echo "[*] Verifying anonymity layer..."
set +e 
IP_CHECK=$(proxychains4 -f "$PROXY_CONF" curl -s https://check.torproject.org/api/ip 2>/dev/null | grep -oP '"IP":"\K[^"]+')
set -e

if [ -n "$IP_CHECK" ]; then
    echo "[SUCCESS] Anonymity Layer Active."
    echo "[DATA] Masked IP: $IP_CHECK"
    echo "[EXEC] Usage: proxychains4 -f $PROXY_CONF <command>"
else
    echo "[FAILURE] Traffic is not being routed through Tor."
    exit 1
fi
