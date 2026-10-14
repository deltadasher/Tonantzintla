import json
import unittest
from unittest import mock

from test_wallpaper_helpers import load_script


class AudioRoutingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.audio = load_script("audio-route.py")

    def test_resolves_serials_to_pulse_indices(self):
        replies = [json.dumps([{"index": 7, "sink": 2, "properties": {"object.serial": "101"}}]),
                   json.dumps([{"index": 9, "name": "headphones", "properties": {"object.serial": "202"}}]), ""]
        with mock.patch.object(self.audio, "run", side_effect=replies) as run:
            self.audio.move_stream("101", "202")
        self.assertEqual(run.call_args.args[0], ["move-sink-input", "7", "headphones"])

    def test_stale_serial_does_not_move_another_stream(self):
        with mock.patch.object(self.audio, "run", return_value="[]") as run:
            with self.assertRaises(ValueError):
                self.audio.move_stream("101", "202")
        self.assertEqual(run.call_count, 1)

    def test_invalid_serial_never_calls_audio_server(self):
        with mock.patch.object(self.audio, "run") as run:
            with self.assertRaises(ValueError):
                self.audio.move_stream("not-a-node", "202")
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
