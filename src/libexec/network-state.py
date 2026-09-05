#!/usr/bin/env python3
"""Collect Wi-Fi, Bluetooth, and Ethernet state for Tonantzintla Link Array."""

from __future__ import annotations

import json
from pathlib import Path
import shutil
import subprocess
import sys


def run(args: list[str], timeout: int = 6) -> str:
    try:
        return subprocess.run(
            args, capture_output=True, text=True, timeout=timeout, check=False
        ).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def networkmanager_available() -> bool:
    return shutil.which("nmcli") is not None and run(
        ["nmcli", "-t", "-f", "RUNNING", "general"]
    ).strip() == "running"


def parse_iw_link(output: str) -> dict[str, object] | None:
    if "Not connected." in output:
        return None
    ssid = ""
    frequency = ""
    signal = 0
    for raw_line in output.splitlines():
        line = raw_line.strip()
        if line.startswith("SSID: "):
            ssid = line.removeprefix("SSID: ").strip()
        elif line.startswith("freq: "):
            frequency = line.removeprefix("freq: ").strip().split(".", 1)[0]
        elif line.startswith("signal: "):
            try:
                dbm = float(line.removeprefix("signal: ").split()[0])
                signal = round(max(0, min(100, 2 * (dbm + 100))))
            except ValueError:
                signal = 0
    if not ssid:
        return None
    return {
        "ssid": ssid,
        "security": "UNKNOWN",
        "secure": True,
        "signal": signal,
        "frequency": frequency,
        "connected": True,
        "saved": True,
    }


def parse_iw_interfaces(output: str) -> list[str]:
    interfaces = []
    for raw_line in output.splitlines():
        line = raw_line.strip()
        if line.startswith("Interface "):
            interface = line.removeprefix("Interface ").strip()
            if interface and interface not in interfaces:
                interfaces.append(interface)
    return interfaces


def wireless_interfaces(
    proc_wireless: Path = Path("/proc/net/wireless"),
    sys_class_net: Path = Path("/sys/class/net"),
) -> list[str]:
    interfaces: list[str] = []
    try:
        lines = proc_wireless.read_text().splitlines()[2:]
    except OSError:
        lines = []
    for line in lines:
        if ":" in line:
            interface = line.split(":", 1)[0].strip()
            if interface and interface not in interfaces:
                interfaces.append(interface)
    try:
        devices = list(sys_class_net.iterdir())
    except OSError:
        devices = []
    for device in devices:
        if (device / "wireless").exists() and device.name not in interfaces:
            interfaces.append(device.name)
    if shutil.which("iw") is not None:
        for interface in parse_iw_interfaces(run(["iw", "dev"])):
            if interface not in interfaces:
                interfaces.append(interface)
    return interfaces


def kernel_active_wifi() -> list[dict[str, object]]:
    interfaces = wireless_interfaces()
    if shutil.which("iw") is not None:
        for interface in interfaces:
            row = parse_iw_link(run(["iw", "dev", interface, "link"]))
            if row is not None:
                row["device"] = interface
                return [row]
    for interface in interfaces:
        try:
            state = (Path("/sys/class/net") / interface / "operstate").read_text().strip()
        except OSError:
            continue
        if state == "up":
            return [{
                "ssid": interface,
                "security": "UNKNOWN",
                "secure": True,
                "signal": 0,
                "frequency": "",
                "connected": True,
                "saved": False,
                "device": interface,
            }]
    return []


def split_escaped(line: str) -> list[str]:
    fields: list[str] = []
    current: list[str] = []
    escaped = False
    for char in line:
        if escaped:
            current.append(char)
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == ":":
            fields.append("".join(current))
            current = []
        else:
            current.append(char)
    fields.append("".join(current))
    return fields


def saved_wifi_names() -> set[str]:
    names = set()
    output = run(["nmcli", "-t", "--escape", "yes", "-f", "NAME,TYPE", "connection", "show"])
    for line in output.splitlines():
        fields = split_escaped(line)
        if len(fields) >= 2 and fields[-1] in ("802-11-wireless", "wifi"):
            names.add(fields[0])
    return names


