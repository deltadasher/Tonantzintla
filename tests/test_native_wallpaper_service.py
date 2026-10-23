import shutil
import unittest
import test_optical_preparation_native as fixture
class NativeWallpaperServiceTests(unittest.TestCase):
    run_fixture = fixture.OpticalPreparationNativeTests.run_fixture
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_native_selection_stale_hotplug_handoff_and_recovery(self):
        calls=self.run_fixture('native-wallpaper-service.qml', None)
        self.assertEqual(calls,["image|/initial.png|B","image|/final.png|C","video|/fail.mp4|C","video|/clip.mp4|C","image|/recover.png|C","image|/restore-fail.png|B","image|/restore-fail.png|B","image|/recover.png|C","video|/clip2.mp4|C"])

    @unittest.skipUnless(shutil.which('qs'), 'Quickshell unavailable')
    def test_late_external_and_stale_failed_handoff_cannot_replace_new_intent(self):
        calls=self.run_fixture('native-wallpaper-races.qml', None)
        self.assertEqual(calls,["image|/slow.png|all","image|/slow-fail.png|A","image|/latest.png|A"])
