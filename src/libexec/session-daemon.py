#!/usr/bin/env python3
"""Per-session Tonantzintla supervisor, independent of the host init system."""
import collections
import fcntl
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[2]


def runtime():
    base = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    if not base.is_dir() or base.stat().st_uid != os.getuid():
        raise RuntimeError("A user-owned XDG_RUNTIME_DIR is required")
    directory = base / "tonantzintla-session"
    directory.mkdir(mode=0o700, exist_ok=True)
    if directory.is_symlink() or directory.stat().st_uid != os.getuid():
        raise RuntimeError("Invalid session directory")
    directory.chmod(0o700)
    return directory


def request(directory, action):
    with socket.socket(socket.AF_UNIX) as client:
        client.settimeout(2)
        client.connect(str(directory / "control"))
        client.sendall(action.encode())
        return json.loads(client.recv(4096))


def terminate(child):
    if child is None:
        return
    # Descendants share this isolated process group, including after qs exits.
    try:
        os.killpg(child.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        child.wait(timeout=4)
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(child.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    child.wait()


def serve(directory):
    lock = (directory / "lock").open("a")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return
    display = os.environ.get("WAYLAND_DISPLAY", "")
    if not display:
        raise RuntimeError("Start Tonantzintla inside a Wayland session")
    display_path = Path(display) if display.startswith("/") else directory.parent / display
    identity = display_path.stat().st_ino
    endpoint = directory / "control"
    endpoint.unlink(missing_ok=True)
    stopping = False
    child = None
    def stop_signal(_signum, _frame):
        nonlocal stopping
        stopping = True
    signal.signal(signal.SIGTERM, stop_signal)
    signal.signal(signal.SIGINT, stop_signal)
    deaths = collections.deque()
    log_path = directory / "shell.log"
    with socket.socket(socket.AF_UNIX) as server, log_path.open("ab", buffering=0) as log:
        server.bind(str(endpoint))
        server.listen(4)
        server.settimeout(0.25)
        try:
            while not stopping:
                if not display_path.exists() or display_path.stat().st_ino != identity:
                    break
                if child is None:
                    child = subprocess.Popen(["qs", "-n", "-p", str(ROOT / "src/quickshell")],
                                             stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                                             start_new_session=True)
                try:
                    connection, _ = server.accept()
                    with connection:
                        connection.settimeout(1)
                        try:
                            action = connection.recv(64).decode()
                            connection.sendall(json.dumps({"supervisor": os.getpid(),
                                "pid": child.pid, "root": str(ROOT),
                                "running": child.poll() is None}).encode())
                            stopping = action == "stop"
                        except (OSError, UnicodeError):
                            pass
                except socket.timeout:
                    pass
                if child.poll() is not None:
                    code = child.returncode
                    terminate(child)
                    child = None
                    if code == 0:
                        break
                    now = time.monotonic()
                    deaths.append(now)
                    while deaths and now - deaths[0] > 60:
                        deaths.popleft()
                    if len(deaths) >= 5:
                        log.write(b"Tonantzintla stopped after five failures in one minute.\n")
                        break
                    time.sleep(0.75)
                if log_path.stat().st_size > 2_000_000:
                    log.truncate(0)
        finally:
            terminate(child)
            endpoint.unlink(missing_ok=True)


def main():
    action = sys.argv[1]
    directory = runtime()
    if action == "serve":
        serve(directory)
        return
    if action == "logs":
        path = directory / "shell.log"
        print(path.read_text(errors="replace")[-32000:] if path.exists() else "No session log yet.")
        return
    try:
        state = request(directory, "status")
    except (OSError, ValueError):
        state = None
    if action == "status":
        print(json.dumps(state) if state else "Tonantzintla daemon is stopped.")
        return
    if action in ("stop", "restart") and state:
        if state["root"] != str(ROOT):
            raise RuntimeError("Another checkout owns this session; use its control command")
        request(directory, "stop")
        for _ in range(60):
            if not (directory / "control").exists():
                break
            time.sleep(0.1)
        else:
            raise RuntimeError("Previous supervisor has not stopped; refusing a duplicate")
        state = None
    if action == "stop":
        return
    if action not in ("start", "restart"):
        raise RuntimeError("Expected start, stop, restart, status, or logs")
    if state:
        if state["root"] != str(ROOT):
            raise RuntimeError("Another checkout owns this session; stop it first")
        return
    with (directory / "supervisor.log").open("w") as log:
        process = subprocess.Popen([sys.executable, __file__, "serve"],
            stdin=subprocess.DEVNULL, stdout=log, stderr=log, start_new_session=True)
    for _ in range(50):
        if process.poll() is not None:
            raise RuntimeError((directory / "supervisor.log").read_text())
        try:
            if request(directory, "status")["running"]:
                return
        except (OSError, ValueError):
            pass
        time.sleep(0.1)
    raise RuntimeError("Supervisor did not become available")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError) as error:
        print(f"Tonantzintla: {error}", file=sys.stderr)
        sys.exit(1)
