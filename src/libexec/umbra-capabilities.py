#!/usr/bin/env python3
"""Bounded Umbra loop preparation and read-only fingerprint capability checks."""
import argparse
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from urllib.parse import unquote, urlparse


def local_path(value):
    if value.startswith('file:'):
        parsed = urlparse(value)
        if parsed.netloc not in ('', 'localhost'):
            raise ValueError('Choose a local file')
        value = unquote(parsed.path)
    path = Path(value).expanduser()
    if not path.is_absolute() or not path.is_file():
        raise ValueError('Choose an existing local file')
    return path


def inspect_media(value):
    path = local_path(value)
    if not shutil.which('ffprobe'):
        raise ValueError('Video preview requires ffprobe; using the still background')
    result = subprocess.run(['ffprobe', '-v', 'error', '-protocol_whitelist', 'file,pipe', '-select_streams', 'v:0',
        '-show_entries', 'stream=width,height,avg_frame_rate', '-of', 'json', str(path)],
        capture_output=True, text=True, timeout=5, check=True)
    data = json.loads(result.stdout)
    stream = data['streams'][0]
    width, height = int(stream['width']), int(stream['height'])
    rate = str(stream.get('avg_frame_rate', '0/1')).split('/')
    fps = float(rate[0]) / max(1, float(rate[1] if len(rate) > 1 else 1))
    if not 0 < width <= 1280 or not 0 < height <= 720 or not math.isfinite(fps) or not 0 < fps <= 30:
        raise ValueError('Use a video at most 1280 × 720 and 30 fps; using the still background')
    return {'available': True, 'width': width, 'height': height, 'path': path.as_uri(),
            'message': 'Video verified · up to 720p / 30 fps'}



LOOP_MAX_BYTES = 12 * 1024 * 1024
CACHE_MAX_BYTES = 48 * 1024 * 1024
CACHE_MAX_FILES = 4
LOOP_VERSION = 'gif-640x360-12fps-8s-v1'


def video_identity(path):
    stat = path.stat()
    return (str(path.resolve()), stat.st_mtime_ns, stat.st_size, stat.st_ctime_ns)


def prune_loops(directory, reserve=False):
    files = sorted(directory.glob('*.gif'), key=lambda path: path.stat().st_mtime_ns, reverse=True)
    count = 0
    total = LOOP_MAX_BYTES if reserve else 0
    for path in files:
        size = path.stat().st_size
        if size > LOOP_MAX_BYTES or count >= CACHE_MAX_FILES - int(reserve) or total + size > CACHE_MAX_BYTES:
            path.unlink()
        else:
            count += 1
            total += size