def wifi_networks(manager_available: bool = True) -> list[dict[str, object]]:
    if not manager_available:
        return kernel_active_wifi()
    saved = saved_wifi_names()
    output = run([
        "nmcli", "-t", "--escape", "yes", "-f",
        "IN-USE,SSID,SECURITY,SIGNAL,FREQ", "device", "wifi", "list", "--rescan", "auto",
    ])
    strongest: dict[str, dict[str, object]] = {}
    for line in output.splitlines():
        fields = split_escaped(line)
        if len(fields) < 5:
            continue
        active, ssid, security, signal, frequency = fields[:5]
        if not ssid:
            continue
        try:
            strength = int(signal)
        except ValueError:
            strength = 0
        row = {
            "ssid": ssid,
            "security": security if security and security != "--" else "OPEN",
            "secure": bool(security and security != "--"),
            "signal": strength,
            "frequency": frequency,
            "connected": active.strip() == "*",
            "saved": ssid in saved,
        }
        previous = strongest.get(ssid)
        if (
            previous is None
            or (bool(row["connected"]) and not bool(previous["connected"]))
            or (
                bool(row["connected"]) == bool(previous["connected"])
                and strength > int(previous["signal"])
            )
        ):
            strongest[ssid] = row
    if not any(bool(row["connected"]) for row in strongest.values()):
        externally_active = active_wifi(manager_available)
        for row in externally_active:
            strongest.setdefault(str(row["ssid"]), row)
    return sorted(
        strongest.values(),
        key=lambda row: (not bool(row["connected"]), -int(row["signal"]), str(row["ssid"]).lower()),
    )


def active_wifi(manager_available: bool = True) -> list[dict[str, object]]:
    """Return only the connected Wi-Fi row for the always-visible bar."""

    if not manager_available:
        return kernel_active_wifi()

    output = run([
        "nmcli", "-t", "--escape", "yes", "-f",
        "IN-USE,SSID,SECURITY,SIGNAL,FREQ", "device", "wifi", "list", "--rescan", "no",
    ])
    for line in output.splitlines():
        fields = split_escaped(line)
        if len(fields) < 5 or fields[0].strip() != "*":
            continue
        _, ssid, security, signal, frequency = fields[:5]
        try:
            strength = int(signal)
        except ValueError:
            strength = 0
        return [{
            "ssid": ssid,
            "security": security if security and security != "--" else "OPEN",
            "secure": bool(security and security != "--"),
            "signal": strength,
            "frequency": frequency,
            "connected": True,
            "saved": True,
        }]
    # NetworkManager reports links owned by another service as
    # "connected (externally)". They are online even though the Wi-Fi scan
    # has no active-AP marker, so use device status as the second source.
    for row in manager_device_status():
        if row["type"] in ("wifi", "802-11-wireless") and row["connected"]:
            return [{
                "ssid": row["connection"] or row["device"],
                "security": "UNKNOWN",
                "secure": True,
                "signal": 0,
                "frequency": "",
                "connected": True,
                "saved": False,
                "device": row["device"],
            }]
    return []


def active_connection(
    wifi: list[dict[str, object]],
    ethernet: list[dict[str, object]],
) -> tuple[bool, str, str]:
    """Return the connection facts used by the always-visible indicator.

    Quickshell's networking model can lag behind externally managed links or
    a NetworkManager resync. The helper has already asked the kernel/manager
    for the current state, so expose one explicit answer for the UI instead of
    making QML infer connectivity from whichever device objects arrived first.
    """

    active_wifi_row = next(
        (row for row in wifi if row.get("connected") is True), None
    )
    if active_wifi_row is not None:
        label = str(
            active_wifi_row.get("ssid")
            or active_wifi_row.get("device")
            or "WI-FI"
        )
        return True, label, "WIFI"

    active_ethernet_row = next(
        (row for row in ethernet if row.get("connected") is True), None
    )
    if active_ethernet_row is not None:
        label = str(
            active_ethernet_row.get("connection")
            or active_ethernet_row.get("device")
            or "ETHERNET"
        )
        return True, label, "LINK"

    return False, "", "NET"


