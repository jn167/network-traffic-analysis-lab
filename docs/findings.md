# Investigations

Analyst-style write-ups of the detections in this lab. Each follows the shape a
SOC analyst uses: what fired, what the traffic actually shows, the verdict, the
response, and how to detect it going forward.

---

## Investigation 1: Cleartext credentials on the wire

- **Source:** `03-cleartext-creds.pcap`
- **ATT&CK:** T1040 Network Sniffing
- **Triggered:** Suricata 1000003 (FTP password in cleartext) and 1000004 (HTTP
  Basic auth in cleartext), both from `10.0.50.40` to `10.0.50.30`.

**What happened.** Two logins crossed the network in the clear. The FTP session
carried the `USER` and `PASS` commands as readable text (`PASS Ftp-Lab-2026`).
The HTTP request to `/admin/` carried an `Authorization: Basic` header holding
`bGFiYWRtaW46V2ViLUxhYi0yMDI2`, which is not encryption, only base64: decoding
it returns `labadmin:Web-Lab-2026`. Anyone positioned to watch the traffic, like
this sensor, reads both credentials with no cracking required.

**Verdict.** Exposure / policy violation. The "attack" is just logging in, but
the finding is that the credentials are recoverable by any observer because the
services use unencrypted protocols.

**Response.** Rotate both exposed accounts, move the services behind TLS (FTPS
or SFTP for file transfer, HTTPS for the admin page), and flag the plaintext
services to their owner for retirement.

**Detection going forward.** Keep the cleartext-credential signatures, and more
broadly alert on plaintext authentication protocols appearing on the network at
all (FTP, Telnet, HTTP Basic over port 80). Low false-positive risk in an
environment that is supposed to be all-TLS.

---

## Investigation 2: SSH brute force, and why the first rule missed it

- **Source:** `02-ssh-bruteforce.pcap`
- **ATT&CK:** T1110.001 Password Guessing
- **Triggered:** Suricata 1000002 (SSH brute force, connection burst), after
  tuning.

**What happened.** Hydra ran a 20-password list against the `labvictim` account
on `10.0.50.30` and ended on a successful login. On the wire this is a burst of
SSH sessions from one source followed by one that succeeds.

**The interesting part.** The rule did not fire at first. Counting SYNs in the
capture showed only 5 new connections to port 22 for all 20 guesses, because SSH
permits several password attempts per connection (MaxAuthTries). The original
threshold of 10 connections in 60 seconds was never reached. Lowering it to 4
caught it. The broader lesson: a connection-rate rule systematically
under-detects brute force against any protocol that reuses a connection for
multiple attempts.

**Verdict.** Malicious. The account should be treated as compromised, since the
run ended in a successful login with a guessed password.

**Response.** Disable or reset the `labvictim` account, review what that account
could reach, and check for any session that opened after the successful guess.

**Detection going forward.** The network rule is a useful tripwire but brittle
here. The more reliable detection is log-based: counting failed-password events
in `auth.log`, which the Lab 1 Wazuh setup already does (built-in SSH brute-force
correlation), and which is independent of how many TCP connections the attacker
used. Best practice is to run both and corroborate.

---

## Investigation 3: C2 beacon caught by timing

- **Source:** `06-c2-beacon.pcap` and the Zeek `conn.log`
- **ATT&CK:** T1071.001 Application Layer Protocol: Web Protocols
- **Triggered:** Suricata 1000006 (check-in shape), and `beacon_detect.py` on the
  Zeek connection log.

**What happened.** `10.0.50.30` checked in to `10.0.50.40:8080` repeatedly on a
near-regular interval. Each request was an ordinary-looking HTTP GET to
`/updates/check`, and it even carried a normal Chrome User-Agent, so nothing
about a single request looks malicious.

**How it was caught.** The timing gave it away. `beacon_detect.py` grouped
connections by source, destination, and port and measured the gaps: 15 check-ins
to `10.0.50.40:8080` with a mean of 20.5 seconds and a coefficient of variation
of 0.11, far more regular than human or normal software traffic. Suricata also
caught the request shape (a check-in path to a raw IP on a non-standard port),
but the UA spoofing shows why a content signature alone is fragile.

**Verdict.** Compromised host beaconing to a controller. Treat `10.0.50.30` as
compromised.

**Response.** Isolate the host, block the destination, hunt for the initial
access that planted the implant, and preserve the capture for IR.

**Detection going forward.** The durable detection is behavioral: flag
destinations that a host contacts on a regular, low-variance interval, using
connection metadata (Zeek) rather than payload signatures. Signatures on the
request shape help but are easy for an attacker to vary.

---

## Planned: public malware pcap

A full investigation of an unknown capture from
[malware-traffic-analysis.net](https://www.malware-traffic-analysis.net/training-exercises.html)
is the natural next exercise: work it from an IDS alert with no prior knowledge,
identify the infected host, the C2, and the response, then replay it through this
lab's Suricata to see which ET Open rules fire. That one is worked carefully by
hand rather than scripted; it will be added here when complete.
