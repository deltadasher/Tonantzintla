#!/usr/bin/env python3
"""Read a specified process's proportional memory; never starts or stops it."""
import argparse
import json
from pathlib import Path
import time


def parse_rollup(text):
    values = {}
    for line in text.splitlines():
        key, separator, value = line.partition(":")
        parts = value.split()
        if separator and len(parts) == 2 and parts[1] == "kB":
            try:
                values[key] = int(parts[0])
            except ValueError:
                continue
    def mib(key):
        return round(values[key] / 1024, 3) if key in values else None
    private = None
    if "Private_Clean" in values and "Private_Dirty" in values:
        private = round((values["Private_Clean"] + values["Private_Dirty"]) / 1024, 3)
    return {"rss_bytes": values["Rss"] * 1024 if "Rss" in values else None,
            "rss_mib": mib("Rss"), "pss_mib": mib("Pss"),
            "private_mib": private, "swap_pss_mib": mib("SwapPss")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pid", type=int, nargs="+", help="Quickshell and Niri PIDs; add owned helper PIDs to include them")
    parser.add_argument("--budget-mb", type=float, default=450, help="Combined RSS limit in decimal MB")
    parser.add_argument("--samples", type=int, default=1)
    parser.add_argument("--interval", type=float, default=1)
    args = parser.parse_args()
    if any(pid < 1 for pid in args.pid) or len(set(args.pid)) != len(args.pid) or not 0 < args.budget_mb <= 100000 or not 1 <= args.samples <= 60 or not 0.1 <= args.interval <= 10:
        parser.error("PID must be positive; samples 1–60; interval 0.1–10 seconds")
    identities = {}
    samples = []
    try:
        for index in range(args.samples):
            # Start time disambiguates PID reuse. The command can contain spaces.
            processes = []
            for pid in args.pid:
                proc = Path("/proc") / str(pid)
                start = proc.joinpath("stat").read_text().rsplit(")", 1)[1].split()[19]
                if pid in identities and start != identities[pid]:
                    raise RuntimeError("PID was reused; measurement stopped")
                identities[pid] = start
                values = parse_rollup(proc.joinpath("smaps_rollup").read_text())
                values["pid"] = pid
                processes.append(values)
            rss_mb = sum(p["rss_bytes"] for p in processes) / 1000000 if all(p["rss_bytes"] is not None for p in processes) else None
            sample = {"monotonic_seconds": round(time.monotonic(), 3), "processes": processes,
                      "combined_rss_MB": round(rss_mb, 3) if rss_mb is not None else None,
                      "within_budget": rss_mb <= args.budget_mb if rss_mb is not None else None}
            samples.append(sample)
            if index + 1 < args.samples:
                time.sleep(args.interval)
    except (OSError, RuntimeError, IndexError) as error:
        print(json.dumps({"pids": args.pid, "error": str(error), "samples": samples}))
        return 1
    print(json.dumps({"pids": args.pid, "budget_MB": args.budget_mb, "samples": samples,
                      "note": "PSS apportions shared pages. Compare the same process state and rendering backend; GPU allocations may be outside these figures."}, indent=2))
    return 0 if all(s["within_budget"] is True for s in samples) else 2


if __name__ == "__main__":
    raise SystemExit(main())
