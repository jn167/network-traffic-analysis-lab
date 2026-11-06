#!/usr/bin/env python3
"""
dns_reassemble.py: rebuild a file that was leaked over DNS, the way a defender
would after finding the tunneling in their logs.

It reads the queried names (either the dnsmasq query log from the lab DNS
server, or a Zeek dns.log), keeps the ones under the tunnel domain, puts the
chunks back in sequence order, and base32-decodes them.

Usage:
    # from the lab DNS server's log
    python3 dns_reassemble.py /var/log/dnsmasq-ntalab.log

    # from a Zeek dns.log, naming the tunnel domain explicitly
    python3 dns_reassemble.py dns.log --domain t.ntalab.test

The query format this expects (produced by scripts/kali/dns-exfil.sh):
    <base32-chunk>.<4-digit-seq>.t.ntalab.test
"""
import argparse
import base64
import re
import sys

DEFAULT_DOMAIN = "t.ntalab.test"


def extract_names(path):
    """Pull queried DNS names out of a dnsmasq log or a Zeek dns.log."""
    names = []
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line:
                continue
            # dnsmasq: "... query[A] <name> from <ip>"
            m = re.search(r"query\[[A-Z]+\]\s+(\S+)\s+from", line)
            if m:
                names.append(m.group(1))
                continue
            if line.startswith("#") or line.startswith("{"):
                # Zeek TSV comment lines are skipped; JSON handled below
                if line.startswith("{"):
                    import json
                    try:
                        q = json.loads(line).get("query")
                        if q:
                            names.append(q)
                    except ValueError:
                        pass
                continue
            # Zeek TSV dns.log: the query is a tab-separated field containing the domain
            for field in line.split("\t"):
                if field.endswith(DEFAULT_DOMAIN) or ".ntalab.test" in field:
                    names.append(field)
                    break
    return names


def reassemble(names, domain):
    suffix = "." + domain.lstrip(".")
    chunks = {}
    for name in names:
        if not name.endswith(suffix):
            continue
        labels = name[: -len(suffix)].split(".")
        if len(labels) < 2:
            continue
        chunk, seq = labels[0], labels[1]
        if not seq.isdigit():
            continue
        chunks[int(seq)] = chunk

    if not chunks:
        return None, 0
    ordered = "".join(chunks[i] for i in sorted(chunks))
    pad = "-" * ((8 - len(ordered) % 8) % 8)
    data = base64.b32decode((ordered + pad).upper())
    return data, len(chunks)


def main():
    ap = argparse.ArgumentParser(description="Rebuild a DNS-tunneled file from query logs.")
    ap.add_argument("log", help="dnsmasq query log or Zeek dns.log")
    ap.add_argument("--domain", default=DEFAULT_DOMAIN, help=f"tunnel domain (default {DEFAULT_DOMAIN})")
    ap.add_argument("-o", "--out", help="write the recovered bytes to this file instead of stdout")
    args = ap.parse_args()

    names = extract_names(args.log)
    data, n = reassemble(names, args.domain)
    if not data:
        print("No tunnel queries found. Check the domain with --domain.", file=sys.stderr)
        sys.exit(1)

    print(f"[+] Recovered {len(data)} bytes from {n} DNS queries.", file=sys.stderr)
    if args.out:
        with open(args.out, "wb") as fh:
            fh.write(data)
        print(f"[+] Written to {args.out}", file=sys.stderr)
    else:
        sys.stdout.buffer.write(data)


if __name__ == "__main__":
    main()
