#!/usr/bin/env python3
"""Offline preview of the volumetric cloud system (no Minecraft needed).

Runs the pack's real cloud programs (begin.csh, begin_a.csh, composite4_a.csh and
CloudComposite.inc) on a CPU OpenGL 4.5 context (Mesa llvmpipe through EGL) with a
synthetic camera, a flat ground and the pack's SEUS sky functions, then tone maps the
result to a PNG. Several frames are accumulated to remove the ray march noise.

It is a development tool: colours are close to, but not exactly, what the full pack
shows (no GI, simplified ground, simple tone mapping). Performance is meaningless.

Examples:
  python3 tools/cloud_preview.py out.png
  python3 tools/cloud_preview.py out.png --sun 8 --yaw 180 --pitch 5
  python3 tools/cloud_preview.py out.png --cam-y 3500 --pitch -20 -O CLOUD_COVERAGE=0.6
  python3 tools/cloud_preview.py out.png --scene sunset

Requires: pip install moderngl numpy pillow ; Mesa EGL (apt install libegl1 libegl-mesa0)
"""
import argparse
import math
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compile_check as cc  # noqa: E402  (include resolver / option overrides)

SHADERS = cc.SHADERS

SCENES = {
    # name: (sun elevation deg, sun azimuth deg, cam y, yaw, pitch)
    "noon":      (60, 150, 120, 0, 12),
    "morning":   (20, 90, 120, 60, 8),
    "sunset":    (4, 270, 120, 265, 6),
    "backlit":   (25, 0, 120, 0, 18),
    "above":     (35, 120, 4200, 30, -12),
    "mountain":  (30, 120, 2100, 0, -2),
    "zenith":    (60, 150, 120, 0, 70),
}


def perspective(fov_y_deg, aspect, near, far):
    f = 1.0 / math.tan(math.radians(fov_y_deg) / 2)
    m = np.zeros((4, 4), dtype=np.float64)
    m[0, 0] = f / aspect
    m[1, 1] = f
    m[2, 2] = (far + near) / (near - far)
    m[2, 3] = 2 * far * near / (near - far)
    m[3, 2] = -1
    return m


def view_matrix(yaw_deg, pitch_deg):
    """Rotation only (player space is camera relative). yaw 0 looks toward -Z (north)."""
    yaw, pitch = math.radians(yaw_deg), math.radians(pitch_deg)
    fwd = np.array([math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch)])
    right = np.cross(fwd, [0, 1, 0]); right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    m = np.identity(4)
    m[0, :3], m[1, :3], m[2, :3] = right, up, -fwd
    return m


def mat_bytes(m):
    return np.asarray(m, dtype=np.float32).T.tobytes()  # column major


def extract_functions(src, names):
    """Extract top level GLSL functions (all overloads) by name from source text."""
    out = []
    for name in names:
        for m in re.finditer(r'^[\w]+\s+' + name + r'\s*\([^;{]*\)\s*\{', src, re.M):
            i = m.end(); depth = 1
            while depth:
                depth += {'{': 1, '}': -1}.get(src[i], 0); i += 1
            out.append(src[m.start():i])
    return "\n".join(out)


def seus_sky_functions():
    src = open(os.path.join(SHADERS, "lib", "Common.inc")).read()
    glob = "\n".join(l for l in src.split("\n") if re.match(
        r'^(const\s+)?(vec3|float)\s+(Rayleigh|exp2Rayleigh|AtmosphereMie|AtmosphereDensity|AtmosphereDensityFalloff|AtmosphereExtent|MplusR)\b', l))
    funcs = extract_functions(src, ["saturate", "SmoothMin", "SmoothMax", "Luminance", "DoNightEyeAtNight", "curve",
                                    "PhaseMie", "AtmosphereAbsorption", "SunAbsorptionAtAltitude", "Atmosphere",
                                    "SkyShading", "RenderSunDisc"])
    # order matters: globals first, then functions (Atmosphere uses PhaseMie etc.)
    return glob + "\n" + funcs


