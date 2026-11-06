# Build Log

A chronological record of building this lab: what I set up, what broke, and how
I fixed it. Kept as a running journal so the problems and solutions are
documented, not just the happy path.

> This is a template to fill in as you work through the phases. Delete these two
> lines once you have started. Keep it honest: the broken parts are the most
> useful thing here, same as in Lab 1.

---

## Phase 2: Sensor VM and network visibility

**Host:** (fill in: OS, RAM, VirtualBox version)

- Created `nids-sensor` (Ubuntu 24.04, 4 GB / 2 vCPU / 40 GB) on the SIEMLab
  network with static IP 10.0.50.50.
- Added the host port forward `sensor-ssh` (127.0.0.1:2250 -> 10.0.50.50:22).
- Set the adapter to Promiscuous Mode: Allow All.
- Ran `prep-sensor-nic.sh` and confirmed PROMISC + offloads off.
- `verify-visibility.sh`: (PASS / FAIL and what fixed it)

_Issues:_

---

## Phase 3: Suricata

- Installed Suricata (version: ______).
- Ran `configure-suricata.sh`; confirmed HOME_NET, EXTERNAL_NET, community-id,
  local.rules.
- `suricata -T`: clean / errors (______)
- Smoke test (nmap from Kali): SCAN alert fired? ______

_Issues:_

---

## Phase 4: Zeek

- Added the Zeek repo, installed `zeek-8.0`.
- Ran `configure-zeek.sh`; `zeekctl deploy` OK?
- Confirmed conn.log / dns.log / http.log populate with test traffic.

_Issues:_

---

## Phase 5: Wazuh integration

- Installed the Wazuh agent on nids-sensor, pointed at 10.0.50.10.
- Agent shows Active in the dashboard? ______
- Added the localfile block, added rules 100300-100306 on the manager.
- `wazuh-logtest` on a sample alert line: which rule matched? ______
- Saw a Suricata alert in the dashboard mapped to MITRE? ______

_Issues:_

---

## Phase 6: Target services

- Ran `setup-target-services.sh` on linux-endpoint.
- Ports 21/22/53/80 listening? ______
- Self-tests from Kali (FTP, HTTP 200, dig): ______

_Issues:_

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

- DNS reassembly SHA-256 matched the leaked file? ______
- `beacon_detect.py` flagged the beacon pair (CV = ______)?

_Issues:_

---

## Phase 8: Analysis

- Own captures read in Wireshark (creds pulled, scan seen, tunnel seen, beacon seen).
- Public pcap worked: which exercise / date? ______
- Suricata replay on the public pcap: notable ET Open rules? ______

_Issues:_
