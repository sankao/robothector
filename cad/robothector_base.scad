// robothector_base.scad: shared parameters, interface constants and library.
// Single source of truth for every joint between the three assemblies.
// Spec: docs/superpowers/specs/2026-10-17-chassis-redesign-design.md
//
// Frame (all part files model their parts in this assembled frame):
//   X forward (cabin at +X), Y left, Z up.
//   Z = 0 ground. X = 0 bulkhead plane (cabin rear face). Y = 0 centreline.
//
// This file has no top-level geometry; include it from every .scad.

$fa = 4; $fs = 0.4;
grid_fn = 12;   // facets for the many small grid holes (keeps CGAL renders fast)
eps = 0.01;

// ======================= printer / fit =======================
bed        = [245, 205, 205];  // usable build volume (MK3S+ 250x210x210 minus margin)
clr_slide  = 0.25;             // per side, sliding fits (dovetail, cassette in well)
clr_face   = 0.2;              // gap between bolted mating faces
clr_vit    = 0.5;              // default gap around bought parts (vitamins)
max_bridge = 20;               // longest allowed unsupported bridge

// ======================= fasteners ===========================
// Tune these from fit_test.scad results; parts must never hard-code hole sizes.
// 2026-10-17 coupon (PETG, MK3S+): M3 pilot 2.8 best both orientations (2.5-2.7 too tight);
// modelled M5 thread best both orientations (4.1/4.3 pilots too tight); 2 mm rod: 2.4
// (2.0/2.2 too tight); dovetail 0.15 decent but slightly loose -> 0.10. Holes print
// ~0.2-0.4 mm small, so the clearance holes were opened by 0.2 (inferred, not tested).
m3_tap_d   = 2.8;   // self-tap pilot (coupon 2026-10-17)
m3_clear_d = 3.6;   // was 3.4; opened for the measured hole shrink
m3_head_d  = 6.2;   // counterbore for socket head (5.5 nominal)
m3_head_h  = 3.3;
m5_pilot_d = 4.3;   // self-tap pilot (mode "pilot")
m5_clear_d = 5.7;   // was 5.5; opened for the measured hole shrink
m5_head_d  = 9.2;
m5_head_h  = 5.3;
m5_pitch   = 0.8;
m5_major   = 5.0;
m5_thread_clr = 0.15;          // radial clearance added to the modelled thread
m5_mode_vertical   = "thread"; // M5 holes whose axis is vertical in print orientation
m5_mode_horizontal = "thread"; // ... horizontal in print orientation (coupon: thread works both ways)
m2_tap_d   = 1.7;
m25_tap_d  = 2.2;

// ======================= grid ================================
grid_pitch  = 20;          // universal M3 mounting grid, aligned to global multiples of 20
                           // (was 10; cut to a quarter of the holes on 2026-10-17). Where a mount
                           // needs finer positions it uses slots >= grid_pitch long in its feet.
grid_hole_d = m3_tap_d;
grid_edge   = 4;           // min distance from a hole centre to the range boundary
grid_slot_len = grid_pitch; // travel of slotted mounting feet (covers every position between nodes)
grid_min_t  = 4;           // min thickness of any grid surface

// ======================= global body =========================
body_w        = 140;   // overall width, wheels inside it
wall_t        = 4;     // default outer wall
floor_t       = 6;     // cabin and lower-carriage floors (Z 12..18)
z_floor       = 12;    // underside of every floor (ground clearance)
z_deck        = 67;    // top of lower carriage = underside of upper carriage
uc_floor_t    = 4;     // upper carriage floor (Z 67..71)
uc_front_wall_t = 4;   // upper carriage front wall (X -4.2..-0.2)
z_uc_top      = 127;   // top rim of the upper carriage tray
lid_t         = 4;     // lid Z 127..131 (grid surface)
z_cab_top     = 150;   // top of the cabin roof
roof_t        = 4;     // roof Z 146..150
bulkhead_t    = 4;     // cabin rear wall X 0..4
x_rear        = -240;  // rear face of both carriages (lower carriage rear wall = rear bumper)
x_cab_front   = 105;   // cabin front face
bumper_d      = 15;    // front bumper X 105..120
x_front_bay_rear = -160; // lower carriage is full width forward of this X
lc_wall_y     = [64, 70];  // |y| of the lower carriage front-bay side walls
lc_rear_wall_x = [-240, -232]; // lower carriage rear (bumper) wall
faceplate_opening = [[-66, 66], [70, 146]]; // cabin front opening: Y range, Z range

// ======================= wheels and motors ===================
DRIVE_wheel_d   = 63;          // soft; approximate
DRIVE_wheel_w   = 26;
DRIVE_axle      = [-200, 31.5];// [x, z]
DRIVE_gearbox_face_y = 41;     // |y| of the TT gearbox outer face (shaft side)
DRIVE_wheel_y_in = 43;         // |y| of the drive wheel inner face
DRIVE_wheel_range = [60, 66];  // wheel diameters the TT clamp can serve