DISPLAY_SHADER = r"""
#version 430
layout(local_size_x = 8, local_size_y = 8) in;
#include "/lib/Settings.inc"

uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform float viewWidth, viewHeight, frameTimeCounter, wetness, nightBrightness, timeMidnight;
uniform int frameCounter, worldTime;
uniform vec3 worldSunVector, worldLightVector, colorSunlight;
uniform float groundY;
layout(rgba32f) uniform writeonly image2D outImg;

%SEUS%

vec3 SkyAmbient() {
	vec3 colorSkyUp = SkyShading(vec3(0.0, 1.0, 0.0), worldSunVector);
	vec3 a = colorSkyUp;
	for (int i = 0; i < 8; i++) {
		float an = float(i) * 0.785398;
		a += SkyShading(normalize(vec3(cos(an), 0.25, sin(an))), worldSunVector);
		a += SkyShading(normalize(vec3(cos(an + 0.39), 1.0, sin(an + 0.39))), worldSunVector);
	}
	return a / 17.0;
}

#include "/lib/clouds/CloudComposite.inc"

void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	ivec2 isz = ivec2(ceil(vec2(viewWidth, viewHeight) * 0.5));
	if (any(greaterThanEqual(px, isz))) return;
	vec2 tc = (vec2(px) + 0.5) / vec2(viewWidth, viewHeight);
	vec4 vp = gbufferProjectionInverse * vec4(tc * 4.0 - 1.0, 1.0, 1.0);
	vec3 dir = normalize(mat3(gbufferModelViewInverse) * (vp.xyz / vp.w));
	vec3 skyAmb = SkyAmbient();

	vec3 n;
	float tg = dir.y < 0.0 ? (groundY - cameraPosition.y) / dir.y : -1.0;
	if (tg > 0.0) {
		vec3 L = worldLightVector;
		vec3 checker = mix(vec3(0.10, 0.16, 0.06), vec3(0.14, 0.2, 0.09), step(0.5, fract(dot(floor((cameraPosition.xz + dir.xz * tg) / 64.0), vec2(0.5)))));
		n = checker * (0.83 * 24.0 * colorSunlight * SUNLIGHT_BRIGHTNESS * max(L.y, 0.0) + 4.5 * skyAmb);
		// crude land haze
		float LdotV = dot(dir, worldSunVector);
		float hz = min(tg * 0.0015, AtmosphereExtent);
		n = n * AtmosphereAbsorption(vec3(dir.x, max(abs(dir.y), 0.01), dir.z), hz) + Atmosphere(vec3(dir.x, 0.01, dir.z), worldSunVector, 0.25, hz, LdotV, LdotV * LdotV + 1.0) * 0.5;
	} else {
		n = SkyShading(dir, worldSunVector);
		n += RenderSunDisc(dir, worldSunVector, colorSunlight) * AtmosphereAbsorption(dir, AtmosphereExtent) * 2000.0;
	}
	vec3 U = n * 0.12;
	CloudComposite(U, dir, tc, skyAmb);
	imageStore(outImg, px, vec4(U / 120.0, 1.0));
}
"""


def build_source(path_or_text, overrides, extra_defines, is_text=False):
    if is_text:
        tmp = os.path.join(SHADERS, "__preview_tmp.csh")
        with open(tmp, "w") as f:
            f.write(path_or_text)
        try:
            src = cc.resolve(tmp)
        finally:
            os.unlink(tmp)
    else:
        src = cc.resolve(path_or_text)
    src = cc.apply_overrides(src, overrides)
    lines = src.split("\n")
    for i, l in enumerate(lines):
        if l.startswith("#version"):
            lines.insert(i + 1, "\n".join("#define " + d for d in cc.IRIS_DEFINES + extra_defines))
            break
    return "\n".join(lines)


