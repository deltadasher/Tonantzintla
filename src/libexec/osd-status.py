#!/usr/bin/env python3
"""Read actual keyboard LED/radio state once. Missing interfaces stay unsupported."""
import argparse
import json
from pathlib import Path


def bit(path):
    value=path.read_text().strip()
    if value not in ('0','1'):raise ValueError('Unsupported hardware state')
    return value=='1'

def read_status(root=Path('/sys')):
    result={}
    for kind in ('capslock','numlock'):
        values=[]
        for led in list((root/'class/leds').glob('*::'+kind))[:64]:
            try:values.append(bit(led/'brightness'))
            except (OSError,ValueError):pass
        result[kind]={'supported':bool(values) and all(value==values[0] for value in values),'enabled':bool(values and values[0])}
    radios=[]
    for radio in list((root/'class/rfkill').glob('rfkill*'))[:64]:
        try:
            if (radio/'type').read_text().strip() in ('wlan','bluetooth','wwan'):
                radios.append(bit(radio/'soft') or bit(radio/'hard'))
        except (OSError,ValueError):pass
    result['airplane']={'supported':bool(radios),'enabled':bool(radios) and all(radios)}
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--sys-root',type=Path,default=Path('/sys'))
    print(json.dumps(read_status(parser.parse_args().sys_root)))

if __name__=='__main__':main()
