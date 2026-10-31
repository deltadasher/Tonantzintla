#!/usr/bin/env python3
"""Compile actual identity consumers and shell graph without constructing them.

Run explicitly on the host Wayland session, e.g.:
  python3 tools/compile-theme-graph.py --project /path/to/canonical --project /path/to/runtime
Only the tiny QtObject compile harness is constructed. No target component is
instantiated; this does not launch the shell, services, surfaces or a real lock.
"""
import argparse
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, action='append', help='staging tree; repeat to check both')
    parser.add_argument('--platform', choices=('wayland', 'offscreen'), default='wayland',
                        help='offscreen is diagnostic only: PanelWindow requires Wayland')
    args = parser.parse_args()
    projects = args.project or [Path(__file__).resolve().parents[1]]
    if not shutil.which('qs'):
        parser.error('Quickshell is unavailable')
    wayland = os.environ.get('WAYLAND_DISPLAY', '')
    if args.platform == 'wayland':
        if not wayland:
            parser.error('Run on the host Wayland session with WAYLAND_DISPLAY set')
        if not Path(wayland).is_absolute():
            runtime = os.environ.get('XDG_RUNTIME_DIR')
            if not runtime:
                parser.error('XDG_RUNTIME_DIR is required to resolve the compositor socket')
            wayland = str(Path(runtime) / wayland)
    failed = False
    for project in projects:
        project = project.resolve()
        qml = project / 'src/quickshell'
        sources = [qml / 'shell.qml', qml / 'modules/ephemeris/EphemerisSurface.qml',
                   qml / 'modules/umbra/UmbraSurface.qml']
        sources += [path for path in sorted(qml.rglob('*.qml')) if re.search(r'\bThemeMark\s*\{', path.read_text())]
        sources = list(dict.fromkeys(sources))
        if not all(path.is_file() for path in sources):
            parser.error('Invalid project graph: ' + str(project))
        with tempfile.TemporaryDirectory(prefix='theme-graph-compile-') as directory:
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory,
                       XDG_CACHE_HOME=directory, XDG_DATA_HOME=directory, XDG_STATE_HOME=directory,
                       XDG_RUNTIME_DIR=directory, QT_QPA_PLATFORM=args.platform, QT_QUICK_BACKEND='software',
                       DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent', DBUS_SYSTEM_BUS_ADDRESS='unix:path=/nonexistent',
                       TONANTZINTLA_TEST_SOURCES=json.dumps([str(path) for path in sources]))
            for key in ('DISPLAY', 'WAYLAND_DISPLAY', 'NIRI_SOCKET', 'SWAYSOCK', 'HYPRLAND_INSTANCE_SIGNATURE'):
                env.pop(key, None)
            if args.platform == 'wayland':
                env['WAYLAND_DISPLAY'] = wayland
            result = subprocess.run(['qs', '-p', str(project / 'tests/qml/compile-surfaces.qml'), '--no-color'],
                                    env=env, text=True, capture_output=True, timeout=30)
        output = result.stdout + result.stderr
        print(str(project) + ': ' + str(len(sources)) + ' actual graph/consumer targets')
        print(output, end='')
        failed |= result.returncode != 0 or 'SURFACE COMPILE COMPLETE 0 failures' not in output or 'SURFACE FAIL' in output
    return int(failed)


if __name__ == '__main__':
    raise SystemExit(main())
