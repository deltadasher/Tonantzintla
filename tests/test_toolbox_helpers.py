import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
def module(name):
    path=ROOT/'src/libexec'/name
    if not path.exists(): return None
    spec=importlib.util.spec_from_file_location(name.replace('-','_'),path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

class ToolboxHelperTests(unittest.TestCase):
    def test_one_directory_is_bounded_and_paths_remain_literal(self):
        files=module('toolbox-files.py');self.assertIsNotNone(files)
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);(root/'folder').mkdir();(root/'folder'/'nested').write_text('private')
            (root/'$(echo literal).txt').write_text('safe');(root/'.hidden').write_text('hidden')
            data=files.list_directory(str(root),False)
            self.assertEqual(len(data['entries']),2)
            self.assertEqual(data['entries'][0]['name'],'folder')
            self.assertEqual(data['entries'][1]['path'],str(root/'$(echo literal).txt'))
            for i in range(520):(root/f'f{i}').touch()
            self.assertEqual(len(files.list_directory(str(root),False)['entries']),500)
            self.assertTrue(files.list_directory(str(root),False)['truncated'])
    def test_durable_pins_do_not_depend_on_history_ids(self):
        pins=module('clipboard-actions.py');self.assertIsNotNone(pins)
        with tempfile.TemporaryDirectory() as d:
            data=b'persist after cliphist wipe'
            first=pins.save_pin(Path(d),data,'text')
            self.assertEqual(pins.save_pin(Path(d),data,'text'),first)
            rows=pins.list_pins(Path(d));self.assertEqual(len(rows),1)
            self.assertTrue(rows[0]['id'].startswith('pin:'))
            self.assertEqual(pins.pin_bytes(Path(d),rows[0]['id']),data)
            self.assertEqual(rows[0]['content'],data.decode())
            pins.remove_pin(Path(d),rows[0]['id']);self.assertEqual(pins.list_pins(Path(d)),[])
    def test_pin_limits_and_traversal_are_rejected(self):
        pins=module('clipboard-actions.py');self.assertIsNotNone(pins)
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(ValueError):pins.save_pin(Path(d),b'x'*(1024*1024+1),'text')
            with self.assertRaises(ValueError):pins.pin_bytes(Path(d),'pin:../../secret')
            for i in range(24):pins.save_pin(Path(d),str(i).encode(),'text')
            with self.assertRaises(ValueError):pins.save_pin(Path(d),b'extra','text')
    def test_osd_state_reads_real_leds_and_radio_blocks_without_polling(self):
        helper=module('osd-status.py');self.assertIsNotNone(helper)
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            self.assertFalse(helper.read_status(root)['capslock']['supported'])
            led=root/'class/leds/input0::capslock';led.mkdir(parents=True);(led/'brightness').write_text('1\n')
            self.assertEqual(helper.read_status(root)['capslock'],{'supported':True,'enabled':True})
            radio=root/'class/rfkill/rfkill0';radio.mkdir(parents=True);(radio/'type').write_text('wlan');(radio/'soft').write_text('1');(radio/'hard').write_text('0')
            self.assertEqual(helper.read_status(root)['airplane'],{'supported':True,'enabled':True})
            (radio/'soft').write_text('0');self.assertFalse(helper.read_status(root)['airplane']['enabled'])
    def test_copy_history_streams_large_entries_without_pin_size_limit(self):
        import os
        from unittest import mock
        pins=module('clipboard-actions.py')
        self.assertTrue(hasattr(pins,'copy_history'))
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);bin_dir=root/'bin';bin_dir.mkdir();output=root/'copied'
            source=bin_dir/'cliphist';source.write_text('#!/usr/bin/python3\nimport sys\nsys.stdout.buffer.write(b"x"*(2*1024*1024))\n');source.chmod(0o755)
            sink=bin_dir/'wl-copy';sink.write_text('#!/usr/bin/python3\nimport sys,os\nfrom pathlib import Path\nwith open(os.environ["COPY_DEST"],"wb") as f:\n while chunk:=sys.stdin.buffer.read(65536):f.write(chunk)\n');sink.chmod(0o755)
            with mock.patch.dict(os.environ,{'PATH':str(bin_dir)+':'+os.environ['PATH'],'COPY_DEST':str(output)}):pins.copy_history('12')
            self.assertEqual(output.stat().st_size,2*1024*1024)
    @unittest.skipUnless(__import__('shutil').which('cliphist'),'cliphist unavailable')
    def test_real_isolated_cliphist_delete_and_pins_survive_wipe(self):
        import os,json,subprocess
        from unittest import mock
        helper=ROOT/'src/libexec/clipboard-actions.py'
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);env=dict(os.environ,XDG_CACHE_HOME=directory,CLIPHIST_DB_PATH=str(root/'test-db'))
            subprocess.run(['cliphist','store'],input=b'durable fixture',env=env,check=True)
            identifier=subprocess.check_output(['cliphist','list'],env=env).split(b'\t')[0].decode()
            result=subprocess.run(['python3',str(helper),'pin',str(root/'pins'),identifier],env=env,capture_output=True,text=True,check=True)
            saved=json.loads(result.stdout);self.assertTrue(saved['ok']);pin_id=saved['pins'][0]['id']
            result=subprocess.run(['python3',str(helper),'delete',str(root/'pins'),identifier],env=env,capture_output=True,text=True,check=True)
            self.assertTrue(json.loads(result.stdout)['ok']);self.assertEqual(subprocess.check_output(['cliphist','list'],env=env),b'')
            result=subprocess.run(['python3',str(helper),'clear',str(root/'pins')],env=env,capture_output=True,text=True,check=True)
            after=json.loads(result.stdout);self.assertEqual(after['pins'][0]['id'],pin_id);self.assertEqual(after['pins'][0]['content'],'durable fixture')
