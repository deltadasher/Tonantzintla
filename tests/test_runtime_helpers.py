"""Regression tests for low-overhead runtime helper paths."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]


def load_script(name: str):
    path = ROOT / "src" / "libexec" / name
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


network_state = load_script("network-state.py")
system_telemetry = load_script("system-telemetry.py")


class NetworkSummaryTests(unittest.TestCase):
    def test_iw_link_fallback_recognizes_obarun_wifi(self) -> None:
        output = """Connected to 10:e1:77:20:b7:c0 (on wlp0s20f3)
\tSSID: SETUP-B7BB
\tfreq: 5220.0
\tsignal: -47 dBm
"""
        row = network_state.parse_iw_link(output)
        self.assertIsNotNone(row)
        self.assertEqual("SETUP-B7BB", row["ssid"])
        self.assertEqual("5220", row["frequency"])
        self.assertEqual(100, row["signal"])
        self.assertTrue(row["connected"])

    def test_iw_link_fallback_handles_disconnected_radio(self) -> None:
        self.assertIsNone(network_state.parse_iw_link("Not connected.\n"))

    def test_iw_inventory_recognizes_wireless_interface(self) -> None:
        self.assertEqual(
            ["wlp0s20f3"],
            network_state.parse_iw_interfaces(
                "phy#0\n\tInterface wlp0s20f3\n\t\ttype managed\n"
            ),
        )

    def test_sysfs_wireless_device_is_not_mislabeled_as_ethernet(self) -> None:
        with __import__("tempfile").TemporaryDirectory() as temporary:
            root = Path(temporary)
            proc_wireless = root / "wireless"
            proc_wireless.write_text("Inter-| sta\n face | data\n")
            sys_class_net = root / "net"
            (sys_class_net / "wlp0s20f3" / "wireless").mkdir(parents=True)
            with mock.patch.object(network_state.shutil, "which", return_value=None):
                self.assertEqual(
                    ["wlp0s20f3"],
                    network_state.wireless_interfaces(proc_wireless, sys_class_net),
                )

    def test_up_wireless_interface_survives_unavailable_iw_link(self) -> None:
        with (
            mock.patch.object(network_state, "wireless_interfaces", return_value=["wlan0"]),
            mock.patch.object(network_state, "run", return_value=""),
            mock.patch.object(network_state.shutil, "which", return_value="/usr/bin/iw"),
            mock.patch.object(network_state.Path, "read_text", return_value="up\n"),
        ):
            rows = network_state.kernel_active_wifi()
        self.assertEqual("wlan0", rows[0]["ssid"])
        self.assertTrue(rows[0]["connected"])
        self.assertEqual(0, rows[0]["signal"])

    def test_wifi_radar_rows_keep_signal_band_and_saved_state(self) -> None:
        def fake_run(args: list[str], timeout: int = 6) -> str:
            if "connection" in args:
                return "Home\\:Lab:802-11-wireless\n"
            return (
                "*:Home\\:Lab:WPA3:67:5785\n"
                ":Home\\:Lab:WPA3:51:5785\n"
                ":Cafe:--:42:2412\n"
            )

        with mock.patch.object(network_state, "run", side_effect=fake_run):
            rows = network_state.wifi_networks()

        self.assertEqual(["Home:Lab", "Cafe"], [row["ssid"] for row in rows])
        self.assertEqual(67, rows[0]["signal"])
        self.assertEqual("5785", rows[0]["frequency"])
        self.assertTrue(rows[0]["saved"])
        self.assertTrue(rows[0]["connected"])
        self.assertFalse(rows[1]["secure"])

    def test_active_wifi_returns_only_connected_row(self) -> None:
        rows = ":Other:WPA2:81:2412\n*:Connected\\:SSID:WPA3:67:5785\n"
        with mock.patch.object(network_state, "run", return_value=rows):
            self.assertEqual(network_state.active_wifi(), [{
                "ssid": "Connected:SSID",
                "security": "WPA3",
                "secure": True,
                "signal": 67,
                "frequency": "5785",
                "connected": True,
                "saved": True,
            }])

    def test_active_wifi_handles_no_connection(self) -> None:
        with mock.patch.object(
            network_state, "run", return_value=":Other:WPA2:81:2412\n"
        ):
            self.assertEqual(network_state.active_wifi(), [])

    def test_externally_connected_wifi_is_visible_from_device_status(self) -> None:
        def fake_run(args: list[str], timeout: int = 6) -> str:
            if "device" in args and "status" in args:
                return "wlan0:wifi:connected (externally):Home\\:Lab\n"
            return ":Other:WPA2:81:2412\n"

        with mock.patch.object(network_state, "run", side_effect=fake_run):
            rows = network_state.active_wifi()

        self.assertEqual("Home:Lab", rows[0]["ssid"])
        self.assertTrue(rows[0]["connected"])

    def test_detailed_wifi_list_keeps_an_externally_connected_link(self) -> None:
        def fake_run(args: list[str], timeout: int = 6) -> str:
            if "connection" in args:
                return ""
            if "device" in args and "status" in args:
                return "wlan0:wifi:connected (externally):Home\n"
            return ":Nearby:WPA2:71:2412\n"

        with mock.patch.object(network_state, "run", side_effect=fake_run):
            rows = network_state.wifi_networks()

        self.assertEqual("Home", rows[0]["ssid"])
        self.assertTrue(rows[0]["connected"])

    def test_externally_connected_ethernet_is_online(self) -> None:
        with mock.patch.object(
            network_state,
            "run",
            return_value="enp5s0:ethernet:connected (externally):Dock\n",
        ):
            rows = network_state.ethernet_devices()

        self.assertEqual("Dock", rows[0]["connection"])
        self.assertTrue(rows[0]["connected"])

    def test_duplicate_ssid_keeps_the_connected_access_point(self) -> None:
        def fake_run(args: list[str], timeout: int = 6) -> str:
            if "connection" in args:
                return ""
            return "*:Office:WPA2:34:2412\n:Office:WPA2:91:5180\n"

        with mock.patch.object(network_state, "run", side_effect=fake_run):
            rows = network_state.wifi_networks()

        self.assertEqual(1, len(rows))
        self.assertEqual("Office", rows[0]["ssid"])
        self.assertTrue(rows[0]["connected"])
        self.assertEqual(34, rows[0]["signal"])

    def test_active_connection_prefers_wifi_and_reports_ethernet(self) -> None:
        connected, label, kind = network_state.active_connection(
            [{"ssid": "Office", "connected": True}],
            [{"device": "enp5s0", "connection": "Dock", "connected": True}],
        )
        self.assertEqual((True, "Office", "WIFI"), (connected, label, kind))

        connected, label, kind = network_state.active_connection(
            [], [{"device": "enp5s0", "connection": "Dock", "connected": True}]
        )
        self.assertEqual((True, "Dock", "LINK"), (connected, label, kind))

    def test_active_connection_reports_offline_without_active_links(self) -> None:
        self.assertEqual(
            (False, "", "NET"), network_state.active_connection([], [])
        )


class SystemTelemetryTests(unittest.TestCase):
    def test_memory_uses_available_memory_and_stays_in_bounds(self) -> None:
        total, used = system_telemetry.memory_from_text(
            "MemTotal:       1024 kB\nMemAvailable:    256 kB\n"
        )
        self.assertEqual(1024 * 1024, total)
        self.assertEqual(768 * 1024, used)

        total, used = system_telemetry.memory_from_text(
            "MemTotal:       1024 kB\nMemAvailable:    4096 kB\n"
        )
        self.assertEqual(0, used)

    def test_snapshot_reuses_slow_sample(self) -> None:
        slow = {
            "disk_total": 10,
            "disk_used": 4,
            "cpu_temp": 52,
            "gpu_temp": 61,
            "processes": 100,
            "hostname": "test-host",
            "kernel": "test-kernel",
        }
        with (
            mock.patch.object(system_telemetry, "cpu_sample", return_value=(10, 4)),
            mock.patch.object(system_telemetry, "memory", return_value=(20, 8)),
            mock.patch.object(system_telemetry, "network_totals", return_value=(30, 12)),
            mock.patch.object(system_telemetry, "read_text", return_value="90.0 0.0"),
            mock.patch.object(system_telemetry.os, "getloadavg", return_value=(1, 2, 3)),
            mock.patch.object(system_telemetry, "slow_snapshot") as slow_probe,
        ):
            payload = system_telemetry.snapshot(slow)
        slow_probe.assert_not_called()
        self.assertEqual(payload["hostname"], "test-host")
        self.assertEqual(payload["memory_used"], 8)
        self.assertEqual(payload["rx_total"], 30)


class CommandSurfaceTests(unittest.TestCase):
    """blackhole and the installer are the only command surface."""

    def test_no_user_facing_scripts_directory(self) -> None:
        root = Path(__file__).resolve().parents[1]
        self.assertFalse(
            (root / "scripts").exists(),
            "scripts/ is back; commands belong to blackhole",
        )
        self.assertTrue((root / "bin" / "blackhole").is_file())
        # Helpers the shell spawns are internal, not commands.
        for helper in ("system-telemetry.py", "weather-state.py", "snipping-tool"):
            self.assertTrue((root / "src" / "libexec" / helper).is_file(), helper)

    def test_control_delegates_machine_changes_to_the_installer(self) -> None:
        root = Path(__file__).resolve().parents[1]
        control = (root / "bin" / "blackhole").read_text()
        # These must route to the Rust binary, never to a sibling script.
        self.assertIn("run_installer", control)
        self.assertIn("tonantzintla-installer", control)
        for gone in ("update-user", "install-user", "uninstall-user", "install-arch"):
            self.assertNotIn(gone, control)


if __name__ == "__main__":
    unittest.main()
