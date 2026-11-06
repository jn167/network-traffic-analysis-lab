#!/usr/bin/env bash
# configure-suricata.sh: point a fresh Suricata install at the lab network.
#
# Run on nids-sensor from the repo root, after installing Suricata:
#   sudo bash scripts/sensor/configure-suricata.sh            # uses enp0s3
#   sudo bash scripts/sensor/configure-suricata.sh enp0s8     # other interface
#
# What it does (each step is idempotent, so re-running is safe):
#   1. Backs up /etc/suricata/suricata.yaml once (suricata.yaml.orig)
#   2. HOME_NET = 10.0.50.0/24, EXTERNAL_NET = any
#      (the attacker lives inside the lab subnet, so the usual
#       "!$HOME_NET" definition would hide every attack)
#   3. Sniffs the given interface with af-packet
#   4. Turns on community-id so Suricata alerts can be matched to Zeek logs
#   5. Installs configs/suricata/local.rules and adds it to rule-files
#   6. Pulls the ET Open ruleset with suricata-update
#   7. Validates the config with "suricata -T" before restarting the service
set -euo pipefail

IFACE="${1:-enp0s3}"
YAML=/etc/suricata/suricata.yaml
LOCAL_RULES_SRC="$(dirname "$0")/../../configs/suricata/local.rules"
LOCAL_RULES_DST=/etc/suricata/rules/local.rules

[[ $EUID -eq 0 ]] || { echo "Run with sudo."; exit 1; }
[[ -f $YAML ]] || { echo "$YAML not found. Install Suricata first (docs/02-suricata.md)."; exit 1; }
[[ -f $LOCAL_RULES_SRC ]] || { echo "Run this from the repo root so configs/ can be found."; exit 1; }
ip link show "$IFACE" >/dev/null 2>&1 || { echo "Interface $IFACE not found. Check 'ip a'."; exit 1; }

[[ -f $YAML.orig ]] || cp "$YAML" "$YAML.orig"
echo "[*] Backup: $YAML.orig"

# 2. Network variables
sed -i -E 's|^(\s*)HOME_NET:.*|\1HOME_NET: "[10.0.50.0/24]"|' "$YAML"
sed -i -E 's|^(\s*)EXTERNAL_NET:.*|\1EXTERNAL_NET: "any"|' "$YAML"

# 3. Capture interface (af-packet and pcap sections ship with eth0)
sed -i -E "s|^(\s*)- interface: eth0\b|\1- interface: ${IFACE}|" "$YAML"

# 4. Community ID
sed -i -E 's|^(\s*)community-id: false|\1community-id: true|' "$YAML"

# 5. Local rules
install -D -m 0644 "$LOCAL_RULES_SRC" "$LOCAL_RULES_DST"
if ! grep -qF -- "- $LOCAL_RULES_DST" "$YAML"; then
    sed -i -E "s|^(\s*)- suricata\.rules\s*$|&\n\1- ${LOCAL_RULES_DST}|" "$YAML"
fi

echo "[*] Settings now in effect:"
grep -nE '^\s*(HOME_NET|EXTERNAL_NET):|community-id: |- interface: |- suricata\.rules|local\.rules' "$YAML" | grep -v '#'

# 6. ET Open rules
echo "[*] Updating ET Open rules (suricata-update)..."
suricata-update -q || suricata-update

# 7. Validate, then restart
echo "[*] Testing configuration..."
suricata -T -c "$YAML" -v
systemctl enable suricata >/dev/null 2>&1 || true
systemctl restart suricata
sleep 3
systemctl --no-pager --lines=0 status suricata
echo "[+] Done. Watch alerts with: sudo tail -f /var/log/suricata/fast.log"
