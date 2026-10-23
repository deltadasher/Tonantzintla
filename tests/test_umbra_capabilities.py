import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('umbra_capabilities',Path(__file__).resolve().parents[1]/'src/libexec/umbra-capabilities.py')
helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)

class UmbraCapabilitiesTests(unittest.TestCase):
    def test_local_paths_reject_remote_missing_and_relative(self):
        for value in ('https://example.org/a.mp4','file://other/a.mp4','relative.mp4','/missing/umbra-file'):
            with self.assertRaises(ValueError): helper.local_path(value)
    def test_video_rejects_excess_resolution_and_rate_before_decode(self):
        with tempfile.NamedTemporaryFile(suffix=' space.mp4') as file:
            for width,height,rate,allowed in [(1280,720,'30/1',True),(1920,1080,'24/1',False),(1280,720,'60/1',False),(0,720,'1/1',False),(1280,720,'0/0',False),(1280,720,'nan/1',False)]:
                response=subprocess.CompletedProcess([],0,json.dumps({'streams':[{'width':width,'height':height,'avg_frame_rate':rate}]}),'')
                with patch.object(helper.shutil,'which',return_value='/usr/bin/ffprobe'),patch.object(helper.subprocess,'run',return_value=response) as run:
                    if allowed:self.assertTrue(helper.inspect_media(file.name)['available'])
                    else:
                        with self.assertRaises(ValueError):helper.inspect_media(file.name)
                    self.assertEqual(run.call_args.args[0][-1],file.name)
                    self.assertEqual(run.call_args.args[0][run.call_args.args[0].index('-protocol_whitelist')+1],'file,pipe')
    def test_pam_scan_is_bounded_and_requires_auth_module(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            (root/'main').write_text('auth include child\n')
            (root/'child').write_text('# auth sufficient pam_fprintd.so\nauth include main\n')
            self.assertFalse(helper.profile_uses_fingerprint('main',root))
            (root/'child').write_text('auth sufficient pam_fprintd.so\n')
            self.assertTrue(helper.profile_uses_fingerprint('main',root))
            self.assertFalse(helper.profile_uses_fingerprint('../main',root))
            (root/'child').write_text('session optional pam_fprintd.so\n')
            self.assertFalse(helper.profile_uses_fingerprint('main',root))

    def test_loop_preparation_is_bounded_cached_and_revalidated(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            source=root/'input.mp4';source.write_bytes(b'video')
            def convert(command, **kwargs):
                Path(command[-1]).write_bytes(b'GIF89a' + b'x' * 32)
                return subprocess.CompletedProcess(command,0,b'',b'')
            with patch.dict(os.environ,{'XDG_CACHE_HOME':directory}), \
                    patch.object(helper,'inspect_media',return_value={'available':True}) as probe, \
                    patch.object(helper.shutil,'which',return_value='/usr/bin/ffmpeg'), \
                    patch.object(helper.subprocess,'run',side_effect=convert) as run:
                first=helper.prepare_video(str(source))
                self.assertFalse(first['cached']);self.assertTrue(first['prepared'])
                second=helper.prepare_video(str(source))
                self.assertTrue(second['cached']);self.assertEqual(first['path'],second['path'])
                self.assertEqual(run.call_count,1)
                source.write_bytes(b'replacement video')
                third=helper.prepare_video(str(source))
                self.assertNotEqual(first['path'],third['path'])
                self.assertEqual(run.call_count,2);self.assertEqual(probe.call_count,3)
                command=run.call_args.args[0]
                self.assertEqual(command[command.index('-t')+1],'8')
                self.assertEqual(command[command.index('-threads')+1],'1')
                self.assertEqual(command[command.index('-filter_threads')+1],'1')
                self.assertIn('fps=12,scale=640:360',command[command.index('-vf')+1])
                self.assertEqual(command[command.index('-protocol_whitelist')+1],'file,pipe')
                self.assertEqual(run.call_args.kwargs['timeout'],25)
                self.assertEqual(len(list((root/'tonantzintla/umbra-loops').glob('*.partial'))),0)

    def test_loop_cache_limits_count_bytes_and_reserves_conversion_space(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            with patch.object(helper,'LOOP_MAX_BYTES',12),patch.object(helper,'CACHE_MAX_BYTES',48):
                for index in range(6): (root/f'{index}.gif').write_bytes(b'x'*12)
                helper.prune_loops(root)
                self.assertEqual(len(list(root.glob('*.gif'))),4)
                helper.prune_loops(root,reserve=True)
                self.assertEqual(len(list(root.glob('*.gif'))),3)
                (root/'too-large.gif').write_bytes(b'x'*13)
                helper.prune_loops(root)
                self.assertFalse((root/'too-large.gif').exists())
