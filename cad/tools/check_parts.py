#!/usr/bin/env python3
"""Export and check printable parts.

usage: check_parts.py <file.scad> <part> [<part> ...] [--no-export]

For each part: runs `openscad -D part="<part>"` to cad/stl/<stem>-<part>.stl (binary STL),
then checks:
  - no ERROR / assertion failure in the OpenSCAD log, and `Simple: yes` (manifold);
  - the bbox fits the bed (245 x 205 x 205, rotated in XY if needed);
  - min Z == 0 (sits on the bed) and volume > 0.
Prints one OK/FAIL line per part; exit status 1 if any part fails.
"""
import importlib.util, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
CAD = os.path.dirname(HERE)
BED = (245.0, 205.0, 205.0)
spec = importlib.util.spec_from_file_location(
    "stl_stats", os.path.expanduser("~/.claude/skills/openscad-cli/stl_stats.py"))
stl_stats = importlib.util.module_from_spec(spec); spec.loader.exec_module(stl_stats)


def stats(path):
    tris = stl_stats.read_stl(path)
    xs = [v[0] for t in tris for v in t]; ys = [v[1] for t in tris for v in t]; zs = [v[2] for t in tris for v in t]
    vol = sum(stl_stats.dot(a, stl_stats.cross(b, c)) for a, b, c in tris) / 6.0
    return (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)), vol


def check(scad, part, export=True):
    stem = os.path.splitext(os.path.basename(scad))[0]
    out = os.path.join(CAD, "stl", f"{stem}-{part}.stl")
    problems = []
    if export:
        r = subprocess.run(["openscad", "-o", out, "--export-format", "binstl", "-D", f'part="{part}"', scad],
                           capture_output=True, text=True)
        log = r.stdout + r.stderr
        if r.returncode != 0 or re.search(r"^ERROR|Assertion", log, re.M):
            problems.append("openscad error: " + " | ".join(l for l in log.splitlines() if "ERROR" in l)[:300])
        if "Simple:        yes" not in log and "Simple: yes" not in log:
            problems.append("not manifold (Simple: no / missing)")
    if not os.path.exists(out):
        return f"FAIL {stem}-{part}: no STL ({'; '.join(problems)})", False
    (x0, x1, y0, y1, z0, z1), vol = stats(out)
    dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
    fits = (dz <= BED[2]) and ((dx <= BED[0] and dy <= BED[1]) or (dy <= BED[0] and dx <= BED[1]))
    if not fits: problems.append(f"bbox {dx:.1f} x {dy:.1f} x {dz:.1f} exceeds bed")
    if abs(z0) > 0.01: problems.append(f"min Z = {z0:.3f}, not on the bed")
    if vol <= 0: problems.append(f"volume {vol:.1f}")
    tag = "OK  " if not problems else "FAIL"
    line = f"{tag} {stem}-{part}: bbox {dx:.1f} x {dy:.1f} x {dz:.1f} mm, volume {vol/1000:.1f} cm3"
    if problems: line += "  <- " + "; ".join(problems)
    return line, not problems


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    if len(args) < 2:
        print(__doc__); return 2
    scad, parts = os.path.abspath(args[0]), args[1:]
    ok = True
    for p in parts:
        line, good = check(scad, p, export="--no-export" not in argv)
        print(line, flush=True); ok &= good
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
