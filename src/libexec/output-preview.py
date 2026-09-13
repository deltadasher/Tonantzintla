"""Session-only Niri scale previews with an independent rollback watchdog.

Never writes compositor configuration. One preview at a time per user runtime.
"""
import fcntl
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


def runtime():
    base = Path(os.environ['XDG_RUNTIME_DIR'])
    if base.stat().st_uid != os.getuid():
        raise ValueError('Runtime directory belongs to another user.')
    folder = base / 'tonantzintla-output-preview'
    folder.mkdir(mode=0o700, exist_ok=True)
    if folder.is_symlink() or folder.stat().st_uid != os.getuid() or folder.stat().st_mode & 0o077:
        raise ValueError('Unsafe preview directory permissions.')
    return folder


def command(*args):
    result = subprocess.run(['niri', 'msg', *args], capture_output=True, text=True, timeout=5)
    if result.returncode:
        raise ValueError((result.stderr or result.stdout).strip()[-800:])
    return result.stdout


def outputs():
    return json.loads(command('--json', 'outputs'))


def scale_of(items, name):
    value = (items.get(name, {}).get('logical') or {}).get('scale')
    if value is None or not math.isfinite(float(value)) or float(value) <= 0:
        raise ValueError('Selected display is disconnected or inactive.')
    return float(value)


def write_state(folder, state):
    with tempfile.NamedTemporaryFile(mode='w', dir=folder, delete=False) as handle:
        json.dump(state, handle)
        temp = Path(handle.name)
    os.replace(temp, folder / 'state.json')


def state_of(folder):
    try:
        return json.loads((folder / 'state.json').read_text())
    except FileNotFoundError:
        return {'phase': 'idle'}


def preview(name, scale, seconds=15):
    if not math.isfinite(scale) or scale not in (1, 1.25, 1.5, 1.75, 2):
        raise ValueError('Choose a supported scale from 100% to 200%.')
    folder = runtime()
    with (folder / 'watchdog.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError('A display preview is already running.')
        original = scale_of(outputs(), name)
        token = os.urandom(16).hex()
        state = dict(phase='applying', output=name, original=original, scale=scale, token=token)
        write_state(folder, state)
        changed = False
        try:
            # Set before dispatch: a timed-out IPC might nevertheless have applied.
            changed = True
            command('output', name, 'scale', str(scale))
            if abs(scale_of(outputs(), name) - scale) > 0.01:
                raise ValueError('Niri did not report the requested scale.')
            state.update(phase='preview', deadline=time.monotonic() + seconds)
            write_state(folder, state)
            while time.monotonic() < state['deadline']:
                receipt = folder / 'keep'
                if receipt.exists() and receipt.read_text() == token:
                    if abs(scale_of(outputs(), name) - scale) > 0.01:
                        raise ValueError('Display settings changed during preview.')
                    changed = False
                    state.update(phase='kept', message='Kept for this session only. Niri configuration was not changed.')
                    return
                time.sleep(0.1)
            state.update(phase='reverted', message='Preview expired; previous scale restored.')
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            state.update(phase='failed', message=str(error))
        finally:
            if changed:
                try:
                    current = scale_of(outputs(), name)
                    if abs(current - scale) <= 0.01:
                        command('output', name, 'scale', str(original))
                        if abs(scale_of(outputs(), name) - original) > 0.01:
                            raise ValueError('Niri did not confirm the restored scale.')
                    else:
                        state.update(phase='changed', message='Another change replaced the preview; left it untouched.')
                except (OSError, ValueError, subprocess.SubprocessError) as error:
                    state.update(phase='failed', message='Could not confirm rollback: ' + str(error))
            write_state(folder, state)


def keep(token):
    folder = runtime()
    state = state_of(folder)
    if state.get('phase') != 'preview' or state.get('token') != token or time.monotonic() >= state['deadline']:
        raise ValueError('Preview expired or was replaced.')
    (folder / 'keep').write_text(token)


def inspect():
    items = outputs()
    result = []
    for name, item in items.items():
        logical = item.get('logical')
        if logical:
            result.append(dict(name=name, scale=logical.get('scale'),
                               width=logical.get('width'), height=logical.get('height')))
    return dict(outputs=result, preview=state_of(runtime()))


if __name__ == '__main__':
    try:
        if len(sys.argv) == 4 and sys.argv[1] == 'preview':
            preview(sys.argv[2], float(sys.argv[3]))
        elif len(sys.argv) == 3 and sys.argv[1] == 'keep':
            keep(sys.argv[2])
        print(json.dumps(inspect()))
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(json.dumps(dict(error=str(error))))
        sys.exit(1)
