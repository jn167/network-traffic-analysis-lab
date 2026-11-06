#!/usr/bin/env bash
# configure-zeek.sh: point a fresh Zeek install (/opt/zeek) at the lab network.
#
# Run on nids-sensor from the repo root, after installing Zeek:
#   sudo bash scripts/sensor/configure-zeek.sh            # uses enp0s3
#   sudo bash scripts/sensor/configure-zeek.sh enp0s8     # other interface
#
# What it does (safe to re-run):
#   1. Installs node.cfg (sniff interface) and networks.cfg (10.0.50.0/24)
#   2. Appends the lab additions to site/local.zeek once
#   3. Runs "zeekctl check" and then "zeekctl deploy"
#   4. Adds the zeekctl cron job that rotates logs and restarts Zeek if it dies
set -euo pipefail

IFACE="${1:-enp0s3}"
ZEEK=/opt/zeek
CFG_SRC="$(dirname "$0")/../../configs/zeek"
LOCAL_ZEEK=$ZEEK/share/zeek/site/local.zeek
MARKER="# --- Network Traffic Analysis Lab additions ---"

[[ $EUID -eq 0 ]] || { echo "Run with sudo."; exit 1; }
[[ -x $ZEEK/bin/zeekctl ]] || { echo "$ZEEK/bin/zeekctl not found. Install Zeek first (docs/03-zeek.md)."; exit 1; }
[[ -f $CFG_SRC/node.cfg ]] || { echo "Run this from the repo root so configs/ can be found."; exit 1; }
ip link show "$IFACE" >/dev/null 2>&1 || { echo "Interface $IFACE not found. Check 'ip a'."; exit 1; }

# 1. Node and network config (keep the originals once)
for f in node.cfg networks.cfg; do
    [[ -f $ZEEK/etc/$f.orig ]] || cp "$ZEEK/etc/$f" "$ZEEK/etc/$f.orig"
done
sed "s/^interface=.*/interface=${IFACE}/" "$CFG_SRC/node.cfg" > "$ZEEK/etc/node.cfg"
cp "$CFG_SRC/networks.cfg" "$ZEEK/etc/networks.cfg"

# 2. local.zeek additions
if ! grep -qF "$MARKER" "$LOCAL_ZEEK"; then
    { echo; echo "$MARKER"; cat "$CFG_SRC/local-additions.zeek"; } >> "$LOCAL_ZEEK"
    echo "[*] Appended lab additions to $LOCAL_ZEEK"
else
    echo "[*] Lab additions already present in $LOCAL_ZEEK"
fi

# 3. Check and deploy
$ZEEK/bin/zeekctl check
$ZEEK/bin/zeekctl deploy
$ZEEK/bin/zeekctl status

# 4. Housekeeping cron (log rotation, crash recovery)
CRON_LINE="*/5 * * * * $ZEEK/bin/zeekctl cron"
if ! crontab -l 2>/dev/null | grep -qF "$ZEEK/bin/zeekctl cron"; then
    (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
    echo "[*] Added root crontab entry: $CRON_LINE"
fi

echo "[+] Done. Live logs are in $ZEEK/logs/current/ (conn.log, dns.log, http.log, ...)"
