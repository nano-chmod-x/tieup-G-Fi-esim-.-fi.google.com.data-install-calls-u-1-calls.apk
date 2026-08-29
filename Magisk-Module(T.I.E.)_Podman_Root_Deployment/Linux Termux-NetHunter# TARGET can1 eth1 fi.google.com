#!/bin/bash
# T.I.E. HARDENED DEPLOYMENT SCRIPT: CAN-BUS & PERSISTENT DATA
# ARCHITECTURE: Linux / Termux-NetHunter
# TARGET: can1 / eth1 / fi.google.com

set -euo pipefail
trap 'echo "[!] Script interrupted. Cleaning up..."; exit 1' SIGINT SIGTERM

# --- DEPENDENCY CHECK ---
check_deps() {
    local deps=("ip" "sudo" "candump" "ip-route")
    for tool in "${deps[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            echo "[-] Error: Required tool '$tool' not found. Install via 'apt install can-utils iproute2'."
            exit 1
        fi
    done
}

# --- DYNAMIC CONFIGURATION ---
echo "--- [T.I.E. RUNTIME CONFIGURATION] ---"
read -p "Enter CAN Interface [can1]: " CAN_IFACE
CAN_IFACE=${CAN_IFACE:-can1}

read -p "Enter CAN Bitrate [500000]: " CAN_BITRATE
CAN_BITRATE=${CAN_BITRATE:-500000}

read -p "Enter Data Interface [eth1]: " DATA_IFACE
DATA_IFACE=${DATA_IFACE:-eth1}

read -p "Enter APN Endpoint [fi.google.com]: " APN_URL
APN_URL=${APN_URL:-fi.google.com}

read -p "Enter Keep-Alive Interval (seconds) [2]: " INTERVAL
INTERVAL=${INTERVAL:-2}

# --- EXECUTION ---
check_deps

echo "[+] Initializing Hardened CAN Interface: $CAN_IFACE"
# Sanity check: ensure interface is down before config
sudo ip link set "$CAN_IFACE" down 2>/dev/null || true

# Hardening: Set bitrate and restart-ms to prevent bus-off lockup
if sudo ip link set "$CAN_IFACE" type can bitrate "$CAN_BITRATE" restart-ms 100; then
    sudo ip link set "$CAN_IFACE" up
    echo "[*] $CAN_IFACE is ACTIVE at $CAN_BITRATE bps."
else
    echo "[-] Failed to initialize $CAN_IFACE. Check hardware connection."
    exit 1
fi

echo "[+] Initializing Persistent Data Connection on $DATA_IFACE"
# Ensure the interface is up
sudo ip link set "$DATA_IFACE" up || echo "[!] Warning: Could not force $DATA_IFACE up."

# --- PERSISTENCE LOOP ---
echo "[+] Entering Permanent Active State. Monitoring $APN_URL..."
while true; do
    # Check if interface has an IP and can reach the APN
    if ! ping -I "$DATA_IFACE" -c 1 -W 2 "$APN_URL" &> /dev/null; then
        echo "[!] Connection Lost on $DATA_IFACE. Attempting Re-init..."
        sudo ip link set "$DATA_IFACE" down
        sleep 1
        sudo ip link set "$DATA_IFACE" up
        # Optional: Trigger DHCP if needed
        # sudo dhcpcd "$DATA_IFACE" &> /dev/null || true
    fi
    
    # Verify CAN status
    CAN_STATUS=$(ip -details link show "$CAN_IFACE" | grep -o "ERROR-ACTIVE" || echo "ERROR")
    if [[ "$CAN_STATUS" == "ERROR" ]]; then
        echo "[!] CAN Bus Error detected. Resetting $CAN_IFACE..."
        sudo ip link set "$CAN_IFACE" down && sudo ip link set "$CAN_IFACE" up
    fi

    sleep "$INTERVAL"
done