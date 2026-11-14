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

- Installed the Wazuh agent (4.14.10) on `nids-sensor`, pointed at the manager
  10.0.50.10 with agent name `nids-sensor`, and held the package version so it
  can not drift ahead of the manager. The agent registered and showed Active in
  the dashboard next to the Lab 1 agents.
- Pointed the agent at Suricata's output by adding a `<localfile>` block
  (`json`, `/var/log/suricata/eve.json`) inside the last `<ossec_config>` block
  of the agent's `ossec.conf`.
- On the manager, appended the lab rules (100300-100306) to `local_rules.xml`
  and restarted `wazuh-manager`. Validated with `wazuh-logtest`: a sample
  Suricata scan alert matched rule 100301 (level 8) with MITRE T1046, tactic
  Discovery, technique Network Service Discovery.
- End to end: an nmap scan from Kali showed up in the dashboard's Threat Hunting
  view as a `nids-sensor` alert mapped to T1046. Network detections now land in
  the same SIEM as the Lab 1 host detections.

### Issue: rules appended twice

A re-run of the append left two copies of the `nta_lab` rule group in
`local_rules.xml`, and `wazuh-logtest` warned that rules 100300-100306 were
duplicated (Wazuh uses only the first copy, so the match still worked, but it
warns on every start). Fixed by restoring the pre-append backup and appending
exactly once, confirmed back to a single copy and a clean logtest.

### Note: finding alerts in the dashboard

The scan alert did not appear at first because of where and when to look: the
individual alerts are under Threat Hunting's **Events** tab, and the time range
has to cover the present. Widening the range surfaced it.

---

## Phase 6: Target services

- Ran `setup-target-services.sh` on `linux-endpoint`. Its guard confirmed the
  host is 10.0.50.30 before installing anything, then stood up vsftpd (FTP, 21),
  Apache (HTTP, 80, with `/admin` behind Basic auth), and dnsmasq (DNS, 53,
  answering only `*.ntalab.test` and forwarding nothing).
- `systemd-resolve` stayed on its loopback addresses (127.0.0.53/54), so there
  was no port-53 conflict with dnsmasq bound to 10.0.50.30. Installing the
  dnsmasq config before the package is what kept it from grabbing every
  interface.
- Self-tests from Kali passed: the HTTP Basic admin page returned its HTML, and
  `dig @10.0.50.30 test.ntalab.test` resolved to 10.0.50.30. Targets ready for
  the scenarios.

---

## Phase 7: Scenarios

All six scenarios run from Kali against `linux-endpoint`, each captured to its
own pcap on the sensor. Every custom rule fired (one needed tuning first).

| # | Scenario | Suricata SID | Fired? | pcap | Screenshot |
|---|---|---|---|---|---|
| 1 | Port scan | 1000001 | yes | 01-recon-scan.pcap | 12 |
| 2 | SSH brute force | 1000002 | yes (after tuning) | 02-ssh-bruteforce.pcap | 13 |
| 3 | FTP cleartext | 1000003 | yes | 03-cleartext-creds.pcap | 14 |
| 4 | HTTP Basic | 1000004 | yes | 03-cleartext-creds.pcap | 14 |
| 5 | DNS tunneling | 1000005 | yes | 05-dns-exfil.pcap | 15, 16 |
| 6 | C2 beacon | 1000006 (+ Zeek) | yes | 06-c2-beacon.pcap | 17, 18 |

### Finding: the SSH brute-force rule needed tuning

The brute-force rule (1000002) did not fire on the first run. Counting SYNs in
the capture showed only 5 new connections to port 22 for all 20 Hydra guesses,
because SSH allows several password attempts per connection (MaxAuthTries). The
original threshold of 10 connections in 60s was never reached. Lowered it to 4,
reloaded Suricata, re-ran, and it fired (rule bumped to rev 2). The real lesson:
a pure connection-rate rule under-detects brute force against a connection-reusing
protocol, and the more reliable detection is log-based (Wazuh counts failed
passwords in auth.log regardless of connection reuse).

### DNS tunneling rebuilt from logs

After the tunneling alert fired, rebuilt the exfiltrated file from nothing but
the dnsmasq query log using `dns_reassemble.py`. The recovered CSV matched the
original on Kali byte-for-byte (SHA-256 identical). Concrete proof of why long
encoded DNS labels are worth alerting on.

### Beacon caught by timing, not signature

The beacon faked an ordinary Chrome user-agent, so a naive signature on the UA
would miss it. `beacon_detect.py` flagged it anyway from the Zeek connection
log: `10.0.50.30 -> 10.0.50.40:8080`, 15 check-ins, mean 20.5s, CV 0.11, well
inside the beaconing threshold. Suricata's 1000006 also caught the request shape
(check-in path to a raw IP on a non-standard port). The timing-based catch is
the durable one.

---

## Phase 8: Analysis

- (pending)
