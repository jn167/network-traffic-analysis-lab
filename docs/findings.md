# Investigations

Analyst-style write-ups for the captures in this lab. Each one follows the same
shape a SOC analyst uses to hand an alert off: what fired, what actually
happened, the verdict, the response, and how to detect it going forward.

> Template below. Replace the bracketed prompts with your findings as you work
> through Phase 8. Aim for three solid write-ups.

---

## Investigation 1: Cleartext credentials on the wire

- **Source:** `03-cleartext-creds.pcap` (lab capture)
- **ATT&CK:** T1040 Network Sniffing
- **Trigger:** Suricata SID 1000003 (FTP PASS) and 1000004 (HTTP Basic)

**What happened.** [Which hosts, which services. What the Follow-TCP-Stream and
the `http.authorization` header showed. The recovered credentials.]

**Verdict.** [Policy violation / exposure. Why cleartext auth is the finding
even though the "attack" is just logging in.]

**Response.** [Rotate the exposed creds, move the service to TLS (FTPS/HTTPS),
and what you would tell the service owner.]

**Detection going forward.** [Keep the cleartext-cred signatures; also alert on
plaintext auth protocols seen on the network at all. Where this could
false-positive.]

---

## Investigation 2: C2 beacon

- **Source:** `06-c2-beacon.pcap` + Zeek `conn.log` (lab capture)
- **ATT&CK:** T1071.001 Application Layer Protocol: Web Protocols
- **Trigger:** Suricata SID 1000006, and `beacon_detect.py` on the Zeek logs

**What happened.** [The repeating GET to /updates/check, the destination, the
interval and jitter. The CV that beacon_detect.py reported. Note the spoofed
Chrome user-agent and why it did not help the attacker here.]

**Verdict.** [Compromised host beaconing to a controller. Treat linux-endpoint
as compromised.]

**Response.** [Isolate the host, block the C2 destination, hunt for how it got
there, preserve the capture.]

**Detection going forward.** [Signature on the request shape is brittle; the
durable detection is the timing regularity in connection metadata. This is the
case for having Zeek, not just signatures.]

---

## Investigation 3: Public malware pcap

- **Source:** malware-traffic-analysis.net exercise [date / name]
- **ATT&CK:** [techniques you identified]
- **Trigger:** [the IDS alert in the exercise scenario]

**Infected host.** [IP, MAC, hostname, Windows user if present, and how you
found each.]

**Timeline.** [First suspicious packet, the infection chain in order.]

**What the malware did.** [C2 domains/IPs, downloads, any exfil. How you read it
from the pcap.]

**Verdict.** [Malware family if identifiable, confidence, evidence.]

**Response.** [Contain, block indicators, next steps to IR.]

**Detection going forward.** [What rule or indicator would have caught it
earlier. Which ET Open rules fired when you replayed it through your Suricata.]

**How I checked my work.** [Compare against the published answer key; note
anything you missed and why.]
