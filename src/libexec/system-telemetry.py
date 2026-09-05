#!/usr/bin/env python3
"""Emit compact, compositor-independent system telemetry for Tonantzintla."""

from __future__ import annotations

import argparse
import glob
import json
import os
import shutil
import subprocess
import time
from pathlib import Path


def read_text(path: str, fallback: str = "") -> str:
    try:
        return Path(path).read_text(encoding="utf-8").strip()
    except (OSError, UnicodeError):
        return fallback


def cpu_sample() -> tuple[int, int]:
    fields = read_text("/proc/stat").splitlines()[0].split()[1:]
    values = [int(value) for value in fields]
    idle = values[3] + (values[4] if len(values) > 4 else 0)
    return sum(values), idle


def memory_from_text(raw: str) -> tuple[int, int]:
    values: dict[str, int] = {}
    for line in raw.splitlines():
        if ":" not in line:
            continue
        key, raw = line.split(":", 1)
        try:
            values[key] = int(raw.strip().split()[0]) * 1024
        except (ValueError, IndexError):
            pass
    total = values.get("MemTotal", 0)
    available = values.get("MemAvailable", total)
    return total, max(0, min(total, total - available))


def memory() -> tuple[int, int]:
    return memory_from_text(read_text("/proc/meminfo"))


def network_totals() -> tuple[int, int]:
    rx = tx = 0
    for line in read_text("/proc/net/dev").splitlines()[2:]:
        if ":" not in line:
            continue
        name, raw = line.split(":", 1)
        if name.strip() == "lo":
            continue
        fields = raw.split()
        if len(fields) >= 9:
            rx += int(fields[0])
            tx += int(fields[8])
    return rx, tx


def temperatures() -> tuple[int, int]:
    cpu_values: list[int] = []
    gpu_values: list[int] = []
    for hwmon in glob.glob("/sys/class/hwmon/hwmon*"):
        name = read_text(os.path.join(hwmon, "name")).lower()
        values = []
        for path in glob.glob(os.path.join(hwmon, "temp*_input")):
            try:
                raw = int(read_text(path, "0"))
                value = round(raw / 1000 if raw > 1000 else raw)
                if 0 < value < 150:
                    values.append(value)
            except ValueError:
                pass
        if not values:
            continue
        if any(token in name for token in ("amdgpu", "nouveau", "nvidia")):
            gpu_values.extend(values)
        elif any(token in name for token in ("coretemp", "k10temp", "zenpower", "cpu", "acpitz")):
            cpu_values.extend(values)
    return max(cpu_values, default=0), max(gpu_values, default=0)


def process_count() -> int:
    return sum(1 for entry in os.scandir("/proc") if entry.name.isdigit())


def slow_snapshot() -> dict[str, object]:
    """Collect values that do not need bar-rate refreshes."""

    disk = shutil.disk_usage(str(Path.home()))
    cpu_temp, gpu_temp = temperatures()
    return {
        "disk_total": disk.total,
        "disk_used": disk.used,
        "cpu_temp": cpu_temp,
        "gpu_temp": gpu_temp,
        "processes": process_count(),
        "hostname": os.uname().nodename,
        "kernel": os.uname().release,
    }


def snapshot(slow: dict[str, object] | None = None) -> dict[str, object]:
    cpu_total, cpu_idle = cpu_sample()
    memory_total, memory_used = memory()
    rx_total, tx_total = network_totals()
    uptime = float(read_text("/proc/uptime", "0").split()[0])
    payload = {
        "cpu_total": cpu_total,
        "cpu_idle": cpu_idle,
        "memory_total": memory_total,
        "memory_used": memory_used,
        "rx_total": rx_total,
        "tx_total": tx_total,
        "uptime": round(uptime),
        "load": [round(value, 2) for value in os.getloadavg()],
    }
    payload.update(slow if slow is not None else slow_snapshot())
    return payload


def watch_snapshots(interval: float) -> None:
    """Stream telemetry without paying Python startup cost every sample."""

    delay = max(0.5, interval)
    slow = slow_snapshot()
    slow_refresh = max(1, round(10 / delay))
    iteration = 0
    while True:
        if iteration > 0 and iteration % slow_refresh == 0:
            slow = slow_snapshot()
        print(json.dumps(snapshot(slow), separators=(",", ":")), flush=True)
        iteration += 1
        time.sleep(delay)


def folder_sizes() -> dict[str, object]:
    home = Path.home()
    candidates = [
        home / "Downloads", home / "Documents", home / "Pictures",
        home / "Videos", home / "Music", home / "Games",
        home / ".config", home / ".cache", home / ".local" / "share",
    ]
    rows = []
    for path in candidates:
        if not path.exists():
            continue
        try:
            result = subprocess.run(
                ["du", "-sk", "--", str(path)], capture_output=True,
                text=True, timeout=15, check=False,
            )
            size_kib = int(result.stdout.split()[0]) if result.stdout.strip() else 0
            rows.append({"name": path.name, "path": str(path), "bytes": size_kib * 1024})
        except (OSError, ValueError, subprocess.TimeoutExpired):
            pass
    rows.sort(key=lambda row: row["bytes"], reverse=True)
    return {"folders": rows[:6]}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--folders", action="store_true")
    parser.add_argument("--slow", action="store_true")
    parser.add_argument("--watch", type=float, metavar="SECONDS")
    args = parser.parse_args()
    if args.watch is not None:
        watch_snapshots(args.watch)
        return
    payload = folder_sizes() if args.folders else slow_snapshot() if args.slow else snapshot()
    print(json.dumps(payload, separators=(",", ":")))


if __name__ == "__main__":
    main()
