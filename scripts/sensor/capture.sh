#!/usr/bin/env bash
# capture.sh: record one scenario's traffic to its own pcap on nids-sensor.
#
#   sudo bash scripts/sensor/capture.sh <scenario-name> [seconds]
#   e.g. sudo bash scripts/sensor/capture.sh 01-recon-scan 120
#
# Without [seconds] it runs until you press Ctrl+C.
# Lab plumbing is filtered out so each pcap holds only the scenario:
#   - the sensor's own SSH session (your terminal)
#   - Wazuh agent traffic (1514/1515) and the Wazuh API (55000)
# Output: ~/captures/<scenario-name>.pcap plus a SHA-256 for the evidence notes.
set -euo pipefail
NAME="${1:?usage: capture.sh <scenario-name> [seconds]}"
SECS="${2:-}"
IFACE="${IFACE:-enp0s3}"
[[ $EUID -eq 0 ]] || { echo "Run with sudo."; exit 1; }
[[ $NAME =~ ^[A-Za-z0-9._-]+$ ]] || { echo "Use letters, numbers, dot, dash or underscore in the name."; exit 1; }

OUTDIR="/home/${SUDO_USER:-$USER}/captures"
mkdir -p "$OUTDIR"
OUT="$OUTDIR/$NAME.pcap"
FILTER='not (host 10.0.50.50 and port 22) and not port 1514 and not port 1515 and not port 55000'

echo "[*] Capturing on $IFACE -> $OUT"
echo "[*] Filter: $FILTER"
if [[ -n $SECS ]]; then
    echo "[*] Stopping automatically after ${SECS}s. Start the scenario now."
    timeout --signal=INT "$SECS" tcpdump -i "$IFACE" -nn -s 0 -w "$OUT" "$FILTER" || true
else
    echo "[*] Press Ctrl+C when the scenario finishes."
    tcpdump -i "$IFACE" -nn -s 0 -w "$OUT" "$FILTER" || true
fi
chown "${SUDO_USER:-root}": "$OUT" "$OUTDIR"
echo
echo "[+] Saved: $OUT"
capinfos -c -d -u "$OUT" 2>/dev/null || tcpdump -nn -r "$OUT" 2>/dev/null | wc -l
sha256sum "$OUT" | tee -a "$OUTDIR/SHA256SUMS"
echo "    Copy to the host:  scp -P 2250 ${SUDO_USER:-user}@127.0.0.1:$OUT ."
