#!/usr/bin/env python3
"""Build PrusaSlicer 3MF print plates from cad/stl/ into cad/3mf/, and optionally check them.

usage: make_3mf.py            build every plate in PLATES
       make_3mf.py --check    also slice each plate (MK3S+, Generic PETG, the plate's layer
                              profile, 4 perimeters, 15% gyroid, supports only for SUPPORTED) and report time,
                              grams and any out-of-bed error; G-code lands in
                              ~/cad/slices/robothector/plates/ (ready to print).

Each plate holds every part as its own object, already in print orientation, packed and
centred on the MK3S+ bed (250 x 210). Like the other 3MFs in ~/cad, the plates carry no
print settings: PrusaSlicer 2.9.6's CLI cannot write them, and a hand-embedded config
crashed its 3MF loader (wipe_tower_extruder). The file name ends with the layer height
to pick: big single parts use 0.30mm DRAFT, plates of small detailed parts 0.20mm SPEED.
"""
import importlib.util, io, os, re, subprocess, sys, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
CAD = os.path.dirname(HERE)
STL, OUT = os.path.join(CAD, "stl"), os.path.join(CAD, "3mf")
GCODE_DIR = os.path.expanduser("~/cad/slices/robothector/plates")   # must be under $HOME (Flatpak sandbox)
BED, MARGIN, GAP = (250.0, 210.0), 2.0, 6.0   # margin 2: the eared tray/lid/frame are 244.8 long
PS = ["flatpak", "run", "--command=/app/bin/prusa-slicer", "com.prusa3d.PrusaSlicer"]
COMMON = ["--printer-profile", "Original Prusa i3 MK3S & MK3S+", "--material-profile", "Generic PETG",
          "--perimeters", "4", "--fill-density", "15%", "--fill-pattern", "gyroid"]
PROFILES = {"draft": "0.30mm DRAFT @MK3", "fine": "0.20mm SPEED @MK3"}
SUFFIX = {"draft": "_0.30mm", "fine": "_0.20mm"}

# (plate name, profile, [(stl stem, copies), ...]). Big single parts use draft (0.30 mm);
# plates of small detailed parts use fine (0.20 mm). The coupon matches the big parts.
PLATES = [
    ("00-fit_test-coupon", "draft", [("fit_test-coupon", 1)]),
    ("01-cabin-body", "draft", [("cabin-body", 1)]),
    ("02-upper_carriage-tray", "draft", [("upper_carriage-tray", 1)]),
    ("03-upper_carriage-lid", "draft", [("upper_carriage-lid", 1)]),
    ("04-lower_carriage-frame", "draft", [("lower_carriage-frame", 1)]),
    ("05-cabin-panels", "fine", [("cabin-roof", 1), ("cabin-bumper", 1)]),
    ("06-cabin-small", "fine", [("cabin-omni_cassette", 2),
                                ("cabin-camera_bracket", 1), ("cabin-camera_cradle", 1), ("cabin-camera_clip", 1)]),
    ("07-upper_carriage-small", "fine", [("upper_carriage-clamp_post", 3), ("upper_carriage-pusher", 3),
                                         ("upper_carriage-rear_stop", 2), ("upper_carriage-knob", 5),
                                         ("upper_carriage-l298n_plate", 1), ("upper_carriage-pd_plate", 1),
                                         ("upper_carriage-speaker_ring", 1)]),
    ("08-lower_carriage-clamps", "fine", [("lower_carriage-tt_clamp", 1), ("lower_carriage-tt_clamp_mirror", 1),
                                          ("lower_carriage-tt_cap", 2)]),
    ("09-rod_cutting_jig", "fine", [("rod_jig-base", 1), ("rod_jig-lid", 1)]),
    ("10-cabin-faceplate", "fine", [("cabin-faceplate", 1)]),
]
# Plates that need slicer supports (none: the faceplate's lip supports are modelled in the part).
SUPPORTED = set()
SUPPORT_ARGS = ["--support-material", "--support-material-auto", "--support-material-threshold", "30"]

spec = importlib.util.spec_from_file_location(
    "stl_stats", os.path.expanduser("~/.claude/skills/openscad-cli/stl_stats.py"))
stl_stats = importlib.util.module_from_spec(spec); spec.loader.exec_module(stl_stats)


def load_mesh(stem):
    tris = stl_stats.read_stl(os.path.join(STL, stem + ".stl"))
    xs = [v[0] for t in tris for v in t]; ys = [v[1] for t in tris for v in t]; zs = [v[2] for t in tris for v in t]
    cx, cy, z0 = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)
    index, verts, faces = {}, [], []
    for t in tris:
        ids = []
        for v in t:
            k = (round(v[0] - cx, 5), round(v[1] - cy, 5), round(v[2] - z0, 5))
            if k not in index:
                index[k] = len(verts); verts.append(k)
            ids.append(index[k])
        if len(set(ids)) == 3:
            faces.append(ids)
    return verts, faces, (max(xs) - min(xs), max(ys) - min(ys))


