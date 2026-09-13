import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class BarControlsTests(unittest.TestCase):
    def test_studio_spawning_uses_the_current_edge_and_detects_placements(self):
        repo = Path(__file__).resolve().parents[1]
        studio = (repo / 'src/quickshell/modules/aperture/BarEditStudio.qml').read_text()
        self.assertIn('Settings.placeIsland(outputName, id, currentEdge, zone, ordered);', studio)
        self.assertIn('readonly property bool present: loc !== null || placement !== null', studio)
        self.assertIn('visible: !present', studio)
        self.assertIn('visible: present', studio)

    def test_live_islands_remain_outlined_in_studio(self):
        repo = Path(__file__).resolve().parents[1]
        island = (repo / 'src/quickshell/components/BarIsland.qml').read_text()
        self.assertIn('border.width: ShellState.barEditMode && barWindow ? 1 : 0', island)

    def test_panel_activation_clears_stale_bar_hover(self):
        repo = Path(__file__).resolve().parents[1]
        button = (repo / 'src/quickshell/components/BarButton.qml').read_text()
        self.assertIn('property bool hoverSuppressed: false', button)
        self.assertIn('readonly property bool hovered: pointer.containsMouse && !pointer.hoverSuppressed', button)
        self.assertIn('hoverSuppressed = true;', button)
        self.assertIn('onExited: hoverSuppressed = false', button)
        self.assertIn('visible: root.hovered', button)
        self.assertNotIn('visible: root.hovered || root.activeFocus', button)

    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_arranger_and_icon_motion(self):
        repo = Path(__file__).resolve().parents[1]
        for width in ('830', '480'):
            with self.subTest(width=width), tempfile.TemporaryDirectory(prefix='bar-controls-') as directory:
                env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                           XDG_RUNTIME_DIR=directory, XDG_CONFIG_HOME=directory, XDG_CACHE_HOME=directory,
                           BAR_WIDTH=width, BAR_ROOT=(repo / 'src/quickshell').as_uri())
                env.pop('WAYLAND_DISPLAY', None)
                fixture = Path(directory) / 'bar-layout.qml'
                fixture.write_text((repo / 'tests/qml/bar-layout.qml').read_text().replace(
                    '"../../src/quickshell"', '"' + (repo / 'src/quickshell').as_uri() + '"'))
                if os.environ.get('BAR_PREVIEW_DIR'):
                    env['BAR_IMAGE'] = str(Path(os.environ['BAR_PREVIEW_DIR']) / ('tonantzintla-bar-' + width + '.png'))
                result = subprocess.run(['qs', '-p', str(fixture), '--no-color'],
                                        env=env, capture_output=True, text=True, timeout=10)
                output = result.stdout + result.stderr
                self.assertEqual(result.returncode, 0, output)
                self.assertNotIn('BAR_FAILED', output)
                self.assertNotIn('Binding loop', output)
                self.assertNotIn('TypeError', output)
                self.assertIn('BAR_LAYOUT_OK', output)
