#!/usr/bin/env python3
"""
beacon_detect.py: find C2-style beaconing in Zeek conn.log files.

Malware that "checks in" with its controller tends to connect to the same
destination over and over at a fairly steady interval (sometimes with a bit
of random jitter). Humans and most normal software do not. This script
groups connections by (source, destination, destination port), measures the
time between connections, and flags pairs whose timing is unusually regular.

Score: the coefficient of variation (CV) of the intervals, stddev / mean.
    CV near 0   -> clockwork timing, very beacon-like
    CV ~0.1-0.3 -> steady with jitter (a common malware setting)
    CV >= 1     -> bursty, human-like

Works with Zeek's default TSV logs or JSON logs, plain or .gz.

Usage:
    python3 beacon_detect.py /opt/zeek/logs/current/conn.log
    python3 beacon_detect.py /opt/zeek/logs/2026-11-*/conn.*.log.gz --min-conns 10 --max-cv 0.3
"""
import argparse
import gzip
import json
import statistics
import sys
from collections import defaultdict


def open_log(path):
    if path.endswith(".gz"):
        return gzip.open(path, "rt", encoding="utf-8", errors="replace")
    return open(path, "r", encoding="utf-8", errors="replace")


def read_conn_log(path):
    """Yield (ts, orig_h, resp_h, resp_p) for each connection in a conn.log."""
    fields = None
    with open_log(path) as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line:
                continue
            if line.startswith("{"):  # JSON log
                rec = json.loads(line)
                yield (float(rec["ts"]), rec["id.orig_h"], rec["id.resp_h"], int(rec["id.resp_p"]))
                continue
            if line.startswith("#fields"):  # TSV header
                fields = line.split("\t")[1:]
                continue
            if line.startswith("#") or fields is None:
                continue
            rec = dict(zip(fields, line.split("\t")))
            yield (float(rec["ts"]), rec["id.orig_h"], rec["id.resp_h"], int(rec["id.resp_p"]))


def analyze(paths, min_conns, max_cv, min_interval):
    groups = defaultdict(list)
    for path in paths:
        try:
            for ts, src, dst, dport in read_conn_log(path):
                groups[(src, dst, dport)].append(ts)
        except (OSError, KeyError, ValueError) as exc:
            print(f"[!] skipping {path}: {exc}", file=sys.stderr)

    results = []
    for (src, dst, dport), stamps in groups.items():
        if len(stamps) < min_conns:
            continue
        stamps.sort()
        intervals = [b - a for a, b in zip(stamps, stamps[1:])]
        mean = statistics.mean(intervals)
        if mean < min_interval:  # sub-second repeats are bulk traffic, not check-ins
            continue
        stdev = statistics.pstdev(intervals)
        cv = stdev / mean if mean else float("inf")
        results.append({
            "src": src, "dst": dst, "dport": dport, "conns": len(stamps),
            "mean_s": mean, "stdev_s": stdev, "cv": cv,
            "first": stamps[0], "last": stamps[-1],
            "suspicious": cv <= max_cv,
        })
    results.sort(key=lambda r: (not r["suspicious"], r["cv"]))
    return results


def main():
    ap = argparse.ArgumentParser(description="Flag beacon-like connection timing in Zeek conn.log files.")
    ap.add_argument("logs", nargs="+", help="conn.log files (TSV or JSON, optionally .gz)")
    ap.add_argument("--min-conns", type=int, default=10, help="ignore pairs with fewer connections (default 10)")
    ap.add_argument("--max-cv", type=float, default=0.3, help="flag pairs at or below this CV (default 0.3)")
    ap.add_argument("--min-interval", type=float, default=1.0, help="ignore pairs whose mean gap is under N seconds (default 1)")
    ap.add_argument("--all", action="store_true", help="also print pairs that were not flagged")
    args = ap.parse_args()

    results = analyze(args.logs, args.min_conns, args.max_cv, args.min_interval)
    shown = [r for r in results if r["suspicious"] or args.all]
    if not shown:
        print("No beacon-like pairs found with the current thresholds.")
        return

    print(f"{'FLAG':<8}{'SOURCE':<17}{'DESTINATION':<17}{'PORT':>6}{'CONNS':>7}{'MEAN(s)':>9}{'STDEV(s)':>10}{'CV':>7}")
    for r in shown:
        flag = "BEACON" if r["suspicious"] else ""
        print(f"{flag:<8}{r['src']:<17}{r['dst']:<17}{r['dport']:>6}{r['conns']:>7}"
              f"{r['mean_s']:>9.1f}{r['stdev_s']:>10.1f}{r['cv']:>7.2f}")


if __name__ == "__main__":
    main()
