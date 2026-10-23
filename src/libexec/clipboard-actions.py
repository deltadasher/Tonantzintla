#!/usr/bin/env python3
"""Explicit clipboard actions and private, bounded pins independent of cliphist IDs."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import selectors
import subprocess
import tempfile
import time

MAX_BYTES=1024*1024
MAX_PINS=24
MAX_TOTAL=16*1024*1024

def prepare(root):
    root.mkdir(parents=True,exist_ok=True,mode=0o700)
    root.chmod(0o700)

def manifest(root):
    try:
        data=json.loads((root/'pins.json').read_text())
        if not isinstance(data,list):return []
        return [row for row in data[:MAX_PINS] if isinstance(row,dict) and re.fullmatch(r'[0-9a-f]{64}',str(row.get('key',''))) and (root/row['key']).is_file()]
    except (OSError,ValueError):return []

def write_manifest(root,rows):
    prepare(root)
    with tempfile.NamedTemporaryFile(mode='w',dir=root,delete=False,encoding='utf-8') as stream:
        json.dump(rows,stream,ensure_ascii=False);temp=stream.name
    os.chmod(temp,0o600);os.replace(temp,root/'pins.json')

def save_pin(root,data,kind):
    prepare(root)
    if not data or len(data)>MAX_BYTES:raise ValueError('Pins must contain 1 byte to 1 MiB.')
    rows=manifest(root);key=hashlib.sha256(data).hexdigest()
    if any(row['key']==key for row in rows):return 'pin:'+key
    if len(rows)>=MAX_PINS:raise ValueError('Up to 24 clipboard pins can be saved.')
    if sum((root/row['key']).stat().st_size for row in rows)+len(data)>MAX_TOTAL:raise ValueError('Clipboard pins are limited to 16 MiB in total.')
    target=root/key
    with target.open('wb') as stream:os.chmod(target,0o600);stream.write(data)
    rows.insert(0,{'key':key,'type':'image' if kind=='image' else 'text','size':len(data)})
    write_manifest(root,rows)
    return 'pin:'+key

def key_for(identifier):
    if not re.fullmatch(r'pin:[0-9a-f]{64}',identifier):raise ValueError('Invalid pin identifier.')
    return identifier[4:]

def pin_bytes(root,identifier):
    key=key_for(identifier)
    if not any(row['key']==key for row in manifest(root)):raise ValueError('Pin is no longer available.')
    with (root/key).open('rb') as stream:data=stream.read(MAX_BYTES+1)
    if len(data)>MAX_BYTES:raise ValueError('Pin is too large.')
    return data

def remove_pin(root,identifier):
    key=key_for(identifier)
    write_manifest(root,[row for row in manifest(root) if row['key']!=key])
    (root/key).unlink(missing_ok=True)

def list_pins(root):
    rows=[]
    for row in manifest(root):
        try:data=pin_bytes(root,'pin:'+row['key'])
        except (OSError,ValueError):continue
        image=row.get('type')=='image'
        preview=data.decode('utf-8',errors='replace')[:2048] if not image else str(root/row['key'])
        rows.append({'id':'pin:'+row['key'],'pinned':True,'type':'image' if image else 'text','content':preview,'size':len(data),'search':'pinned image' if image else preview.lower()})
    return rows

def capture(command,limit=MAX_BYTES):
    proc=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
    chunks=[];size=0;deadline=time.monotonic()+8
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(proc.stdout,selectors.EVENT_READ)
            while True:
                if not selector.select(max(0,deadline-time.monotonic())):raise ValueError('Clipboard command timed out.')
                chunk=os.read(proc.stdout.fileno(),min(65536,limit+1-size))
                if not chunk:break
                chunks.append(chunk);size+=len(chunk)
                if size>limit:raise ValueError('Clipboard entry exceeds the size limit.')
        if proc.wait(timeout=max(.1,deadline-time.monotonic()))!=0:raise ValueError('Clipboard command failed.')
        return b''.join(chunks)
    finally:
        if proc.poll() is None:proc.kill()
        proc.wait();proc.stdout.close()

def numeric_id(identifier):
    if not re.fullmatch(r'[0-9]{1,20}',identifier):raise ValueError('Invalid history identifier.')
    return identifier

def delete_entry(identifier):
    identifier=numeric_id(identifier)
    # cliphist delete reads a selected list row from stdin; passing an argv ID
    # exits successfully without deleting on supported cliphist versions.
    listing=capture(['cliphist','list'],2*MAX_BYTES).decode('utf-8',errors='replace')
    row=next((line for line in listing.splitlines() if line.split('\t',1)[0]==identifier),None)
    if row is None:raise ValueError('Clipboard entry is no longer available.')
    subprocess.run(['cliphist','delete'],input=(row+'\n').encode(),check=True,timeout=8)

def copy_history(identifier):
    """Stream ordinary entries through a kernel pipe; only saved pins have a size cap."""
    identifier=numeric_id(identifier)
    decoder=subprocess.Popen(['cliphist','decode',identifier],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
    copier=None
    try:
        copier=subprocess.Popen(['wl-copy'],stdin=decoder.stdout,stderr=subprocess.DEVNULL)
        decoder.stdout.close()
        if decoder.wait(timeout=15)!=0:raise ValueError('Clipboard entry could not be decoded.')
        if copier.wait(timeout=15)!=0:raise ValueError('Clipboard copy failed.')
    finally:
        for proc in (decoder,copier):
            if proc is not None:
                if proc.poll() is None:proc.kill()
                proc.wait()
        if not decoder.stdout.closed:decoder.stdout.close()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['list','pin','unpin','copy','delete','clear'])
    parser.add_argument('root',type=Path);parser.add_argument('identifier',nargs='?',default='');parser.add_argument('--kind',choices=['text','image'],default='text')
    args=parser.parse_args()
    try:
        prepare(args.root)
        with (args.root/'.lock').open('a') as lock:
            os.chmod(args.root/'.lock',0o600);fcntl.flock(lock,fcntl.LOCK_EX)
            if args.action=='pin':save_pin(args.root,capture(['cliphist','decode',numeric_id(args.identifier)]),args.kind)
            elif args.action=='unpin':remove_pin(args.root,args.identifier)
            elif args.action=='delete':
                if args.identifier.startswith('pin:'):remove_pin(args.root,args.identifier)
                else:delete_entry(args.identifier)
            elif args.action=='clear':subprocess.run(['cliphist','wipe'],check=True,timeout=8)
            elif args.action=='copy':
                if args.identifier.startswith('pin:'):
                    subprocess.run(['wl-copy'],input=pin_bytes(args.root,args.identifier),check=True,timeout=8)
                else:copy_history(args.identifier)
            result={'ok':True,'pins':list_pins(args.root)}
    except (OSError,ValueError,subprocess.SubprocessError) as error:result={'ok':False,'error':str(error)}
    print(json.dumps(result,ensure_ascii=False))

if __name__=='__main__':main()
