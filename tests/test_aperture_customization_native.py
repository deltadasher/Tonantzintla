import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ApertureCustomizationTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_native_faces_keys_density_bounds_and_persistence(self):
        source = (ROOT/'tests/instruments/aperture.qml').read_text().replace('../../src/quickshell/', '').replace('"../../src/quickshell"', '"."')
        with tempfile.TemporaryDirectory(prefix='aperture-custom-') as directory:
            root = Path(directory); (root/'tonantzintla').mkdir()
            settings = root/'tonantzintla/settings.json'
            settings.write_text(json.dumps({'clipboardPaused': True, 'motion': False, 'weatherEnabled': False}))
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory, XDG_CACHE_HOME=directory,
                       XDG_STATE_HOME=directory, XDG_RUNTIME_DIR=directory, QT_QPA_PLATFORM='offscreen',
                       QT_QUICK_BACKEND=os.environ.get('APERTURE_BACKEND','software'), DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',
                       APERTURE_CAPTURE=str(root/'aperture.png'))
            for key in ('WAYLAND_DISPLAY', 'NIRI_SOCKET', 'SWAYSOCK', 'HYPRLAND_INSTANCE_SIGNATURE'):
                env.pop(key, None)
            with tempfile.NamedTemporaryFile(mode='w', prefix='test-aperture-', suffix='.qml', dir=ROOT/'src/quickshell') as harness:
                harness.write(source); harness.flush()
                result = subprocess.run(['qs','-p',harness.name,'--no-color'], env=env, capture_output=True, text=True, timeout=20)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn('APERTURE COMPLETE 0 failures', output)
            for bad in ('APERTURE FAIL','ReferenceError','TypeError','Binding loop','Unable to assign','Failed to load configuration'):
                self.assertNotIn(bad, output)
            self.assertGreater((root/'aperture.png').stat().st_size, 3000)
            data = json.loads(settings.read_text())
            self.assertEqual(data['barClockFace'], 'compact')
            self.assertEqual(data['barTelemetryFace'], 'trace')
            self.assertEqual(data['barTelemetryMetrics'], ['cpu','memory'])
            self.assertEqual(data['islandDensity']['clock'], 'compact')
            self.assertEqual(data['barMediaWidth'], 200)
            self.assertFalse(data['barMediaShowArt'])
            self.assertEqual(data['launcherWidth'], 720)
            self.assertEqual(data['launcherVisibleRows'], 7)
            if os.environ.get('APERTURE_CAPTURE'):
                destination = Path(os.environ['APERTURE_CAPTURE'])
                shutil.copyfile(root/'aperture.png', destination)
                for suffix in ('-arc','-trace'):
                    shutil.copyfile(str(root/'aperture.png')+suffix+'.png', destination.with_stem(destination.stem+suffix))

    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_actual_popup_short_viewport_keyboard_scroll_and_close(self):
        self.run_popup_fixture('aperture-popup.qml', 'POPUP', '-popup-320')

    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_dock_pages_scroll_and_app_lists_remain_bounded(self):
        self.run_popup_fixture('dock-popup.qml', 'DOCK POPUP', '-dock-popup-320')

    def run_popup_fixture(self, fixture, marker, suffix):
        source = (ROOT/'tests/instruments'/fixture).read_text().replace('../../src/quickshell', '.')
        popup = (ROOT/'src/quickshell/modules/aperture/IslandQuickSettings.qml').read_text()
        popup = popup.replace('import "."', 'import "./modules/aperture"')
        popup = popup.replace('"../.."', '"."').replace('"../../', '"./')
        popup = popup.replace('import QtQuick\n', 'import QtQuick\nimport QtTest\n', 1)
        popup = popup.replace('PanelWindow {', 'Window {\n    property alias nativeEvents: nativeEventsObject\n    TestEvent { id:nativeEventsObject }', 1)
        popup = popup.replace('required property var modelData', 'property var modelData: Quickshell.screens[0]')
        popup = re.sub(r'(?m)^    screen:.*$', '    width: 320; height: 280; visible: true', popup)
        for line in ('    focusable: true', '    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive',
                     '    anchors { top: true; bottom: true; left: true; right: true }',
                     '    exclusionMode: ExclusionMode.Ignore', '    WlrLayershell.layer: WlrLayer.Overlay',
                     '    WlrLayershell.namespace: "tonantzintla-island-popover"'):
            popup = popup.replace(line, '')
        with tempfile.TemporaryDirectory(prefix='aperture-popup-') as directory:
            folder = Path(directory); (folder/'tonantzintla').mkdir()
            (folder/'tonantzintla/settings.json').write_text(json.dumps({'clipboardPaused':True,'motion':False,'weatherEnabled':False,'dockPins':'["first","second","third","fourth"]'}))
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory, XDG_CACHE_HOME=directory,
                       XDG_STATE_HOME=directory, XDG_RUNTIME_DIR=directory, XDG_DATA_HOME=directory,
                       QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', QT_SCALE_FACTOR='1.25',
                       DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent', POPUP_CAPTURE=str(folder/'popup.png'))
            for key in ('WAYLAND_DISPLAY','NIRI_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE'):
                env.pop(key,None)
            with tempfile.NamedTemporaryFile(mode='w',prefix='test-popup-',suffix='.qml',dir=ROOT/'src/quickshell') as popup_file, tempfile.NamedTemporaryFile(mode='w',prefix='test-popup-keys-',suffix='.qml',dir=ROOT/'src/quickshell') as harness:
                popup_file.write(popup); popup_file.flush()
                harness.write(source.replace('POPUP_SOURCE',Path(popup_file.name).name)); harness.flush()
                result = subprocess.run(['qs','-p',harness.name,'--no-color'],env=env,capture_output=True,text=True,timeout=12)
            output = result.stdout+result.stderr
            self.assertEqual(result.returncode,0,output)
            self.assertIn(marker+' COMPLETE 0 failures',output)
            for bad in ('POPUP FAIL','POPUP TIMEOUT','ReferenceError','TypeError','Binding loop','Unable to assign','Failed to load configuration','Detected function'):
                self.assertNotIn(bad,output)
            self.assertGreater((folder/'popup.png').stat().st_size,3000)
            if os.environ.get('APERTURE_CAPTURE'):
                destination=Path(os.environ['APERTURE_CAPTURE'])
                shutil.copyfile(folder/'popup.png',destination.with_stem(destination.stem+suffix))