def pack(sizes):
    """Shelf-pack rectangles (w, d) on the bed; returns centre positions or None if they don't fit.
    Tries each part in both orientations (0 / 90 deg about Z) and keeps the first layout that fits."""
    order = sorted(range(len(sizes)), key=lambda i: -max(sizes[i]))
    for rotate_long in (False, True):
        pos, rot = [None] * len(sizes), [0] * len(sizes)
        x = y = MARGIN; shelf_h = 0.0; ok = True
        for i in order:
            w, d = sizes[i]
            if rotate_long and w < d:
                w, d = d, w; rot[i] = 90
            if x + w > BED[0] - MARGIN:
                x, y, shelf_h = MARGIN, y + shelf_h + GAP, 0.0
            if x + w > BED[0] - MARGIN or y + d > BED[1] - MARGIN:
                ok = False; break
            pos[i] = (x + w / 2, y + d / 2, w, d); x += w + GAP; shelf_h = max(shelf_h, d)
        if ok:
            # centre the whole layout on the bed
            x0 = min(p[0] - p[2] / 2 for p in pos); x1 = max(p[0] + p[2] / 2 for p in pos)
            y0 = min(p[1] - p[3] / 2 for p in pos); y1 = max(p[1] + p[3] / 2 for p in pos)
            dx, dy = (BED[0] - (x1 - x0)) / 2 - x0, (BED[1] - (y1 - y0)) / 2 - y0
            return [(p[0] + dx, p[1] + dy) for p in pos], rot
    return None, None


def model_xml(objects):
    out = io.StringIO()
    out.write('<?xml version="1.0" encoding="UTF-8"?>\n<model unit="millimeter" xml:lang="en-US" '
              'xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">\n <resources>\n')
    for oid, (name, verts, faces, _, _) in enumerate(objects, 1):
        out.write(f'  <object id="{oid}" name="{name}" type="model">\n   <mesh>\n    <vertices>\n')
        out.write("".join(f'     <vertex x="{v[0]:.5f}" y="{v[1]:.5f}" z="{v[2]:.5f}"/>\n' for v in verts))
        out.write('    </vertices>\n    <triangles>\n')
        out.write("".join(f'     <triangle v1="{f[0]}" v2="{f[1]}" v3="{f[2]}"/>\n' for f in faces))
        out.write('    </triangles>\n   </mesh>\n  </object>\n')
    out.write(' </resources>\n <build>\n')
    for oid, (_, _, _, (px, py), rot) in enumerate(objects, 1):
        c, s = (1, 0) if rot == 0 else (0, 1)
        # 3MF row-major 3x4: m00 m01 m02 m10 m11 m12 m20 m21 m22 tx ty tz (row vectors)
        out.write(f'  <item objectid="{oid}" transform="{c} {s} 0 {-s} {c} 0 0 0 1 {px:.4f} {py:.4f} 0" printable="1"/>\n')
    out.write(' </build>\n</model>\n')
    return out.getvalue()


CONTENT_TYPES = ('<?xml version="1.0" encoding="UTF-8"?>\n<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
                 '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
                 '<Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>'
                 '</Types>\n')
RELS = ('<?xml version="1.0" encoding="UTF-8"?>\n<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>'
        '</Relationships>\n')


def main():
    os.makedirs(OUT, exist_ok=True)
    meshes, rc = {}, 0
    for base, prof, items in PLATES:
        name = base + SUFFIX[prof]
        parts = []
        for stem, copies in items:
            if stem not in meshes: meshes[stem] = load_mesh(stem)
            for k in range(copies):
                parts.append((f"{stem}" + (f" #{k + 1}" if copies > 1 else ""),) + meshes[stem])
        pos, rot = pack([p[3] for p in parts])
        if pos is None:
            print(f"FAIL {name}: parts do not fit one bed"); rc = 1; continue
        objects = [(p[0], p[1], p[2], pos[i], rot[i]) for i, p in enumerate(parts)]
        path = os.path.join(OUT, name + ".3mf")
        with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
            z.writestr("[Content_Types].xml", CONTENT_TYPES)
            z.writestr("_rels/.rels", RELS)
            z.writestr("3D/3dmodel.model", model_xml(objects))
        print(f"OK   {name}.3mf: {len(parts)} objects, print with {PROFILES[prof]}")
        if "--check" in sys.argv:
            rc |= check(name, prof, base in SUPPORTED)
    return rc


def check(name, prof, supports=False):
    os.makedirs(GCODE_DIR, exist_ok=True)
    g = os.path.join(GCODE_DIR, name + ".gcode")
    if os.path.exists(g): os.remove(g)
    extra = SUPPORT_ARGS if supports else []
    r = subprocess.run(PS + ["--export-gcode"] + COMMON + ["--print-profile", PROFILES[prof]] + extra + ["-o", g,
                             os.path.join(OUT, name + ".3mf")], capture_output=True, text=True)
    log = r.stdout + r.stderr
    if r.returncode != 0 or not os.path.exists(g) or "outside of the print volume" in log:
        print(f"     FAIL slicing {name}: rc {r.returncode}", log.strip().splitlines()[-1:] if log.strip() else "")
        return 1
    t = open(g).read()
    def get(key):  # key as it appears in the G-code footer, matched literally
        m = re.search(r"^; " + re.escape(key) + r" = (.*)$", t, re.M)
        return m.group(1) if m else "?"
    print(f"     sliced: {get('estimated printing time (normal mode)')}, {get('total filament used [g]')} g, "
          f"layer {get('layer_height')}, {get('filament_settings_id')}, supports {get('support_material')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
