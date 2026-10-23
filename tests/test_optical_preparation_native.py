import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class OpticalPreparationNativeTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_shared_preparation_lifecycle_coalescing_and_video_fallback(self):
        self.run_fixture('optical-preparation.qml', ['/A image.png','/C image.png','/bad.png','/limit0.png','/limit1.png','/limit2.png','/limit3.png','/laneA.png','scan','/laneA.png','scan','/laneB.png'])

    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_explicit_refresh_and_reapply_invalidate_same_path_and_inflight_result(self):
        self.run_fixture('optical-freshness.qml', ['/fresh.png','/fresh.png','/bad.png','scan','/bad.png','/fresh.png','/fresh.png'])

    def run_fixture(self, fixture_name, expected):
        with tempfile.TemporaryDirectory(prefix='wallpaper-demand-') as directory:
            folder = Path(directory)
            config = folder / 'config'; config.mkdir()
            services = config / 'services'; services.mkdir()
            helpers = folder / 'libexec'; helpers.mkdir()
            binaries = folder / 'bin'; binaries.mkdir()
            # Prevent the service capability probe from finding live wallpaper backends.
            (binaries / 'sh').write_text('#!/bin/sh\nexit 0\n')
            (binaries / 'sh').chmod(0o755)
            (binaries / 'swaybg').write_text('#!/bin/sh\nexit 0\n')
            (binaries / 'swaybg').chmod(0o755)
            (binaries / 'bash').symlink_to('/bin/bash')
            (helpers / 'wallpaper-apply').write_text('#!/bin/bash\nprintf \'%s|%s|%s\\n\' \"$1\" \"$2\" \"$3\" >> \"$APPLY_TEST_LOG\"\n[[ \"$2\" != /fail.mp4 ]]\n')
            apply_script=(helpers/'wallpaper-apply').read_text()
            apply_script=apply_script.replace('[[ "$2" != /fail.mp4 ]]', 'if [[ "$2" == /restore-fail.png && ! -f "$APPLY_TEST_LOG.once" ]]; then : > "$APPLY_TEST_LOG.once"; exit 1; fi\n[[ "$2" != /fail.mp4 ]]')
            apply_script=apply_script.replace('[[ \"$2\" != /fail.mp4 ]]', 'if [[ \"$2\" == /slow.png || \"$2\" == /slow-fail.png ]]; then /bin/sleep 1.2; fi\n[[ \"$2\" != /fail.mp4 && \"$2\" != /slow-fail.png ]]')
            (helpers/'wallpaper-apply').write_text(apply_script)
            (binaries / 'python3').symlink_to(shutil.which('python3'))
            shutil.copyfile(ROOT / 'src/quickshell/services/Environment.qml', services / 'Environment.qml')
            (services / 'qmldir').write_text('singleton Environment 1.0 Environment.qml\nsingleton Compositor 1.0 Compositor.qml\n')
            (services / 'Compositor.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property var workspaces: []; property string focusedOutput: "" }\n')
            (config / 'qmldir').write_text('singleton Settings 1.0 Settings.qml\nsingleton ShellState 1.0 ShellState.qml\nsingleton AdaptivePalette 1.0 AdaptivePalette.qml\n')
            (config / 'Settings.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property bool opticalControls: true; property string controlMaterial: "etched"; function controlFinishFor(scope) { return controlMaterial; } property bool persistenceReady: true; property string wallpaperPath: ""; property string wallpaperKind: "image"; property string wallpaperOutputs: "all"; property string wallpaperTransition: "fade"; property string wallpaperRenderer: "external"; property var nativeWallpaperAssignments: ({}) }\n')
            (config / 'ShellState.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { property bool ephemerisVisible: false; property string ephemerisTab: "apps" }\n')
            (config / 'AdaptivePalette.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { function refresh() {} }\n')
            components = config / 'components'; components.mkdir()
            shutil.copyfile(ROOT / 'src/quickshell/components/OpticalBackdrop.qml', components / 'OpticalBackdrop.qml')
            (helpers / 'wallpaper-library.py').write_text('''import json, os, sys, time
from pathlib import Path
assert sys.argv[1] in ('--optical-preview','--native-wallpaper-preview','--bundled-root')
source=sys.argv[2] if sys.argv[1] in ('--optical-preview','--native-wallpaper-preview') else 'scan'
with Path(os.environ['LIBRARY_TEST_LOG']).open('a') as stream: stream.write(source+'\\n')
time.sleep(.28)
print(json.dumps([] if source=='scan' else {'ok':source!='/bad.png' or Path(os.environ['LIBRARY_TEST_LOG']).read_text().splitlines().count(source)>1,'source':source,'preview':os.environ['PREP_IMAGE'],'width':64,'height':32}))
''')
            (helpers / 'snipping-tool').write_text('#!/bin/sh\nprintf \'{"state":"idle"}\\n\'\n')
            (helpers / 'snipping-tool').chmod(0o755)
            from test_optical_preview import png
            preview=folder/'prepared.png';png(preview,64,32)
            fixture=config/'test.qml'
            fixture.write_text((ROOT/'tests/instruments'/fixture_name).read_text())
            log=folder/'scans.log'
            env=dict(os.environ, HOME=directory,XDG_CONFIG_HOME=directory,XDG_CACHE_HOME=directory,
                XDG_STATE_HOME=directory,XDG_RUNTIME_DIR=directory,QT_QPA_PLATFORM='offscreen',
                QT_QUICK_BACKEND='software',DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',
                PATH=str(binaries),LIBRARY_TEST_LOG=str(log),PREP_IMAGE=str(preview),APPLY_TEST_LOG=str(folder/'apply.log'))
            for key in ('WAYLAND_DISPLAY','NIRI_SOCKET','SWAYSOCK','HYPRLAND_INSTANCE_SIGNATURE'):env.pop(key,None)
            result=subprocess.run([shutil.which('qs'),'-p',str(fixture),'--no-color'],env=env,capture_output=True,text=True,timeout=12)
            output=result.stdout+result.stderr
            self.assertEqual(result.returncode,0,output)
            self.assertIn('PREP COMPLETE 0',output)
            for bad in ('PREP FAIL','ReferenceError','TypeError','Unable to assign','Failed to load configuration'):self.assertNotIn(bad,output)
            if expected is not None:self.assertEqual(log.read_text().splitlines(), expected)
            return (folder/'apply.log').read_text().splitlines() if (folder/'apply.log').exists() else []
