#!/usr/bin/env bash
# beacon.sh: scenario 6, a compromised host "checking in" with its controller
# (MITRE T1071.001).
#
# Run on linux-endpoint (the stand-in "infected" host), AFTER starting
# scripts/kali/checkin-listener.py on kali-attacker:
#   bash scripts/target/beacon.sh                 # 30s interval, 20 minutes
#   bash scripts/target/beacon.sh 30 20 0.2       # interval(s) minutes jitter
#
# Benign by design: it only sends a GET and prints the reply. It never runs
# anything the listener sends back. The traffic pattern is the whole point:
#   - the same destination and the same URL path, over and over
#   - a fixed interval with +/- jitter, the way real malware sleep settings work
#   - a spoofed, ordinary Chrome User-Agent, so a naive "bad user-agent" rule
#     misses it and you are pushed toward detecting the timing instead
set -euo pipefail
C2="10.0.50.40:8080"
INTERVAL="${1:-30}"
MINUTES="${2:-20}"
JITTER="${3:-0.2}"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
ID="$(hostname)"

[[ $C2 == 10.0.50.* ]] || { echo "Listener must be inside 10.0.50.0/24."; exit 1; }
END=$(( $(date +%s) + MINUTES * 60 ))
n=0
echo "[*] Checking in to http://$C2 every ${INTERVAL}s (+/-$(awk "BEGIN{print $JITTER*100}")%) for ${MINUTES} min. Ctrl+C to stop."
while [[ $(date +%s) -lt $END ]]; do
    n=$((n + 1))
    reply=$(curl -s -m 5 -A "$UA" "http://$C2/updates/check?id=$ID&n=$n" || echo "(no reply)")
    echo "$(date +%T)  check-in #$n -> $reply"
    sleep "$(awk -v i="$INTERVAL" -v j="$JITTER" 'BEGIN{srand(); printf "%.1f", i*(1-j+2*j*rand())}')"
done
echo "[+] Done: $n check-ins."
