# Phase 5: Ship Suricata Alerts into Wazuh

Goal: Suricata's alerts show up in the Lab 1 Wazuh console, mapped to MITRE,
next to the host detections from Lab 1. This is what ties the two labs together.

> [!NOTE]
> This phase needs the Lab 1 `wazuh-server` (10.0.50.10) powered on. If you are
> running the IDS scenarios with it off to save RAM, skip this phase and come
> back to it. Suricata and Zeek work fully without Wazuh.

## How the pipeline works

```
Suricata (nids-sensor) writes /var/log/suricata/eve.json
   -> Wazuh AGENT on nids-sensor tails it (log_format json)
   -> wazuh-server decodes it: built-in rules 86600-86604 tag Suricata events
   -> the lab rules 100300-100306 re-score the NTALAB signatures and add MITRE
   -> alerts appear in the Wazuh dashboard
```

## 1. Install the Wazuh agent on the sensor

Same method as the Lab 1 Linux endpoint, pointed at the same manager:

```bash
sudo apt-get install -y gnupg apt-transport-https curl
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | sudo gpg --no-default-keyring \
  --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && sudo chmod 644 /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
  | sudo tee /etc/apt/sources.list.d/wazuh.list
sudo apt-get update
sudo WAZUH_MANAGER="10.0.50.10" WAZUH_AGENT_NAME="nids-sensor" apt-get install -y wazuh-agent
sudo systemctl daemon-reload
sudo systemctl enable --now wazuh-agent
sudo apt-mark hold wazuh-agent
```

Confirm the agent shows up as **Active** on the Wazuh dashboard under Agents.
You should now see three agents: `linux-endpoint`, `win-endpoint` (from Lab 1),
and `nids-sensor`.

## 2. Tell the agent to read Suricata's log

Add the localfile block from
[`configs/wazuh/ossec-localfile-suricata.xml`](../configs/wazuh/ossec-localfile-suricata.xml)
inside `<ossec_config>` in `/var/ossec/etc/ossec.conf` **on the sensor**, then:

```bash
sudo systemctl restart wazuh-agent
```

That is all the agent needs: it tails `eve.json`, and because each line is JSON,
Wazuh's built-in Suricata rules understand it out of the box.

## 3. Add the lab's scoring rules on the manager

On `wazuh-server`, append the contents of
[`configs/wazuh/local_rules_nta.xml`](../configs/wazuh/local_rules_nta.xml) to
`/var/ossec/etc/rules/local_rules.xml` (keep the Lab 1 rules 100100-100200 that
are already in there), then restart the manager:

```bash
sudo systemctl restart wazuh-manager
```

These rules (100300-100306) sit on top of Wazuh's built-in Suricata alert rule
(86601) and do two things: raise the severity to match how serious each
technique is, and attach the MITRE mapping so the alert is tagged with its
technique.

| Rule | Fires on Suricata SID | Level | MITRE |
|---|---|---|---|
| 100301 | 1000001 (scan) | 8 | T1046 |
| 100302 | 1000002 (SSH brute force) | 10 | T1110.001 |
| 100303 | 1000003 (FTP creds) | 7 | T1040 |
| 100304 | 1000004 (HTTP creds) | 7 | T1040 |
| 100305 | 1000005 (DNS tunneling) | 12 | T1071.004 / T1048 |
| 100306 | 1000006 (C2 check-in) | 12 | T1071.001 |

## 4. Validate the rule logic

Before relying on it, test one rule offline with `wazuh-logtest` on the manager.
Paste a sample Suricata alert line (grab one from `eve.json` after a scenario, a
line with `"event_type":"alert"`) at the prompt:

```bash
sudo /var/ossec/bin/wazuh-logtest
```

A correctly matched line reports the lab rule firing (for example
`Rule: 100301 ... TCP SYN port scan`) with the MITRE block populated. That
confirms the field names in the rule match the real event before any live
attack depends on it.

## 5. Confirm end to end

Run the port-scan smoke test from Kali again. Within a few seconds you should
see it in two places: `fast.log` on the sensor, and the Wazuh dashboard
(Threat Hunting / Security events) as a `nids-sensor` alert mapped to T1046.

<div align="center">
  <em>Screenshot to capture: the Wazuh dashboard showing a Suricata alert from
  nids-sensor with its MITRE technique. (screenshots/)</em>
</div>

## Screenshot checklist

- [x] All three agents Active in Wazuh (screenshot 8; win-endpoint off)
- [x] `wazuh-logtest` matching a lab rule (100301-100306) with MITRE populated (screenshot 9)
- [x] A Suricata network alert in the Wazuh dashboard, mapped to MITRE (screenshot 10)
