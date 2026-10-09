#!/usr/bin/env python3
"""Offline compile check of the shader pack programs with glslangValidator.

Resolves Iris-style `#include "/abs/path"` directives, injects the defines Iris
would provide, and compiles each program for its stage. Run with option
overrides to test several configurations, e.g.:

  python3 tools/compile_check.py                        # default options
  python3 tools/compile_check.py -D VOXY                # Voxy LOD path
  python3 tools/compile_check.py -D CLOUD_RES=1 -D CLOUD_DEBUG_VIEW=2
  python3 tools/compile_check.py --only composite4 begin

Requires glslangValidator (apt install glslang-tools).
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHADERS = os.path.join(ROOT, "shaders")
STAGES = {".fsh": "frag", ".vsh": "vert", ".gsh": "geom", ".csh": "comp"}
INCLUDE_RE = re.compile(r'^\s*#include\s+"([^"]+)"')
DEFINE_RE = re.compile(r'^(\s*)(//\s*)?#define\s+(\w+)(\s+[^/\s][^/]*?)?\s*(//.*)?$')

IRIS_DEFINES = ["MC_VERSION 12100", "IS_IRIS", "MC_GL_RENDERER_NVIDIA", "MC_GL_VENDOR_NVIDIA",
                "IRIS_FEATURE_COMPUTE_SHADERS", "IRIS_FEATURE_CUSTOM_IMAGES",
                # Distant Horizons block ids (injected by Iris when DH is installed)
                "DH_BLOCK_LEAVES 1", "DH_BLOCK_WATER 2", "DH_BLOCK_LAVA 3", "DH_BLOCK_ILLUMINATED 4"]
# Programs that are not loaded by Iris itself (Physics Mod ocean shaders).
SKIP = {"physics_ocean_v2.fsh", "physics_ocean_v2.vsh"}


def resolve(path, stack=()):
    if path in stack:
        raise RuntimeError("include cycle: " + " -> ".join(stack + (path,)))
    out = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = INCLUDE_RE.match(line)
            if m:
                inc = m.group(1)
                full = os.path.join(SHADERS, inc.lstrip("/")) if inc.startswith("/") else os.path.join(os.path.dirname(path), inc)
                out.append(resolve(os.path.normpath(full), stack + (path,)))
            else:
                out.append(line if line.endswith("\n") else line + "\n")
    return "".join(out)


def apply_overrides(src, overrides):
    """Mimic Iris option overrides: rewrite `#define NAME value` lines (and toggle `//#define NAME`)."""
    if not overrides:
        return src
    lines = src.split("\n")
    for i, line in enumerate(lines):
        m = DEFINE_RE.match(line)
        if not m:
            continue
        name = m.group(3)
        if name in overrides:
            val = overrides[name]
            if val is None:          # boolean option forced on
                lines[i] = f"#define {name}"
            elif val == "!":         # boolean option forced off
                lines[i] = f"// #define {name}"
            else:
                lines[i] = f"#define {name} {val}"
    return "\n".join(lines)


def compile_one(path, defines, overrides):
    stage = STAGES[os.path.splitext(path)[1]]
    src = apply_overrides(resolve(path), overrides)
    lines = src.split("\n")
    inject = "\n".join(f"#define {d}" for d in IRIS_DEFINES + defines)
    for i, l in enumerate(lines):
        if l.startswith("#version"):
            lines.insert(i + 1, inject)
            break
    else:
        lines.insert(0, inject)
    with tempfile.NamedTemporaryFile("w", suffix="." + stage, delete=False) as tf:
        tf.write("\n".join(lines))
        tmp = tf.name
    try:
        r = subprocess.run(["glslangValidator", "-S", stage, tmp], capture_output=True, text=True)
        out = (r.stdout + r.stderr).replace(tmp, os.path.relpath(path, ROOT))
        ok = r.returncode == 0
        return ok, out.strip()
    finally:
        os.unlink(tmp)


def iris_lint():
    """Checks for things glslang accepts but Iris rejects. Returns the number of problems."""
    problems = 0
    inc = re.compile(r'^\s*#include\s+"[^"]*"\s*\S')
    for root, _, files in os.walk(SHADERS):
        for name in files:
            if not name.endswith((".fsh", ".vsh", ".gsh", ".csh", ".glsl", ".inc")):
                continue
            path = os.path.join(root, name)
            for i, line in enumerate(open(path, encoding="utf-8", errors="replace"), 1):
                if inc.match(line):  # Iris reads the rest of the line as part of the path
                    print(f"IRIS: {os.path.relpath(path, SHADERS)}:{i}: text after #include: {line.strip()}")
                    problems += 1
    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-D", action="append", default=[], help="extra define injected after #version (NAME or NAME=VALUE)")
    ap.add_argument("-O", action="append", default=[], help="option override: NAME=VALUE, NAME (force on) or NAME=! (force off)")
    ap.add_argument("--only", nargs="*", help="program name prefixes to check")
    ap.add_argument("--dir", default="", help="sub-directory (e.g. world-1)")
    args = ap.parse_args()

    defines = [d.replace("=", " ", 1) for d in args.D]
    overrides = {}
    for o in args.O:
        k, _, v = o.partition("=")
        overrides[k] = v if v else None

    base = os.path.join(SHADERS, args.dir)
    files = sorted(f for f in os.listdir(base) if os.path.splitext(f)[1] in STAGES and f not in SKIP)
    if args.only:
        files = [f for f in files if any(f.startswith(p) for p in args.only)]
    failed = 0
    for f in files:
        ok, out = compile_one(os.path.join(base, f), defines, overrides)
        if not ok:
            failed += 1
            print(f"FAIL {f}\n{out}\n")
    print(f"{len(files) - failed}/{len(files)} programs compiled" + (" OK" if not failed else f", {failed} FAILED"))
    lint = iris_lint()
    if lint:
        print(f"{lint} Iris specific problem(s)")
    sys.exit(1 if failed or lint else 0)


if __name__ == "__main__":
    main()