def set_u(prog, name, value):
    try:
        u = prog[name]
    except KeyError:
        return
    if isinstance(value, (bytes, bytearray)):
        u.write(value)
    else:
        u.value = value


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--scene", choices=SCENES.keys())
    ap.add_argument("--sun", type=float, default=35, help="sun elevation (deg)")
    ap.add_argument("--sun-az", type=float, default=150, help="sun azimuth (deg, 0 = north/-Z, 90 = east/+X)")
    ap.add_argument("--cam-y", type=float, default=120)
    ap.add_argument("--cam-x", type=float, default=0)
    ap.add_argument("--cam-z", type=float, default=0)
    ap.add_argument("--yaw", type=float, default=0)
    ap.add_argument("--pitch", type=float, default=10)
    ap.add_argument("--fov", type=float, default=70)
    ap.add_argument("--width", type=int, default=640, help="internal (output) width")
    ap.add_argument("--height", type=int, default=360)
    ap.add_argument("--frames", type=int, default=6, help="frames accumulated")
    ap.add_argument("--time", type=float, default=6000, help="worldTime ticks (drives cloud motion)")
    ap.add_argument("--wetness", type=float, default=0.0)
    ap.add_argument("--ground", type=float, default=64)
    ap.add_argument("--exposure", type=float, default=0.0, help="EV offset")
    ap.add_argument("-O", action="append", default=[], help="option override NAME=VALUE (see compile_check.py)")
    args = ap.parse_args()

    if args.scene:  # scene values are defaults: explicit flags win
        given = set(a.split("=")[0] for a in sys.argv[1:] if a.startswith("--"))
        for flag, val in zip(("--sun", "--sun-az", "--cam-y", "--yaw", "--pitch"), SCENES[args.scene]):
            if flag not in given:
                setattr(args, flag[2:].replace("-", "_"), val)

    import moderngl
    from PIL import Image

    overrides = {"CLOUD_RES": "1"}
    for o in args.O:
        k, _, v = o.partition("=")
        overrides[k] = v if v else None

    ctx = moderngl.create_standalone_context(backend="egl", require=430)

    W, H = args.width, args.height
    viewW, viewH = W * 2, H * 2

    # ---- textures --------------------------------------------------------------------
    def raw_tex3d(name, size):
        data = np.fromfile(os.path.join(SHADERS, "textures", "clouds", name), dtype=np.uint8)
        t = ctx.texture3d((size, size, size), 4, data.tobytes(), dtype="f1")
        t.repeat_x = t.repeat_y = t.repeat_z = True
        t.filter = (moderngl.LINEAR, moderngl.LINEAR)
        return t

    base = raw_tex3d("noise_base.dat", 128)
    detail = raw_tex3d("noise_detail.dat", 32)
    curl = ctx.texture((128, 128), 4, np.fromfile(os.path.join(SHADERS, "textures", "clouds", "curl.dat"), dtype=np.uint8).tobytes(), dtype="f1")
    curl.repeat_x = curl.repeat_y = True
    curl.filter = (moderngl.LINEAR, moderngl.LINEAR)
    bn = np.array(Image.open(os.path.join(SHADERS, "textures", "blueNoiseRGB.png")).convert("RGBA"), dtype=np.uint8)
    noisetex = ctx.texture((64, 64), 4, bn.tobytes(), dtype="f1")

    def img3d(w, h, d):
        t = ctx.texture3d((w, h, d), 4, dtype="f2")
        t.repeat_x = t.repeat_y = t.repeat_z = False
        t.filter = (moderngl.LINEAR, moderngl.LINEAR)
        return t

    regime = ctx.texture((512, 512), 4, dtype="f2")
    regime.filter = (moderngl.LINEAR, moderngl.LINEAR)
    wNear = img3d(2048, 2048, 2)
    wFar = img3d(1024, 1024, 2)
    raw = ctx.texture((W, H), 4, dtype="f2")
    histA = ctx.texture((W, H), 4, dtype="f2")
    histB = ctx.texture((W, H), 4, dtype="f2")
    out = ctx.texture((W, H), 4, dtype="f4")

    # ---- camera / scene --------------------------------------------------------------
    cam = (args.cam_x, args.cam_y, args.cam_z)
    proj = perspective(args.fov, W / H, 1.0, 1.0e6)  # far plane beyond any ground hit
    view = view_matrix(args.yaw, args.pitch)
    projInv, viewInv = np.linalg.inv(proj), np.linalg.inv(view)

    el, az = math.radians(args.sun), math.radians(args.sun_az)
    sun = np.array([math.cos(el) * math.sin(az), math.sin(el), -math.cos(el) * math.cos(az)])
    light = sun if sun[1] > -0.05 else -sun
    shadowMVInv = np.identity(4); shadowMVInv[:3, 2] = light
    nightBrightness = 0.0001
    Ly = light[1]
    v1 = 0.233333 * (1 - math.exp(-Ly * 24)) / (Ly + 0.00001)
    v2 = min(Ly * 40, 1) * (nightBrightness if sun[1] < 0 else 1)
    colorSunlight = tuple(math.exp((-a - args.wetness) * v1) * v2 * b for a, b in zip((0.175, 0.405, 0.995), (0.976709, 0.946058, 0.871758)))

    # depth of the flat ground for each internal pixel (march stops there)
    ys, xs = np.mgrid[0:H, 0:W]
    tcx, tcy = (xs + 0.5) / viewW, (ys + 0.5) / viewH
    ndc = np.stack([tcx * 4 - 1, tcy * 4 - 1, np.ones_like(tcx), np.ones_like(tcx)], -1)
    vp = ndc @ projInv.T; vp = vp[..., :3] / vp[..., 3:]
    dirs = vp @ viewInv[:3, :3].T; dirs /= np.linalg.norm(dirs, axis=-1, keepdims=True)
    tg = np.where(dirs[..., 1] < 0, (args.ground - cam[1]) / np.minimum(dirs[..., 1], -1e-6), 1e9)
    depth = np.ones((H * 2, W * 2), dtype=np.float32)
    hit = tg < 1e8
    vpos = vp / np.linalg.norm(vp, axis=-1, keepdims=True) * np.where(hit, tg, 1.0)[..., None]
    clip = np.concatenate([vpos, np.ones_like(vpos[..., :1])], -1) @ proj.T
    dval = (clip[..., 2] / clip[..., 3]) * 0.5 + 0.5
    depth[:H, :W] = np.where(hit, np.clip(dval, 0, 0.9999999), 1.0)
    depthtex = ctx.texture((W * 2, H * 2), 1, depth.tobytes(), dtype="f4")
    depthtex.filter = (moderngl.NEAREST, moderngl.NEAREST)

    # ---- programs ----------------------------------------------------------------------
    def program(path):
        return ctx.compute_shader(build_source(os.path.join(SHADERS, path), overrides, []))

    pRegime, pBeginN, pBeginF = program("begin.csh"), program("begin_a.csh"), program("begin_b.csh")
    pMarch, pResolve = program("composite4_a.csh"), program("composite4_b.csh")
    disp_src = DISPLAY_SHADER.replace("%SEUS%", seus_sky_functions())
    pDisp = ctx.compute_shader(build_source(disp_src, overrides, [], is_text=True))

    units = {"cloudNoiseBase": base, "cloudNoiseDetail": detail, "cloudCurl": curl, "noisetex": noisetex,
             "depthtex0": depthtex, "cloudRegimeSampler": regime, "cloudWeatherNearSampler": wNear, "cloudWeatherFarSampler": wFar,
             "cloudRawSampler": raw, "cloudHistASampler": histA, "cloudHistBSampler": histB}

    def common_uniforms(p, frame):
        set_u(p, "cameraPosition", cam)
        set_u(p, "previousCameraPosition", cam)
        set_u(p, "gbufferModelViewInverse", mat_bytes(viewInv))
        set_u(p, "gbufferProjectionInverse", mat_bytes(projInv))
        set_u(p, "gbufferPreviousModelView", mat_bytes(view))
        set_u(p, "gbufferPreviousProjection", mat_bytes(proj))
        set_u(p, "shadowModelViewInverse", mat_bytes(shadowMVInv))
        set_u(p, "viewWidth", float(viewW)); set_u(p, "viewHeight", float(viewH))
        set_u(p, "frameTimeCounter", frame / 60.0)
        set_u(p, "wetness", args.wetness); set_u(p, "rainStrength", args.wetness)
        set_u(p, "thunderStrength", 0.0)
        set_u(p, "frameCounter", frame)
        set_u(p, "worldTime", int(args.time)); set_u(p, "worldDay", 0)
        set_u(p, "worldSunVector", tuple(sun)); set_u(p, "worldLightVector", tuple(light))
        set_u(p, "colorSunlight", colorSunlight)
        set_u(p, "nightBrightness", nightBrightness)
        set_u(p, "timeMidnight", float(np.clip(-sun[1] * 10, 0, 1)))
        set_u(p, "groundY", args.ground)
        for i, (name, tex) in enumerate(units.items()):
            try:
                p[name].value = i
                tex.use(location=i)
            except KeyError:
                pass

    def run(p, gx, gy, gz=1):
        p.run(gx, gy, gz)
        ctx.memory_barrier()

    # weather
    common_uniforms(pRegime, 0)
    regime.bind_to_image(0, read=False, write=True)
    run(pRegime, 32, 32)
    for p, img, size in ((pBeginN, wNear, 2048), (pBeginF, wFar, 1024)):
        common_uniforms(p, 0)
        img.bind_to_image(0, read=False, write=True)  # image uniforms are left at unit 0 (moderngl cannot rebind them)
        run(p, size // 16, size // 16)
        layer = np.frombuffer(img.read(), dtype=np.float16).reshape(2, size, size, 4)
        print(f"weather {size}: footprint>0 {np.mean(layer[0, ..., 0] > 0):.3f}  thick mean {layer[0, ..., 2].mean():.2f}  dist max {layer[1, ..., 0].max():.2f}")
    # rebind samplers after image use
    acc = np.zeros((H, W, 4), dtype=np.float64)
    for f in range(args.frames):
        common_uniforms(pMarch, f)
        raw.bind_to_image(0, read=False, write=True)
        run(pMarch, (W + 7) // 8, (H + 7) // 8)
        r = np.frombuffer(raw.read(), dtype=np.float16).reshape(H, W, 4).astype(np.float64)
        acc += r
        print(f"frame {f + 1}/{args.frames}", end="\r", flush=True)
    acc /= args.frames
    print()

    # resolve once (sanity check of the temporal program), then use accumulated data as history
    common_uniforms(pResolve, 0)
    histA.bind_to_image(0, read=False, write=True)  # frame 0 is even: writes cloudHistA
    run(pResolve, (W + 7) // 8, (H + 7) // 8)

    histA.write(np.concatenate([acc[..., :3], np.ones_like(acc[..., :1])], -1).astype(np.float16).tobytes())
    raw.write(acc.astype(np.float16).tobytes())  # depth channel averaged: only used for haze
    common_uniforms(pDisp, 0)
    out.bind_to_image(0, read=False, write=True)
    run(pDisp, (W + 7) // 8, (H + 7) // 8)
    img = np.frombuffer(out.read(), dtype=np.float32).reshape(H, W, 4)[..., :3].astype(np.float64)

    # simple auto exposure + filmic tone map
    lum = np.dot(img, [0.2126, 0.7152, 0.0722])
    key = np.exp(np.mean(np.log(np.maximum(lum, 1e-6))))
    x = img * (0.18 / max(key, 1e-6)) * 2 ** args.exposure
    a, b, c, d, e = 2.51, 0.03, 2.43, 0.59, 0.14
    y = np.clip((x * (a * x + b)) / (x * (c * x + d) + e), 0, 1) ** (1 / 2.2)
    Image.fromarray((y[::-1] * 255).astype(np.uint8)).save(args.out)

    t = acc[..., 2]
    if os.environ.get("CLOUD_DEBUG_STATS"):
        m = t < 0.5
        print("pixels with clouds:", m.sum())
        for name, ch in (("sun", 0), ("sky", 1), ("depthKm", 3)):
            v = acc[..., ch][m]
            print(f"{name}: p5 {np.percentile(v,5):.4f} p50 {np.percentile(v,50):.4f} p95 {np.percentile(v,95):.4f}")
    print(f"saved {args.out}  cloud cover (1-T mean): {1 - t.mean():.3f}  exposure key {key:.4g}")


if __name__ == "__main__":
    main()
