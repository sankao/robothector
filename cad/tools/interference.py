#!/usr/bin/env python3
"""Pairwise interference check between assemblies and ghost vitamins.

usage: interference.py [a:b ...]       default: every pair in DEFAULT_PAIRS
Each pair renders tools/interference.scad with -D a=.. -D b=.. ; an empty intersection
(OpenSCAD writes no file) or a volume < 1 mm^3 is OK. Exit status 1 on any FAIL.
Assemblies: cab, uc, lc. Vitamins: cab_v, uc_v, lc_v.
"""
import importlib.util, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SCAD = os.path.join(HERE, "interference.scad")
DEFAULT_PAIRS = ["cab:lc", "cab:uc", "uc:lc",
                 "cab:cab_v", "cab:uc_v", "cab:lc_v",
                 "uc:uc_v", "uc:cab_v", "uc:lc_v",
                 "lc:lc_v", "lc:cab_v", "lc:uc_v"]
spec = importlib.util.spec_from_file_location(
    "stl_stats", os.path.expanduser("~/.claude/skills/openscad-cli/stl_stats.py"))
stl_stats = importlib.util.module_from_spec(spec); spec.loader.exec_module(stl_stats)


def volume(path):
    tris = stl_stats.read_stl(path)
    return abs(sum(stl_stats.dot(a, stl_stats.cross(b, c)) for a, b, c in tris) / 6.0), tris


def run(pair):
    a, b = pair.split(":")
    with tempfile.TemporaryDirectory() as td:
        out = os.path.join(td, "x.stl")
        r = subprocess.run(["openscad", "-o", out, "-D", f'a="{a}"', "-D", f'b="{b}"', SCAD],
                           capture_output=True, text=True)
        log = r.stdout + r.stderr
        if "Ignoring unknown module" in log:
            return f"SKIP {pair}: a module is missing (part not written yet?)", True
        if not os.path.exists(out) or os.path.getsize(out) == 0:
            return f"OK   {pair}: no intersection", True
        vol, tris = volume(out)
        if vol < 1.0:
            return f"OK   {pair}: {vol:.3f} mm3", True
        xs = [v[0] for t in tris for v in t]; ys = [v[1] for t in tris for v in t]; zs = [v[2] for t in tris for v in t]
        return (f"FAIL {pair}: {vol:.1f} mm3 within x[{min(xs):.1f},{max(xs):.1f}] "
                f"y[{min(ys):.1f},{max(ys):.1f}] z[{min(zs):.1f},{max(zs):.1f}]"), False


def main(argv):
    pairs = argv or DEFAULT_PAIRS
    ok = True
    for p in pairs:
        line, good = run(p)
        print(line, flush=True); ok &= good
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
