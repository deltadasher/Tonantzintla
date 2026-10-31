"""Actual Qt Canvas/scene containment checks. Never imports lock/auth surfaces.

Run normally with unittest. The Qt child has disposable HOME/XDG paths and no
session bus. No screenshot goldens or implementation-formula assertions: painted
pixels are inspected on an enlarged artboard and the real scene viewport.

Scenes are stacks of cached layers that only move by transform. Each layer is
painted alone to find its real painted bounds; those must fit the Canvas box
it is cached in (or it would be clipped), and the bounds carried through the
layer's motion over the whole loop must stay on the artboard.
"""
from pathlib import Path
import importlib.util
import json
import math
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
NAMES = ['ruby', 'seashell', 'fire', 'wabi-sabi', 'sun', 'leaf', 'ice-cube',
         'water-droplet', 'ringed-planet', 'night-sky', 'snowflake', 'moon', 'cloud', 'ink']
LIGHT = ['ruby', 'fire', 'night-sky', 'cloud', 'ink']
DRAWING = ROOT / 'src/quickshell/components/identity/SceneDrawing.js'
# Painted geometry and its motion must stay inside this artboard inset.
SAFE = (70, 930)
# Mirrors ThemeScene's per-layer transform: Item position, then Scale, then
# Rotation, both about the layer's origin. Sampled across the whole loop.
ENVELOPE = """
function logoBounds(id, box) {
    const b = BOUNDS[id], k = box[2] / 128;
    return [box[0] + b[0]*k, box[1] + b[1]*k, box[0] + (b[0]+b[2])*k, box[1] + (b[1]+b[3])*k];
}
function motionEnvelope(layer, painted, reach) {
    const box = layer.box, o = layer.origin || [box[0] + box[2]/2, box[1] + box[3]/2];
    let corners = [[painted[0], painted[1]], [painted[2], painted[1]], [painted[0], painted[3]], [painted[2], painted[3]]];
    // A spinning layer sweeps a disc; its rotated rectangle would overstate it.
    if (reach) {
        corners = [];
        for (let i = 0; i < 32; i++) corners.push([o[0] + reach * Math.cos(i * Math.PI / 16), o[1] + reach * Math.sin(i * Math.PI / 16)]);
    }
    let lo = [Infinity, Infinity], hi = [-Infinity, -Infinity];
    for (let t = 0; t < LOOP; t += .25) {
        const p = layer.motion ? pose(layer.motion, t) : REST;
        const a = ((layer.rotate || 0) + p.r) * Math.PI / 180, c = Math.cos(a), s = Math.sin(a);
        for (let i = 0; i < corners.length; i++) {
            const dx = (corners[i][0] - o[0]) * p.sx, dy = (corners[i][1] - o[1]) * p.sy;
            const x = o[0] + p.x + dx*c - dy*s, y = o[1] + p.y + dx*s + dy*c;
            lo = [Math.min(lo[0], x), Math.min(lo[1], y)]; hi = [Math.max(hi[0], x), Math.max(hi[1], y)];
        }
    }
    return [lo[0], lo[1], hi[0], hi[1]];
}
"""


