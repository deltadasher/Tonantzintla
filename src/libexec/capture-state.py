#!/usr/bin/env python3
"""Own one portal recorder until it finishes; never infer recording from a PID.

The short-lived supervisor exists only during a requested recording. First-frame
confirmation uses GPU Screen Recorder's documented .ts sidecar when supported.
Older versions remain pending (with an explicit explanation) until completion.
"""
from __future__ import annotations

import argparse
import fcntl
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import uuid

ACTIVE = {'pending', 'recording', 'finalizing'}


def state_root():
    return Path(os.environ.get('XDG_STATE_HOME') or Path.home() / '.local/state') / 'tonantzintla'


def stop_path():
    return state_root() / 'capture.stop'


def owner_start(pid):
    try:
        # The comm field may contain spaces and parentheses; fields after it
        # begin with process state, and starttime is field 22.
        return Path(f'/proc/{int(pid)}/stat').read_text().rsplit(')', 1)[1].split()[19]
    except (OSError, ValueError, IndexError):
        return ''


def write_state(state):
    root = state_root()
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', dir=root, delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(state, stream)
        os.replace(temporary, root / 'capture.json')
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def read_status():
    try:
        state = json.loads((state_root() / 'capture.json').read_text())
        if not isinstance(state, dict):
            raise ValueError('Invalid capture state')
    except (OSError, ValueError):
        return {'state': 'idle', 'message': 'Ready to choose a portal target', 'output': ''}
    if state.get('state') in ACTIVE:
        expected = state.get('ownerStart', '')
        if not expected or owner_start(state.get('ownerPid', 0)) != expected:
            return dict(state, state='error', message='Capture supervisor ended; the recording was not confirmed saved.')
    return state


def request_stop():
    state = read_status()
    if state.get('state') in {'pending', 'recording'}:
        # Only our live owner observes this token. Never signal a PID read from
        # a file, which might have been reused by an unrelated process.
        stop_path().write_text(state['token'])
    return state


def recorder_command(output, fps, desktop, microphone, pointer, timestamp):
    if fps not in (30, 60):
        raise ValueError('Choose 30 or 60 FPS')
    command = ['gpu-screen-recorder', '-w', 'portal', '-f', str(fps), '-q', 'very_high', '-k', 'h264']
    audio = (['default_output'] if desktop else []) + (['default_input'] if microphone else [])
    if audio:
        command += ['-a', '|'.join(audio)]
    command += ['-cursor', 'yes' if pointer else 'no']
    if timestamp:
        command += ['-write-first-frame-ts', 'yes']
    return command + ['-o', str(output)]


def first_frame(path):
    try:
        rows = path.read_text().splitlines()
        return len(rows) >= 2 and all(int(value) > 0 for value in rows[1].split()[:2]) and len(rows[1].split()) == 2
    except (OSError, ValueError):
        return False


def supervise(args):
    root = state_root()
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (root / 'capture.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        token = uuid.uuid4().hex
        state = {'state': 'pending', 'message': 'Preparing capture', 'output': '',
                 'token': token, 'ownerPid': os.getpid(), 'ownerStart': owner_start(os.getpid()),
                 'countdown': args.countdown}
        def publish(phase, message, **extra):
            state.update(state=phase, message=message, **extra)
            write_state(state)
        def stopped():
            try:
                return stop_path().read_text().strip() == token
            except OSError:
                return False
        stop_path().unlink(missing_ok=True)
        publish('pending', 'Preparing capture')
        process = None
        try:
            probe = subprocess.run(['gpu-screen-recorder', '--help'], capture_output=True, text=True, timeout=4, check=False)
            timestamp = '-write-first-frame-ts' in probe.stdout + probe.stderr
            deadline = time.monotonic() + args.countdown
            remaining = -1
            while time.monotonic() < deadline:
                if stopped():
                    publish('idle', 'Countdown cancelled', countdown=0)
                    return
                next_remaining = max(1, int(deadline - time.monotonic() + .999))
                if next_remaining != remaining:
                    remaining = next_remaining
                    publish('pending', f'Portal opens in {remaining} seconds', countdown=remaining)
                time.sleep(.1)
            folder = Path.home() / 'Videos/Tonantzintla Captures'
            folder.mkdir(parents=True, exist_ok=True)
            output = folder / (time.strftime('Tonantzintla_%Y-%m-%d-%H%M%S_') + token[:6] + '.mp4')
            sidecar = Path(str(output) + '.ts')
            publish('pending', 'Choose a monitor or window in the desktop portal', output=str(output), countdown=0)
            with (root / 'recording.log').open('wb') as log:
                process = subprocess.Popen(recorder_command(output, args.fps, args.desktop_audio, args.microphone, args.pointer, timestamp), stdout=log, stderr=log)
                captured = False
                stopping = False
                while process.poll() is None:
                    if not stopping and not captured and first_frame(sidecar):
                        captured = True
                        publish('recording', 'Recording', startedAt=time.time())
                    if stopped() and not stopping:
                        stopping = True
                        publish('finalizing', 'Finalizing recording…' if captured else 'Cancelling portal capture…')
                        process.send_signal(signal.SIGINT)
                    if not stopping and not timestamp and not captured and state['message'] != 'Recorder active; this version cannot confirm its first frame. Stop to finish.':
                        publish('pending', 'Recorder active; this version cannot confirm its first frame. Stop to finish.')
                    time.sleep(.1)
                code = process.wait()
            captured = captured or first_frame(sidecar)
            has_file = output.is_file() and output.stat().st_size > 0
            if code == 0 and has_file and (captured or not timestamp):
                publish('saved', 'Recording saved')
                sidecar.unlink(missing_ok=True)
            elif stopping and not captured:
                publish('idle', 'Capture cancelled')
            else:
                publish('error', f'Recorder exited with status {code}; no completed recording was confirmed. See recording.log in the Tonantzintla state folder.')
        except (OSError, ValueError, subprocess.TimeoutExpired) as error:
            publish('error', f'Could not record: {error}')
        finally:
            if process is not None and process.poll() is None:
                process.send_signal(signal.SIGINT)
                # Do not report saved without waiting for normal completion.
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    publish('error', 'Recorder did not finish; check the recording before starting another capture.')
            stop_path().unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['start', 'run', 'stop', 'status'])
    parser.add_argument('--fps', type=int, choices=[30, 60], default=60)
    parser.add_argument('--desktop-audio', choices=['yes', 'no'], default='yes')
    parser.add_argument('--microphone', choices=['yes', 'no'], default='no')
    parser.add_argument('--pointer', choices=['yes', 'no'], default='yes')
    parser.add_argument('--countdown', type=int, choices=[0, 3, 5, 10], default=3)
    args = parser.parse_args()
    if args.action == 'start':
        if read_status().get('state') not in ACTIVE:
            command = [sys.executable, str(Path(__file__).resolve()), 'run'] + sys.argv[2:]
            subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True, close_fds=True)
            # Return only after the supervisor has published a real state.
            for _ in range(20):
                if read_status().get('state') in ACTIVE:
                    break
                time.sleep(.05)
        print(json.dumps(read_status()))
    elif args.action == 'run':
        args.desktop_audio = args.desktop_audio == 'yes'
        args.microphone = args.microphone == 'yes'
        args.pointer = args.pointer == 'yes'
        supervise(args)
    else:
        print(json.dumps(request_stop() if args.action == 'stop' else read_status()))


if __name__ == '__main__':
    main()
