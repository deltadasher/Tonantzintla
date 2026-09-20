#!/usr/bin/env python3
"""Prefer the shell's registered polkit agent; otherwise start an external agent.

Bounded session-start check only. Never kills or replaces another agent.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import time


def native_ready():
    try:
        result = subprocess.run(['qs', 'list', '--all', '--json'], capture_output=True, text=True, timeout=1)
        for instance in json.loads(result.stdout):
            if 'tonantzintla' not in instance.get('config_path', '').lower():
                continue
            status = subprocess.run(['qs', 'ipc', '--pid', str(instance['pid']), 'call', 'authentication', 'status'],
                                    capture_output=True, text=True, timeout=1)
            if status.returncode == 0 and status.stdout.strip() == 'ready':
                return True
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired):
        pass
    return False


def fallback():
    candidates = ['/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1',
                  '/usr/libexec/polkit-gnome-authentication-agent-1',
                  shutil.which('lxqt-policykit-agent'), shutil.which('mate-polkit')]
    return next((path for path in candidates if path and Path(path).is_file() and os.access(path, os.X_OK)), None)


def main():
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        if native_ready():
            return 0
        time.sleep(0.25)
    executable = fallback()
    if executable:
        os.execv(executable, [executable])
    print('No registered Tonantzintla agent or supported external polkit agent found.', file=__import__('sys').stderr)
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
