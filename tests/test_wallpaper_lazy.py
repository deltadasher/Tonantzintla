import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class WallpaperLazyTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_native_library_demand_refresh_retry_and_favorite_retention(self):
        with tempfile.TemporaryDirectory(prefix='wallpaper-demand-') as directory:
            folder = Path(directory)
            config = folder / 'config'; config.mkdir()
            services = config / 'services'; services.mkdir()
            helpers = folder / 'libexec'; helpers.mkdir()
            binaries = folder / 'bin'; binaries.mkdir()
            # Prevent the service capability probe from finding live wallpaper backends.
            (binaries / 'sh').write_text('#!/bin/sh\nexit 0\n')
            (binaries / 'sh').chmod(0o755)
            (binaries / 'python3').symlink_to(shutil.which('python3'))
            shutil.copyfile(ROOT / 'src/quickshell/services/Environment.qml', services / 'Environment.qml')
            (services / 'qmldir').write_text('singleton Environment 1.0 Environment.qml\nsingleton Compositor 1.0 Compositor.qml\n')
            (services / 'Compositor.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property var workspaces: []; property string focusedOutput: "" }\n')
            (config / 'qmldir').write_text('singleton Settings 1.0 Settings.qml\nsingleton ShellState 1.0 ShellState.qml\nsingleton AdaptivePalette 1.0 AdaptivePalette.qml\n')
            (config / 'Settings.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property bool persistenceReady: true; property string wallpaperPath: ""; property string wallpaperKind: "image"; property string wallpaperOutputs: "all"; property string wallpaperTransition: "fade" }\n')
            (config / 'ShellState.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property bool ephemerisVisible: false; property string ephemerisTab: "apps" }\n')
            (config / 'AdaptivePalette.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { function refresh() {} }\n')
            (helpers / 'wallpaper-library.py').write_text('''import json, os, sys, time
from pathlib import Path
if '--import-json' in sys.argv:
    print(json.dumps({'action':'import','imported':['/fixture.jpg'],'errors':[]}))
    sys.exit(0)
log = Path(os.environ['LIBRARY_TEST_LOG'])
count = len(log.read_text().splitlines()) if log.exists() else 0
with log.open('a') as stream: stream.write('scan\\n')
time.sleep(.12)
print(json.dumps({'error': 'fixture retry'} if count == 1 else [{'path':'/fixture.jpg','name':'Fixture','kind':'image','source':'Local','preview':'','favorite':True}]))
''')
            (helpers / 'snipping-tool').write_text('#!/bin/sh\nprintf \'{"state":"idle"}\\n\'\n')
            (helpers / 'snipping-tool').chmod(0o755)
            fixture = config / 'test.qml'
            fixture.write_text('''import QtQuick
import Quickshell
import "services"
ShellRoot {
 id: test
 property int stage: 0
 property int failures: 0
 property int starts: 0
 property int ticks: 0
 function check(ok, message) { if (!ok) { failures++; console.error("LAZY FAIL", message); } }
 Connections { target: Environment.libraryProcess; function onRunningChanged() { if (Environment.libraryProcess.running) test.starts++; } }
 Timer { interval: 200; repeat: true; running: true
  onTriggered: {
   if (++test.ticks > 35) { console.error("LAZY FAIL timeout"); Qt.quit(); return; }
   if (test.stage === 0) {
    test.check(!Environment.libraryProcess.running && !Environment.libraryLoading && test.starts === 0, "startup leaves library idle");
    if (typeof Environment.ensureWallpapers !== "function") { console.error("LAZY FAIL missing ensureWallpapers"); Qt.quit(); return; }
    Environment.restoreWallpaper();
    test.check(test.starts === 0, "restore does not index library");
    Environment.ensureWallpapers(); Environment.ensureWallpapers(); Environment.ensureWallpapers();
    test.stage++;
   } else if (Environment.libraryLoading || Environment.libraryProcess.running || Environment.libraryOperationBusy) { return;
   } else if (test.stage === 1) {
    test.check(test.starts === 1 && !Environment.libraryRefreshPending, "repeated first ensure has one scan and no queued scan");
    test.check(Environment.localWallpapers.length === 1 && Environment.localWallpapers[0].favorite, "favorite loaded");
    Environment.ensureWallpapers();
    test.stage++;
   } else if (test.stage === 2) {
    test.check(test.starts === 1, "reopen reuses loaded library");
    Environment.refreshWallpapers(); test.stage++;
   } else if (test.stage === 3) {
    test.check(test.starts === 2 && Environment.libraryError.length > 0, "explicit refresh reports failure");
    test.check(Environment.localWallpapers.length === 1 && Environment.localWallpapers[0].favorite, "failed refresh preserves model and favorites");
    Environment.ensureWallpapers(); test.stage++;
   } else if (test.stage === 4) {
    test.check(test.starts === 2, "ensure does not repeatedly retry a failed refresh");
    Environment.refreshWallpapers();
    Environment.refreshWallpapers(); Environment.refreshWallpapers(); test.stage++;
   } else if (test.stage === 5) {
    test.check(test.starts === 4 && Environment.libraryError.length === 0, "retry plus coalesced in-flight explicit refresh complete");
    test.check(Environment.localWallpapers[0].favorite, "favorite survives retry");
    Environment.importWallpapers(["file:///fixture.jpg"]); test.stage++;
   } else if (test.stage === 6) {
    test.check(test.starts === 5, "successful library operation refreshes existing model");
    Environment.ensureWallpapers(); test.stage++;
   } else {
    test.check(test.starts === 5, "final reopen remains idle");
    console.log("LAZY COMPLETE", test.failures); Qt.quit();
   }
  }
 }
}
''')
            log = folder / 'scans.log'
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory,
                       XDG_CACHE_HOME=directory, XDG_STATE_HOME=directory, XDG_RUNTIME_DIR=directory,
                       QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                       DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',
                       PATH=str(binaries), LIBRARY_TEST_LOG=str(log))
            for key in ('WAYLAND_DISPLAY', 'NIRI_SOCKET', 'SWAYSOCK', 'HYPRLAND_INSTANCE_SIGNATURE'):
                env.pop(key, None)
            result = subprocess.run([shutil.which('qs'), '-p', str(fixture), '--no-color'],
                                    env=env, capture_output=True, text=True, timeout=12)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn('LAZY COMPLETE 0', output)
            for bad in ('LAZY FAIL', 'ReferenceError', 'TypeError', 'Unable to assign', 'Failed to load configuration'):
                self.assertNotIn(bad, output)
            self.assertEqual(log.read_text().splitlines(), ['scan'] * 5)


if __name__ == '__main__':
    unittest.main()
