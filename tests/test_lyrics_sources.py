import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('lyrics_state', ROOT/'src/libexec/lyrics-state.py')
lyrics = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lyrics)


class LyricsSourceTests(unittest.TestCase):
    def test_adjacent_local_lrc_and_remote_rejection(self):
        self.assertTrue(callable(getattr(lyrics, 'local_lyrics', None)), 'Local LRC source is missing')
        with tempfile.TemporaryDirectory() as directory:
            track = Path(directory) / 'song with spaces.flac'
            track.touch()
            lrc = track.with_suffix('.lrc')
            lrc.write_text('[00:01.20]hello\n[00:02.30]world')
            payload = lyrics.local_lyrics(track.as_uri())
            self.assertEqual(payload['source'], 'LOCAL LRC')
            self.assertEqual(payload['synced'], lrc.read_text())
            self.assertIsNone(lyrics.local_lyrics('https://example.org/song.flac'))
            self.assertIsNone(lyrics.local_lyrics('file://remote/song.flac'))
            self.assertIsNone(lyrics.local_lyrics('file:///'))
            self.assertIsNone(lyrics.local_lyrics('file://['))
            lrc.write_bytes(b'x' * (256 * 1024 + 1))
            self.assertIsNone(lyrics.local_lyrics(track.as_uri()))

    @unittest.skipUnless(shutil.which('node'), 'Node unavailable')
    def test_only_real_word_timestamps_become_seek_links(self):
        source = ROOT/'src/quickshell/services/LyricsModel.js'
        self.assertTrue(source.is_file(), 'Enhanced LRC parser is missing')
        script = source.read_text().replace('.pragma library', '') + r'''
const assert = require('node:assert/strict');
let ordinary = syncedLines('[00:01.25]hello world\n[00:03.50]next line');
assert.equal(ordinary[0].time, 1.25);
assert.equal(ordinary[0].text, 'hello world');
assert.deepEqual(ordinary[0].words, []);
let enhanced = syncedLines('[00:01.00]<00:01.00>Hello <00:01.50>bright <00:02.00>world');
assert.equal(enhanced[0].text, 'Hello bright world');
assert.deepEqual(enhanced[0].words.map(w=>w.time), [1, 1.5, 2]);
assert.equal(enhanced[0].words[1].text, 'bright ');
assert.equal(syncedLines('[00:05.00]<00:05.00>one <00:04.00>bad')[0].words.length, 0);
assert.equal(syncedLines('[00:70]bad').length, 0);
assert.equal(syncedLines('[00:01][00:03]chorus').length, 2);
let dangerous = syncedLines('[00:01]<00:01><b>not markup</b>')[0];
const html = wordHtml(dangerous, 1.1);
assert.ok(html.includes('&lt;b&gt;'));
assert.ok(!html.includes('<b>'));
assert.ok(html.includes('href="seek:1"'));
assert.equal(wordHtml(ordinary[0], 1.1), 'hello world');
'''
        subprocess.run(['node', '-e', script], check=True, capture_output=True, text=True)
