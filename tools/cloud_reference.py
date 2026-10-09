#!/usr/bin/env python3
"""Path traced reference for the cloud lighting model (CloudMarch.inc), and fit of its constants.

A uniform spherical cloud (radius R m, extinction 0.06 /m, albedo 1) is rendered with an
orthographic camera by backward path tracing with next event estimation toward the sun:
  - transport: physical droplet phase function (HG 0.995 diffraction peak + Draine 0.594 / 27.1,
    Jendersie & d'Eon 2023)
  - display (next event estimation): the pack's phase function (HG peak widened to 0.8)
The result is the radiance per unit sun irradiance, the quantity the shader outputs as "sun".
The same images are computed with the pack's model (octaves + diffusion term, exact optical
depth toward the sun) and its constants are fitted (Nelder-Mead) to the references.

  python3 tools/cloud_reference.py render 250 256 ref250.npz   # radius, samples per pixel, output
  python3 tools/cloud_reference.py render 600 96 ref600.npz
  python3 tools/cloud_reference.py fit 250:ref250.npz,600:ref600.npz [iterations]
  python3 tools/cloud_reference.py compare 250:ref250.npz out.png [params json]

Requires numpy (and pillow for compare). A 256 spp render of R = 250 m takes ~3 min on a CPU.
"""
import json
import math
import sys

import numpy as np

SIGMA = 0.06
N = 96
G_TRANSPORT = 0.995
rng = np.random.default_rng(1)

# view direction D (camera -> cloud), sun direction L (toward the sun)
CASES = {
    "front": (np.array([0, 0, -1.0]), np.array([0.3, 0.45, 1.0])),       # sun behind the camera
    "side": (np.array([0, 0, -1.0]), np.array([1.0, 0.5, 0.0])),         # sun from the right
    "back": (np.array([0, 0, -1.0]), np.array([0.25, 0.35, -1.0])),      # sun behind the cloud
    "below": (np.array([0.0, 0.85, -0.53]), np.array([0.3, 0.9, 0.3])),   # looking up, sun high
    "below2": (np.array([0.0, 0.6, -0.8]), np.array([-0.4, 0.8, 0.45])),  # looking up, sun behind the camera
}

# CLOUD_LIGHT_MODEL 0 (previous) and the fitted values of CLOUD_LIGHT_MODEL 1
PREVIOUS = dict(decay=0.22, octave_b=0.4, diffuse_w=0.85, gd=0.3, gm=0.4)
FITTED = dict(decay=0.26, octave_b=0.34, diffuse_w=0.48, gd=0.27, gm=1.0)


def hg(c, g):
    d = 1 + g * g - 2 * g * c
    return (1 - g * g) / (4 * math.pi * d * np.sqrt(d))


def draine(c, g, a):
    d = 1 + g * g - 2 * g * c
    return ((1 - g * g) * (1 + a * c * c)) / (4 * math.pi * (1 + a * (1 + 2 * g * g) / 3) * d * np.sqrt(d))


def phase(c, k=1.0):
    """CloudPhase() of CloudCommon.inc"""
    return 0.5 * hg(c, 0.8 * k) + 0.5 * draine(c, 0.594 * k, 27.1)


_cs = np.linspace(-1, 1, 20001)
_pd = draine(_cs, 0.594, 27.1) * 2 * math.pi
_cdf = np.concatenate([[0], np.cumsum((_pd[1:] + _pd[:-1]) * 0.5 * np.diff(_cs))])
_cdf /= _cdf[-1]


def sample_cos(n):
    u = rng.random(n)
    g = G_TRANSPORT
    s = (1 - g * g) / (1 - g + 2 * g * u)
    c_hg = (1 + g * g - s * s) / (2 * g)
    c_dr = np.interp(rng.random(n), _cdf, _cs)
    return np.clip(np.where(rng.random(n) < 0.5, c_hg, c_dr), -1, 1)