def parse_bluetooth_devices(output: str) -> dict[str, str]:
    devices: dict[str, str] = {}
    for line in output.splitlines():
        parts = line.strip().split(" ", 2)
        if len(parts) == 3 and parts[0] == "Device":
            devices[parts[1]] = parts[2]
    return devices


def manager_device_status() -> list[dict[str, object]]:
    output = run([
        "nmcli", "-t", "--escape", "yes", "-f",
        "DEVICE,TYPE,STATE,CONNECTION", "device", "status",
    ])
    rows = []
    for line in output.splitlines():
        fields = split_escaped(line)
        if len(fields) < 4 or not fields[0]:
            continue
        state = fields[2]
        rows.append({
            "device": fields[0],
            "type": fields[1],
            "state": state,
            "connection": fields[3] if fields[3] != "--" else "",
            "connected": state.startswith("connected"),
        })
    return rows


def bluetooth_devices() -> tuple[bool, list[dict[str, object]]]:
    show = run(["bluetoothctl", "show"])
    powered = "Powered: yes" in show
    known = parse_bluetooth_devices(run(["bluetoothctl", "devices"]))
    paired = set(parse_bluetooth_devices(run(["bluetoothctl", "devices", "Paired"])).keys())
    connected = set(parse_bluetooth_devices(run(["bluetoothctl", "devices", "Connected"])).keys())
    rows = [
        {
            "address": address,
            "name": name,
            "paired": address in paired,
            "connected": address in connected,
        }
        for address, name in known.items()
    ]
    rows.sort(key=lambda row: (not bool(row["connected"]), not bool(row["paired"]), str(row["name"]).lower()))
    return powered, rows


def kernel_ethernet_devices() -> list[dict[str, object]]:
    rows = []
    network_root = Path("/sys/class/net")
    try:
        devices = list(network_root.iterdir())
    except OSError:
        return rows
    wireless = set(wireless_interfaces())
    for device in devices:
        if device.name == "lo" or device.name in wireless:
            continue
        try:
            state = (device / "operstate").read_text().strip()
        except OSError:
            continue
        rows.append({
            "device": device.name,
            "state": state,
            "connection": "",
            "connected": state == "up",
        })
    return rows


def ethernet_devices(manager_available: bool = True) -> list[dict[str, object]]:
    if not manager_available:
        return kernel_ethernet_devices()
    rows = []
    for row in manager_device_status():
        if row["type"] != "ethernet":
            continue
        rows.append({
            "device": row["device"],
            "state": row["state"],
            "connection": row["connection"],
            "connected": row["connected"],
        })
    return rows


def main() -> None:
    manager_available = networkmanager_available()
    manager = "networkmanager" if manager_available else "external"
    if "--summary" in sys.argv:
        wifi = active_wifi(manager_available)
        ethernet = ethernet_devices(manager_available)
        connected, label, kind = active_connection(wifi, ethernet)
        print(json.dumps({
            "available": manager_available,
            "manager": manager,
            "summary": True,
            "connected": connected,
            "label": label,
            "kind": kind,
            "wifi": wifi,
            "ethernet": ethernet,
        }, separators=(",", ":")))
        return
    bluetooth_powered, bluetooth = bluetooth_devices()
    wifi = wifi_networks(manager_available)
    ethernet = ethernet_devices(manager_available)
    connected, label, kind = active_connection(wifi, ethernet)
    payload = {
        "available": manager_available,
        "manager": manager,
        "connected": connected,
        "label": label,
        "kind": kind,
        "wifi": wifi,
        "bluetoothPowered": bluetooth_powered,
        "bluetooth": bluetooth,
        "ethernet": ethernet,
    }
    print(json.dumps(payload, separators=(",", ":")))


if __name__ == "__main__":
    main()