// Keep-out for motors + clamps + wheels in the lower carriage motor zone:
// [[x0,x1], [|y|0,|y|1], [z0,z1]]; frame structure stays out of it.
MOTOR_keepout = [[-222, -140], [18, 41.5], [18, 45]];
// Wheel keep-out: everything outboard of |y| = 41.5 in this X range below z_deck.
MOTOR_wheel_keepout_x = [-236, -164];

// TT gearmotor (SunFounder drawing). Hole spacing is uncertain (15..17.5): clamps must slot.
TT_gearbox   = [64.4, 18.7, 22.3]; // length (along X), thickness (Y), height (Z)
TT_shaft_from_tab_end = 11.0;      // shaft axis from the gearbox's tab end
TT_shaft_d   = 5.5;
TT_shaft_flat = 3.7;
TT_shaft_len = 9.1;
TT_clip_t    = 22.6;               // thickness over the motor clip
TT_clip_len  = 20;                 // length of the clip region at the motor end (approx.)
TT_hole_d    = 2.8;
TT_hole_x    = 31.1;               // through-holes from the tab end (along X)
TT_hole_dz   = 17.5;               // spacing between the two through-holes (uncertain)
TT_tab       = [5.0, 6, 2.4];      // tab length beyond gearbox end, tab height, hole offset

OMNI_wheel_d    = 58;
OMNI_wheel_w    = 29;              // assumed maximum
OMNI_rod_d      = 2;
OMNI_rod_hole_d = 2.4;             // coupon 2026-10-17 (2.2 too tight)
OMNI_axle       = [66, 29];        // [x, z]
OMNI_adj        = 4;               // +/- ride height adjustment of the cassette
OMNI_well_x     = [33, 99];
OMNI_well_y     = [28, 66];        // |y| range of the well
OMNI_inner_wall_y = [24, 28];      // |y| of the inner well wall
OMNI_rear_wall_x  = [29, 33];      // cross wall closing the rear of each well
OMNI_well_top_z = 70;
OMNI_cheek_t    = 3;
OMNI_roof_t     = 3;
OMNI_cassette_w = OMNI_well_y[1] - OMNI_well_y[0] - 2*clr_slide; // 37.5

// ======================= joints ==============================
// J1: cabin <-> lower carriage. Dovetail tongue (part of the cabin floor) + 2x M5 along X.
J1_tongue_x = [-30, 0];
J1_tongue_z = [12, 22];
J1_tongue_w = [80, 96];            // width at x = 0, width at x = -30 (flares rearward)
J1_bolts    = [[60, 55], [-60, 55]]; // [y, z]; heads inside the cabin, screw runs -X
J1_col_y    = [52, 70];            // |y| of the lower-carriage wall columns holding the J1 threads
J1_col_x    = [-20, 0];
J1_engage   = 12;                  // min thread engagement in the column
J1_m5_mode  = m5_mode_horizontal;
J1_dovetail_clr = 0.10;            // per side, tongue in notch (coupon: 0.15 slightly loose)

// J2: upper carriage floor <-> lower carriage tops. 6x M3 vertical, heads inside the tray.
J2_holes  = [[-45, 62], [-45, -62], [-150, 62], [-150, -62], [-229, 30], [-229, -30]]; // [x, y]
J2_engage = 10;

// J3: upper carriage front wall <-> cabin bulkhead. 2x M5 along X, heads inside the tray.
J3_bolts  = [[50, 100], [-50, 100]]; // [y, z]
J3_engage = 12;                      // min engagement in the bulkhead bosses
J3_m5_mode = m5_mode_horizontal;

// Cable passages. P = [centre_a, centre_z, w, h]: rectangle w x h, then a 45 deg top
// narrowing to a flat of opening_flat. For P1/P2, centre_a is Y.
opening_flat = 16;
P1 = [0, 95, 40, 24];   // bulkhead + tray front wall
P2 = [0, 42, 40, 20];   // bulkhead, into the lower carriage front bay
P3_holes = [[-215, 0], [-30, 40]]; // tray floor, [x, y]
P3_d = 16;

// ======================= power bank bay (upper carriage) =====
BANK_bay_x      = [-195, -10];
BANK_bay_y      = [-50, 50];
BANK_max        = [155, 90, 32];   // largest supported bank (L, W, H)
BANK_plug_clear = 12;              // right-angle plugs behind the port face
BANK_port_face_x = BANK_bay_x[0] + BANK_plug_clear; // ports face -X
BANK_strap_x    = [-40, -140];     // strap slot centres (over the open front bay)
BANK_strap_w    = 22;