def rotate(d, c):
    n = len(d)
    phi = rng.random(n) * 2 * math.pi
    s = np.sqrt(np.maximum(1 - c * c, 0))
    a = np.where(np.abs(d[:, 2:3]) < 0.9, np.array([[0, 0, 1.0]]), np.array([[1.0, 0, 0]]))
    t1 = np.cross(d, a)
    t1 /= np.linalg.norm(t1, axis=1, keepdims=True)
    t2 = np.cross(d, t1)
    return d * c[:, None] + t1 * (s * np.cos(phi))[:, None] + t2 * (s * np.sin(phi))[:, None]


def chord(p, d, R):
    b = np.sum(p * d, axis=1)
    c = np.sum(p * p, axis=1) - R * R
    return -b + np.sqrt(np.maximum(b * b - c, 0))


def camera(D, R):
    D = D / np.linalg.norm(D)
    a = np.array([0, 1.0, 0]) if abs(D[1]) < 0.9 else np.array([1.0, 0, 0])
    u = np.cross(D, a)
    u /= np.linalg.norm(u)
    v = np.cross(u, D)
    xs = ((np.arange(N) + 0.5) / N * 2 - 1) * R * 1.05
    X, Y = np.meshgrid(xs, xs)
    o = (X[..., None] * u + Y[..., None] * v - D * (3 * R)).reshape(-1, 3)
    b = o @ D
    c = np.sum(o * o, axis=1) - R * R
    disc = b * b - c
    return o, D, disc > 0, -b - np.sqrt(np.maximum(disc, 0)), -b + np.sqrt(np.maximum(disc, 0))


def reference(D, L, R, spp):
    o, D, hit, t0, _ = camera(D, R)
    L = L / np.linalg.norm(L)
    idx = np.repeat(np.where(hit)[0], spp)
    pos = o[idx] + D * t0[idx][:, None]
    d = np.tile(D, (len(idx), 1))
    acc = np.zeros(len(idx))
    alive = np.ones(len(idx), bool)
    for _ in range(20000):
        a = np.where(alive)[0]
        if len(a) == 0:
            break
        s = -np.log(1 - rng.random(len(a))) / SIGMA
        out = s >= chord(pos[a], d[a], R)
        alive[a[out]] = False
        a, s = a[~out], s[~out]
        pos[a] += d[a] * s[:, None]
        acc[a] += phase(d[a] @ L) * np.exp(-SIGMA * chord(pos[a], np.broadcast_to(L, (len(a), 3)), R))
        d[a] = rotate(d[a], sample_cos(len(a)))
    img = np.zeros(len(o))
    np.add.at(img, idx, acc)
    return (img / spp).reshape(N, N)


def model(D, L, R, decay, octave_b, diffuse_w, gd, gm, deep=0.4, octaves=3, ds=2.0):
    """The ray march lighting of CloudMarch.inc with the exact optical depth toward the sun"""
    o, D, hit, t0, t1 = camera(D, R)
    L = L / np.linalg.norm(L)
    cosT = D @ L
    ph = [phase(cosT, 2.0 ** -k) for k in range(octaves)]
    dphase = (1.0 + gm * (4 * math.pi * hg(cosT, gd) - 1.0)) / math.pi
    diffuse = 1 - math.exp(-2 * R * SIGMA * 0.12)
    img = np.zeros(len(o))
    T = np.ones(len(o))
    ext = math.exp(-SIGMA * ds)
    for t in np.arange(0, (t1 - t0)[hit].max(), ds):
        inside = hit & (t < t1 - t0)
        p = o + D * (t0 + t + ds * 0.5)[:, None]
        tauL = SIGMA * chord(p, np.broadcast_to(L, p.shape), R)
        sun, a, b = np.zeros(len(o)), 1.0, 1.0
        for k in range(octaves):
            sun += a * ph[k] * np.exp(-tauL * b)
            a *= 0.5
            b *= octave_b
        diffusion = (1 - deep) * np.exp(-tauL * decay) + deep / (1 + 0.1 * tauL)
        sun += dphase * diffusion * diffuse * diffuse_w
        img += np.where(inside, T * (1 - ext), 0) * sun
        T = np.where(inside, T * ext, T)
    return img.reshape(N, N)


def load_sets(arg):
    return [(float(r), np.load(f)) for r, f in (a.split(":") for a in arg.split(","))]


