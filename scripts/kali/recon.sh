#!/usr/bin/env bash
# recon.sh: scenario 1, network reconnaissance (MITRE T1046).
#
#   sudo bash scripts/kali/recon.sh [target]       default target 10.0.50.30
#
# This is the "noisy" scenario: a port scan is usually the first thing a
# defender should catch. It exists so you can see what a scan looks like on
# the wire (a fan of bare SYNs) and confirm the sensor's scan rule fires.
#
# Stage 1: fast SYN scan of the top 1000 TCP ports.
# Stage 2: service/version detection on whatever came back open.
set -euo pipefail
source "$(dirname "$0")/_guard.sh"
T="${1:-10.0.50.30}"; lab_guard "$T"
[[ $EUID -eq 0 ]] || { echo "Run with sudo (SYN scans need raw sockets)."; exit 1; }
command -v nmap >/dev/null || { echo "nmap not found (sudo apt install nmap)."; exit 1; }

echo "[*] Stage 1: SYN scan, top 1000 ports -> $T"
nmap -sS -T4 --top-ports 1000 -n "$T" -oN "recon-syn-$T.txt"

PORTS=$(grep -oE '^[0-9]+/tcp[[:space:]]+open' "recon-syn-$T.txt" | cut -d/ -f1 | paste -sd, -)
if [[ -n $PORTS ]]; then
    echo "[*] Stage 2: version detection on $PORTS"
    nmap -sV -n -p "$PORTS" "$T" -oN "recon-svc-$T.txt"
fi
echo "[+] Done. Results in recon-*.txt on this host."
