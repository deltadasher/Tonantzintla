"""Native Qt rendering of actual components with inert compositor/settings fixtures."""
import os
os.environ['QT_QPA_PLATFORM']='offscreen'
os.environ['QT_QUICK_BACKEND']='software'
import shutil, tempfile, unittest
from pathlib import Path
from PySide6.QtCore import Qt, QObject
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtTest import QTest
from PySide6.QtQuick import QQuickWindow, QQuickItem

BASE=Path(__file__).resolve().parents[1]
APP=QGuiApplication.instance() or QGuiApplication([])

class BarFaceTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.root=Path(self.tmp.name)
        (self.root/'components').mkdir(); (self.root/'services').mkdir()
        variant=os.environ.get('TONA_BAR_VARIANT','src')
        source=BASE/variant/'quickshell/components'
        for name in ('WorkspaceOrbit.qml','ApertureClockFace.qml','MatrixClockFace.qml'):
            if (source/name).exists(): shutil.copyfile(source/name,self.root/'components'/name)
        (self.root/'qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton Settings 1.0 Settings.qml\n')
        (self.root/'Settings.qml').write_text('''pragma Singleton
import QtQuick
QtObject { property string barWorkspaceStyle: "orbital"; property string barPosition: "top"; property bool motion: false; property string motionSpeedProfile: "instant"; property bool clock12h: false; property bool showSeconds: false; property bool showDate: false; property string clockFormat: "HH:mm"; property string dateFormat: "ddd d" }
''')
        (self.root/'Theme.qml').write_text('''pragma Singleton
import QtQuick
QtObject { property color accent: "#d5b28c"; property color void_: "#17181b"; property color moon: "#eeeeee"; property color muted: "#9999aa"; property color warning: "#e9a85b"; property color barNeutralHover: "#444444"; property color barHairlineHover: "#555555"; property string fontMono: "monospace"; property string fontDisplay: "sans-serif"; property int textMicro: 10; property int motionFast: 0; function duration(x) { return 0; } }
''')
        if variant=='runtime-src':
            theme=self.root/'Theme.qml'
            theme.write_text(theme.read_text().replace('property int textMicro: 10;','').replace('function duration(x) { return 0; }',''))
        (self.root/'services/qmldir').write_text('singleton Compositor 1.0 Compositor.qml\n')
        (self.root/'services/Compositor.qml').write_text('''pragma Singleton
import QtQuick
QtObject { property bool available: true; property int lastFocus: -1; property var workspaces: [{id:10,idx:1,output:"test",is_active:true},{id:11,idx:2,output:"test"},{id:12,idx:3,output:"test",is_urgent:true},{id:13,idx:4,output:"test"}]; property var windows: [{workspace_id:11}]; function focusWorkspace(id) { lastFocus=id; } }
''')
        (self.root/'main.qml').write_text('''import QtQuick
import "components"
import "services"
import "."
Window { width: 560; height: 300; visible: true; color: "#17181b"
property alias orbit: orbit
property int lastFocus: Compositor.lastFocus
function setStyle(style) { Settings.barWorkspaceStyle=style; }
function setVertical(on) { Settings.barPosition=on ? "left" : "top"; clock.item.vertical=on; }
function setTwelve(on) { Settings.clock12h=on; }
function setSeconds(on) { Settings.showSeconds=on; }
function setTime(hour,minute,second) { clock.item.dateTime=new Date(2026,9,29,hour,minute,second); }
function setClock(face) { clock.item.variant=face; }
function setMotion(on,profile) { Settings.motion=on; Settings.motionSpeedProfile=profile; }
function setEmpty() { Compositor.workspaces=[]; }
WorkspaceOrbit { id: orbit; objectName: "orbit"; output:"test"; x:20; y:20 }
Loader { id: clock; objectName:"clockLoader"; x:200; y:20; Component.onCompleted: setSource("components/ApertureClockFace.qml", {dateTime:new Date(2026,9,29,17,42,8),variant:"matrix"}) }
}
''')
        self.engine=QQmlApplicationEngine(); self.warnings=[]
        self.engine.warnings.connect(lambda warnings:self.warnings.extend(w.toString() for w in warnings))
        self.engine.load(str(self.root/'main.qml'))
        self.assertTrue(self.engine.rootObjects(),self.warnings)
        self.win=self.engine.rootObjects()[0]; QTest.qWait(80)
        self.orbit=self.win.findChild(QObject,'orbit')
    def tearDown(self):
        self.engine.deleteLater(); QTest.qWait(10); self.tmp.cleanup()
    def find_visual(self, item, name):
        if item.objectName()==name:return item
        for child in item.childItems():
            found=self.find_visual(child,name)
            if found:return found
        return None
    def test_workspace_styles_preserve_hit_geometry_and_keyboard_action(self):
        for style in ('orbital','pills','dots','track'):
            self.win.setStyle(style); QTest.qWait(10)
            self.assertEqual(self.orbit.property('style'),style)
            cell=self.find_visual(self.win.contentItem(),'workspace-11'); self.assertIsNotNone(cell)
            self.assertEqual((cell.property('width'),cell.property('height')),(30,30))
            self.assertTrue(cell.property('hasWindows'))
            cell.forceActiveFocus(); QTest.keyClick(self.win,Qt.Key_Return); QTest.qWait(10)
            self.assertEqual(self.win.property('lastFocus'),11)
            self.assertEqual(self.orbit.property('implicitWidth'),135)
        self.win.setVertical(True); QTest.qWait(10)
        self.assertEqual((self.orbit.property('implicitWidth'),self.orbit.property('implicitHeight')),(30,135))
        self.win.setStyle('unknown'); QTest.qWait(10)
        self.assertEqual(self.orbit.property('style'),'orbital')
        self.win.setMotion(True,'instant'); QTest.qWait(10)
        self.assertFalse(self.orbit.property('motionEnabled'))
        self.win.setMotion(True,'normal'); QTest.qWait(10)
        self.assertTrue(self.orbit.property('motionEnabled'))
        self.win.setMotion(False,'normal'); QTest.qWait(10)
        self.assertFalse(self.orbit.property('motionEnabled'))
        self.win.setEmpty(); QTest.qWait(10)
        self.assertIsNone(self.find_visual(self.win.contentItem(),'workspace-11'))
        self.assertFalse(self.warnings,self.warnings)
    def test_matrix_clock_notation_and_bounded_render(self):
        matrix=self.win.findChild(QObject,'matrixClock'); self.assertIsNotNone(matrix,self.warnings)
        self.assertEqual(matrix.property('timeText'),'17:42')
        self.win.setTwelve(True); QTest.qWait(10)
        self.assertEqual(matrix.property('timeText'),'05:42')
        self.assertEqual(matrix.property('periodText'),'PM')
        self.assertLessEqual(matrix.property('implicitHeight'),30)
        self.win.setSeconds(True); self.win.setTime(0,3,9); QTest.qWait(10)
        self.assertEqual(matrix.property('timeText'),'12:03:09')
        self.assertEqual(matrix.property('periodText'),'AM')
        self.win.setTime(12,3,9); QTest.qWait(10)
        self.assertEqual(matrix.property('timeText'),'12:03:09')
        self.assertEqual(matrix.property('periodText'),'PM')
        matrix.setProperty('vertical',True); QTest.qWait(10)
        self.assertLessEqual(matrix.property('implicitWidth'),30)
        self.assertEqual(matrix.property('timeText'),'12:03')
        self.assertFalse(self.warnings,self.warnings)
    def test_existing_clock_faces_still_load(self):
        for face in ('classic','stacked','compact','matrix'):
            self.win.setClock(face); QTest.qWait(20)
            self.assertFalse(self.warnings,self.warnings)
    def test_render_styles(self):
        target=os.environ.get('TONA_BAR_ARTIFACTS')
        for style in ('orbital','pills','dots','track'):
            self.win.setStyle(style); QTest.qWait(30)
            image=self.win.grabWindow(); self.assertFalse(image.isNull())
            if target:
                dest=Path(target);dest.mkdir(parents=True,exist_ok=True);image.save(str(dest/(style+'.png')))
        self.win.setVertical(True); QTest.qWait(30)
        if target:self.win.grabWindow().save(str(dest/'vertical-track.png'))

if __name__=='__main__':unittest.main()
