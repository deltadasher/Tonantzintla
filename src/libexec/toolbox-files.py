#!/usr/bin/env python3
"""Bounded single-directory listing; no recursive indexing or shell commands."""
import argparse
import json
import os
from pathlib import Path


def list_directory(path, show_hidden=False):
    root=Path(path).expanduser().resolve(strict=True)
    if not root.is_dir(): raise ValueError('Choose a directory.')
    entries=[]
    truncated=False
    with os.scandir(root) as iterator:
        for entry in iterator:
            if not show_hidden and entry.name.startswith('.'): continue
            if len(entries)>=500:
                truncated=True
                break
            try:
                directory=entry.is_dir()
                entries.append({'name':entry.name,'path':str(root/entry.name),'directory':directory})
            except OSError:
                continue
    entries.sort(key=lambda entry:(not entry['directory'],entry['name'].casefold()))
    return {'ok':True,'path':str(root),'parent':str(root.parent),'entries':entries,'truncated':truncated}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('path');parser.add_argument('--hidden',action='store_true')
    args=parser.parse_args()
    try: result=list_directory(args.path,args.hidden)
    except (OSError,ValueError) as error:result={'ok':False,'error':str(error),'entries':[]}
    print(json.dumps(result,ensure_ascii=False))

if __name__=='__main__':main()
