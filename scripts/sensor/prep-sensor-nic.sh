#!/usr/bin/env bash
# prep-sensor-nic.sh: get the sensor's NIC ready to watch other machines' traffic.
#
#   sudo bash scripts/sensor/prep-sensor-nic.sh            # uses enp0s3
#
# 1. Promiscuous mode: accept frames addressed to other machines. (VirtualBox must
#    ALSO allow it: Settings > Network > Adapter 1 > Advanced > Promiscuous Mode: Allow All.)
# 2. Offloads off: with GRO/LRO on, the kernel glues packets together before
#    capture tools see them, which produces giant "packets" and bad checksums.
# 3. Installs a small systemd unit so both settings survive a reboot.
set -euo pipefail
IFACE="${1:-enp0s3}"
[[ $EUID -eq 0 ]] || { echo "Run with sudo."; exit 1; }
command -v ethtool >/dev/null || apt-get install -y ethtool

ip link set "$IFACE" promisc on
ethtool -K "$IFACE" gro off lro off gso off tso off rx off tx off 2>/dev/null || true

cat > /etc/systemd/system/sensor-nic.service <<UNIT
[Unit]
Description=Promiscuous mode and offloads off for the lab sensor NIC
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ip link set ${IFACE} promisc on
ExecStart=-/usr/sbin/ethtool -K ${IFACE} gro off lro off gso off tso off rx off tx off
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now sensor-nic.service >/dev/null

echo "[*] $IFACE flags:"; ip -br link show "$IFACE"
echo "[*] Offloads:"; ethtool -k "$IFACE" | grep -E '^(generic-receive|large-receive|tcp-segmentation|rx-checksumming|tx-checksumming)'
echo "[+] Look for PROMISC above. Next: run scripts/sensor/verify-visibility.sh"
