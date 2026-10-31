"""Actual Qt Canvas/scene containment checks. Never imports lock/auth surfaces.

Run normally with unittest. The Qt child has disposable HOME/XDG paths and no
session bus. No screenshot goldens or implementation-formula assertions: painted
pixels are inspected on an enlarged artboard and the real scene viewport.
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
NAMES = ['ruby', 'seashell', 'fire', 'wabi-sabi', 'sun', 'leaf', 'ice-cube',
         'water-droplet', 'ringed-planet', 'night-sky', 'snowflake', 'moon', 'cloud', 'ink']
LIGHT = ['ruby', 'fire', 'night-sky', 'cloud', 'ink']


def render_child(output):
    from PySide6.QtCore import QEventLoop, QTimer, QUrl
    from PySide6.QtGui import QGuiApplication, QColor
    from PySide6.QtQuick import QQuickView
    from PySide6.QtSvg import QSvgRenderer
    app = QGuiApplication([])
    identity = ROOT / 'src/quickshell/components/identity'
    marks = ROOT / 'src/quickshell/assets/theme-marks'
    common = 'import QtQuick\nimport "' + (identity / 'SceneDrawing.js').as_uri() + '" as Drawing\n'
    raw = common + '''Item {
        id: root
        property string identity: "ruby"
        property bool lightMode: true
        property color backgroundColor: Drawing.background(identity, lightMode)
        property color foregroundColor: lightMode ? "#24272B" : "#F3F1ED"
        property var mark: Drawing.markPlacement(identity)
        Rectangle { anchors.fill: parent; color: root.backgroundColor }
        Canvas {
            id: drawing; anchors.fill: parent; renderTarget: Canvas.Image
            onPaint: {
                const ctx = getContext("2d"); ctx.reset();
                // 100px guard on all sides exposes paths beyond the nominal board.
                ctx.translate(100, 100);
                Drawing.paint(ctx, root.identity, Drawing.approvedAccent(root.identity),
                              root.backgroundColor, root.foregroundColor, root.lightMode);
            }
        }
        Image {
            visible: root.identity !== "leaf"
            x: 100 + root.mark.x; y: 100 + root.mark.y
            width: root.mark.size; height: width
            source: "MARKS/" + root.identity + ".svg"
            fillMode: Image.PreserveAspectFit
        }
        onIdentityChanged: drawing.requestPaint()
        onLightModeChanged: drawing.requestPaint()
    }'''.replace('MARKS', marks.as_uri())
    scene = 'import QtQuick\nimport "' + identity.as_uri() + '" as Identity\n' + '''Identity.ThemeScene {
        motion: false
    }'''
    def settle():
        loop = QEventLoop()
        QTimer.singleShot(120, loop.quit)
        loop.exec()
    def differs(image, x, y, bg):
        c = image.pixelColor(x, y)
        return max(abs(c.red()-bg.red()), abs(c.green()-bg.green()), abs(c.blue()-bg.blue())) > 4
    def occupied(image, rects, bg):
        # Sample every boundary pixel. Entire guard bands expose geometry that
        # crosses or sits outside the artboard; internal overlaps are allowed.
        return sum(differs(image, x, y, bg) for x0,y0,x1,y1 in rects
                   for y in range(y0,y1) for x in range(x0,x1))
    records = []
    for label, qml, sizes in [('artboard',raw,[(1200,1200)]), ('viewport',scene,[(1280,800),(540,960)])]:
        qml_file = Path(output).parent / (label + '.qml')
        qml_file.write_text(qml)
        view = QQuickView()
        view.setResizeMode(QQuickView.SizeRootObjectToView)
        view.setSource(QUrl.fromLocalFile(str(qml_file)))
        if view.status() == QQuickView.Error:
            raise RuntimeError('\n'.join(e.toString() for e in view.errors()))
        view.show()
        for width,height in sizes:
            view.resize(width,height)
            for name in NAMES:
                root = view.rootObject()
                root.setProperty('identity',name)
                root.setProperty('lightMode',name in LIGHT)
                settle()
                image = view.grabWindow()
                if image.isNull():
                    raise RuntimeError('Native screenshot failed: ' + name)
                bg = root.property('backgroundColor')
                if label == 'artboard':
                    # Require 8 nominal pixels of breathing room, plus the guard.
                    bands = [(0,0,1200,108),(0,1092,1200,1200),
                             (0,108,108,1092),(1092,108,1200,1092)]
                else:
                    bands = [(0,0,width,3),(0,height-3,width,height),
                             (0,3,3,height-3),(width-3,3,width,height-3)]
                records.append({'mode':label,'theme':name,'size':[width,height],
                                'painted_boundary_pixels':occupied(image,bands,bg),
                                'painted_content_present':any(differs(image,x,y,bg)
                                    for y in range(0,height,16) for x in range(0,width,16))})
        view.close()
        view.deleteLater()
        settle()
    svg_valid = {name: QSvgRenderer(str(marks / (name + '.svg'))).isValid() for name in NAMES}
    Path(output).write_text(json.dumps({'renders':records,'svg_valid':svg_valid}))


@unittest.skipUnless(importlib.util.find_spec('PySide6'), 'optional native PySide6 renderer unavailable')
class ThemeSceneNativeContainment(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with tempfile.TemporaryDirectory(prefix='theme-containment-') as directory:
            result = Path(directory) / 'result.json'
            env = dict(os.environ)
            for key in ['HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','XDG_STATE_HOME','XDG_RUNTIME_DIR']:
                env[key] = directory
            env.update(QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                       DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent')
            for key in ['WAYLAND_DISPLAY','NIRI_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE']:
                env.pop(key,None)
            process = subprocess.run([sys.executable,str(Path(__file__).resolve()),'--render-child',str(result)],
                                     env=env,capture_output=True,text=True,timeout=120)
            if process.returncode:
                raise AssertionError(process.stdout + process.stderr)
            cls.report = json.loads(result.read_text())
            cls.render_log = process.stderr

    def test_all_fourteen_artboards_have_painted_content_clear_of_bounds(self):
        rows = [r for r in self.report['renders'] if r['mode']=='artboard']
        self.assertEqual(len(rows),14)
        self.assertEqual([r for r in rows if r['painted_boundary_pixels']],[])
        self.assertTrue(all(r['painted_content_present'] for r in rows))

    def test_all_fourteen_scenes_clear_desktop_and_portrait_viewport_edges(self):
        rows = [r for r in self.report['renders'] if r['mode']=='viewport']
        self.assertEqual(len(rows),28)
        self.assertEqual([r for r in rows if r['painted_boundary_pixels']],[])
        self.assertTrue(all(r['painted_content_present'] for r in rows))

    def test_native_svg_loader_accepts_all_approved_marks(self):
        self.assertEqual(len(self.report['svg_valid']),14)
        self.assertTrue(all(self.report['svg_valid'].values()))
        self.assertNotIn('Error:',self.render_log)


if __name__ == '__main__':
    if len(sys.argv)>1 and sys.argv[1]=='--render-child':
        render_child(sys.argv[2])
    else:
        unittest.main()
