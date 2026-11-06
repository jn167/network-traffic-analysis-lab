#!/usr/bin/env bash
# setup-target-services.sh: give linux-endpoint some deliberately weak services.
#
#   sudo bash scripts/target/setup-target-services.sh           # install
#   sudo bash scripts/target/setup-target-services.sh --remove  # undo
#
# Installs, all reachable only inside the isolated SIEMLab network:
#   - vsftpd (FTP, port 21)    user ftplab / Ftp-Lab-2026      -> cleartext creds
#   - Apache (HTTP, port 80)   /admin with labadmin / Web-Lab-2026 (Basic auth)
#   - dnsmasq (DNS, port 53)   answers *.ntalab.test only, forwards nothing
# SSH (labvictim) is already there from Lab 1.
#
# These accounts and passwords exist only for this lab. Never reuse them.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo."; exit 1; }
CFG="$(dirname "$0")/../../configs/target"
[[ -f $CFG/dnsmasq-ntalab.conf ]] || { echo "Run this from the repo root so configs/ can be found."; exit 1; }

if [[ ${1:-} == "--remove" ]]; then
    systemctl disable --now vsftpd dnsmasq 2>/dev/null || true
    a2disconf -q ntalab-admin 2>/dev/null || true
    systemctl reload apache2 2>/dev/null || true
    rm -f /etc/dnsmasq.d/ntalab.conf /etc/apache2/conf-available/ntalab-admin.conf /etc/apache2/.htpasswd-ntalab
    rm -rf /var/www/ntalab-admin
    if id ftplab >/dev/null 2>&1; then userdel -r ftplab 2>/dev/null || true; fi
    echo "[+] Lab services removed (packages left installed; apt purge vsftpd apache2 dnsmasq to remove them)."
    exit 0
fi

# Sanity check: only ever do this on the lab box
if ! ip -4 addr | grep -q 'inet 10\.0\.50\.30/'; then
    echo "This host is not 10.0.50.30 (linux-endpoint). Refusing to install weak services here."
    exit 1
fi

# dnsmasq config goes in BEFORE the package, so it never tries to grab port 53
# on every interface and collide with systemd-resolved on 127.0.0.53.
install -D -m 0644 "$CFG/dnsmasq-ntalab.conf" /etc/dnsmasq.d/ntalab.conf
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y vsftpd apache2 apache2-utils dnsmasq

# FTP account (vsftpd on Ubuntu allows local users to log in by default)
if ! id ftplab >/dev/null 2>&1; then
    useradd -m -s /bin/bash ftplab
fi
echo 'ftplab:Ftp-Lab-2026' | chpasswd
echo "Quarterly numbers draft - LAB DATA ONLY" > /home/ftplab/q4-report.txt
chown ftplab: /home/ftplab/q4-report.txt

# HTTP Basic auth page
mkdir -p /var/www/ntalab-admin
echo "<h1>NTA Lab admin panel</h1><p>If you can read this, your credentials crossed the wire.</p>" > /var/www/ntalab-admin/index.html
htpasswd -bc /etc/apache2/.htpasswd-ntalab labadmin 'Web-Lab-2026' 2>/dev/null
install -m 0644 "$CFG/apache-ntalab-admin.conf" /etc/apache2/conf-available/ntalab-admin.conf
a2enconf -q ntalab-admin

systemctl enable --now vsftpd apache2 dnsmasq
systemctl restart vsftpd apache2 dnsmasq

echo "[*] Listening services:"
ss -ltnup | grep -E ':(21|22|53|80)\s' || true
echo "[+] Done. Quick self-test from Kali:"
echo "    curl -s -u labadmin:Web-Lab-2026 http://10.0.50.30/admin/ | head -1"
echo "    dig +short @10.0.50.30 test.ntalab.test"
