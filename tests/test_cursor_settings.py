import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
import shutil
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('cursor_settings', Path(__file__).resolve().parents[1] / 'src/libexec/cursor-settings.py')
cursor = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cursor)


class CursorSettingsTests(unittest.TestCase):
    def test_stale_ui_revision_cannot_overwrite_config(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'config.kdl'
            original = 'cursor {}\n'
            path.write_text(original)
            with patch.object(cursor, 'config_path', return_value=path), patch.object(cursor, 'themes', return_value=['Ice']):
                with self.assertRaisesRegex(ValueError, 'changed since'):
                    cursor.apply('Ice', 24, revision='stale')
            self.assertEqual(path.read_text(), original)
            self.assertEqual(len(list(Path(directory).iterdir())), 1)

    @unittest.skipUnless(shutil.which('niri'), 'Niri not installed')
    def test_real_niri_validation(self):
        source = 'cursor {\n    hide-when-typing\n    xcursor-theme "Old"\n}\nwindow-rule {\n    match app-id=r#"^(example)$"#\n}\n'
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'config.kdl'
            path.write_text(source)
            with patch.object(cursor, 'config_path', return_value=path), patch.object(cursor, 'themes', return_value=['Bibata-Modern-Ice']):
                result = cursor.apply('Bibata-Modern-Ice', 32, {'hideTyping': True, 'hideAfter': 5000})
            self.assertEqual(result['theme'], 'Bibata-Modern-Ice')
            self.assertEqual(result['size'], 32)
            self.assertTrue(result['hideTyping'])
            self.assertEqual(result['hideAfter'], 5000)
            with patch.object(cursor, 'config_path', return_value=path), patch.object(cursor, 'themes', return_value=['Bibata-Modern-Ice']):
                result = cursor.apply('Bibata-Modern-Ice', 32, {'hideTyping': False, 'hideAfter': 0})
            self.assertFalse(result['hideTyping'])
            self.assertEqual(result['hideAfter'], 0)

    def test_preserves_other_options_and_raw_strings(self):
        source = 'window-rule { match app-id=r#"cursor { }"#; }\ncursor {\n    hide-when-typing\n    xcursor-theme "Old"\n    xcursor-size 32\n}\n'
        result = cursor.update(source, 'Bibata-Modern-Ice', 24)
        self.assertIn('app-id=r#"cursor { }"#', result)
        self.assertIn('hide-when-typing', result)
        self.assertNotIn('"Old"', result)
        self.assertEqual(result.count('xcursor-theme'), 1)

    def test_comments_are_not_cursor_blocks(self):
        source = '// cursor { ignored }\n/* nested /* cursor { } */ comment */\n'
        self.assertTrue(cursor.update(source, 'Ice', 24).startswith(source))

    def test_preserves_commented_setting(self):
        source = 'cursor {\n/*\nxcursor-theme "comment"\n*/\nxcursor-size 24\n}\n'
        self.assertIn('xcursor-theme "comment"', cursor.update(source, 'Ice', 32))

    def test_refuses_ambiguous_configs(self):
        for source in ['cursor {}\ncursor {}', 'include "other.kdl"', '/- cursor {}', 'cursor {']:
            with self.subTest(source=source), self.assertRaises(ValueError):
                cursor.update(source, 'Ice', 24)

    def test_idempotent(self):
        result = cursor.update('', 'Ice', 24)
        self.assertEqual(cursor.update(result, 'Ice', 24), result)

    def test_failed_validation_leaves_original(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'config.kdl'
            path.write_text('cursor {}\n')
            with patch.object(cursor, 'config_path', return_value=path), patch.object(cursor, 'themes', return_value=['Ice']), patch.object(cursor.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, '', 'invalid')):
                with self.assertRaises(ValueError):
                    cursor.apply('Ice', 24)
            self.assertEqual(path.read_text(), 'cursor {}\n')
            self.assertEqual(len(list(Path(directory).iterdir())), 1)

    def test_success_keeps_backup(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'config.kdl'
            path.write_text('cursor {}\n')
            with patch.object(cursor, 'config_path', return_value=path), patch.object(cursor, 'themes', return_value=['Ice']), patch.object(cursor.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, '', '')):
                cursor.apply('Ice', 24)
            backups = list(Path(directory).glob('*.before-cursor-*'))
            self.assertEqual(len(backups), 1)
            self.assertEqual(backups[0].read_text(), 'cursor {}\n')
            self.assertIn('xcursor-theme "Ice"', path.read_text())
