"""Each identity's lock voice: complete, distinct, and drawn inside its bounds.

The style table is evaluated as plain JavaScript; password lines and buttons are
painted by the real portable QML components on a disposable offscreen view.
Never imports lock or authentication surfaces.
"""
from pathlib import Path
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
IDENTITY = ROOT / 'src/quickshell/components/identity'
NAMES = ['ruby', 'seashell', 'fire', 'wabi-sabi', 'sun', 'leaf', 'ice-cube',
         'water-droplet', 'ringed-planet', 'night-sky', 'snowflake', 'moon', 'cloud', 'ink']
PLACES = {'end', 'under', 'underEnd', 'start', 'over'}
CHOOSERS = {'captions', 'chips', 'sentence', 'stacked', 'brackets'}
ACTIONS = {'bottomRight', 'bottomLeft', 'bottomCenter', 'topRight', 'formRow'}


def load_tables():
    script = r'''const fs=require('fs'),vm=require('vm');
const read=f=>fs.readFileSync(f,'utf8').replace(/^\.pragma.*$/m,'');
const styles={Qt:{fontFamilies:()=>[],formatDateTime:()=>''}};vm.createContext(styles);vm.runInContext(read(process.argv[1]),styles);
const draw={};vm.createContext(draw);vm.runInContext(read(process.argv[2]),draw);
console.log(JSON.stringify({styles:styles.STYLES,shapes:Object.keys(draw.SHAPES)}));'''
    result = subprocess.run(['node', '-e', script, str(IDENTITY / 'LockStyles.js'), str(IDENTITY / 'ControlDrawing.js')],
                            capture_output=True, text=True, check=True)
    return json.loads(result.stdout)


def render_child(output):
    from PySide6.QtCore import QEventLoop, QTimer, QUrl
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQuick import QQuickView
    app = QGuiApplication([])
    tables = load_tables()
    qml = Path(output).parent / 'controls.qml'
    qml.write_text('import QtQuick\nimport "' + IDENTITY.as_uri() + '" as Identity\n' + '''Rectangle {
        width: 460; height: 220; color: "#101010"
        property string kind: "orbit"
        property int cap: 32
        property int count: 0
        property string shape: "circle"
        property bool filled: false
        Identity.SceneEntry { x: 20; y: 20; width: 420; height: 90; kind: parent.kind; cap: parent.cap
                              count: parent.count; accent: "#e9b872"; foreground: "#f3f1ed"; motion: false }
        Identity.SceneButton { x: 20; y: 140; width: 60; height: 60; shape: parent.shape; filled: parent.filled
                               accent: "#e9b872"; foreground: "#f3f1ed"; background: "#101010" }
    }''')
    view = QQuickView()
    view.setSource(QUrl.fromLocalFile(str(qml)))
    if view.status() == QQuickView.Error:
        raise RuntimeError('\n'.join(e.toString() for e in view.errors()))
    view.show()
    root = view.rootObject()

    def settle():
        loop = QEventLoop()
        QTimer.singleShot(90, loop.quit)
        loop.exec()

    def painted(image, x0, y0, x1, y1):
        return sum(1 for y in range(y0, y1, 2) for x in range(x0, x1, 2)
                   if image.pixelColor(x, y).name() != '#101010')

    def edge(image, x0, y0, x1, y1):
        ring = [(x, y0) for x in range(x0, x1)] + [(x, y1 - 1) for x in range(x0, x1)]
        ring += [(x0, y) for y in range(y0, y1)] + [(x1 - 1, y) for y in range(y0, y1)]
        return sum(1 for x, y in ring if image.pixelColor(x, y).name() != '#101010')

    entries, buttons = [], []
    for name, spec in tables['styles'].items():
        root.setProperty('kind', spec['entry']['kind'])
        root.setProperty('cap', spec['entry']['cap'])
        for count in (0, 1, 6, spec['entry']['cap'] + 8):
            root.setProperty('count', count)
            settle()
            image = view.grabWindow()
            entries.append({'theme': name, 'count': count, 'painted': painted(image, 20, 20, 440, 110),
                            'edge': edge(image, 20, 20, 440, 110)})
    for shape in tables['shapes']:
        root.setProperty('shape', shape)
        for filled in (False, True):
            root.setProperty('filled', filled)
            settle()
            image = view.grabWindow()
            buttons.append({'shape': shape, 'filled': filled, 'painted': painted(image, 20, 140, 80, 200),
                            'edge': edge(image, 20, 140, 80, 200)})
    Path(output).write_text(json.dumps({'entries': entries, 'buttons': buttons}))


