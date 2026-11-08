# Phase 4: Zeek Network Metadata

Goal: Zeek running alongside Suricata, turning raw traffic into readable
connection logs. Where Suricata says "this packet matched a known-bad pattern",
Zeek says "here is every connection, in full, go hunt."

## 1. Install

Zeek is not in the Ubuntu repos, so add the official OpenSUSE Build Service repo
(this is the method from the Zeek docs for Ubuntu 24.04):

```bash
echo 'deb http://download.opensuse.org/repositories/security:/zeek/xUbuntu_24.04/ /' \
  | sudo tee /etc/apt/sources.list.d/security:zeek.list
curl -fsSL https://download.opensuse.org/repositories/security:zeek/xUbuntu_24.04/Release.key \
  | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/security_zeek.gpg > /dev/null
sudo apt update
sudo apt install -y zeek-8.0
```

Zeek installs under `/opt/zeek`. Add it to your PATH:

```bash
echo 'export PATH=$PATH:/opt/zeek/bin' >> ~/.bashrc && source ~/.bashrc
zeek --version
```

> [!NOTE]
> The `zeek-8.0` package pins the 8.0 LTS line, so an `apt upgrade` will not
> jump you to a new feature release mid-lab. That is the behaviour you want for
> something you are documenting.

## 2. Configure it for the lab

```bash
sudo bash scripts/sensor/configure-zeek.sh          # assumes enp0s3
```

It installs three small config pieces and then deploys:

| File | Sets |
|---|---|
| `/opt/zeek/etc/node.cfg` | Standalone node sniffing `enp0s3` |
| `/opt/zeek/etc/networks.cfg` | `10.0.50.0/24` is "local" (so `conn.log` marks local vs remote) |
| appended to `site/local.zeek` | ignore VirtualBox checksum offload, add community-id, log MACs |

The community-id line is the important one: it makes Zeek write the same flow
hash Suricata writes, so a Suricata alert and its matching Zeek connection share
one ID.

> [!TIP]
> `redef ignore_checksums = T;` is in the config for the same reason the sensor
> NIC prep turns off offloading. VirtualBox hands up packets with checksums the
> host never finished computing, and without this line Zeek quietly ignores
> them and your logs come out half empty.

## 3. Confirm it is logging

```bash
sudo /opt/zeek/bin/zeekctl status
ls -l /opt/zeek/logs/current/
```

Generate a little traffic (from Kali, `ping 10.0.50.30` or `curl http://10.0.50.30`)
and then look:

```bash
cat /opt/zeek/logs/current/conn.log
# human-readable columns:
/opt/zeek/bin/zeek-cut -d ts id.orig_h id.resp_h id.resp_p proto service < /opt/zeek/logs/current/conn.log
```

The core logs you will use:

| Log | Holds |
|---|---|
| `conn.log` | Every connection: who, to whom, port, duration, bytes, state |
| `dns.log` | Every DNS query and answer (the DNS tunneling evidence) |
| `http.log` | HTTP requests: host, URI, method, user-agent, status |
| `ftp.log` | FTP commands including `USER` / `PASS` |
| `ssl.log` / `x509.log` | TLS handshakes and certs |

## 4. How Zeek earns its place here

Suricata already catches five of the six scenarios with a signature. The sixth,
the C2 beacon, is the one a signature struggles with, because the beacon is
built to look ordinary on any single request. Zeek wins there by looking across
*many* connections:

```bash
# after the beacon scenario has run for a while
python3 scripts/analysis/beacon_detect.py /opt/zeek/logs/current/conn.log
```

That script groups connections by (source, destination, port) and flags the
pairs whose timing is suspiciously regular. That is covered in Phase 7; the
point for now is that Zeek's logs are what make it possible.

## Screenshot checklist

- [x] `zeekctl status` showing the node running (screenshot 7)
- [ ] `conn.log` through `zeek-cut` with real connections
- [ ] `dns.log` or `http.log` populated after some traffic
