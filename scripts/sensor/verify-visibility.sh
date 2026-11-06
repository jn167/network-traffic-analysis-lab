#!/usr/bin/env bash
# verify-visibility.sh: prove the sensor can see traffic between OTHER machines.
#
#   sudo bash scripts/sensor/verify-visibility.sh            # uses enp0s3
#
# While this runs (20 seconds), go to kali-attacker and run:
#   ping -c 10 10.0.50.30
# If the sensor sees those ICMP packets, mirroring works. If it sees nothing,
# recheck "Promiscuous Mode: Allow All" on the sensor's VirtualBox adapter.
set -euo pipefail
IFACE="${1:-enp0s3}"
[[ $EUID -eq 0 ]] || { echo "Run with sudo."; exit 1; }
echo "[*] Listening 20s on $IFACE for ICMP between 10.0.50.40 (kali) and 10.0.50.30 (linux-endpoint)."
echo "    Now run on Kali:  ping -c 10 10.0.50.30"
count=$(timeout 20 tcpdump -i "$IFACE" -nn -l 'icmp and host 10.0.50.40 and host 10.0.50.30' 2>/dev/null | tee /dev/stderr | wc -l || true)
echo
if [[ ${count:-0} -gt 0 ]]; then
    echo "[+] PASS: saw $count packets between two other hosts. The sensor has visibility."
else
    echo "[-] FAIL: saw nothing. Check: VirtualBox adapter Promiscuous Mode = Allow All,"
    echo "    'ip -br link' shows PROMISC, and Kali's ping actually ran during the window."
    exit 1
fi