def prepare_video(value):
    path = local_path(value)
    identity = video_identity(path)
    metadata = inspect_media(value)  # Fresh probe even if a prepared loop exists.
    if video_identity(path) != identity:
        raise ValueError('Video changed during validation; try again')
    cache = Path(os.environ.get('XDG_CACHE_HOME', str(Path.home() / '.cache'))) / 'tonantzintla/umbra-loops'
    cache.mkdir(parents=True, exist_ok=True, mode=0o700)
    key = hashlib.sha256(json.dumps([LOOP_VERSION, identity]).encode()).hexdigest()
    target = cache / (key + '.gif')
    with (cache / '.prepare.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise ValueError('Another loop is preparing; try playback again shortly') from error
        for stale in cache.glob('*.partial'):
            stale.unlink()
        prune_loops(cache)
        cached = target.is_file() and 6 < target.stat().st_size <= LOOP_MAX_BYTES
        if not cached:
            if not shutil.which('ffmpeg'):
                raise ValueError('Preparing a video loop requires ffmpeg; using the still background')
            prune_loops(cache, reserve=True)
            handle, temporary = tempfile.mkstemp(dir=cache, suffix='.partial')
            os.close(handle)
            try:
                subprocess.run(['ffmpeg', '-v', 'error', '-nostdin', '-y',
                    '-threads', '1', '-filter_threads', '1', '-filter_complex_threads', '1',
                    '-protocol_whitelist', 'file,pipe', '-i', str(path),
                    '-t', '8', '-an', '-sn', '-dn', '-map', '0:v:0',
                    '-vf', 'fps=12,scale=640:360:force_original_aspect_ratio=decrease:flags=bilinear',
                    '-threads', '1', '-loop', '0', '-fs', str(LOOP_MAX_BYTES), '-f', 'gif', temporary],
                    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=25, check=True)
                output = Path(temporary)
                if not 6 < output.stat().st_size <= LOOP_MAX_BYTES:
                    raise ValueError('Video loop exceeds the cache budget; use a simpler clip')
                if video_identity(path) != identity:
                    raise ValueError('Video changed during preparation; try again')
                output.replace(target)
            finally:
                Path(temporary).unlink(missing_ok=True)
        else:
            target.touch()
        prune_loops(cache)
    return dict(metadata, path=target.as_uri(), prepared=True, cached=cached,
        message='Silent loop · first 8 seconds · up to 640 × 360 / 12 fps')

def profile_uses_fingerprint(profile, root=Path('/etc/pam.d'), seen=None):
    if not re.fullmatch(r'[A-Za-z0-9_.-]{1,80}', profile):
        return False
    seen = set() if seen is None else seen
    if profile in seen or len(seen) >= 8:
        return False
    seen.add(profile)
    try:
        with (root / profile).open() as source:
            text = source.read(65536)
    except OSError:
        return False
    for raw in text.splitlines():
        line = raw.split('#', 1)[0].strip()
        if re.search(r'\bpam_fprintd\.so\b', line) and re.match(r'^-?auth\s', line):
            return True
        match = re.match(r'^(?:-?auth\s+(?:include|substack)|@include)\s+([\w.-]+)', line)
        if match and profile_uses_fingerprint(match[1], root, seen):
            return True
    return False


def fingerprint(profile):
    if not profile_uses_fingerprint(profile):
        raise ValueError('Choose an existing PAM profile with pam_fprintd; password remains available')
    module_roots = [Path('/usr/lib/security'), Path('/usr/lib64/security'), Path('/lib/security')]
    module_roots += list(Path('/usr/lib').glob('*/security')) + list(Path('/lib').glob('*/security'))
    if not any((directory / 'pam_fprintd.so').is_file() for directory in module_roots):
        raise ValueError('Fingerprint PAM module is unavailable; use password')
    if not shutil.which('gdbus'):
        raise ValueError('Fingerprint capability check unavailable; use password')
    def call(path, method, *args):
        return subprocess.run(['gdbus', 'call', '--system', '--dest', 'net.reactivated.Fprint',
            '--object-path', path, '--method', method, *args], capture_output=True,
            text=True, timeout=4, check=True).stdout
    devices = call('/net/reactivated/Fprint/Manager', 'net.reactivated.Fprint.Manager.GetDevices')
    paths = re.findall(r"'(/net/reactivated/Fprint/Device/[^']+)'", devices)
    for device in paths[:4]:
        enrolled = call(device, 'net.reactivated.Fprint.Device.ListEnrolledFingers', os.environ.get('USER', ''))
        if re.search(r"'(?:left|right)-[a-z-]+'", enrolled):
            return {'available': True, 'message': 'Enrolled fingerprint and existing PAM profile found'}
    raise ValueError('No enrolled fingerprint reader found; use password')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('kind', choices=['video', 'fingerprint'])
    parser.add_argument('value')
    args = parser.parse_args()
    try:
        result = prepare_video(args.value) if args.kind == 'video' else fingerprint(args.value)
    except (ValueError, OSError, subprocess.SubprocessError, KeyError, IndexError, json.JSONDecodeError) as error:
        message = str(error) if isinstance(error, ValueError) else 'Capability check failed; using the safe fallback'
        result = {'available': False, 'message': message}
    print(json.dumps(result))

if __name__ == '__main__':
    main()
