#!/usr/bin/env python3
"""Create the still fallback from gravity-scene.js's 3D equations using NumPy.

This is CPU asset production. It neither compiles GLSL nor validates a browser GPU.
SPDX-License-Identifier: GPL-3.0-or-later
"""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image


def smooth(a, b, x):
    t = np.clip((x-a)/(b-a), 0, 1)
    return t*t*(3-2*t)


def normalize(v):
    return v / np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-8)


def turn(pair, angle):
    s, c = np.sin(angle), np.cos(angle)
    return np.stack([c*pair[..., 0]+s*pair[..., 1], -s*pair[..., 0]+c*pair[..., 1]], axis=-1)


def stream(p):
    angle = np.arctan2(p[..., 2], p[..., 0])
    radial = np.linalg.norm(p[..., [0,2]], axis=-1)
    wave = np.sin(angle*3+.65)*.055 + np.sin(angle*5-.8)*.025
    rise = .78*.5*(np.sqrt(p[..., 2]**2+.035)-p[..., 2])
    center = 1.47+wave+np.sin(angle+1.2)*.10
    width = .26+.06*np.sin(angle*2-.7)
    height = .025+.012*(.5+.5*np.cos(angle*3))
    y = p[..., 1]+.19-rise-np.sin(angle*2)*.035
    q = np.stack([np.abs(radial-center)-width+.02, np.abs(y)-height+.02], axis=-1)
    slab = np.linalg.norm(np.maximum(q,0),axis=-1)+np.minimum(np.max(q,axis=-1),0)-.02
    lower = np.hypot((radial-1.16)*.70,p[..., 1]+.69)-.027
    lower = np.maximum(lower,.35-p[..., 2])
    lower = np.maximum(lower,-.35-p[..., 0])
    return np.minimum(slab,lower)


def render(width, height):
    ro = np.array([0.,1.35,5.35],dtype=np.float32)
    ro[1:]=turn(ro[1:],-.06)
    ro[[0,2]]=turn(ro[[0,2]],-.16)
    target=np.array([0.,.12,0.],dtype=np.float32)
    fw=normalize(target-ro)
    right=normalize(np.cross(fw,[0.,1.,0.]))
    up=np.cross(right,fw)
    amber=np.array([1.,.58,.23]); pale=np.array([1.,.88,.65]); violet=np.array([.60,.55,.78])
    result=np.empty((height,width,3),dtype=np.uint8)
    for row in range(0,height,40):
        rows=min(40,height-row)
        yy,xx=np.mgrid[row:row+rows,0:width]
        screen=np.stack([((xx+.5)/width-.5)*(width/height), .5-(yy+.5)/height],axis=-1).astype(np.float32)
        rd=normalize(fw*2.95+right*screen[...,0,None]*2+up*screen[...,1,None]*2).astype(np.float32)
        oc=ro-np.array([.035,.15,0.])
        b=np.sum(oc*rd,axis=-1); c=np.sum(oc*oc)-.83*.83; hs=b*b-c
        horizon=np.where(hs<0,100,np.maximum(0,-b-np.sqrt(np.maximum(hs,0))))
        b=np.sum(ro*rd,axis=-1); h=b*b-np.sum(ro*ro)+2.55*2.55
        t=np.maximum(0,-b-np.sqrt(np.maximum(h,0)))
        end=np.minimum(-b+np.sqrt(np.maximum(h,0)),horizon)
        glow=np.zeros_like(t); hit=np.zeros_like(t,dtype=bool); active=h>=0
        p=ro+rd*t[...,None]
        for _ in range(96):
            p=ro+rd*t[...,None]
            d=stream(p)
            glow+=np.where(active,np.exp(-np.abs(d)*22)*.005,0)
            hit |= active & (d<.0045)
            active &= ~hit
            t+=np.where(active,np.maximum(d*.76,.009),0)
            active &= t<=end
            if not np.any(active): break
        p=ro+rd*t[...,None]
        bg=np.zeros_like(rd)+[.0431,.0431,.0510]
        ambient=np.exp(-np.sum((screen*[.7,1])**2,axis=-1)*3)
        bg+=ambient[...,None]*[.014,.009,.008]
        rgb=bg+amber*glow[...,None]*.36
        tc=np.array([.035,.15,0.])-ro
        impact=np.linalg.norm(tc-np.sum(tc*rd,axis=-1)[...,None]*rd,axis=-1)
        halo=np.exp(-np.abs(impact-.846)*42)
        rgb+=(amber*.78+violet*.22)*halo[...,None]*.20
        rgb=np.where((horizon<100)[...,None], np.array([.004,.004,.006])+amber*halo[...,None]*.055, rgb)
        a=np.arctan2(p[...,2],p[...,0]); r=np.linalg.norm(p[..., [0,2]],axis=-1)
        normals=[]
        for i in range(3):
            e=np.zeros(3); e[i]=.006
            normals.append(stream(p+e)-stream(p-e))
        n=normalize(np.stack(normals,axis=-1))
        light=normalize(np.array([-1.5,3.,-1.8]))
        diffuse=.26+.74*np.maximum(np.sum(n*light,axis=-1),0)
        fresnel=(1-np.abs(np.sum(n*-rd,axis=-1)))**2
        shear=a
        turbulence=np.sin(a*3+r*7)*.012+np.sin(a*7-r*5)*.008
        lanes=(.5+.5*np.sin((r+turbulence)*112+np.sin(shear*3)*1.3))**10
        fine=.5+.5*np.sin(r*357+a*6+np.sin(a*9)*2)
        mottled=.5+.5*np.sin(r*38+a*5+np.sin(a*11+r*6))
        temp=np.clip((1.9-r)*.95,0,1)
        blend=.30+mottled*.24
        base=np.array([.18,.075,.025])*(1-blend[...,None])+amber*blend[...,None]
        base=base*(1-temp[...,None]*.45)+pale*temp[...,None]*.45
        doppler=.55+.45*(.5+.5*np.sin(a-.6))**2
        material=base*(diffuse*.72+lanes*.58+fine*.085)[...,None]*doppler[...,None]
        material+=pale*(lanes*temp*.36)[...,None]+amber*(fresnel*.19)[...,None]+amber*glow[...,None]*.12
        polished=np.maximum(np.sum(n*normalize(light-rd),axis=-1),0)**16
        material+=pale*polished[...,None]*.72
        material=1-np.exp(-material*1.65)
        rgb=np.where((hit & (t<end))[...,None],material,rgb)
        vignette=1-smooth(.45,1.10,np.linalg.norm(screen,axis=-1))
        rgb=bg*(1-vignette[...,None])+rgb*vignette[...,None]
        grain=np.mod(np.sin((xx+.5)*12.9898+(height-yy-.5)*78.233)*43758.5453,1)
        rgb+=(grain[...,None]-.5)/255
        result[row:row+rows]=np.uint8(np.clip(rgb*255,0,255))
    return Image.fromarray(result)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--width',type=int,default=1440)
    parser.add_argument('--height',type=int,default=900)
    parser.add_argument('--supersample',type=float,default=1.5)
    parser.add_argument('--output',type=Path,default=Path('docs/assets/gravity-study.webp'))
    args=parser.parse_args()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    image=render(round(args.width*args.supersample),round(args.height*args.supersample))
    image.resize((args.width,args.height),Image.Resampling.LANCZOS).save(args.output,quality=92,method=6)
    print(f'CPU-rendered still asset: {args.output} ({args.width} × {args.height})')
