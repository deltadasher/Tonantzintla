#!/usr/bin/env python3
"""On-demand local OCR/QR extraction. Emits one JSON object; never copies or opens.

PNG inputs only, at most 32 MiB / 64 million pixels. Images exist only inside a
private temporary directory and are removed on normal completion, SIGINT/SIGTERM,
errors and timeouts. SIGKILL or power loss cannot guarantee temporary cleanup.
Decoder stdout/stderr are bounded in memory and never logged. QR binary mode
uses zbar's XML base64 payload to avoid its heuristic character-set conversion.
"""
import argparse
import base64
import binascii
import json
import os
from pathlib import Path
import re
import resource
import selectors
import shutil
import signal
import stat
import struct
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET

MAX_IMAGE = 32 * 1024 * 1024
MAX_PIXELS = 64_000_000
MAX_TEXT = 65536
MAX_OUTPUT = 1024 * 1024
LANGUAGE = re.compile(r'[A-Za-z0-9_]{1,64}\Z')


class ExtractError(Exception):
    pass


class Cancelled(Exception):
    pass


def result(kind, state, message='', text='', values=None):
    return dict(kind=kind, state=state, message=message, text=text, values=values or [])


def child_limits():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_FSIZE, (MAX_IMAGE, MAX_IMAGE))
    resource.setrlimit(resource.RLIMIT_AS, (2 * 1024**3, 2 * 1024**3))
    resource.setrlimit(resource.RLIMIT_CPU, (35, 35))


def run_tool(args, timeout=30):
    """Drain both pipes with a combined limit, kill/reap the group on every exit."""
    process = None
    output = [bytearray(), bytearray()]
    try:
        process = subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, start_new_session=True,
                                   preexec_fn=child_limits,
                                   env={**os.environ, 'OMP_THREAD_LIMIT': '2'})
        deadline = time.monotonic() + timeout
        with selectors.DefaultSelector() as selector:
            for index, pipe in enumerate((process.stdout, process.stderr)):
                os.set_blocking(pipe.fileno(), False)
                selector.register(pipe, selectors.EVENT_READ, index)
            while selector.get_map():
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise ExtractError(f'{Path(args[0]).name} timed out. Try a smaller selection.')
                for key, _ in selector.select(min(remaining, .1)):
                    chunk = os.read(key.fileobj.fileno(), 65536)
                    if not chunk:
                        selector.unregister(key.fileobj)
                        continue
                    output[key.data].extend(chunk)
                    if sum(map(len, output)) > MAX_OUTPUT:
                        raise ExtractError('The decoder returned too much data. Try a smaller selection.')
            try:
                code = process.wait(timeout=max(.01, deadline - time.monotonic()))
            except subprocess.TimeoutExpired:
                raise ExtractError(f'{Path(args[0]).name} timed out.') from None
        return code, bytes(output[0]), bytes(output[1])
    except OSError:
        raise ExtractError(f'Could not run {Path(args[0]).name}. Check that it is installed.') from None
    finally:
        if process is not None:
            # Descendants may still exist even when the immediate child has exited.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
            process.stdout.close()
            process.stderr.close()


def user_models():
    base = os.environ.get('XDG_DATA_HOME') or str(Path.home() / '.local/share')
    return Path(base) / 'tonantzintla/ocr'


def languages():
    code, stdout, _ = run_tool(['tesseract', '--list-langs'], timeout=8)
    if code:
        raise ExtractError('Could not read installed OCR languages.')
    try:
        names = {line.strip() for line in stdout.decode('utf-8').splitlines()
                 if LANGUAGE.fullmatch(line.strip()) and line.strip() != 'osd'}
        names.update(path.stem for path in user_models().glob('*.traineddata')
                     if path.is_file() and LANGUAGE.fullmatch(path.stem) and path.stem != 'osd')
    except (UnicodeError, OSError):
        raise ExtractError('Could not read installed OCR languages.') from None
    return sorted(names)


