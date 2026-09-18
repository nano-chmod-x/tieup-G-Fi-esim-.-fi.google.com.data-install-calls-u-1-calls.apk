LPA:1$t-mobile.esim.prod$TMOBILE_5G_UL_PLUS_
846759$9021

#!/usr/bin/env bash

# --- T.I.E. HARDENED ARCHITECTURE ---
# -e: Exit on error | -u: Error on unset vars | -o pipefail: Catch pipeline failures
set -euo pipefail

# --- TRAP FOR CLEANUP ---
trap 'echo -e "\n[!] Interrupt received. Cleaning up processes..."; exit 1' SIGINT SIGTERM

# --- DEPENDENCY CHECK ---
DEPENDENCIES=( "candump" "cansend" "ip" "grep" )
for cmd in "${DEPENDENCIES[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "[ERROR] Required tool '$cmd' not found. Install can-utils/iproute2."
        exit 1
    fi
done

echo "--- T.I.E. TELEMATICS CONFIGURATION ---"

# --- DYNAMIC CONFIGURATION (Interactive) ---
read -p "Enter Target Interface [can0]: " IFACE
IFACE=${IFACE:-can0}

read -p "Enter EID [89852351225042202743]: " TARGET_EID
TARGET_EID=${TARGET_EID:-89852351225042202743}

read -p "Enter IMEI [359470646111791]: " TARGET_IMEI
TARGET_IMEI=${TARGET_IMEI:-359470646111791}

read -p "Enter Log Directory [/tmp/telematics_logs]: " LOG_DIR
LOG_DIR=${LOG_DIR:-/tmp/telematics_logs}

# --- SANITY CHECKS ---
if [[ ! -d "$LOG_DIR" ]]; then
    echo "[*] Creating log directory: $LOG_DIR"
    mkdir -p "$LOG_DIR"
fi

# Ensure the interface is up
if ! ip link show "$IFACE" | grep -q "UP"; then
    echo "[!] Warning: Interface $IFACE appears to be DOWN."
    read -p "Attempt to bring up $IFACE? (y/n): " UP_CHOICE
    if [[ "$UP_CHOICE" == "y" ]]; then
        sudo ip link set "$IFACE" up type can bitrate 500000 || echo "[!] Failed to bring up $IFACE."
    fi
fi

# --- CORE LOGIC ---
LOG_FILE="$LOG_DIR/session_$(date +%Y%m%d_%H%M%S).log"

echo -e "\n[+] Initializing Interrogation Session"
echo "[+] Target EID: $TARGET_EID"
echo "[+] Target IMEI: $TARGET_IMEI"
echo "[+] Logging to: $LOG_FILE"

# Function to simulate/send a diagnostic request for Telematics ID
function request_telematics_info() {
    echo "[*] Sending Diagnostic Request (ID: 0x7DF)..."
    # Example: Sending a generic OBD-II request to trigger response
    # In a real scenario, specific UDS (Unified Diagnostic Services) IDs would be used.
    cansend "$IFACE" 7DF#0201000000000000
}

# Start background capture
echo "[*] Starting candump in background..."
candump "$IFACE" -l > "$LOG_FILE" &
DUMP_PID=$!

# Execute request
request_telematics_info

# Allow time for capture
sleep 2

# Kill background capture
kill "$DUMP_PID"

echo "[+] Interrogation Complete. Data stored in $LOG_FILE"

