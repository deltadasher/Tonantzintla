"""Actual clock weather creation/destruction and initial font mapping, without network."""
import json
import os
from pathlib import Path
import re
import selectors
import shutil
import subprocess
import tempfile
import time
import unittest
ROOT=Path(__file__).resolve().parents[1]

class ClockWeatherLifetimeTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'),'Quickshell unavailable')
    def test_weather_content_exists_only_under_original_visibility_condition(self):
        with tempfile.TemporaryDirectory(prefix='clock-weather-') as d:
            folder=Path(d);(folder/'tonantzintla').mkdir()
            (folder/'tonantzintla/settings.json').write_text(json.dumps({'motion':False,'adaptivePalette':False,'weatherEnabled':False,'dockEnabled':False,'barLayoutHorizontal':json.dumps({'start':[],'center':['clock'],'end':[]})}))
            env=dict(os.environ,HOME=d,XDG_CONFIG_HOME=d,XDG_CACHE_HOME=d,XDG_STATE_HOME=d,XDG_DATA_HOME=d,XDG_RUNTIME_DIR=d,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',DBUS_SYSTEM_BUS_ADDRESS='unix:path=/nonexistent')
            for key in ('WAYLAND_DISPLAY','NIRI_SOCKET'):env.pop(key,None)
            source=(ROOT/'tests/fonts/clock-weather.qml').read_text().replace('../../src/quickshell','.')
            maps={};lines=[]
            with tempfile.NamedTemporaryFile(mode='w',prefix='test-clock-weather-',suffix='.qml',dir=ROOT/'src/quickshell') as qml:
                qml.write(source);qml.flush()
                process=subprocess.Popen(['qs','-p',qml.name,'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
                selector=selectors.DefaultSelector();selector.register(process.stdout,selectors.EVENT_READ)
                pending=b'';deadline=time.monotonic()+8
                try:
                    while time.monotonic()<deadline:
                        events=selector.select(.2)
                        for key,_ in events:
                            block=os.read(key.fileobj.fileno(),65536)
                            if not block:selector.unregister(key.fileobj);continue
                            pending+=block
                            while b'\n' in pending:
                                line,pending=pending.split(b'\n',1);line=line.decode(errors='replace');lines.append(line)
                                match=re.search(r'WEATHER_STAGE (\d+)',line)
                                if match:maps[int(match[1])]=Path(f'/proc/{process.pid}/smaps').read_text()
                        if process.poll() is not None and not selector.get_map():break
                    process.wait(timeout=1)
                finally:
                    selector.close()
                    process.stdout.close()
                    if process.poll() is None:process.terminate();process.wait(timeout=3)
            output='\n'.join(lines)
            artifact=os.environ.get('TONA_WEATHER_ARTIFACTS')
            if artifact:
                dest=Path(artifact);dest.mkdir(parents=True,exist_ok=True)
                (dest/'native.log').write_text(output)
                for phase,value in maps.items():(dest/f'{phase}.smaps').write_text(value)
            self.assertEqual(process.returncode,0,output)
            self.assertIn('WEATHER_COMPLETE 0',output)
            self.assertEqual(set(maps),set(range(6)),output)
            self.assertNotIn('IosevkaNerdFont-Regular.ttf',maps[0])
            self.assertIn('IosevkaNerdFont-Regular.ttf',maps[1])
            for error in ('WEATHER_FAILED','TypeError','ReferenceError','Unable to assign','Binding loop'):self.assertNotIn(error,output)
