# Phase 3: Suricata IDS

Goal: Suricata watching the lab network, with the six custom rules loaded and
validated.

## 1. Install

On `nids-sensor`:

```bash
sudo apt update
sudo apt install -y suricata
suricata -V        # confirm 7.x
```

## 2. Configure it for the lab

The repo ships a script that edits `/etc/suricata/suricata.yaml` for you. It is
safe to re-run.

```bash
sudo bash scripts/sensor/configure-suricata.sh          # assumes enp0s3
```

What it changes, and why each one matters:

| Setting | Value | Why |
|---|---|---|
| `HOME_NET` | `[10.0.50.0/24]` | The network to protect |
| `EXTERNAL_NET` | `any` | **Critical:** the attacker lives *inside* the lab subnet, so the usual `!$HOME_NET` would make Suricata ignore every attack |
| capture interface | `enp0s3` | The NIC the sensor sniffs |
| `community-id` | `true` | Adds a flow hash Suricata and Zeek share, so one ID pivots between a Suricata alert and the Zeek logs |
| `rule-files` | adds `local.rules` | Loads the lab's custom rules |

> [!IMPORTANT]
> The `EXTERNAL_NET: any` change is the one that trips people up. Suricata's
> default `EXTERNAL_NET` is "anything that is not home", which assumes the
> threat comes from outside. In this lab the attacker is `10.0.50.40`, inside
> `HOME_NET`, so with the default almost nothing would fire.

## 3. The custom rules

All six are in [`configs/suricata/local.rules`](../configs/suricata/local.rules),
using local SID range `1000000-1999999` so they never collide with the ET Open
set. Each message starts with `NTALAB` so Phase 5's Wazuh rules can pick them
out.

| SID | Message | Keys on |
|---|---|---|
| 1000001 | SCAN Possible TCP SYN port scan | 50 bare SYNs from one source in 10s |
| 1000002 | BRUTEFORCE Possible SSH brute force | 10 new connections to port 22 in 60s |
| 1000003 | CREDS FTP password sent in cleartext | `PASS ` at the start of an FTP payload |
| 1000004 | CREDS HTTP Basic auth in cleartext | `Authorization: Basic` request header |
| 1000005 | EXFIL DNS query with long encoded label | a single DNS label of 40+ chars, 5+ times in 60s |
| 1000006 | C2 HTTP check-in to raw IP on non-standard port | GET to a `/updates/check?id=` path, Host is a bare IP |

> [!TIP]
> Rule 1000006 does not trust the User-Agent. The beacon fakes a normal Chrome
> UA on purpose, so the rule keys on the request *shape* instead (a check-in
> path to a raw IP on a non-standard port). That mismatch between what a signature
> can see and what the traffic really is becomes the point of the Zeek phase.

## 4. Pull the ET Open ruleset

The configure script runs this, but you can refresh it any time. It adds tens of
thousands of community rules on top of the custom six:

```bash
sudo suricata-update
sudo systemctl restart suricata
```

## 5. Validate

The configure script finishes with `suricata -T`, which loads the full config
and every rule without going live. You want a clean "Configuration provided was
successfully loaded."

> [!NOTE]
> You will see one warning on the SSH rule: *"SYN-only to port 22 w/o direction
> specified, disabling for toclient direction."* That is expected and harmless.
> The rule only cares about the client-to-server direction (the SYN flood
> inbound), so Suricata disabling the reverse direction is correct.

Then confirm it is running and watch the alert log:

```bash
systemctl status suricata
sudo tail -f /var/log/suricata/fast.log
```

## 6. Quick smoke test

Before the full scenarios, prove at least one rule fires. From `kali-attacker`:

```bash
sudo nmap -sS -T4 --top-ports 1000 10.0.50.30
```

Within a few seconds `fast.log` on the sensor should show the SCAN alert
(SID 1000001). If it does, the pipeline works end to end.

## Screenshot checklist

- [ ] `suricata -T` clean load
- [ ] `fast.log` showing the SCAN alert from the smoke test
- [ ] `suricata-update` summary (rules loaded)
