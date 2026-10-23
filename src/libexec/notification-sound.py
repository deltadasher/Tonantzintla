#!/usr/bin/env python3
"""Validate or play one bounded local PCM WAV; check never starts playback."""
import json
import math
import os
from pathlib import Path
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
from urllib.parse import unquote, urlsplit
import wave


def run(action, source, volume):
    player=shutil.which('pw-play')
    if not player:
        return {'available':False,'state':'unsupported','message':'pw-play is unavailable; notification sound is disabled.'}
    try:
        url=urlsplit(str(source))
        if url.scheme and (url.scheme!='file' or url.netloc not in ('','localhost')):
            raise ValueError('Choose a local PCM WAV file.')
        path=Path(unquote(url.path) if url.scheme=='file' else str(source)).expanduser()
        if not source or not path.is_absolute():
            raise ValueError('Choose a local PCM WAV file.')
        # The same descriptor is validated and passed to the player, so replacing
        # a selected path cannot swap in an unvalidated file between operations.
        fd=os.open(path,os.O_RDONLY|os.O_NONBLOCK)
        with os.fdopen(fd,'rb') as data:
            info=os.fstat(data.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_size>8*1024*1024:
                raise ValueError('Choose a regular WAV file no larger than 8 MiB.')
            with wave.open(data,'rb') as audio:
                rate=audio.getframerate();frames=audio.getnframes()
                if audio.getnchannels() not in (1,2) or audio.getsampwidth() not in (1,2,3,4) or not 8000<=rate<=192000:
                    raise ValueError('Use a mono or stereo PCM WAV, 8–192 kHz.')
                if not 0<frames<=rate*5:
                    raise ValueError('Notification sounds must be between 0 and 5 seconds long.')
            if action=='check':
                return {'available':True,'state':'ready','message':'Local WAV and pw-play are available. Audio-server playback has not been tested.'}
            if action!='play':
                raise ValueError('Unknown sound operation.')
            data.seek(0)
            gain=float(volume);gain=max(0.,min(1.,gain)) if math.isfinite(gain) else .5
            with tempfile.TemporaryFile() as errors:
                result=subprocess.run([player,'--volume',str(gain),'--sample-count',str(frames),'--',f'/proc/self/fd/{data.fileno()}'],
                    stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=errors,pass_fds=(data.fileno(),),timeout=7,check=False)
            if result.returncode:
                return {'available':False,'state':'error','message':'Sound playback failed. Check the PipeWire connection and audio output.'}
            return {'available':True,'state':'played','message':'Notification sound completed.'}
    except subprocess.TimeoutExpired:
        return {'available':False,'state':'error','message':'Sound playback timed out after 7 seconds.'}
    except (OSError,ValueError,wave.Error,EOFError) as error:
        message=str(error) if isinstance(error,ValueError) else 'The local PCM WAV could not be read.'
        return {'available':False,'state':'error','message':message}


if __name__=='__main__':
    # Raising through subprocess.run terminates/reaps its child on cancellation.
    signal.signal(signal.SIGTERM,lambda signum,frame: sys.exit(0))
    print(json.dumps(run(sys.argv[1] if len(sys.argv)>1 else 'check',sys.argv[2] if len(sys.argv)>2 else '',sys.argv[3] if len(sys.argv)>3 else .5)))