def render_child(output):
    from PySide6.QtCore import QEventLoop, QTimer, QUrl
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QJSEngine
    from PySide6.QtQuick import QQuickView
    from PySide6.QtSvg import QSvgRenderer
    from PIL import Image, ImageChops
    app = QGuiApplication([])
    identity = ROOT / 'src/quickshell/components/identity'
    marks = ROOT / 'src/quickshell/assets/theme-marks'
    common = 'import QtQuick\nimport "' + DRAWING.as_uri() + '" as Drawing\n'
    raw = common + '''Item {
        id: root
        property string identity: "ruby"
        property bool lightMode: true
        property string layerName: ""
        property color backgroundColor: Drawing.background(identity, lightMode)
        property color foregroundColor: lightMode ? "#24272B" : "#F3F1ED"
        Rectangle { anchors.fill: parent; color: root.backgroundColor }
        Canvas {
            id: drawing; anchors.fill: parent; renderTarget: Canvas.Image
            onPaint: {
                const ctx = getContext("2d"); ctx.reset();
                // 100px guard on all sides exposes paths beyond the nominal board.
                ctx.translate(100, 100);
                const accent = Drawing.approvedAccent(root.identity);
                if (root.layerName)
                    Drawing.paintLayer(ctx, root.identity, root.layerName, accent,
                                       root.backgroundColor, root.foregroundColor, root.lightMode);
                else
                    Drawing.paint(ctx, root.identity, accent,
                                  root.backgroundColor, root.foregroundColor, root.lightMode);
            }
        }
        // The artwork Canvas is the clipping boundary under test. SVG marks
        // are independent Image items and are covered by actual ThemeScene
        // viewport captures below.
        onIdentityChanged: drawing.requestPaint()
        onLightModeChanged: drawing.requestPaint()
        onLayerNameChanged: drawing.requestPaint()
    }'''
    scene = 'import QtQuick\nimport "' + identity.as_uri() + '" as Identity\n' + '''Identity.ThemeScene {
        motion: false
    }'''
    # Geometry and motion are plain JavaScript; evaluate them without a scene.
    engine = QJSEngine()
    source = DRAWING.read_text().replace('.pragma library', '')
    engine.evaluate(source, str(DRAWING))
    engine.evaluate(ENVELOPE)
    def call(name, *args):
        value = engine.globalObject().property(name).call([engine.toScriptValue(a) for a in args])
        if value.isError():
            raise RuntimeError(value.toString())
        return value.toVariant()

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
    def painted_reach(image, bg, origin):
        # Furthest painted pixel from the rotation origin, in artboard units.
        rgba = image.convertToFormat(image.Format.Format_RGBA8888)
        pixels = Image.frombytes('RGBA', (image.width(), image.height()), bytes(rgba.constBits())).convert('RGB')
        blank = Image.new('RGB', pixels.size, (bg.red(), bg.green(), bg.blue()))
        mask = ImageChops.difference(pixels, blank).convert('L').point(lambda v: 255 if v > 4 else 0)
        ox, oy, width = origin[0] + 100, origin[1] + 100, pixels.size[0]
        return max((math.hypot(i % width - ox, i // width - oy) for i, v in enumerate(mask.getdata()) if v), default=0) + 1
    def painted_bounds(image, bg):
        width, height = image.width(), image.height()
        # Keep the converted image alive while its bytes are copied.
        rgba = image.convertToFormat(image.Format.Format_RGBA8888)
        pixels = Image.frombytes('RGBA', (width, height), bytes(rgba.constBits())).convert('RGB')
        blank = Image.new('RGB', (width, height), (bg.red(), bg.green(), bg.blue()))
        box = ImageChops.difference(pixels, blank).point(lambda v: 255 if v > 4 else 0).getbbox()
        return None if box is None else [box[0] - 100, box[1] - 100, box[2] - 100, box[3] - 100]

    records = []
    layers = []
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
                if label == 'artboard':
                    root.setProperty('layerName', '')
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
                if label != 'artboard':
                    continue
                # Each cached layer alone, in both appearance modes.
                for light in (False, True):
                    root.setProperty('lightMode', light)
                    for layer in call('layers', name):
                        reach = 0
                        if layer.get('logo'):
                            bounds = call('logoBounds', name, layer['box'])
                        else:
                            root.setProperty('layerName', layer['name'])
                            settle()
                            frame = view.grabWindow()
                            bounds = painted_bounds(frame, root.property('backgroundColor'))
                            if 'spin' in (layer.get('motion') or {}):
                                box = layer['box']
                                reach = painted_reach(frame, root.property('backgroundColor'),
                                                      layer.get('origin') or [box[0] + box[2]/2, box[1] + box[3]/2])
                        layers.append({'theme': name, 'light': light, 'layer': layer['name'],
                                       'box': layer['box'], 'painted': bounds,
                                       'envelope': None if bounds is None else
                                           call('motionEnvelope', layer, bounds, reach)})
                    root.setProperty('layerName', '')
        view.close()
        view.deleteLater()
        settle()
    svg_valid = {name: QSvgRenderer(str(marks / (name + '.svg'))).isValid() for name in NAMES}
    Path(output).write_text(json.dumps({'renders':records,'layers':layers,'svg_valid':svg_valid}))


@unittest.skipUnless(importlib.util.find_spec('PySide6') and importlib.util.find_spec('PIL'),
                     'optional native PySide6/Pillow renderer unavailable')
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
                                     env=env,capture_output=True,text=True,timeout=300)
            if process.returncode:
                raise AssertionError(process.stdout + process.stderr)
            cls.report = json.loads(result.read_text())
            cls.render_log = process.stderr

    def test_all_fourteen_canvas_artboards_are_clear_of_bounds(self):
        rows = [r for r in self.report['renders'] if r['mode']=='artboard']
        self.assertEqual(len(rows),14)
        self.assertEqual([r for r in rows if r['painted_boundary_pixels']],[])

    def test_all_fourteen_scenes_clear_desktop_and_portrait_viewport_edges(self):
        rows = [r for r in self.report['renders'] if r['mode']=='viewport']
        self.assertEqual(len(rows),28)
        self.assertEqual([r for r in rows if r['painted_boundary_pixels']],[])
        self.assertTrue(all(r['painted_content_present'] for r in rows))

    def test_every_scene_places_its_approved_mark(self):
        themes = {r['theme'] for r in self.report['layers'] if r['layer'] == 'logo'}
        self.assertEqual(themes, set(NAMES))

    def test_every_layer_paints_inside_its_cached_box(self):
        clipped = []
        for r in self.report['layers']:
            if r['layer'] == 'logo':
                continue
            self.assertIsNotNone(r['painted'], f"{r['theme']} {r['layer']} paints nothing")
            x, y, w, h = r['box']
            left, top, right, bottom = r['painted']
            if left < x - 1 or top < y - 1 or right > x + w + 1 or bottom > y + h + 1:
                clipped.append((r['theme'], r['light'], r['layer'], r['box'], r['painted']))
        self.assertEqual(clipped, [])

    def test_motion_keeps_every_layer_on_the_artboard(self):
        low, high = SAFE
        escaped = [(r['theme'], r['light'], r['layer'], [round(v) for v in r['envelope']])
                   for r in self.report['layers']
                   if r['envelope'] and (min(r['envelope'][:2]) < low or max(r['envelope'][2:]) > high)]
        self.assertEqual(escaped, [])

    def test_native_svg_loader_accepts_all_approved_marks(self):
        self.assertEqual(len(self.report['svg_valid']),14)
        self.assertTrue(all(self.report['svg_valid'].values()))
        self.assertNotIn('Error:',self.render_log)


if __name__ == '__main__':
    if len(sys.argv)>1 and sys.argv[1]=='--render-child':
        render_child(sys.argv[2])
    else:
        unittest.main()
