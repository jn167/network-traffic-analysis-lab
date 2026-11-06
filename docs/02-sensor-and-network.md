# Phase 2: Sensor VM and Network Visibility

Goal: a new VM, `nids-sensor`, that can see **all** traffic on the lab network,
not just its own. This is the part people get wrong, so it gets its own phase.

## 1. Why a sensor needs special treatment

A switch (and a VirtualBox NAT network behaves like one) only sends each host
the traffic meant for it. A sensor that just joins the network sees broadcasts
and its own conversations, and nothing else. To watch other machines you need
two things:

- the virtual NIC set to **promiscuous mode**, so it keeps frames addressed to
  other machines instead of dropping them, and
- VirtualBox told to actually deliver those frames to the adapter.

> [!IMPORTANT]
> On real hardware you would configure a SPAN / mirror port on the switch. In
> VirtualBox the equivalent is the adapter's **Promiscuous Mode** setting, which
> is what lets one VM observe the others on the same NAT network.

## 2. Create the VM

In VirtualBox: **Machine > New**, check **Skip Unattended Installation** so you
can set a static IP during install.

| Setting | Value |
|---|---|
| Name | `nids-sensor` |
| Type / Version | Linux / Ubuntu (64-bit) |
| RAM | 4096 MB |
| vCPU | 2 |
| Disk | 40 GB |
| Network Adapter 1 | NAT Network: **SIEMLab** |

Install Ubuntu Server 24.04 LTS. During install:

- Static IP: address `10.0.50.50/24`, gateway `10.0.50.1`, DNS `10.0.50.1`.
- Check **Install OpenSSH server**.

If you installed with DHCP by mistake, fix it the same way as in Lab 1 by
editing `/etc/netplan/50-cloud-init.yaml` and running `sudo netplan apply`.

## 3. Add the SSH port forward for the sensor

So you can SSH to the sensor and copy captures off it, add a host port forward.
Run on the Windows host in PowerShell (the Lab 1 script is extended here):

```powershell
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" natnetwork modify `
  --netname SIEMLab --port-forward-4 "sensor-ssh:tcp:[127.0.0.1]:2250:[10.0.50.50]:22"
```

Now `ssh user@127.0.0.1 -p 2250` from the host reaches the sensor.

## 4. Turn on promiscuous mode in VirtualBox

With `nids-sensor` powered off:

**Settings > Network > Adapter 1 > Advanced > Promiscuous Mode: `Allow All`**

> [!WARNING]
> `Allow All` means this adapter can see every other VM's traffic on the NAT
> network. That is exactly what a sensor is for, but it is also why you only set
> it on the sensor, and only on an isolated lab network, never on an adapter
> bridged to your real LAN.

## 5. Prep the NIC inside the guest

Boot the sensor, clone this repo onto it, and run the prep script. It sets
promiscuous mode on the interface, turns off NIC offloading (which otherwise
mangles captured packets), and makes both survive a reboot.

```bash
sudo bash scripts/sensor/prep-sensor-nic.sh          # assumes enp0s3
```

Check the interface name first with `ip a` if you are not sure; pass it as an
argument if it is not `enp0s3`.

> [!TIP]
> Offloading (GRO/LRO) lets the NIC hand the OS huge pre-assembled "packets"
> for speed. Great for a server, bad for a sensor: your capture shows 40 KB
> segments that never existed on the wire, and checksums look wrong. The prep
> script turns it off so captures match reality.

## 6. Prove the sensor can see other machines

This is the gate for the whole lab. Do not move on until it passes.

On the sensor:

```bash
sudo bash scripts/sensor/verify-visibility.sh
```

While it runs, go to `kali-attacker` and ping the Linux endpoint:

```bash
ping -c 10 10.0.50.30
```

The sensor is watching traffic between two **other** hosts. If it reports
packets seen, mirroring works. If it sees nothing, the fix is almost always the
VirtualBox **Promiscuous Mode: Allow All** setting from step 4.

<div align="center">
  <em>Screenshot to capture: verify-visibility.sh reporting PASS with the ICMP
  packets between kali and linux-endpoint. (screenshots/)</em>
</div>

## Screenshot checklist

- [ ] VirtualBox showing the sensor's Adapter 1 set to Promiscuous Mode: Allow All
- [ ] `ip -br link` on the sensor showing `PROMISC`
- [ ] `verify-visibility.sh` PASS output