def capabilities():
    tools = {name: bool(shutil.which(name)) for name in ('tesseract', 'zbarimg', 'grim', 'slurp')}
    message = ''
    installed = []
    if tools['tesseract']:
        try:
            installed = languages()
        except ExtractError as error:
            message = str(error)
    return {**result('capabilities', 'ready', message), 'tools': tools, 'languages': installed,
            'defaultLanguage': 'eng' if 'eng' in installed else (installed[0] if installed else ''),
            'ocrAvailable': tools['tesseract'] and bool(installed),
            'qrAvailable': tools['zbarimg'], 'captureAvailable': tools['grim'] and tools['slurp']}


def validate_geometry(raw):
    geometry = raw.strip()
    match = re.fullmatch(r'(-?\d{1,6}),(-?\d{1,6}) (\d{1,5})x(\d{1,5})', geometry)
    if not match:
        raise ExtractError('The selected screen region was invalid.')
    x, y, width, height = map(int, match.groups())
    if abs(x) > 100000 or abs(y) > 100000 or not 0 < width <= 32768 or not 0 < height <= 32768 or width * height > MAX_PIXELS:
        raise ExtractError('The selected screen region is too large or empty.')
    return f'{x},{y} {width}x{height}'


def read_png(path):
    try:
        descriptor = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
        with os.fdopen(descriptor, 'rb') as stream:
            info = os.fstat(stream.fileno())
            if not stat.S_ISREG(info.st_mode) or not 0 < info.st_size <= MAX_IMAGE:
                raise ExtractError('Choose a PNG image smaller than 32 MiB.')
            data = stream.read(MAX_IMAGE + 1)
    except OSError:
        raise ExtractError('The image could not be read.') from None
    if len(data) > MAX_IMAGE or len(data) < 33 or data[:8] != b'\x89PNG\r\n\x1a\n' or data[8:16] != b'\x00\x00\x00\rIHDR':
        raise ExtractError('Choose a valid PNG image smaller than 32 MiB.')
    width, height = struct.unpack('>II', data[16:24])
    if not 0 < width <= 32768 or not 0 < height <= 32768 or width * height > MAX_PIXELS:
        raise ExtractError('The image dimensions are too large or empty.')
    return data


def decode_qr(data):
    if b'<!DOCTYPE' in data.upper() or b'<!ENTITY' in data.upper():
        raise ExtractError('The QR decoder returned malformed data.')
    try:
        root = ET.fromstring(data)
        if root.tag.rsplit('}', 1)[-1] != 'barcodes':
            raise ValueError()
        values = []
        for symbol in root.iter():
            if symbol.tag.rsplit('}', 1)[-1] != 'symbol' or symbol.get('type') != 'QR-Code':
                continue
            nodes = [node for node in symbol if node.tag.rsplit('}', 1)[-1] == 'data']
            if len(nodes) != 1:
                raise ValueError()
            node = nodes[0]
            content = node.text or ''
            if node.get('format') == 'base64':
                raw = base64.b64decode(''.join(content.split()), validate=True)
                if node.get('length') is not None and int(node.get('length')) != len(raw):
                    raise ValueError()
                content = raw.decode('utf-8')
            elif node.get('format'):
                raise ValueError()
            values.append(content)
            if len(values) > 128 or sum(len(value) for value in values) + len(values) - 1 > MAX_TEXT:
                raise ExtractError('Too much QR text. Try a smaller selection.')
        return values
    except (ET.ParseError, ValueError, UnicodeError, binascii.Error):
        raise ExtractError('The QR data is malformed or is not UTF-8 text.') from None


