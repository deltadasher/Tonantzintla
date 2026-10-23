#!/usr/bin/env python3
"""Requested Quickshell renderer and render-loop policy; no driver probe or running-state claim."""
import argparse
import os
from pathlib import Path
import sys
import stat
import tempfile

BACKENDS = ('opengl', 'vulkan')
PREFERENCES = ('auto',) + BACKENDS
MANAGED_KEY = 'TONANTZINTLA_QSG_RHI_BACKEND'
POLICIES = {
    'graphics': ('graphics-backend', 'QSG_RHI_BACKEND', MANAGED_KEY, BACKENDS, 'renderer', 'backend'),
    'render-loop': ('render-loop', 'QSG_RENDER_LOOP', 'TONANTZINTLA_QSG_RENDER_LOOP',
                    ('basic', 'threaded'), 'render loop', 'render-loop'),
}


def preference_path(environ=None, *, policy='graphics'):
    env = os.environ if environ is None else environ
    config = env.get('XDG_CONFIG_HOME') or str(Path(env.get('HOME') or Path.home()) / '.config')
    return Path(config) / 'tonantzintla' / POLICIES[policy][0]


def read_preference(environ=None, *, policy='graphics'):
    """Accept one bounded literal; malformed/unreadable preferences use auto."""
    path = preference_path(environ, policy=policy)
    try:
        descriptor = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
        try:
            if not stat.S_ISREG(os.fstat(descriptor).st_mode):
                return {'requested': 'auto', 'valid': False, 'detail': 'invalid nonregular preference ignored'}
            raw = os.read(descriptor, 33)
        finally:
            os.close(descriptor)
    except FileNotFoundError:
        return {'requested': 'auto', 'valid': True, 'detail': 'default (no preference file)'}
    except OSError:
        return {'requested': 'auto', 'valid': False, 'detail': 'unreadable preference ignored'}
    for value in ('auto',) + POLICIES[policy][3]:
        if raw in (value.encode(), (value+'\n').encode(), (value+'\r\n').encode()):
            return {'requested': value, 'valid': True, 'detail': 'saved preference'}
    return {'requested': 'auto', 'valid': False, 'detail': 'invalid preference ignored'}


def write_preference(value, environ=None, *, policy='graphics'):
    """Replace only the preference file; never launch or restart the shell."""
    if value not in ('auto',) + POLICIES[policy][3]:
        raise ValueError('Expected '+', '.join(('auto',) + POLICIES[policy][3]))
    path = preference_path(environ, policy=policy)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='ascii', prefix='.'+path.name+'-',
                                         dir=path.parent, delete=False) as handle:
            temporary = Path(handle.name)
            os.fchmod(handle.fileno(), 0o600)
            handle.write(value+'\n')
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def explicit_environment(environ):
    """Remove only a still-matching renderer value that this policy supplied."""
    result = dict(environ)
    for _filename, key, marker, values, _label, _automatic in POLICIES.values():
        managed = result.pop(marker, None)
        if managed in values and result.get(key) == managed:
            result.pop(key, None)
    return result


def quickshell_environment(environ=None):
    """Return a new child environment; an explicit Qt override always wins."""
    inherited = os.environ if environ is None else environ
    result = explicit_environment(inherited)
    for policy, (_filename, key, marker, values, _label, _automatic) in POLICIES.items():
        if key not in result:
            requested = read_preference(inherited, policy=policy)['requested']
            if requested in values:
                result[key] = requested
                result[marker] = requested
    return result


def status(environ=None, *, policy='graphics'):
    inherited = os.environ if environ is None else environ
    preference = read_preference(inherited, policy=policy)
    explicit = explicit_environment(inherited)
    child = quickshell_environment(inherited)
    _filename, key, _marker, _values, label, automatic = POLICIES[policy]
    print('Requested: '+preference['requested']+' ('+preference['detail']+')')
    if key in explicit:
        print('Next start: explicit '+key+'='+repr(explicit[key])+' takes precedence')
    elif key in child:
        print('Next start: '+child[key]+' requested for Quickshell')
    else:
        print('Next start: Qt automatic '+automatic+' selection')
    print('Running '+label+': not inspected. Changes take effect on the next shell start.')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--policy', choices=tuple(POLICIES), default='graphics')
    parser.add_argument('action')
    parser.add_argument('arguments', nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    if args.action == 'launch' and args.policy == 'graphics':
        command = args.arguments
        if command[:1] == ['--']:
            command = command[1:]
        if not command or command[0] != 'qs':
            parser.error('launch is restricted to the Quickshell child')
        os.execvpe('qs', command, quickshell_environment())
        return
    if args.action not in ('status', 'auto') + POLICIES[args.policy][3]:
        parser.error('invalid '+args.policy+' action')
    if args.arguments:
        parser.error('unexpected arguments')
    try:
        if args.action != 'status':
            write_preference(args.action, policy=args.policy)
        status(policy=args.policy)
    except OSError as error:
        print('Could not save '+args.policy+' preference: '+str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
