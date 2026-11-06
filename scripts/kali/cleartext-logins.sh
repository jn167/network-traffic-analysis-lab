#!/usr/bin/env bash
# cleartext-logins.sh: scenarios 3 and 4, credentials over unencrypted protocols
# (MITRE T1040, the data an attacker sniffing the wire would collect).
#
#   bash scripts/kali/cleartext-logins.sh [target]   default target 10.0.50.30
#
# Logs in to the lab's FTP service and its HTTP Basic-auth page, each time
# once with a wrong password and once with the right one, so the capture
# shows both a rejected and an accepted login. The lesson is in Wireshark
# afterwards: FTP sends the password in plain text, and HTTP Basic only
# base64-encodes it, which is encoding, not encryption.
set -euo pipefail
source "$(dirname "$0")/_guard.sh"
T="${1:-10.0.50.30}"; lab_guard "$T"

echo "[*] FTP: wrong password, then correct password, then fetch a file"
curl -s --max-time 10 --user 'ftplab:wrong-guess' "ftp://$T/" || echo "    (login refused, as expected)"
sleep 2
curl -s --max-time 10 --user 'ftplab:Ftp-Lab-2026' "ftp://$T/" || true
curl -s --max-time 10 --user 'ftplab:Ftp-Lab-2026' "ftp://$T/q4-report.txt" -o /tmp/q4-report.txt \
    && echo "    downloaded q4-report.txt"
sleep 2

echo "[*] HTTP Basic auth: wrong password, then correct password"
curl -s -o /dev/null -w '    HTTP %{http_code}\n' -u 'labadmin:wrong-guess'   "http://$T/admin/"
sleep 2
curl -s -o /dev/null -w '    HTTP %{http_code}\n' -u 'labadmin:Web-Lab-2026'  "http://$T/admin/"
echo "[+] Done."
