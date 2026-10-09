#!/usr/bin/env python3
"""Generate the tileable noise textures used by the volumetric cloud system.

Outputs raw binary textures (loaded by Iris through `customTexture.*` in
shaders.properties) into shaders/textures/clouds/:

  noise_base.dat    128^3 RGBA8  R: Perlin-Worley  G,B,A: Worley fBm (4, 8, 16 cells/tile)
  noise_detail.dat   32^3 RGBA8  R,G,B: Worley fBm (2, 4, 8 cells/tile)  A: Perlin fBm
  curl.dat          128^2 RGBA8  RG: 2D curl of a tileable Perlin field (signed, 0.5 = 0)  B,A: Perlin fBm

Every texture tiles seamlessly (REPEAT wrap is enabled through .mcmeta files).
The script is deterministic: re-running it produces identical files.

Usage: python3 tools/gen_cloud_noise.py [--preview OUT_DIR]
"""
import os
import sys
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "shaders", "textures", "clouds")


def grid(n, dims):
    axes = [(np.arange(n, dtype=np.float32) + 0.5) / n] * dims
    return np.stack(np.meshgrid(*axes, indexing="ij"), axis=-1)  # (n,..,n,dims) in [0,1)


def worley(p, cells, seed):
    """Tileable Worley (F1 distance, normalised to ~[0,1]); p in [0,1)."""
    rng = np.random.default_rng(seed)
    dims = p.shape[-1]
    feat = rng.random((cells,) * dims + (dims,), dtype=np.float32)
    q = p * cells
    cell = np.floor(q).astype(np.int32)
    frac = q - cell
    best = np.full(p.shape[:-1], 1e9, dtype=np.float32)
    offsets = np.stack(np.meshgrid(*[np.arange(-1, 2)] * dims, indexing="ij"), -1).reshape(-1, dims)
    for o in offsets:
        nc = cell + o
        idx = tuple(np.mod(nc[..., k], cells) for k in range(dims))
        fp = feat[idx]
        d = o + fp - frac
        best = np.minimum(best, np.sum(d * d, axis=-1))
    return np.clip(np.sqrt(best) / np.sqrt(dims) * 1.6, 0.0, 1.0)


def perlin(p, period, seed):
    """Tileable gradient noise in [-1,1] (approximately)."""
    rng = np.random.default_rng(seed)
    dims = p.shape[-1]
    g = rng.normal(size=(period,) * dims + (dims,)).astype(np.float32)
    g /= np.linalg.norm(g, axis=-1, keepdims=True)
    q = p * period
    cell = np.floor(q).astype(np.int32)
    f = q - cell
    u = f * f * f * (f * (f * 6 - 15) + 10)
    out = np.zeros(p.shape[:-1], dtype=np.float32)
    for corner in range(1 << dims):
        o = np.array([(corner >> k) & 1 for k in range(dims)], dtype=np.int32)
        idx = tuple(np.mod(cell[..., k] + o[k], period) for k in range(dims))
        d = np.sum(g[idx] * (f - o), axis=-1)
        w = np.ones_like(out)
        for k in range(dims):
            w *= u[..., k] if o[k] else (1 - u[..., k])
        out += w * d
    return out * (1.0 / np.sqrt(dims / 4.0))


def worley_fbm(p, cells, seed):
    # Inverted Worley ("billowy") fBm, 3 octaves.
    w = (1 - worley(p, cells, seed)) * 0.625 \
        + (1 - worley(p, cells * 2, seed + 1)) * 0.25 \
        + (1 - worley(p, cells * 4, seed + 2)) * 0.125
    return w


def perlin_fbm(p, period, seed, octaves=5):
    v = np.zeros(p.shape[:-1], dtype=np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        v += perlin(p, period << o, seed + o) * amp
        tot += amp
        amp *= 0.5
    return v / tot


def remap(x, a, b, c, d):
    return c + (x - a) / (b - a) * (d - c)


def normalize01(x):
    lo, hi = np.percentile(x, 0.5), np.percentile(x, 99.5)
    return np.clip((x - lo) / (hi - lo), 0, 1)


def to_u8(x):
    return np.round(np.clip(x, 0, 1) * 255).astype(np.uint8)


def write(name, channels):
    data = np.stack([to_u8(c) for c in channels], axis=-1)
    # Raw texture layout: x fastest, then y, then z  -> array index [z][y][x][c]
    data = np.ascontiguousarray(np.moveaxis(data, list(range(data.ndim - 1)), list(range(data.ndim - 2, -1, -1))))
    path = os.path.join(OUT, name)
    data.tofile(path)
    with open(path + ".mcmeta", "w") as f:
        f.write('{\n  "texture": {\n    "blur": true,\n    "clamp": false\n  }\n}\n')
    print(f"wrote {path} {data.shape} {os.path.getsize(path)} bytes")
    return data


def main():
    os.makedirs(OUT, exist_ok=True)

    print("base 128^3 ...")
    p = grid(128, 3)
    pf = normalize01(perlin_fbm(p, 4, 10, octaves=4))
    w0 = worley_fbm(p, 4, 100)
    # Perlin-Worley: dilate the perlin with billowy worley (Schneider 2015)
    pw = normalize01(remap(pf, w0 - 1.0, 1.0, 0.0, 1.0))
    base = write("noise_base.dat", [pw, normalize01(w0), normalize01(worley_fbm(p, 8, 200)), normalize01(worley_fbm(p, 16, 300))])

    print("detail 32^3 ...")
    p = grid(32, 3)
    detail = write("noise_detail.dat", [normalize01(worley_fbm(p, 2, 400)), normalize01(worley_fbm(p, 4, 500)),
                                         normalize01(worley_fbm(p, 8, 600)), normalize01(perlin_fbm(p, 2, 700, octaves=3))])

    print("curl 128^2 ...")
    p = grid(128, 2)
    n = perlin_fbm(p, 4, 800, octaves=3)
    dy, dx = np.gradient(n.T)  # n indexed [x][y]; gradient over transposed -> d/dy, d/dx
    curl = np.stack([dy.T, -dx.T], -1)  # (dn/dy, -dn/dx)
    curl /= np.max(np.abs(curl)) + 1e-6
    write("curl.dat", [curl[..., 0] * 0.5 + 0.5, curl[..., 1] * 0.5 + 0.5,
                       normalize01(perlin_fbm(p, 8, 900, octaves=4)), normalize01(perlin_fbm(p, 2, 950, octaves=4))])

    if "--preview" in sys.argv:
        from PIL import Image
        out_dir = sys.argv[sys.argv.index("--preview") + 1]
        Image.fromarray(base[0, :, :, :3]).save(os.path.join(out_dir, "noise_base_slice.png"))
        Image.fromarray(base[0, :, :, 3]).save(os.path.join(out_dir, "noise_base_slice_a.png"))
        Image.fromarray(detail[0, :, :, :3]).resize((128, 128), Image.NEAREST).save(os.path.join(out_dir, "noise_detail_slice.png"))


if __name__ == "__main__":
    main()
