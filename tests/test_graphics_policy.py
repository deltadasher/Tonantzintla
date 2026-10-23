import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'src/libexec/graphics_policy.py'
MARKER = 'TONANTZINTLA_QSG_RHI_BACKEND'


def load(path):
    spec = importlib.util.spec_from_file_location(path.stem, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class GraphicsPolicyTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix='graphics-policy-')
        self.addCleanup(self.folder.cleanup)
        self.base = Path(self.folder.name)
        self.env = {'HOME': str(self.base), 'XDG_CONFIG_HOME': str(self.base / 'config'), 'PATH': os.environ['PATH']}
        self.module = load(HELPER)
        self.path = self.base / 'config/tonantzintla/graphics-backend'

    def test_default_and_strict_bounded_parser(self):
        self.assertEqual(self.module.read_preference(self.env)['requested'], 'auto')
        self.assertTrue(self.module.read_preference(self.env)['valid'])
        self.path.parent.mkdir(parents=True)
        for raw in (b'', b'Vulkan\n', b'vulkan\nopengl\n', b' vulkan\n', b'$(touch bad)\n', b'vulkan\x00', b'\xff', b'x' * 10000):
            self.path.write_bytes(raw)
            value = self.module.read_preference(self.env)
            self.assertEqual(value['requested'], 'auto', raw[:30])
            self.assertFalse(value['valid'], raw[:30])
            self.assertNotIn('QSG_RHI_BACKEND', self.module.quickshell_environment(self.env))
        for raw in (b'opengl', b'opengl\n', b'opengl\r\n'):
            self.path.write_bytes(raw)
            self.assertEqual(self.module.read_preference(self.env)['requested'], 'opengl')

    def test_nonregular_preference_does_not_block_recovery_status(self):
        self.path.parent.mkdir(parents=True)
        os.mkfifo(self.path)
        result = self.cli('graphics', 'status')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('invalid', result.stdout.lower())
        self.assertEqual(self.cli('graphics', 'auto').returncode, 0)
        self.assertEqual(self.path.read_text(), 'auto\n')

    def test_atomic_roundtrip_and_failed_replace_preserves_previous(self):
        for requested in ('auto', 'opengl', 'vulkan'):
            self.module.write_preference(requested, self.env)
            self.assertEqual(self.path.read_bytes(), (requested+'\n').encode())
            self.assertEqual(self.module.read_preference(self.env)['requested'], requested)
            self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)
        with patch.object(self.module.os, 'replace', side_effect=OSError('fixture failure')):
            with self.assertRaises(OSError): self.module.write_preference('auto', self.env)
        self.assertEqual(self.path.read_text(), 'vulkan\n')
        self.assertEqual([p.name for p in self.path.parent.iterdir()], ['graphics-backend'])
        with self.assertRaises(ValueError): self.module.write_preference('invalid', self.env)
        self.assertEqual(self.path.read_text(), 'vulkan\n')

    def test_owned_restart_tracks_preference_and_auto_removes_only_owned_value(self):
        self.module.write_preference('opengl', self.env)
        first = self.module.quickshell_environment(self.env)
        self.assertEqual(first['QSG_RHI_BACKEND'], 'opengl')
        self.assertEqual(first[MARKER], 'opengl')
        self.module.write_preference('vulkan', self.env)
        second = self.module.quickshell_environment(first)
        self.assertEqual(second['QSG_RHI_BACKEND'], 'vulkan')
        self.assertEqual(second[MARKER], 'vulkan')
        self.module.write_preference('auto', self.env)
        third = self.module.quickshell_environment(second)
        self.assertNotIn('QSG_RHI_BACKEND', third)
        self.assertNotIn(MARKER, third)
        self.assertEqual(first['QSG_RHI_BACKEND'], 'opengl')

    def test_explicit_override_wins_and_invalid_marker_never_claims_ownership(self):
        self.module.write_preference('vulkan', self.env)
        for value, marker in [('opengl', None), ('opengl', 'vulkan'), ('software', 'invalid'), ('', 'vulkan'), ('software', 'software')]:
            original = dict(self.env, QSG_RHI_BACKEND=value)
            if marker is not None: original[MARKER] = marker
            snapshot = dict(original)
            child = self.module.quickshell_environment(original)
            self.assertEqual(child['QSG_RHI_BACKEND'], value)
            self.assertNotIn(MARKER, child)
            self.assertEqual(original, snapshot)
        with patch.dict(os.environ, self.env, clear=True):
            snapshot = dict(os.environ)
            self.module.quickshell_environment()
            self.assertEqual(dict(os.environ), snapshot)

    def test_supervisor_reads_each_spawn_preserves_allocator_and_parent(self):
        daemon = load(ROOT / 'src/libexec/session-daemon.py')
        inherited = dict(self.env, MALLOC_CONF='thp:never')
        for requested in ('opengl', 'vulkan', 'auto'):
            self.module.write_preference(requested, self.env)
            child = daemon.quickshell_environment(inherited)
            self.assertEqual(child.get('QSG_RHI_BACKEND'), None if requested == 'auto' else requested)
            self.assertEqual(child['MALLOC_CONF'], 'thp:never,narenas:2,dirty_decay_ms:0,muzzy_decay_ms:0')
        self.assertNotIn('QSG_RHI_BACKEND', inherited)
        self.assertEqual(inherited['MALLOC_CONF'], 'thp:never')

    def cli(self, *args, env=None):
        return subprocess.run(['bash', str(ROOT / 'bin/blackhole'), *args], env=self.env if env is None else env, capture_output=True, text=True, timeout=5)

    def test_cli_recovery_and_status_do_not_start_qs_or_claim_applied(self):
        fakebin=self.base/'bin'; fakebin.mkdir()
        fake=fakebin/'qs'; fake.write_text('#!/bin/sh\nexit 99\n'); fake.chmod(0o755)
        env=dict(self.env, PATH=str(fakebin)+os.pathsep+self.env['PATH'])
        for requested in ('vulkan','opengl','auto'):
            result=self.cli('graphics',requested,env=env)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertIn('Requested: '+requested,result.stdout)
            self.assertIn('Next start:',result.stdout)
            self.assertNotIn('applied',result.stdout.lower())
        self.path.write_text('invalid\n')
        status=self.cli('graphics','status',env=env)
        self.assertEqual(status.returncode,0,status.stderr)
        self.assertIn('invalid',status.stdout.lower())
        self.assertIn('not inspected',status.stdout.lower())
        for args in [('wrong',), ('vulkan','extra'), ('exec','qs')]:
            self.assertEqual(self.cli('graphics',*args,env=env).returncode,2)
        self.assertEqual(self.path.read_text(),'invalid\n')
        self.assertEqual(self.cli('graphics','auto',env=env).returncode,0)

    def test_direct_run_exec_boundary_and_inherited_restart(self):
        fakebin=self.base/'bin'; fakebin.mkdir()
        fake=fakebin/'qs'
        fake.write_text('#!'+sys.executable+'\nimport json,os,sys\nprint(json.dumps({"env":dict(os.environ),"args":sys.argv[1:]}))\n')
        fake.chmod(0o755)
        env=dict(self.env,PATH=str(fakebin)+os.pathsep+self.env['PATH'],MALLOC_CONF='thp:never')
        self.module.write_preference('opengl',env)
        first=self.cli('run',env=env)
        self.assertEqual(first.returncode,0,first.stderr)
        value=json.loads(first.stdout)
        self.assertEqual(value['args'],['-p',str(ROOT/'src/quickshell')])
        self.assertEqual(value['env']['QSG_RHI_BACKEND'],'opengl')
        self.assertEqual(value['env'][MARKER],'opengl')
        self.assertEqual(value['env']['MALLOC_CONF'],'thp:never,narenas:2,dirty_decay_ms:0,muzzy_decay_ms:0')
        self.module.write_preference('vulkan',env)
        child=json.loads(self.cli('run',env=value['env']).stdout)['env']
        self.assertEqual(child['QSG_RHI_BACKEND'],'vulkan')
        override=dict(child,QSG_RHI_BACKEND='opengl')
        child=json.loads(self.cli('run',env=override).stdout)['env']
        self.assertEqual(child['QSG_RHI_BACKEND'],'opengl')
        self.assertNotIn(MARKER,child)
        self.assertNotIn('QSG_RHI_BACKEND',env)

    def test_render_loop_bounded_parser_fifo_and_cli_recovery(self):
        path=self.path.with_name('render-loop')
        self.assertEqual(self.module.read_preference(self.env, policy='render-loop')['requested'],'auto')
        path.parent.mkdir(parents=True)
        for raw in (b'',b'vulkan',b'BASIC',b'basic\nthreaded',b'basic\x00',b'x'*10000):
            path.write_bytes(raw)
            self.assertFalse(self.module.read_preference(self.env,policy='render-loop')['valid'])
            self.assertNotIn('QSG_RENDER_LOOP',self.module.quickshell_environment(self.env))
        path.unlink();os.mkfifo(path)
        self.assertIn('invalid',self.cli('render-loop','status').stdout)
        self.assertEqual(self.cli('render-loop','basic').returncode,0)
        self.assertEqual(path.read_text(),'basic\n')
        self.assertEqual(path.stat().st_mode & 0o777,0o600)
        self.assertEqual(self.cli('render-loop','auto').returncode,0)
        self.assertEqual(path.read_text(),'auto\n')
        for args in [('vulkan',),('basic','extra'),('launch','qs')]:
            self.assertEqual(self.cli('render-loop',*args).returncode,2)
        self.assertEqual(path.read_text(),'auto\n')

    def test_render_loop_atomic_failure_preserves_saved_value(self):
        self.module.write_preference('basic',self.env,policy='render-loop')
        with patch.object(self.module.os,'replace',side_effect=OSError('fixture failure')):
            with self.assertRaises(OSError):
                self.module.write_preference('threaded',self.env,policy='render-loop')
        self.assertEqual(self.path.with_name('render-loop').read_text(),'basic\n')
        self.assertEqual([p.name for p in self.path.parent.iterdir()],['render-loop'])

    def test_render_loop_override_owned_restart_and_supervisor_independence(self):
        marker='TONANTZINTLA_QSG_RENDER_LOOP'
        self.module.write_preference('vulkan',self.env)
        self.module.write_preference('basic',self.env,policy='render-loop')
        first=self.module.quickshell_environment(self.env)
        self.assertEqual((first['QSG_RHI_BACKEND'],first['QSG_RENDER_LOOP']),('vulkan','basic'))
        self.assertEqual(first[marker],'basic')
        self.module.write_preference('threaded',self.env,policy='render-loop')
        second=self.module.quickshell_environment(first)
        self.assertEqual(second['QSG_RENDER_LOOP'],'threaded')
        for explicit,owned in [('basic',None),('basic','threaded'),('custom','custom'),('','threaded')]:
            env=dict(self.env,QSG_RENDER_LOOP=explicit)
            if owned is not None:env[marker]=owned
            child=self.module.quickshell_environment(env)
            self.assertEqual(child['QSG_RENDER_LOOP'],explicit)
            self.assertNotIn(marker,child)
        self.module.write_preference('auto',self.env,policy='render-loop')
        child=load(ROOT/'src/libexec/session-daemon.py').quickshell_environment(second)
        self.assertNotIn('QSG_RENDER_LOOP',child)
        self.assertNotIn(marker,child)
        self.assertEqual(child['QSG_RHI_BACKEND'],'vulkan')
        self.assertEqual(second['QSG_RENDER_LOOP'],'threaded')
        self.assertNotIn('QSG_RENDER_LOOP',self.env)

    def test_render_loop_actual_cli_run_lock_and_status(self):
        fakebin=self.base/'bin';fakebin.mkdir()
        fake=fakebin/'qs';fake.write_text('#!'+sys.executable+'\nimport json,os,sys\nprint(json.dumps({"env":dict(os.environ),"args":sys.argv[1:]}))\n');fake.chmod(0o755)
        env=dict(self.env,PATH=str(fakebin)+os.pathsep+self.env['PATH'])
        result=self.cli('render-loop','basic',env=env)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('Next start: basic',result.stdout)
        self.assertIn('Running render loop: not inspected',result.stdout)
        self.assertNotIn('applied',result.stdout)
        for action in ['run','lock']:
            r=self.cli(action,env=env);self.assertEqual(r.returncode,0,r.stderr)
            value=json.loads(r.stdout)
            self.assertEqual(value['env']['QSG_RENDER_LOOP'],'basic')
            self.assertEqual(value['env']['TONANTZINTLA_QSG_RENDER_LOOP'],'basic')
            self.assertIn('-p',value['args'])
        self.cli('render-loop','threaded',env=env)
        result=self.cli('run',env=value['env']);self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(json.loads(result.stdout)['env']['QSG_RENDER_LOOP'],'threaded')
        explicit=dict(env,QSG_RENDER_LOOP='basic')
        self.assertIn('explicit QSG_RENDER_LOOP',self.cli('render-loop','status',env=explicit).stdout)
        self.assertEqual(json.loads(self.cli('run',env=explicit).stdout)['env']['QSG_RENDER_LOOP'],'basic')

if __name__ == '__main__': unittest.main()