def blocks(a):
    n = a.shape[0] // 4 * 4
    return a[:n, :n].reshape(n // 4, 4, n // 4, 4).mean((1, 3))


def error(sets, params, verbose=False):
    e = []
    for R, ref in sets:
        for name, (D, L) in CASES.items():
            if name not in ref:
                continue
            r, m = blocks(ref[name]), blocks(model(D, L, R, ds=4.0 if R > 400 else 2.0, **params))
            mask = r > r.max() * 0.02
            e.append(np.abs(m - r)[mask].mean() / r[mask].mean())
            if verbose:
                print(f"  R{R:.0f} {name:6s} ref mean {r[mask].mean():.4f} p10-p90 {np.percentile(r[mask], 10):.4f}-{np.percentile(r[mask], 90):.4f}"
                      f" | model {m[mask].mean():.4f} {np.percentile(m[mask], 10):.4f}-{np.percentile(m[mask], 90):.4f} | error {e[-1]:.2f}")
    return float(np.mean(e))


def nelder_mead(f, x0, steps, iters):
    pts = [x0] + [x0 + np.eye(len(x0))[i] * steps[i] for i in range(len(x0))]
    vals = [f(p) for p in pts]
    for it in range(iters):
        o = np.argsort(vals)
        pts, vals = [pts[i] for i in o], [vals[i] for i in o]
        c = np.mean(pts[:-1], 0)
        xr = c + (c - pts[-1])
        fr = f(xr)
        if fr < vals[0]:
            xe = c + 2 * (c - pts[-1])
            fe = f(xe)
            pts[-1], vals[-1] = (xe, fe) if fe < fr else (xr, fr)
        elif fr < vals[-2]:
            pts[-1], vals[-1] = xr, fr
        else:
            xc = c + 0.5 * (pts[-1] - c)
            fc = f(xc)
            if fc < vals[-1]:
                pts[-1], vals[-1] = xc, fc
            else:
                pts = [pts[0]] + [pts[0] + 0.5 * (p - pts[0]) for p in pts[1:]]
                vals = [vals[0]] + [f(p) for p in pts[1:]]
        if it % 10 == 0:
            print(it, round(vals[0], 4), np.round(pts[0], 3), flush=True)
    return pts[int(np.argmin(vals))]


def main():
    cmd = sys.argv[1]
    if cmd == "render":
        R, spp, out = float(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
        res = {}
        for name, (D, L) in CASES.items():
            print(name, flush=True)
            res[name] = reference(D, L, R, spp)
        np.savez(out, **res)
    elif cmd == "fit":
        sets = load_sets(sys.argv[2])
        names = list(PREVIOUS)
        print("previous:", round(error(sets, PREVIOUS, True), 3))

        def f(x):
            if x[0] < 0.02 or not 0.05 < x[1] < 1 or x[2] < 0 or not 0 <= x[3] < 0.95 or not 0 <= x[4] <= 1:
                return 9.0
            return error(sets, dict(zip(names, x)))
        best = nelder_mead(f, np.array(list(PREVIOUS.values())), [0.15, 0.15, 0.3, 0.2, 0.3],
                           int(sys.argv[3]) if len(sys.argv) > 3 else 60)
        print("fitted:", {k: round(float(v), 3) for k, v in zip(names, best)})
        print("error:", round(error(sets, dict(zip(names, best)), True), 3))
    elif cmd == "compare":
        from PIL import Image
        (R, ref), = load_sets(sys.argv[2])
        params = json.loads(sys.argv[4]) if len(sys.argv) > 4 else FITTED
        rows = []
        for name, (D, L) in CASES.items():
            m0, m1 = model(D, L, R, **PREVIOUS), model(D, L, R, **params)
            rows.append(np.concatenate([m0, np.ones((N, 3)), ref[name], np.ones((N, 3)), m1], 1) / 0.25)
        img = np.concatenate([np.concatenate([r, np.ones((3, r.shape[1]))], 0) for r in rows], 0)
        Image.fromarray((np.clip(img, 0, 1) ** (1 / 2.2) * 255).astype(np.uint8)[::-1]).save(sys.argv[3])
        print("columns: previous model | reference | fitted model; rows (top to bottom):", ", ".join(reversed(list(CASES))))


if __name__ == "__main__":
    main()
