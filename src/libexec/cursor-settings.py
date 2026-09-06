"""Installed Xcursor selection with validated, recoverable Niri config edits."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time


def config_path():
    override = os.environ.get("NIRI_CONFIG")
    # A compositor started with --config overrides its environment.
    for proc in Path('/proc').glob('[0-9]*'):
        try:
            if proc.stat().st_uid != os.getuid() or (proc / 'comm').read_text().strip() != 'niri':
                continue
            args = (proc / 'cmdline').read_bytes().decode().split('\0')
            for i, arg in enumerate(args):
                if arg in ('-c', '--config'):
                    return ((proc / 'cwd').resolve() / Path(args[i + 1]).expanduser()).resolve()
                if arg.startswith('--config='):
                    return ((proc / 'cwd').resolve() / Path(arg.split('=', 1)[1]).expanduser()).resolve()
        except (OSError, UnicodeError, IndexError):
            continue
    return Path(override or Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'niri/config.kdl').expanduser().resolve()


def themes():
    roots = [Path.home() / '.icons', Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share')) / 'icons']
    roots += [Path(p) / 'icons' for p in os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':') if p]
    roots += [Path(p).expanduser() for p in os.environ.get('XCURSOR_PATH', '').split(':') if p]
    names = set()
    for root in roots:
        if root.is_dir():
            for folder in root.iterdir():
                if (folder / 'cursors').is_dir():
                    names.add(folder.name)
    return sorted(names, key=lambda s: (not s.startswith('Bibata-Modern'), s.casefold()))


def mask_kdl(source):
    """Hide strings and comments without changing offsets or line boundaries."""
    chars = list(source)
    i = 0
    while i < len(source):
        start = i
        if source.startswith('//', i):
            i = source.find('\n', i)
            if i < 0:
                i = len(source)
        elif source.startswith('/*', i):
            depth = 1
            i += 2
            while i < len(source) and depth:
                if source.startswith('/*', i):
                    depth += 1
                    i += 2
                elif source.startswith('*/', i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            if depth:
                raise ValueError('Unterminated KDL comment.')
        else:
            raw = re.match(r'(?:r(\#*)|(\#+))"', source[i:])
            if raw:
                ending = '"' + (raw[1] if raw[1] is not None else raw[2])
                end = source.find(ending, i + len(raw[0]))
                if end < 0:
                    raise ValueError('Unterminated raw KDL string.')
                i = end + len(ending)
            elif source[i] == '"':
                i += 1
                while i < len(source) and source[i] != '"':
                    i += 2 if source[i] == '\\' else 1
                if i >= len(source):
                    raise ValueError('Unterminated KDL string.')
                i += 1
            else:
                i += 1
                continue
        for at in range(start, i):
            if chars[at] != '\n':
                chars[at] = ' '
    return ''.join(chars)


def cursor_span(source):
    masked = mask_kdl(source)
    if '/-' in masked:
        raise ValueError('Disabled KDL nodes require a manual cursor edit; config was not changed.')
    if re.search(r'(?m)^\s*include\b', masked):
        raise ValueError('Included Niri configs need a manual cursor edit; config was not changed.')
    depth = 0
    start = None
    spans = []
    for token in re.finditer(r'\bcursor\s*\{|[{}]', masked):
        if token[0].startswith('cursor'):
            if depth == 0:
                start = token.start()
            depth += 1
        elif token[0] == '{':
            depth += 1
        else:
            depth -= 1
            if depth == 0 and start is not None:
                spans.append((start, token.end()))
                start = None
    if depth or len(spans) > 1:
        raise ValueError('Ambiguous cursor block; config was not changed.')
    return spans[0] if spans else None


def update(source, theme, size):
    span = cursor_span(source)
    values = '\n    xcursor-theme ' + json.dumps(theme) + '\n    xcursor-size ' + str(size) + '\n'
    if not span:
        return source + '\ncursor {' + values + '}\n'
    start, end = span
    block = source[start:end]
    # Only remove standalone theme/size lines. Other cursor options survive.
    masked = mask_kdl(block)
    edits = list(re.finditer(r'(?m)^[ \t]*xcursor-(?:theme|size)\s+(?:"(?:\\.|[^"\\])*"|\d+)[ \t]*;?[ \t]*(?://[^\n]*)?\n?', block))
    for match in reversed(edits):
        if masked[match.start():match.end()].lstrip().startswith('xcursor-'):
            block = block[:match.start()] + block[match.end():]
    if re.search(r'\bxcursor-(theme|size)\b', mask_kdl(block)):
        raise ValueError('Put cursor theme and size on separate lines first; config was not changed.')
    return source[:start] + block[:-1].rstrip() + values + '}' + source[end:]


def inspect():
    path = config_path()
    result = dict(themes=themes(), path=str(path), theme='', size=24, hideTyping=False, hideAfter=0, editable=False)
    try:
        source = path.read_text()
        span = cursor_span(source)
        block = source[span[0]:span[1]] if span else ''
        result['hideTyping'] = bool(re.search(r'(?m)^\s*hide-when-typing\b', mask_kdl(block)))
        idle = re.search(r'(?m)^\s*hide-after-inactive-ms\s+(\d+)', mask_kdl(block))
        result['hideAfter'] = int(idle[1]) if idle else 0
        match = re.search(r'(?m)^\s*xcursor-theme\s+("(?:\\.|[^"\\])*")', block)
        if match:
            result['theme'] = json.loads(match[1])
        match = re.search(r'(?m)^\s*xcursor-size\s+(\d+)', block)
        if match:
            result['size'] = int(match[1])
        result['editable'] = bool(shutil.which('niri') and os.access(path, os.W_OK))
        if not result['editable']:
            result['message'] = 'Niri or a writable user configuration is unavailable.'
    except (OSError, ValueError) as error:
        result['message'] = str(error)
    return result


def apply(theme, size, behavior=None):
    if theme not in themes() or not 16 <= size <= 96:
        raise ValueError('Choose an installed cursor theme and a size from 16 to 96.')
    path = config_path()
    source = path.read_text()
    candidate = update(source, theme, size)
    if behavior is not None:
        if not isinstance(behavior, dict) or type(behavior.get('hideTyping')) is not bool or type(behavior.get('hideAfter')) is not int or not 0 <= behavior['hideAfter'] <= 60000:
            raise ValueError('Invalid cursor behavior settings.')
        start, end = cursor_span(candidate)
        block = candidate[start:end]
        masked = mask_kdl(block)
        for match in reversed(list(re.finditer(r'(?m)^[ \t]*(?:hide-when-typing|hide-after-inactive-ms\s+\d+)[ \t]*;?[ \t]*(?://[^\n]*)?\n?', block))):
            if masked[match.start():match.end()].lstrip().startswith('hide-'):
                block = block[:match.start()] + block[match.end():]
        if re.search(r'\bhide-(?:when-typing|after-inactive-ms)\b', mask_kdl(block)):
            raise ValueError('Put cursor behavior options on separate lines first.')
        additions = '\n    hide-when-typing' if behavior['hideTyping'] else ''
        if behavior['hideAfter']:
            additions += '\n    hide-after-inactive-ms ' + str(behavior['hideAfter'])
        candidate = candidate[:start] + block[:-1].rstrip() + additions + '\n}' + candidate[end:]
    staged = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, suffix='.kdl', delete=False) as handle:
            staged = Path(handle.name)
            handle.write(candidate)
        check = subprocess.run(['niri', 'validate', '-c', str(staged)], capture_output=True, text=True, timeout=10)
        if check.returncode:
            raise ValueError('Niri rejected the change: ' + (check.stderr or check.stdout)[-1600:])
        if path.read_text() != source:
            raise ValueError('Config changed during validation. Retry; nothing was overwritten.')
        backup = path.with_name(path.name + '.before-cursor-' + str(time.time_ns()))
        shutil.copy2(path, backup)
        os.chmod(staged, path.stat().st_mode & 0o777)
        os.replace(staged, path)
        result = inspect()
        result['message'] = 'Saved to Niri. Existing apps may need reopening. Backup: ' + str(backup)
        return result
    finally:
        if staged and staged.exists():
            staged.unlink()


if __name__ == '__main__':
    try:
        result = apply(sys.argv[2], int(sys.argv[3]), json.loads(sys.argv[4]) if len(sys.argv) == 5 else None) if len(sys.argv) in (4, 5) and sys.argv[1] == 'apply' else inspect()
        print(json.dumps(result))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(json.dumps(dict(error=str(error))))
        sys.exit(1)