@unittest.skipUnless(subprocess.run(['which', 'node'], capture_output=True).returncode == 0, 'node unavailable')
class LockStyleTable(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tables = load_tables()

    def test_every_identity_has_a_complete_voice(self):
        styles = self.tables['styles']
        self.assertEqual(set(styles), set(NAMES))
        for name, spec in styles.items():
            with self.subTest(name=name):
                for role in ('clock', 'date', 'label'):
                    self.assertTrue(spec[role]['families'], role)
                self.assertIn('format', spec['date'])
                self.assertIn(spec['button']['shape'], self.tables['shapes'])
                self.assertIn(spec['button']['place'], PLACES)
                self.assertIn(spec['chooser'], CHOOSERS)
                self.assertIn(spec['actions'], ACTIONS)
                self.assertGreater(spec['entry']['cap'], 8)

    def test_every_identity_is_distinct(self):
        styles = self.tables['styles'].values()
        faces = [(s['clock']['families'][0], s['clock'].get('style', ''), s['clock'].get('weight')) for s in styles]
        self.assertEqual(len(set(faces)), len(NAMES))
        self.assertEqual(len({s['entry']['kind'] for s in styles}), len(NAMES))
        self.assertEqual(len({s['button']['shape'] for s in styles}), len(NAMES))


@unittest.skipUnless(importlib.util.find_spec('PySide6') and subprocess.run(['which', 'node'], capture_output=True).returncode == 0,
                     'optional native PySide6 renderer unavailable')
class LockControlsNative(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with tempfile.TemporaryDirectory(prefix='lock-controls-') as directory:
            result = Path(directory) / 'result.json'
            env = dict(os.environ)
            for key in ['HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_STATE_HOME', 'XDG_RUNTIME_DIR']:
                env[key] = directory
            env.update(QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                       DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent')
            for key in ['WAYLAND_DISPLAY', 'NIRI_SOCKET', 'SWAYSOCK', 'HYPRLAND_INSTANCE_SIGNATURE']:
                env.pop(key, None)
            process = subprocess.run([sys.executable, str(Path(__file__).resolve()), '--render-child', str(result)],
                                     env=env, capture_output=True, text=True, timeout=180)
            if process.returncode:
                raise AssertionError(process.stdout + process.stderr)
            cls.report = json.loads(result.read_text())

    def test_password_lines_grow_with_typing_and_stay_inside(self):
        by_theme = {}
        for row in self.report['entries']:
            by_theme.setdefault(row['theme'], {})[row['count']] = row
            self.assertEqual(row['edge'], 0, row)
        for name, rows in by_theme.items():
            counts = sorted(rows)
            with self.subTest(name=name):
                self.assertGreater(rows[counts[1]]['painted'], rows[counts[0]]['painted'])
                self.assertGreater(rows[counts[2]]['painted'], rows[counts[1]]['painted'])
                # Beyond the cap the line is full; it neither grows nor breaks.
                self.assertGreater(rows[counts[3]]['painted'], 0)

    def test_every_button_shape_paints_inside_its_box(self):
        for row in self.report['buttons']:
            with self.subTest(shape=row['shape'], filled=row['filled']):
                self.assertGreater(row['painted'], 60)
                self.assertEqual(row['edge'], 0)


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == '--render-child':
        render_child(sys.argv[2])
    else:
        unittest.main()
