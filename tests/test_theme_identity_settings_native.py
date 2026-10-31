"""Compare the exporter with native evaluation of the real Theme.qml settings path."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def exporter():
    spec = importlib.util.spec_from_file_location('greeter_native_parity', ROOT/'src/libexec/umbra-greeter-palette.py')
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def cases():
    settings = dict(themeIdentity='auto', themeMode='auto', adaptivePalette=False, accentName='violet',
                    wallpaperPath='/example.png', paletteSeedColor='', spectralColors={})
    payload = dict(ok=True, source='/example.png', seed='', mode='light', palette={'colors': {
        'primary': {'light': {'color': '#123456'}, 'dark': {'color': '#abcdef'}},
        'source_color': {'light': {'color': '#d11e40'}, 'dark': {'color': '#d11e40'}},
        'surface_container_lowest': {'light': {'color': '#112233'}, 'dark': {'color': '#223344'}}}})
    rows = []
    def add(name, preferences=None, cache=None):
        rows.append(dict(name=name, settings=dict(settings, **(preferences or {})), payload=payload if cache is None else cache))
    add('disabled ignores matching cached source and material')
    add('enabled uses matching cached source and material', dict(adaptivePalette=True))
    add('enabled rejects stale wallpaper', dict(adaptivePalette=True), dict(payload, source='/other.png'))
    add('enabled rejects stale seed', dict(adaptivePalette=True), dict(payload, seed='#ffffff'))
    add('ready source survives material mode change', dict(adaptivePalette=True, themeMode='dark'))
    for invalid in ('', 'bad', None):
        cache = json.loads(json.dumps(payload))
        cache['palette']['colors']['source_color'] = {'light': {'color': invalid}}
        add('invalid cached source uses preset ' + str(invalid), dict(adaptivePalette=True), cache)
    cache = json.loads(json.dumps(payload))
    cache['palette']['colors']['primary'] = {'light': {'color': 'bad'}}
    add('invalid cache is not ready', dict(adaptivePalette=True), cache)
    for adaptive in (False, True):
        add('exact action wins over seed ' + str(adaptive), dict(adaptivePalette=adaptive,
            paletteSeedColor='#ffffff', spectralColors={'accent':'#83dad9'}))
        add('seed precedes preset ' + str(adaptive), dict(adaptivePalette=adaptive, paletteSeedColor='#ffffff'))
        add('manual mark wins over colors ' + str(adaptive), dict(adaptivePalette=adaptive,
            themeIdentity='ink', spectralColors={'accent':'#83dad9'}))
        add('explicit mode wins ' + str(adaptive), dict(adaptivePalette=adaptive, themeIdentity='leaf', themeMode='dark'))
    for mode in ('auto', 'light', 'dark'):
        add('Leaf lock mode independent of desktop ' + mode, dict(themeIdentity='leaf', themeMode=mode))
    for mark in exporter().identity.identities():
        for choice in ('auto', 'light', 'dark'):
            add('mode independent from ' + mark['id'] + ' ' + choice,
                dict(themeIdentity=mark['id'], themeMode=choice, paletteSeedColor='#101010'))
    add('selected cyan preset controls accent', dict(accentName='cyan'))
    return rows


class IdentitySettingsNativeParityTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_real_theme_settings_and_greeter_agree(self):
        rows = cases()
        with tempfile.TemporaryDirectory(prefix='identity-native-parity-') as directory:
            folder = Path(directory)
            (folder/'tonantzintla').mkdir()
            (folder/'tonantzintla/settings.json').write_text(json.dumps(dict(motion=False,
                adaptivePalette=False, clipboardPaused=True, wallpaperPath='')))
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory, XDG_CACHE_HOME=directory,
                       XDG_STATE_HOME=directory, XDG_DATA_HOME=directory, XDG_RUNTIME_DIR=directory,
                       QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                       DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent', DBUS_SYSTEM_BUS_ADDRESS='unix:path=/nonexistent',
                       IDENTITY_PARITY_CASES=json.dumps(rows))
            for key in ('WAYLAND_DISPLAY', 'NIRI_SOCKET', 'SWAYSOCK', 'HYPRLAND_INSTANCE_SIGNATURE'):
                env.pop(key, None)
            qml = r'''import QtQuick
import Quickshell
import "."
QtObject {
    property Timer probe: Timer {
        interval: 30; running: true; repeat: true
        onTriggered: {
            if (!Settings.persistenceReady) return;
            const rows = JSON.parse(Quickshell.env("IDENTITY_PARITY_CASES"));
            const result = [];
            for (const row of rows) {
                Settings.adaptivePalette = false;
                AdaptivePalette.ready = false;
                for (const key of Object.keys(row.settings)) Settings[key] = row.settings[key];
                AdaptivePalette.applyPayload(row.payload);
                AdaptivePalette.refreshDelay.stop();
                result.push({themeIdentity: Theme.identity.id, themeMode: Theme.mode,
                    lockMode: Theme.lockIsLight ? "light" : "dark", identityColor: Theme.identity.color, accent: String(Theme.accent), voidColor: String(Theme.void_)});
            }
            console.log("IDENTITY_PARITY_RESULT", JSON.stringify(result));
            Qt.exit(0);
        }
    }
    property Timer deadline: Timer { interval: 5000; running: true; onTriggered: Qt.exit(2) }
}
'''
            with tempfile.NamedTemporaryFile('w', prefix='identity-native-parity-', suffix='.qml', dir=ROOT/'src/quickshell') as harness:
                harness.write(qml); harness.flush()
                result = subprocess.run(['qs', '-p', harness.name, '--no-color'], env=env, capture_output=True,
                                        text=True, timeout=8)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, output)
        data = next((line.split('IDENTITY_PARITY_RESULT ', 1)[1] for line in output.splitlines() if 'IDENTITY_PARITY_RESULT ' in line), None)
        self.assertIsNotNone(data, output)
        observed = json.loads(data)
        self.assertEqual(len(observed), len(rows))
        helper = exporter()
        for row, actual in zip(rows, observed):
            with self.subTest(case=row['name']):
                expected = dict(line.split('=', 1) for line in helper.render(row['payload'], row['settings']).splitlines() if '=' in line)
                self.assertEqual({key: value.lower() if key.endswith('Color') or key == 'accent' else value for key, value in actual.items()}, {key: expected[key].lower() if key.endswith('Color') or key == 'accent' else expected[key] for key in actual})
        for error in ('TypeError', 'ReferenceError', 'Unable to assign', 'Binding loop', 'Failed to load configuration'):
            self.assertNotIn(error, output)
