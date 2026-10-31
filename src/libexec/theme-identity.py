#!/usr/bin/env python3
"""The greeter's read-only adapter for the shell's shared identity registry."""
import json
from pathlib import Path

REGISTRY = Path(__file__).resolve().parents[1] / 'quickshell/components/ThemeIdentities.js'
PRESETS = dict(violet='#9874cd', cyan='#83dad9', rose='#ee927f', amber='#e9b872', emerald='#467b50', solar='#c44f28', silver='#c8cdd3')


def identities():
    # The data file deliberately contains a single JSON-compatible assignment.
    return json.loads(REGISTRY.read_text().partition('var identities = ')[2].strip().removesuffix(';'))


def valid_color(value):
    import re
    return isinstance(value, str) and re.fullmatch(r'#[0-9a-fA-F]{6}', value) is not None


def channels(color):
    return [int(color[i:i+2], 16) / 255 for i in (1, 3, 5)]


def lab(color):
    rgb = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in channels(color)]
    l = (.4122214708*rgb[0]+.5363325363*rgb[1]+.0514459929*rgb[2])**(1/3)
    m = (.2119034982*rgb[0]+.6806995451*rgb[1]+.1073969566*rgb[2])**(1/3)
    s = (.0883024619*rgb[0]+.2817188376*rgb[1]+.6299787005*rgb[2])**(1/3)
    return (.2104542553*l+.793617785*m-.0040720468*s,
            1.9779984951*l-2.428592205*m+.4505937099*s,
            .0259040371*l+.7827717662*m-.808675766*s)


def match(color, marks=None):
    marks = marks or identities()
    lookup = {mark['id']: mark for mark in marks}
    if not valid_color(color):
        return lookup['wabi-sabi']
    for mark in marks:
        if color.lower() == mark['color'].lower():
            return mark
    rgb = channels(color)
    if max(rgb)-min(rgb) < .10:
        brightness = sum(a*b for a,b in zip(rgb, (.299,.587,.114)))
        name = 'ink' if brightness < .14 else 'cloud' if brightness < .58 else 'moon' if brightness < .91 else 'snowflake'
        return lookup[name]
    target = lab(color)
    return min(marks[:10], key=lambda mark: sum(w*(a-b)**2 for w,a,b in zip((.35,1,1),target,lab(mark['color']))))


def resolve(settings, source_color=''):
    marks = identities()
    lookup = {mark['id']: mark for mark in marks}
    selection = settings.get('themeIdentity', 'wabi-sabi')
    if selection != 'auto' and selection not in lookup: selection = 'wabi-sabi'
    spectral = settings.get('spectralColors', {})
    exact = spectral.get('accent', '') if isinstance(spectral, dict) else ''
    seed = settings.get('paletteSeedColor', '')
    fallback = source_color if valid_color(source_color) else PRESETS.get(settings.get('accentName', 'violet'), '#e9b872')
    color = next((c for c in (exact,seed,fallback) if valid_color(c)), '#e9b872')
    mark = match(color,marks) if selection == 'auto' else lookup.get(selection,lookup['wabi-sabi'])
    mode = settings.get('themeMode', 'auto')
    if mode not in ('light','dark'):
        if selection != 'auto' and selection != 'wabi-sabi':
            mode = 'light' if mark['light'] else 'dark'
        elif valid_color(exact) or valid_color(seed):
            rgb = channels(exact if valid_color(exact) else seed)
            mode = 'dark' if sum(a*b for a,b in zip(rgb,(.299,.587,.114))) >= .5 else 'light'
        else:
            mode = 'light' if mark['light'] else 'dark'
    return mark, mode
