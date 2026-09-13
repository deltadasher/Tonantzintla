"""The Super+Alt gesture, its spotlight, and the panels it opens."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / "src/quickshell" / path).read_text()


class GestureTests(unittest.TestCase):
    def test_island_drag_is_owned_by_editor_or_visible_grip(self) -> None:
        island = source("components/BarIsland.qml")
        self.assertIn("ShellState.barEditMode || overGrip", island)
        self.assertIn("acceptedButtons: Qt.LeftButton", island)
        self.assertNotIn("hasMeta", island)
        self.assertNotIn("hasAlt", island)

    def test_widget_gesture_matches_the_island_gesture(self) -> None:
        surface = source("modules/ephemeris/EphemerisSurface.qml")
        self.assertIn("ShellState.openWidgetSettings", surface)
        self.assertIn("hasMeta && hasAlt", surface)
        # Every other click must fall through to the widget untouched.
        self.assertIn("mouse.accepted = false;", surface)

    def test_super_alt_left_click_opens_arranging(self) -> None:
        island = source("components/BarIsland.qml")
        self.assertNotIn("longHoldTimer", island)
        bar = source("modules/aperture/ApertureContents.qml")
        self.assertNotIn("acceptedModifiers: Qt.MetaModifier | Qt.AltModifier", bar)
        niri = (ROOT / "compositors/niri/config.kdl").read_text()
        self.assertIn("Mod+Alt+MouseLeft", niri)
        self.assertIn("blackhole\\\" bar-edit", niri)

    def test_cli_bar_edit_is_open_not_toggle(self) -> None:
        cli = (ROOT / "bin/blackhole").read_text()
        case = cli.split("    bar-edit)", 1)[1].split("        ;;") [0]
        self.assertIn("call_ipc aperture edit", case)
        self.assertNotIn("toggleEdit", case)

    def test_studio_does_not_steal_the_live_bar_pointer(self) -> None:
        studio = source("modules/aperture/BarEditStudio.qml")
        self.assertIn("mask: Region", studio)
        self.assertIn("Region { item: bottomDrawer }", studio)
        self.assertIn("Region { item: sideDrawer }", studio)
        self.assertNotIn("anchors.fill: parent\n            onClicked: function(mouse) { mouse.accepted = true; }", studio)

    def test_drag_uses_a_live_full_size_island(self) -> None:
        studio = source("modules/aperture/BarEditStudio.qml")
        state = source("ShellState.qml")
        self.assertIn("id: dragProxy", studio)
        self.assertIn("IslandHost {", studio)
        self.assertIn("barWindow: proxyBarContext", studio)
        self.assertIn("ShellState.dragHoverEdge", studio)
        self.assertIn("dragVelocityX", state)


class SpotlightTests(unittest.TestCase):
    def test_scrim_dims_with_plain_rectangles(self) -> None:
        scrim = source("components/FocusScrim.qml")
        # The Canvas version rendered nothing at all on the real shell, and
        # nothing here can lint or preview Canvas compositing. Four solid
        # fills either paint or fail loudly at load.
        self.assertNotIn("Canvas {", scrim)
        self.assertNotIn("getContext(", scrim)
        self.assertEqual(4, scrim.count("color: root.scrimColor"))
        self.assertIn("readonly property bool hasFocus", scrim)
        for edge in ("holeLeft", "holeRight", "holeTop", "holeBottom"):
            self.assertIn(f"readonly property real {edge}", scrim)

    def test_scrim_bands_cover_everything_but_the_hole(self) -> None:
        # The band algebra the QML declares, checked against a pixel sweep.
        def bands(w, h, fx, fy, fw, fh, halo):
            has = fw > 0 and fh > 0
            left = max(0, min(w, fx - halo)) if has else 0
            right = max(0, min(w, fx + fw + halo)) if has else 0
            top = max(0, min(h, fy - halo)) if has else 0
            bottom = max(0, min(h, fy + fh + halo)) if has else 0
            return [
                (0, 0, w, top),
                (0, bottom, w, max(0, h - bottom)),
                (0, top, left, max(0, bottom - top)),
                (right, top, max(0, w - right), max(0, bottom - top)),
            ], (left, top, right, bottom)

        cases = [
            (200, 100, 0, 0, 200, 44, 0),      # the studio's full-width bar
            (200, 100, 60, 30, 40, 20, 6),     # a popover target mid-screen
            (200, 100, 0, 0, 0, 0, 6),         # nothing measured yet
        ]
        for w, h, fx, fy, fw, fh, halo in cases:
            rects, (left, top, right, bottom) = bands(w, h, fx, fy, fw, fh, halo)
            for px in range(w):
                for py in range(h):
                    inside = left <= px < right and top <= py < bottom
                    covered = any(bx <= px < bx + bw and by <= py < by + bh
                                  for bx, by, bw, bh in rects)
                    self.assertEqual(not inside, covered,
                                     f"({px},{py}) in {(w, h, fx, fy, fw, fh, halo)}")

    def test_both_surfaces_spotlight_their_target(self) -> None:
        popover = source("modules/aperture/IslandQuickSettings.qml")
        studio = source("modules/aperture/BarEditStudio.qml")
        widget = source("modules/ephemeris/WidgetQuickSettings.qml")
        for name, text in (("popover", popover), ("studio", studio), ("widget", widget)):
            self.assertIn("FocusScrim {", text, name)
        # The studio used to lay a flat wash over everything instead.
        self.assertNotIn("color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.28)",
                         studio)

    def test_widget_popover_is_hosted_and_gated(self) -> None:
        shell = source("shell.qml")
        state = source("ShellState.qml")
        self.assertIn("WidgetQuickSettings {}", shell)
        self.assertIn("ShellState.widgetSettingsVisible", shell)
        self.assertIn("function openWidgetSettings", state)
        # Closing the surface must take its popover with it.
        self.assertIn("closeWidgetSettings();", state)


class PlainLanguageTests(unittest.TestCase):
    def test_the_new_panels_say_what_they_do(self) -> None:
        texts = "".join(source(p) for p in (
            "modules/aperture/IslandQuickSettings.qml",
            "modules/aperture/BarEditStudio.qml",
            "modules/ephemeris/WidgetQuickSettings.qml",
            "modules/ephemeris/IslandArrangementEditor.qml",
        ))
        for invented in ("Hardware Telemetry", "Orbital Aperture Controls",
                         "Mission Control", "Celestial Calendar Hub",
                         "Visible Telemetry Pills", "Violet Nebula",
                         "Bar Studio Active", "staging canvas"):
            self.assertNotIn(invented, texts, invented)


if __name__ == "__main__":
    unittest.main()
