# Phase 7: Run the Traffic Scenarios

Goal: run each of the six scenarios, capture its traffic to its own pcap, and
confirm the sensor detects it. Every scenario is scoped to the lab network and
benign by design (see each script's header).

## The capture pattern

For each scenario, start a capture on the sensor **first**, run the scenario,
then stop the capture. The capture script filters out lab plumbing (your SSH
session, Wazuh agent traffic) so each pcap holds just the scenario.

On `nids-sensor`:

```bash
sudo bash scripts/sensor/capture.sh <name> <seconds>
```

It writes `~/captures/<name>.pcap` and prints a SHA-256 for your evidence notes.
Copy pcaps to the host with the command it prints
(`scp -P 2250 ...`).

> [!TIP]
> Watch `sudo tail -f /var/log/suricata/fast.log` in a second SSH session while
> each scenario runs. Seeing the alert fire live is more convincing than finding
> it afterward, and it is a good screenshot.

## Scenario 1: Port scan (T1046)

Capture, then from Kali:

```bash
# sensor:
sudo bash scripts/sensor/capture.sh 01-recon-scan 90
# kali:
sudo bash scripts/kali/recon.sh 10.0.50.30
```

Expect Suricata SID **1000001** (SCAN). In the pcap you will see the fan of
SYN packets to many ports with no completed handshakes.

## Scenario 2: SSH brute force (T1110.001)

```bash
# sensor:
sudo bash scripts/sensor/capture.sh 02-ssh-bruteforce 120
# kali:
bash scripts/kali/ssh-bruteforce.sh 10.0.50.30
```

Expect Suricata SID **1000002** (BRUTEFORCE), and if Wazuh is on, also the Lab 1
built-in SSH brute-force correlation on the host side. The run ends in a
successful login (the last password in the list is real), so the capture shows
the full failure-burst-then-success story.

## Scenario 3 and 4: Cleartext credentials (T1040)

Both run from one script:

```bash
# sensor:
sudo bash scripts/sensor/capture.sh 03-cleartext-creds 60
# kali:
bash scripts/kali/cleartext-logins.sh 10.0.50.30
```

Expect SID **1000003** (FTP `PASS`) and **1000004** (HTTP Basic). This capture is
the centrepiece of the Wireshark phase: you will literally read the password off
the wire.

## Scenario 5: DNS tunneling (T1048 / T1071.004)

```bash
# sensor:
sudo bash scripts/sensor/capture.sh 05-dns-exfil 120
# kali:
bash scripts/kali/dns-exfil.sh 10.0.50.30
```

Expect SID **1000005** (EXFIL). With no file argument the script leaks a
generated fake record set, so no real data is involved. Afterward, rebuild what
was leaked from the DNS server's own log, the way a defender would:

```bash
# on linux-endpoint:
python3 scripts/analysis/dns_reassemble.py /var/log/dnsmasq-ntalab.log -o /tmp/recovered
```

That recovered file matching the SHA-256 the exfil script printed is the proof
the tunneling worked, and shows why long encoded DNS labels are worth alerting on.

## Scenario 6: C2 beaconing (T1071.001)

This one needs the listener running first. On `kali-attacker`:

```bash
python3 scripts/kali/checkin-listener.py
```

Then on `linux-endpoint`, and capture on the sensor. Let it run a while so the
timing pattern is clear (a shorter interval keeps the lab quick):

```bash
# sensor:
sudo bash scripts/sensor/capture.sh 06-c2-beacon 600
# linux-endpoint:
bash scripts/target/beacon.sh 20 10 0.2      # every 20s +/-20%, for 10 min
```

Expect Suricata SID **1000006** on the request shape. The real lesson is the
Zeek side: after it has run, analyse the connection timing.

```bash
# on nids-sensor:
python3 scripts/analysis/beacon_detect.py /opt/zeek/logs/current/conn.log
```

It flags the `linux-endpoint -> kali:8080` pair as a beacon from the regularity
of the intervals, while leaving normal traffic alone. That is how you catch a
beacon that fakes a normal user-agent and never trips a content signature.

## Tally

Keep a simple table as you go (there is one in [build-log.md](build-log.md)):

| # | Scenario | Suricata SID | Fired? | pcap | Screenshot |
|---|---|---|---|---|---|
| 1 | Port scan | 1000001 | | 01-recon-scan.pcap | |
| 2 | SSH brute force | 1000002 | | 02-ssh-bruteforce.pcap | |
| 3 | FTP cleartext | 1000003 | | 03-cleartext-creds.pcap | |
| 4 | HTTP Basic | 1000004 | | 03-cleartext-creds.pcap | |
| 5 | DNS tunneling | 1000005 | | 05-dns-exfil.pcap | |
| 6 | C2 beacon | 1000006 (+Zeek) | | 06-c2-beacon.pcap | |

## Screenshot checklist

- [ ] `fast.log` showing each scenario's alert
- [ ] The DNS reassembly recovering the leaked file (SHA-256 match)
- [ ] `beacon_detect.py` flagging the beacon pair