def extract(kind, image, language='eng'):
    try:
        decoder = 'tesseract' if kind == 'ocr' else 'zbarimg'
        needed = [decoder] + ([] if image else ['grim', 'slurp'])
        for tool in needed:
            if not shutil.which(tool):
                raise ExtractError(f'Install {tool} to use this action.')
        if kind == 'ocr' and (not LANGUAGE.fullmatch(language) or language not in languages()):
            raise ExtractError('The selected OCR language is not installed. Choose an installed language.')
        with tempfile.TemporaryDirectory(prefix='tonantzintla-extract-') as folder:
            path = Path(folder) / 'selection.png'
            if image:
                with path.open('xb') as stream:
                    os.chmod(path, 0o600)
                    stream.write(read_png(image))
            else:
                code, stdout, stderr = run_tool(['slurp'], timeout=120)
                if code:
                    if code in (1, 130, -signal.SIGINT) and stderr.strip() in (b'', b'selection cancelled'):
                        return result(kind, 'cancelled', 'Selection cancelled.')
                    raise ExtractError('Screen selection failed. Check the Wayland session.')
                try:
                    geometry = validate_geometry(stdout.decode('ascii'))
                except UnicodeError:
                    raise ExtractError('The selected screen region was invalid.') from None
                # A private parent directory prevents access even before chmod.
                code, _, _ = run_tool(['grim', '-g', geometry, str(path)], timeout=15)
                if code:
                    raise ExtractError('The selected screen region could not be captured.')
                os.chmod(path, 0o600)
                read_png(path)
            if kind == 'ocr':
                command = ['tesseract', str(path), 'stdout', '-l', language, '--psm', '6']
                if (user_models() / (language + '.traineddata')).is_file():
                    command += ['--tessdata-dir', str(user_models())]
                code, stdout, _ = run_tool(command)
                if code:
                    raise ExtractError('Text recognition failed. Check the selected image and OCR language.')
                try:
                    text = stdout.decode('utf-8').strip()
                except UnicodeError:
                    raise ExtractError('Text recognition returned invalid text.') from None
                if len(text) > MAX_TEXT:
                    raise ExtractError('Too much text. Try a smaller selection.')
                values = []
            else:
                code, stdout, _ = run_tool(['zbarimg', '--nodbus', '--quiet', '--xml', '--set', 'disable',
                                           '--set', 'qrcode.enable', '--set', 'qrcode.binary', str(path)])
                if code not in (0, 4):
                    raise ExtractError('QR decoding failed. Check the selected image.')
                values = decode_qr(stdout)
                text = '\n'.join(values)
            found = bool(text) if kind == 'ocr' else bool(values)
            return result(kind, 'ready' if found else 'empty',
                          '' if found else ('No text found.' if kind == 'ocr' else 'No QR codes found.'), text, values)
    except Cancelled:
        return result(kind, 'cancelled', 'Selection cancelled.')
    except ExtractError as error:
        return result(kind, 'error', str(error))
    except OSError:
        return result(kind, 'error', 'Could not prepare the temporary image.')


class JsonParser(argparse.ArgumentParser):
    def error(self, message):
        raise ExtractError('Invalid arguments. Use capabilities, ocr or qr with an optional --image PNG and --language code.')


def main():
    kind = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] in ('ocr', 'qr', 'capabilities') else ''
    def cancel(_signal, _frame):
        raise Cancelled()
    signal.signal(signal.SIGTERM, cancel)
    signal.signal(signal.SIGINT, cancel)
    try:
        parser = JsonParser(description=__doc__)
        parser.add_argument('kind', choices=('capabilities', 'ocr', 'qr'))
        parser.add_argument('--image')
        parser.add_argument('--language', default='eng')
        args = parser.parse_args()
        payload = capabilities() if args.kind == 'capabilities' else extract(args.kind, args.image, args.language)
    except Cancelled:
        payload = result(kind, 'cancelled', 'Selection cancelled.')
    except ExtractError as error:
        payload = result(kind, 'error', str(error))
    print(json.dumps(payload, ensure_ascii=True, separators=(',', ':')))
    return 1 if payload['state'] == 'error' else 0


if __name__ == '__main__':
    sys.exit(main())