// ======================= screen + Pi unit ====================
SCREEN_board   = [106, 68];        // Waveshare 4.3" DSI
SCREEN_t       = 14.05;
SCREEN_active  = [94, 56];         // approx. 800x480 4.3" active area, assumed centred
SCREEN_corner_holes = [99.3, 61.8];
SCREEN_corner_hole_d = 2.7;        // probably M2.5; user has no M2.5 screws -> prefer a clamp frame
SCREEN_pillar  = 6;                // copper pillar between screen and Pi (unmeasured)
SCREEN_unit    = [108, 70, 45];    // envelope incl. Pi 4 and connectors (W, H, depth)
SCREEN_cable_clear = 25;           // free depth behind the unit for cables

// ======================= helper functions ====================
function grid_vals(r, pitch = grid_pitch, edge = grid_edge) =
    let(a = ceil((r[0] + edge) / pitch) * pitch, b = floor((r[1] - edge) / pitch) * pitch)
    a > b ? [] : [for (v = [a : pitch : b]) v];
function _in_rects(u, v, rects) =
    len([for (q = rects) if (u >= q[0] && u <= q[1] && v >= q[2] && v <= q[3]) 1]) > 0;
function _min_dist(x, y, pts) = len(pts) == 0 ? 1e9 : min([for (p = pts) norm([x - p[0], y - p[1]])]);
function pilot_d(screw) = screw == 5 ? m5_pilot_d : screw == 3 ? m3_tap_d
                        : screw == 2.5 ? m25_tap_d : m2_tap_d;
// Dovetail tongue outline in plan (x, y), grown by c on every side except the open front.
function j1_tongue_pts(c = 0) = [
    [J1_tongue_x[1] + (c > 0 ? 1 : 0), -(J1_tongue_w[0]/2 + c)],
    [J1_tongue_x[1] + (c > 0 ? 1 : 0),  (J1_tongue_w[0]/2 + c)],
    [J1_tongue_x[0] - c,  (J1_tongue_w[1]/2 + c)],
    [J1_tongue_x[0] - c, -(J1_tongue_w[1]/2 + c)]];

// ======================= orientation helpers =================
// Hole/opening modules are built along local -Z with the entry face at local z = 0.
// These map local -Z to a world direction, keeping local +Y as world +Z (up).
module into_x(dir) { if (dir < 0) rotate([90, 0, 90]) children(); else rotate([90, 0, -90]) children(); }
module into_y(dir) { if (dir > 0) rotate([90, 0, 0]) children(); else rotate([90, 0, 180]) children(); }
module into_z(dir) { if (dir < 0) children(); else rotate([180, 0, 0]) children(); }

// ======================= holes (negative solids) =============
// All: entry face at z = 0, solid from z = +0.5 down to z = -depth.
module _bore(d, depth) translate([0, 0, -depth]) cylinder(d = d, h = depth + 0.5);

module m3_tap(depth)            _bore(m3_tap_d, depth);
module m3_clear(depth, cbore = 0) {
    _bore(m3_clear_d, depth);
    if (cbore > 0) _bore(m3_head_d, cbore);
}
module m5_clear(depth, cbore = 0) {
    _bore(m5_clear_d, depth);
    if (cbore > 0) _bore(m5_head_d, cbore);
}
module pilot(screw, depth) _bore(pilot_d(screw), depth);

// ISO M5x0.8 internal thread cutter (right-hand), plus a lead-in chamfer.
function _thr_r(t, P, rmin, rmax) =
    let(u = (t <= 0.5 ? t : 1 - t) * P,          // axial distance from crest centre, 0..P/2
        ch = P / 16, rh = P / 8, fl = P / 2 - ch - rh)
    u <= ch ? rmax : u >= P / 2 - rh ? rmin : rmax - (u - ch) / fl * (rmax - rmin);
module m5_thread(depth) {
    P = m5_pitch;
    rmax = m5_major / 2 + m5_thread_clr;
    rmin = rmax - 0.5413 * P;                     // 5/8 H thread depth
    n = 48;
    h = depth + 0.5;
    pts = [for (i = [0 : n - 1]) let(a = 360 * i / n, r = _thr_r(i / n, P, rmin, rmax)) [r * cos(a), r * sin(a)]];
    translate([0, 0, -depth])
        linear_extrude(height = h, twist = -360 * h / P, slices = ceil(h / P * 16), convexity = 6)
            polygon(pts);
    translate([0, 0, -0.8]) cylinder(d1 = 2 * rmin, d2 = 2 * rmax + 1.2, h = 0.8 + eps); // lead-in
    translate([0, 0, 0]) cylinder(d = 2 * rmax + 1.2, h = 0.5);
}
module m5_hole(depth, mode = m5_mode_vertical) {
    if (mode == "thread") m5_thread(depth); else _bore(m5_pilot_d, depth);
}

