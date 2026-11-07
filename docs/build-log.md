# Build Log

A chronological record of building this lab: what I set up, what broke, and how
I fixed it. Kept as a running journal so the problems and solutions are
documented, not just the happy path.

---

## Phase 1 and 2: Sensor VM and network visibility

**Host:** Windows, 32 GB RAM, 10-core CPU, running VirtualBox. Reused the Lab 1
`SIEMLab` NAT network (10.0.50.0/24) and the existing `wazuh-server`,
`linux-endpoint`, and `kali-attacker` VMs. `win-endpoint` left powered off since
this lab does not need it, which also keeps RAM use comfortable (sensor 4 GB +
wazuh 8 GB + linux 2 GB + kali 4 GB is about 18 GB of the 32).

- Created `nids-sensor` (Ubuntu Server 24.04, 4 GB / 2 vCPU / 40 GB) on the
  SIEMLab network with static IP 10.0.50.50, interface `enp0s3`.
- Set the adapter to Promiscuous Mode: Allow All (the setting that lets the
  sensor see other machines' traffic).
- Deselected LVM during install so the whole 40 GB disk goes to root. This
  deliberately sidesteps the half-disk problem that caused the "no space left"
  failure on the Lab 1 Wazuh server.
- Ran `prep-sensor-nic.sh`: confirmed `PROMISC` on the interface and all NIC
  offloads off (so captured packets match the wire).
- `verify-visibility.sh`: PASS, 21 packets seen between kali and linux-endpoint.

### Issue: could not copy/paste into the VM console

Same clipboard problem as Lab 1. VirtualBox's Shared Clipboard needs a graphical
session in the guest, and this is a headless Ubuntu Server, so it does not work
in the text console. Fix: added a host port forward (`sensor-ssh`,
127.0.0.1:2250 -> 10.0.50.50:22) and SSH into the sensor from the host terminal,
where copy/paste is native. This is also how captures get pulled off the sensor
later.

### Issue: SSH login kept being denied

I was SSHing in with the wrong username out of habit. The sensor's account is
`emmastone` (what felt like the name was actually the display-name field; the
Linux username is the lowercase one). Confirmed with `whoami` at the console,
then SSH worked. The password was fine the whole time.

### Issue: first visibility test saw only 1 packet

I had forgotten to power on `linux-endpoint`, so Kali's pings had nothing to
reply to, and I also started the ping late in the 20-second window. Booted the
endpoint and reran starting the ping immediately: 21 packets, full request and
reply pairs. The lesson from Lab 1 held again: verify the preconditions before
trusting a result.

---

## Phase 3: Suricata

- Installed Suricata 7.0.3.
- Ran `configure-suricata.sh`: set `HOME_NET` to 10.0.50.0/24 and, importantly,
  `EXTERNAL_NET` to `any` (the attacker lives inside the subnet, so the default
  would hide the attacks), sniff interface `enp0s3`, community-id on, and the
  custom `local.rules` loaded.
- `suricata-update` pulled the ET Open ruleset. Final count: 53337 rules loaded
  across 2 files (ET Open plus the 6 custom), 0 failed.
- The one expected warning appeared (rule 1000002, SSH, "disabling for toclient
  direction"), which is correct since that rule only watches the inbound
  direction.
- `suricata -T` reported "Configuration provided was successfully loaded" and
  the service came up `active (running)`.

### Smoke test

Ran `nmap -sS -T4 --top-ports 1000 10.0.50.30` from Kali. The custom rule
`1000001 NTALAB SCAN` fired, and alongside it the ET Open rules caught the same
scan hitting specific service ports (MySQL, MSSQL, PostgreSQL, Oracle, VNC).
Good illustration of signature IDS working on two levels: a broad custom "someone
is scanning" rule plus the community set's service-specific probes.

---

## Phase 4: Zeek

- Added Zeek's official OpenSUSE Build Service repo and installed `zeek-8.0`
  (version 8.0.11). Installs under `/opt/zeek`; added it to PATH.
- The install pulled in postfix and showed its mail-config prompt. Chose "Local
  only" since the lab needs no outbound mail.
- Ran `configure-zeek.sh`: node set to sniff `enp0s3`, 10.0.50.0/24 marked local,
  lab tweaks appended to `local.zeek` (ignore VirtualBox checksum offload,
  community-id, MAC logging). `zeekctl deploy` succeeded and `zeekctl status`
  shows the node `running`.

### Issue: a pasted command split in the middle

Adding the Zeek repo, a long single-line command got broken mid-line by the
terminal paste, so `sudo` ran with no command and `tee` ran without root
("Permission denied"). Exactly the split-paste gremlin from Lab 1. Fix: ran each
line on its own, one at a time, and confirmed the repo line echoed back before
moving on.

---

## Phase 5: Wazuh integration

- (pending)

---

## Phase 6: Target services

- (pending)

---

## Phase 7: Scenarios

| # | Scenario | Suricata SID | Fired? | pcap saved | Screenshot |
|---|---|---|---|---|---|
| 1 | Port scan | 1000001 | | | |
| 2 | SSH brute force | 1000002 | | | |
| 3 | FTP cleartext | 1000003 | | | |
| 4 | HTTP Basic | 1000004 | | | |
| 5 | DNS tunneling | 1000005 | | | |
| 6 | C2 beacon | 1000006 (+Zeek) | | | |

---

## Phase 8: Analysis

- (pending)
