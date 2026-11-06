# Phase 8: Analysis and Investigations

Goal: turn the captures into findings. First by reading your own lab captures in
Wireshark, then by working a capture you did not create, the way a SOC analyst
picks up an unknown pcap. Write-ups go in [`docs/findings.md`](findings.md).

## Part A: Read your own captures in Wireshark

Copy the pcaps from the sensor to your host (the capture script prints the
exact `scp -P 2250 ...` line) and open them in Wireshark. These are the moves
worth knowing.

### Pull the cleartext password out (scenario 3/4)

Open `03-cleartext-creds.pcap`.

- **FTP:** filter `ftp`. You will see `USER ftplab` and `PASS Ftp-Lab-2026` in
  plain text. Right-click a packet > **Follow > TCP Stream** to read the whole
  session as a conversation.
- **HTTP Basic:** filter `http.authorization`. The `Authorization: Basic` header
  holds `bGFiYWRtaW46V2ViLUxhYi0yMDI2`. That is base64, not encryption:
  `echo bGFiYWRtaW46V2ViLUxhYi0yMDI2 | base64 -d` gives `labadmin:Web-Lab-2026`.

> [!IMPORTANT]
> This is the single most useful thing to show someone about why "it has a
> login box" is not the same as "it is secure." The password crossed the wire
> readable by anyone watching. That is the entire argument for TLS in one screen.

### See the scan (scenario 1)

Open `01-recon-scan.pcap`, filter `tcp.flags.syn == 1 && tcp.flags.ack == 0`.
A wall of SYNs from `10.0.50.40` to many ports on `10.0.50.30`, most with no
reply, is the scan. **Statistics > Conversations** shows one host talking to
hundreds of ports, the shape of reconnaissance.

### Trace the DNS tunneling (scenario 5)

Open `05-dns-exfil.pcap`, filter `dns`. The queries have absurdly long labels of
encoded text, nothing like a normal hostname. **Statistics > DNS** shows the
volume. This is the visual that justifies alerting on label length.

### Spot the beacon (scenario 6)

Open `06-c2-beacon.pcap`, filter `http.request`. The same GET to
`/updates/check` repeats on a near-regular interval to the same destination.
**Statistics > Conversations > TCP**, sorted by time, shows the drumbeat. Note
how ordinary each single request looks, which is why the Zeek timing analysis
does the real work here.

## Part B: Work a capture you did not make

Everything so far, you set up, so you knew the answer in advance. Real analysis
starts from an alert and an unfamiliar pcap. This part practises that.

[malware-traffic-analysis.net](https://www.malware-traffic-analysis.net/training-exercises.html)
publishes real malware traffic captures as training exercises, each with a
scenario and a separate answer key. Pick a recent one and work it before
reading the answers.

> [!WARNING]
> The pcap archives on that site are password-protected (the password is on the
> site) **because some contain real malware binaries extracted from the
> traffic**. Only open them inside a lab VM you can throw away, never on your
> daily machine, and do not execute anything extracted from them. For this phase
> you are reading packets, not running files.

> [!TIP]
> Work the analysis on the `nids-sensor` or a disposable VM. You can even replay
> the pcap past your own Suricata to see which ET Open rules fire on real
> malware:
> `suricata -r exercise.pcap -S /etc/suricata/rules/suricata.rules -l ./out`,
> then read `out/fast.log`. That connects this phase back to the IDS you built.

Answer the standard SOC questions and write them up in `findings.md`:

1. **Which host is infected?** (IP, MAC, hostname from DHCP/NBNS, Windows user
   if visible)
2. **When did it start?** (first suspicious packet, timestamp)
3. **What is the malware doing?** (C2 domains/IPs, what was downloaded, any
   exfil)
4. **How would you detect this?** (what rule or indicator would have caught it
   earlier)
5. **What is the response?** (contain the host, block the indicators, next steps)

That last pair is the point: tie what you see in the packets back to a
detection and a response, which is what separates "I found it in Wireshark"
from "I handled it."

## Writing the investigations

For both your own captures and the public pcap, write each one up in
[`docs/findings.md`](findings.md) using the template there: what triggered it,
what the traffic actually shows, the verdict, the response, and how you would
detect it going forward. Three solid write-ups (say, the cleartext-creds
capture, the beacon, and the public pcap) is a good target.

## Screenshot checklist

- [ ] Wireshark Follow-TCP-Stream showing the FTP password in cleartext
- [ ] The decoded HTTP Basic credentials
- [ ] The DNS tunneling queries with long labels
- [ ] The repeating beacon requests in the HTTP view
- [ ] Your Suricata replay (`fast.log`) on the public pcap
