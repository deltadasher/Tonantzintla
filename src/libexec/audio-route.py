#!/usr/bin/env python3
"""Move one identified playback stream; never change global routing policy."""

from __future__ import annotations

import json
import subprocess
import sys


def run(arguments: list[str]) -> str:
    result = subprocess.run(["pactl", *arguments], capture_output=True, text=True,
                            check=True, timeout=5)
    return result.stdout


def find_serial(rows: list[dict], serial: str) -> dict:
    matches = [row for row in rows
               if str((row.get("properties") or {}).get("object.serial", "")) == serial]
    if len(matches) != 1:
        raise ValueError("Audio device or stream changed. Select it again.")
    return matches[0]


def move_stream(stream_serial: str, sink_serial: str) -> None:
    if not stream_serial.isdecimal() or not sink_serial.isdecimal():
        raise ValueError("This stream cannot be rerouted through PulseAudio compatibility.")
    # PulseAudio indices are NOT PipeWire node IDs. Resolve both fresh, by the
    # monotonically assigned object serial, so stale UI objects cannot select
    # an unrelated stream after a device disconnect or a player restart.
    stream = find_serial(json.loads(run(["--format=json", "list", "sink-inputs"])), stream_serial)
    sink = find_serial(json.loads(run(["--format=json", "list", "sinks"])), sink_serial)
    index = str(stream.get("index", ""))
    sink_name = sink.get("name")
    if not index.isdecimal() or not isinstance(sink_name, str) or not sink_name:
        raise ValueError("The audio server did not provide a usable route.")
    if str(stream.get("sink")) == str(sink.get("index")):
        return
    run(["move-sink-input", index, sink_name])


def main() -> int:
    try:
        if len(sys.argv) != 3:
            raise ValueError("Select a playback stream and an output.")
        move_stream(sys.argv[1], sys.argv[2])
        result = {"ok": True, "status": "Playback moved"}
    except FileNotFoundError:
        result = {"ok": False, "status": "Install pactl to move playback streams"}
    except subprocess.TimeoutExpired:
        result = {"ok": False, "status": "The audio server did not respond"}
    except subprocess.CalledProcessError:
        result = {"ok": False, "status": "The audio server refused this route"}
    except (ValueError, TypeError, KeyError) as error:
        result = {"ok": False, "status": str(error)}
    print(json.dumps(result))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