// ======================= grids ==============================
// Holes at global multiples of grid_pitch inside the given ranges (inset by grid_edge).
// excl: list of [u0, u1, v0, v1] rectangles (in the same two coordinates) to skip.
module grid_z(xr, yr, z_top, depth, excl = [], d = grid_hole_d, dir = -1) {
    for (x = grid_vals(xr), y = grid_vals(yr)) if (!_in_rects(x, y, excl))
        translate([x, y, z_top]) into_z(dir) _bore(d, depth, $fn = grid_fn);
}
module grid_y(xr, zr, y_face, depth, dir, excl = [], d = grid_hole_d) {
    for (x = grid_vals(xr), z = grid_vals(zr)) if (!_in_rects(x, z, excl))
        translate([x, y_face, z]) into_y(dir) _bore(d, depth, $fn = grid_fn);
}
module grid_x(yr, zr, x_face, depth, dir, excl = [], d = grid_hole_d) {
    for (y = grid_vals(yr), z = grid_vals(zr)) if (!_in_rects(y, z, excl))
        translate([x_face, y, z]) into_x(dir) _bore(d, depth, $fn = grid_fn);
}

// ======================= shapes ==============================
// Opening: rectangle w x h centred on the origin (local X horizontal, local Y up), with a
// 45 deg top narrowing to a flat of width `flat` (<= max_bridge). Extruded along local -Z.
module pointed_profile(w, h, flat = opening_flat) {
    polygon([[-w/2, -h/2], [w/2, -h/2], [w/2, h/2], [flat/2, h/2 + (w - flat)/2],
             [-flat/2, h/2 + (w - flat)/2], [-w/2, h/2]]);
}
module pointed_opening(w, h, depth, flat = opening_flat) {
    translate([0, 0, -depth]) linear_extrude(depth + 0.5) pointed_profile(w, h, flat);
}
// Passage P through a wall normal to X at x_face, cutting depth in direction dir.
module passage_x(p, x_face, depth, dir) {
    translate([x_face, p[0], p[1]]) into_x(dir) pointed_opening(p[2], p[3], depth);
}

// Box with rounded vertical edges; corner at the origin (like cube()).
module rbox(size, r = 3) {
    if (r <= 0) cube(size);
    else hull() for (x = [r, size[0] - r], y = [r, size[1] - r])
        translate([x, y, 0]) cylinder(r = r, h = size[2]);
}

// ======================= adapter plates =====================
// Universal adapter: plate of `size` [w, d] centred on the origin, bottom at z = 0,
// thickness t. Install it with its centre on a grid node. M3 clearance holes sit at
// local grid nodes, and standoffs carry the component's own holes.
// holes: [[x, y], ...] in plate coordinates; hole_d: the pilot for the component screws.
module adapter_plate(size, holes, standoff_h = 5, hole_d = m3_tap_d, standoff_d = 6.5, t = 3) {
    keep = standoff_d / 2 + m3_head_d / 2 + 0.5;
    difference() {
        union() {
            translate([-size[0]/2, -size[1]/2, 0]) rbox([size[0], size[1], t], 3);
            for (h = holes) translate([h[0], h[1], 0]) cylinder(d = standoff_d, h = t + standoff_h);
        }
        for (h = holes) translate([h[0], h[1], t + standoff_h]) _bore(hole_d, t + standoff_h + 1);
        for (x = grid_vals([-size[0]/2, size[0]/2]), y = grid_vals([-size[1]/2, size[1]/2]))
            if (_min_dist(x, y, holes) > keep)
                translate([x, y, t]) _bore(m3_clear_d, t + 1);
    }
}
// Light-duty universal plate for boards with unknown hole patterns: M3 grid holes on
// rows y = 10k, pilot slots (screws self-tap into the slot walls) on rows y = 10k + 5,
// and zip-tie slots at the ends of the slot rows.
module slotted_plate(size, t = 3) {
    difference() {
        translate([-size[0]/2, -size[1]/2, 0]) rbox([size[0], size[1], t], 3);
        for (x = grid_vals([-size[0]/2, size[0]/2]), y = grid_vals([-size[1]/2, size[1]/2]))
            if (abs(x) >= size[0]/2 - grid_edge - grid_pitch)
                translate([x, y, t]) _bore(m3_clear_d, t + 1);
        for (y = [for (v = grid_vals([-size[1]/2 + 5, size[1]/2 + 5])) v - 5])
            if (abs(y) < size[1]/2 - 3) {
                hull() for (x = [-size[0]/2 + 16, size[0]/2 - 16]) translate([x, y, -1]) cylinder(d = m3_tap_d - 0.1, h = t + 2);
                for (s = [-1, 1]) translate([s * (size[0]/2 - 9) - 1, y - 2, -1]) cube([2, 4, t + 2]);
            }
    }
}
