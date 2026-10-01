#!/usr/bin/env python3
"""Render the still view with gravity-scene.js's curved-light equations.

This is CPU asset production, not GLSL compilation or browser GPU validation.
The shader and this renderer share the camera, velocity-Verlet ray integration,
zero-thickness disk, gas noise, emissivity, optical-depth and tone-map equations.
The saved still adds a mild photographic glare and offline supersampling.
SPDX-License-Identifier: GPL-3.0-or-later
"""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

HORIZON = .72
STEPS = 192


def smooth(a, b, x):
    t = np.clip((x-a)/(b-a), 0, 1)
    return t*t*(3-2*t)


def normalize(v):
    return v/np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-9)


def turn(pair, angle):
    s, c = np.sin(angle), np.cos(angle)
    return np.stack([c*pair[..., 0]+s*pair[..., 1], -s*pair[..., 0]+c*pair[..., 1]], axis=-1)


def fract(x):
    return x-np.floor(x)


def noise(q):
    i, f = np.floor(q), fract(q)
    f = f*f*(3-2*f)

    def hash_value(p):
        p = fract(p*np.array([123.34, 456.21]))
        p += np.sum(p*(p+45.32), axis=-1)[..., None]
        return fract(p[..., 0]*p[..., 1])

    a, b = hash_value(i), hash_value(i+[1, 0])
    c, d = hash_value(i+[0, 1]), hash_value(i+[1, 1])
    return ((a*(1-f[..., 0])+b*f[..., 0])*(1-f[..., 1])
            +(c*(1-f[..., 0])+d*f[..., 0])*f[..., 1])


def gas(q):
    value, weight = np.zeros(q.shape[:-1]), .55
    for _ in range(4):
        value += weight*noise(q)
        # GLSL mat2 is column-major; row-vector NumPy uses its transpose.
        q = q@np.array([[1.6, 1.2], [-1.2, 1.6]])+np.array([4.7, 9.2])
        weight *= .5
    return value


def acceleration(p, momentum):
    radius = np.linalg.norm(p, axis=-1)
    return -1.5*HORIZON*momentum[:, None]*p/np.maximum(radius[:, None]**5, .001)


def trace(screen, yaw, pitch, time):
    ro = np.array([0., 2.32, 12.])
    ro[1:] = turn(ro[1:], pitch)
    ro[[0, 2]] = turn(ro[[0, 2]], yaw)
    forward = normalize(-ro)
    right = normalize(np.cross(forward, [0., 1., 0.]))
    up = np.cross(right, forward)
    velocity = normalize(forward*1.35+right*screen[:, 0, None]+up*screen[:, 1, None])
    p = np.broadcast_to(ro, velocity.shape).copy()
    momentum = np.sum(np.cross(p, velocity)**2, axis=-1)
    radiance, opacity = np.zeros_like(p), np.zeros(len(p))
    active = np.ones(len(p), dtype=bool)
    for _ in range(STEPS):
        ids = np.flatnonzero(active)
        if not len(ids):
            break
        point, v, h2 = p[ids], velocity[ids], momentum[ids]
        radius = np.linalg.norm(point, axis=-1)
        step = .045+.048*radius
        acc = acceleration(point, h2)
        next_point = point+v*step[:, None]+.5*acc*step[:, None]**2
        next_v = v+.5*(acc+acceleration(next_point, h2))*step[:, None]
        crossings = np.flatnonzero(point[:, 1]*next_point[:, 1] < 0)
        if len(crossings):
            start, end = point[crossings], next_point[crossings]
            fraction = np.clip(start[:, 1]/(start[:, 1]-end[:, 1]), 0, 1)
            hit = start+(end-start)*fraction[:, None]
            rad = np.linalg.norm(hit[:, [0, 2]], axis=-1)
            disk = (rad > 2.15) & (rad < 5.4)
            if np.any(disk):
                hit, rad = hit[disk], rad[disk]
                disk_ids = ids[crossings[disk]]
                angle = np.arctan2(hit[:, 2], hit[:, 0])
                edge = smooth(2.15, 2.42, rad)*(1-smooth(3.4, 5.4, rad))
                heat = (2.5/np.maximum(rad, 2.15))**2.7
                shear = angle+rad*.58-time*.035/rad**1.5
                q = np.stack([np.cos(shear), np.sin(shear)], axis=-1)*rad[:, None]*1.8
                cloud = .38+.9*gas(q)
                beaming = (1+.38*(-hit[:, 0]/rad))**3
                emission = np.array([1., .26, .055])*(1-heat[:, None]*.8)+np.array([1., .9, .68])*heat[:, None]*.8
                power = heat*edge*cloud*beaming*1.3
                radiance[disk_ids] += emission*power[:, None]*(1-opacity[disk_ids, None])
                opacity[disk_ids] += (1-opacity[disk_ids])*.88*edge
        p[ids], velocity[ids] = next_point, next_v
        distance = np.linalg.norm(next_point, axis=-1)
        active[ids] = (distance >= HORIZON) & (distance <= 15.5) & (opacity[ids] <= .99)
    return radiance


def render(width, height, yaw=-.16, pitch=-.06, time=0):
    result = np.zeros((height, width, 3), dtype=np.float32)
    for row in range(0, height, 32):
        end = min(height, row+32)
        yy, xx = np.mgrid[row:end, 0:width]
        screen = np.stack([((xx+.5)/width-.5)*(width/height), .5-(yy+.5)/height], axis=-1)
        rgb = trace(screen.reshape(-1, 2), yaw, pitch, time)
        result[row:end] = (1-np.exp(-rgb*.85)).reshape(end-row, width, 3)
    light = Image.fromarray(np.uint8(np.clip(result*255, 0, 255)))
    # Very mild glare from emitted light; never a metallic/specular material.
    for radius, amount in [(height/300, .18), (height/90, .10), (height/30, .05)]:
        result += np.asarray(light.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32)/255*amount
    result = np.maximum(result, np.array([.0431, .0431, .0510]))
    return Image.fromarray(np.uint8(np.clip(result*255, 0, 255)))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--width', type=int, default=1440)
    parser.add_argument('--height', type=int, default=900)
    parser.add_argument('--supersample', type=float, default=1.5)
    parser.add_argument('--yaw', type=float, default=-.16)
    parser.add_argument('--pitch', type=float, default=-.06)
    parser.add_argument('--time', type=float, default=0)
    parser.add_argument('--output', type=Path, default=Path('docs/assets/gravity-study.webp'))
    args = parser.parse_args()
    if args.width < 1 or args.height < 1 or args.supersample <= 0:
        parser.error('Dimensions and supersampling must be positive')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    image = render(round(args.width*args.supersample), round(args.height*args.supersample), args.yaw, args.pitch, args.time)
    image.resize((args.width, args.height), Image.Resampling.LANCZOS).save(args.output, quality=92, method=6)
    print(f'CPU-rendered bent-light still: {args.output} ({args.width} × {args.height})')
