# Phase 6: Target Services on linux-endpoint

Goal: give `linux-endpoint` a few deliberately weak, unencrypted services for
the scenarios to attack. These are what produce the cleartext credentials and
the DNS traffic you will later find in the captures.

## 1. What gets installed

Run on `linux-endpoint` from the repo root:

```bash
sudo bash scripts/target/setup-target-services.sh
```

| Service | Port | Lab account | Purpose |
|---|---|---|---|
| vsftpd (FTP) | 21 | `ftplab` / `Ftp-Lab-2026` | Sends the password in cleartext (scenario 3) |
| Apache (HTTP) | 80 | `labadmin` / `Web-Lab-2026` | `/admin` behind HTTP Basic auth (scenario 4) |
| dnsmasq (DNS) | 53 | n/a | Answers `*.ntalab.test`, the tunnel endpoint (scenario 5) |

SSH (the `labvictim` account) is already there from Lab 1 and is reused for the
brute-force scenario.

> [!WARNING]
> These services are insecure on purpose and the passwords are fixed and public
> in this repo. They exist only on an isolated lab VM. Never reuse these
> accounts or run these services on anything reachable from a real network.

> [!NOTE]
> The script refuses to run unless the host's IP is `10.0.50.30`, so you cannot
> accidentally install weak services on the wrong machine. `dnsmasq` is
> configured to bind only `10.0.50.30` and forward nothing, so it will not fight
> with `systemd-resolved` or answer anything outside the lab.

## 2. The DNS endpoint for tunneling

`dnsmasq` is set to answer every name under `ntalab.test` and forward nothing
else. `ntalab.test` uses the reserved `.test` TLD, which can never resolve on
the real internet, so the DNS tunneling scenario stays entirely inside the lab
even though "exfil over DNS" is the whole idea.

## 3. Self-test

From `kali-attacker`, confirm each service answers before running the scenarios:

```bash
# FTP banner
curl -s --max-time 5 ftp://10.0.50.30/ --user ftplab:Ftp-Lab-2026 | head

# HTTP Basic auth page (expect HTTP 200 with the right password, 401 without)
curl -s -o /dev/null -w '%{http_code}\n' -u labadmin:Web-Lab-2026 http://10.0.50.30/admin/

# DNS answers for the tunnel domain
dig +short @10.0.50.30 test.ntalab.test
```

Expected: the FTP banner prints, the HTTP code is `200`, and the `dig` returns
`10.0.50.30`.

## 4. Undo when you are done

```bash
sudo bash scripts/target/setup-target-services.sh --remove
```

That disables the services, removes the lab config and the `ftplab` account, and
leaves the packages installed (add `apt purge vsftpd apache2 dnsmasq` to remove
those too).

## Screenshot checklist

- [x] `ss -ltnup` on linux-endpoint showing ports 21, 22, 53, 80 listening (screenshot 11)
- [x] The three self-test commands succeeding from Kali (curl + dig verified from Kali)
