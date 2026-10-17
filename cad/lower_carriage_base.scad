// lower_carriage_base.scad: LOWER CARRIAGE = frame + 2 TT motor clamps (+ their caps).
// Parameters and modules only, no top-level geometry. Every name starts with lc_.
// Spec: docs/superpowers/specs/2026-10-17-chassis-redesign-design.md, §5.3, §6 (J1, J2,
// drive motor interface) and §8 (lower carriage).
//
// Modelled in the global assembled frame: X forward, Y left, Z up, Z = 0 ground,
// X = 0 bulkhead plane (cabin at X > 0). Print orientation is applied only in
// lower_carriage.scad.
//
// Provides: lc_frame(), lc_clamp_body() / lc_cap() (left side; mirror for the right),
//           lc_assembled(), lc_vitamins().
include <robothector_base.scad>
include <vitamins.scad>

// ============================ frame parameters ============================
lc_x1        = -clr_face;             // front faces of floor, walls and J1 columns (bear on the bulkhead)
lc_floor_top = z_floor + floor_t;     // 18: top of the floor (clamps and grid adapters sit here)
lc_mz_y      = DRIVE_gearbox_face_y;  // 41: half-width of the narrow motor zone (wheels outboard of it)
lc_bay_y     = body_w / 2;            // 70: half-width of the front bay
lc_rear_r    = 8;    // plan radius of the rear bumper corners
lc_corner_r  = 3;    // other outer vertical edges (front-bay rear corners)
lc_neck_r    = 4;    // concave plan fillet of the floor at the X = x_front_bay_rear narrowing.
                     // Limited by the wheel keep-out: <= x_front_bay_rear - MOTOR_wheel_keepout_x[1].
lc_fillet    = 3;    // 45 deg wall-to-floor fillet strips (front bay walls, columns, rear wall)
lc_sh_t      = 5;    // shoulder (return) wall at the narrowing: X [x_front_bay_rear, + lc_sh_t]
lc_sh_y0     = 46;   // |y| of the shoulder wall's rounded inboard end (clears motor clip + clamp finger)
lc_sh_fillet = 10;   // plan fillet / gusset between the shoulder wall and the side wall (full height)
lc_col_fillet = 4;   // plan fillet between the J1 column rear face and the side wall
lc_spine_hw  = 4;    // spine rib half-width (spec: <= 8). The clamp feet sit just outboard of it.
lc_spine_top = MOTOR_keepout[2][1];   // 45
lc_spine_x1  = -150; // spine is full height back to the rear wall from here, 45 deg nose forward of it
lc_boss_r    = 5;    // J2 boss radius (dia 10 >= 2.5 x M3)
lc_boss_blend = 6;   // half-length of the boss-to-wall blend (hull) along the wall
lc_j2_depth  = J2_engage + 4;               // 14: M3x16 through the 4 mm tray floor leaves 2 mm spare
lc_j1_depth  = J1_col_x[1] - J1_col_x[0];   // 20: J1 M5 pilot runs through the 19.8 mm column
lc_grid_depth = floor_t + 1;                // floor grid holes go through the floor
lc_holes     = true; // false skips the grids: faster CGAL for interference checks (holes only remove material)

// ---------- grid exclusions ([u0, u1, v0, v1] in the grid's two coordinates) ----------
lc_notch_hw = J1_tongue_w[1] / 2 + J1_dovetail_clr;
function lc_box(p, h) = [p[0] - h, p[0] + h, p[1] - h, p[1] + h];
lc_floor_excl = concat(
    [[J1_tongue_x[0] - J1_dovetail_clr - grid_edge, 1e3, -(lc_notch_hw + grid_edge), lc_notch_hw + grid_edge],
     [-1e3, lc_spine_x1 + (lc_spine_top - lc_floor_top) + grid_edge, -(lc_spine_hw + grid_edge), lc_spine_hw + grid_edge]],
    [for (h = J2_holes) lc_box(h, lc_boss_r + grid_edge - 0.1)]);
lc_sh_excl_x = x_front_bay_rear + lc_sh_t + lc_sh_fillet + grid_edge - 0.1;  // shoulder gusset zone
lc_bay_excl = concat(lc_floor_excl, [
    [-1e3, 1e3, -(lc_mz_y - grid_edge), lc_mz_y - grid_edge],            // inner strip: done by the motor-zone grid
    [J1_col_x[0] - grid_edge, 1e3,  J1_col_y[0] - grid_edge,  1e3],       // J1 columns
    [J1_col_x[0] - grid_edge, 1e3, -1e3, -(J1_col_y[0] - grid_edge)],
    [-1e3, lc_sh_excl_x,  lc_wall_y[0] - lc_sh_fillet - grid_edge,  1e3], // shoulder gussets
    [-1e3, lc_sh_excl_x, -1e3, -(lc_wall_y[0] - lc_sh_fillet - grid_edge)]]);
lc_wall_excl = concat([[-1e3, lc_sh_excl_x + 1, -1e3, 1e3]],               // (x, z) on the side walls
    [for (h = J2_holes) if (abs(h[1]) > lc_mz_y) [h[0] - lc_boss_r - grid_edge, h[0] + lc_boss_r + grid_edge, -1e3, 1e3]]);

// ============================ 2D helpers ============================
module lc_rect(x0, x1, y0, y1) translate([x0, y0]) square([x1 - x0, y1 - y0]);
// Rectangle with per-corner radii r = [x0y0, x1y0, x1y1, x0y1] (0 = sharp).
module lc_rrect(x0, x1, y0, y1, r = [0, 0, 0, 0]) {
    c = [[x0, y0], [x1, y0], [x1, y1], [x0, y1]];
    s = [[1, 1], [-1, 1], [-1, -1], [1, -1]];
    hull() for (i = [0 : 3])
        if (r[i] > 0) translate(c[i] + s[i] * r[i]) circle(r = r[i]);
        else translate(c[i] - [s[i][0] < 0 ? eps : 0, s[i][1] < 0 ? eps : 0]) square(eps);
}
// Concave fillet of radius r in the corner at p, filling the quadrant towards (sx, sy).
module lc_cfillet(p, r, sx, sy) translate(p) difference() {
    scale([sx, sy]) square(r);
    translate([sx * r, sy * r]) circle(r = r);
}
module lc_side(s) { if (s > 0) children(); else mirror([0, 1, 0]) children(); }

// 45 deg fillet strip at the foot of a wall face normal to Y (y_face), running along X.
// dir: direction from the wall face into the free space (+1 / -1).
module lc_strip_x(x0, x1, y_face, dir, f = lc_fillet)
    translate([x0, 0, 0]) rotate([90, 0, 90]) linear_extrude(x1 - x0)
        polygon([[y_face - dir * 0.5, lc_floor_top - 0.5], [y_face + dir * (f + 0.5), lc_floor_top - 0.5],
                 [y_face - dir * 0.5, lc_floor_top + f + 0.5]]);
// Same for a wall face normal to X (x_face), running along Y.
module lc_strip_y(y0, y1, x_face, dir, f = lc_fillet)
    translate([0, y1, 0]) rotate([90, 0, 0]) linear_extrude(y1 - y0)
        polygon([[x_face - dir * 0.5, lc_floor_top - 0.5], [x_face + dir * (f + 0.5), lc_floor_top - 0.5],
                 [x_face - dir * 0.5, lc_floor_top + f + 0.5]]);

// ============================ frame ============================
// Floor plan: full-width front bay + narrow motor zone, rounded rear bumper corners,
// filleted narrowing. (The J1 notch is cut later, through floor and above it.)
module lc_floor_outline() {
    lc_rrect(x_rear, x_front_bay_rear + 1, -lc_mz_y, lc_mz_y, [lc_rear_r, 0, 0, lc_rear_r]);
    lc_rrect(x_front_bay_rear, lc_x1, -lc_bay_y, lc_bay_y, [lc_corner_r, 0, 0, lc_corner_r]);
    for (s = [-1, 1]) lc_cfillet([x_front_bay_rear, s * lc_mz_y], lc_neck_r, -1, s);
}

// Everything that rises from the floor to z_deck, in plan (one side, y > 0).
module lc_walls_half2d() {
    // front-bay side wall
    lc_rrect(x_front_bay_rear, lc_x1, lc_wall_y[0], lc_wall_y[1], [0, 0, 0, lc_corner_r]);
    // shoulder wall at the narrowing, rounded inboard end, plus the full-height gusset fillet
    lc_rrect(x_front_bay_rear, x_front_bay_rear + lc_sh_t, lc_sh_y0, lc_wall_y[1],
             [lc_sh_t / 2, lc_sh_t / 2, 0, lc_corner_r]);
    lc_cfillet([x_front_bay_rear + lc_sh_t, lc_wall_y[0]], lc_sh_fillet, 1, -1);
    // J1 column (front end of the side wall) and its fillet into the wall
    lc_rect(J1_col_x[0], lc_x1, J1_col_y[0], J1_col_y[1]);
    lc_cfillet([J1_col_x[0], lc_wall_y[0]], lc_col_fillet, -1, -1);
}
module lc_walls2d() {
    lc_walls_half2d();
    mirror([0, 1, 0]) lc_walls_half2d();
    // rear (bumper) wall: the floor outline behind lc_rear_wall_x[1], so it keeps the rounded corners
    intersection() {
        lc_floor_outline();
        lc_rect(x_rear - 1, lc_rear_wall_x[1], -lc_mz_y - 1, lc_mz_y + 1);
    }
    // J2 bosses: full-height pillars blended into their wall (no overhang in print)
    for (h = J2_holes) let(s = sign(h[1])) hull() {
        translate(h) circle(r = lc_boss_r);
        if (abs(h[1]) > lc_mz_y)   // front pairs: inside the side walls
            lc_rect(h[0] - lc_boss_blend, h[0] + lc_boss_blend,
                    min(s * lc_wall_y[0], s * (lc_wall_y[0] + 0.5)), max(s * lc_wall_y[0], s * (lc_wall_y[0] + 0.5)));
        else                       // rear pair: on the front face of the rear wall
            lc_rect(lc_rear_wall_x[1] - 0.5, lc_rear_wall_x[1], h[1] - lc_boss_blend, h[1] + lc_boss_blend);
    }
}

// Central spine rib in the motor zone, |y| <= lc_spine_hw, up to lc_spine_top, 45 deg nose.
module lc_spine() {
    rise = lc_spine_top - lc_floor_top;
    rotate([90, 0, 0]) linear_extrude(2 * lc_spine_hw, center = true)
        polygon([[lc_rear_wall_x[1] - 0.5, lc_floor_top - 0.5], [lc_spine_x1 + rise + 0.5, lc_floor_top - 0.5],
                 [lc_spine_x1, lc_spine_top], [lc_rear_wall_x[1] - 0.5, lc_spine_top]]);
}

module lc_fillets() {
    for (s = [-1, 1]) {
        lc_strip_x(x_front_bay_rear + lc_sh_t, J1_col_x[0], s * lc_wall_y[0], -s);   // side walls
        lc_strip_x(J1_col_x[0], lc_x1, s * J1_col_y[0], -s);                          // column inboard faces
        lc_strip_y(min(s * J1_col_y[0], s * lc_wall_y[0]), max(s * J1_col_y[0], s * lc_wall_y[0]),
                   J1_col_x[0], -1);                                                  // column rear faces
    }
    lc_strip_y(-lc_mz_y, lc_mz_y, lc_rear_wall_x[1], 1);                              // rear wall front face
}

module lc_frame_cuts() {
    // J1 notch: the cabin's dovetail tongue drops in from above; keep its full height free
    translate([0, 0, z_floor - 1]) linear_extrude(J1_tongue_z[1] - z_floor + 2) polygon(j1_tongue_pts(J1_dovetail_clr));
    // J1: M5 along X into the columns, entry at the column front face, running -X
    for (b = J1_bolts) translate([lc_x1, b[0], b[1]]) into_x(-1) m5_hole(lc_j1_depth, J1_m5_mode);
    // J2: vertical M3 pilots from z_deck down into the bosses
    for (h = J2_holes) translate([h[0], h[1], z_deck]) m3_tap(lc_j2_depth);
    if (lc_holes) {
        // floor grid: inner strip |y| <= lc_mz_y over the whole length (motor zone = clamp mounting standard) ...
        grid_z([lc_rear_wall_x[1], lc_x1], [-lc_mz_y, lc_mz_y], lc_floor_top, lc_grid_depth, lc_floor_excl);
        // ... and the outer front-bay rows
        grid_z([x_front_bay_rear, lc_x1], [-lc_wall_y[0], lc_wall_y[0]], lc_floor_top, lc_grid_depth, lc_bay_excl);
        // front-bay side walls (holes along Y, through the wall)
        for (s = [-1, 1])
            grid_y([x_front_bay_rear, J1_col_x[0]], [lc_floor_top, z_deck], s * lc_wall_y[1],
                   lc_wall_y[1] - lc_wall_y[0] + 1, -s, lc_wall_excl);
    }
}

module lc_frame() {
    difference() {
        union() {
            translate([0, 0, z_floor]) linear_extrude(floor_t) lc_floor_outline();
            translate([0, 0, z_floor]) linear_extrude(z_deck - z_floor) lc_walls2d();
            lc_spine();
            lc_fillets();
        }
        lc_frame_cuts();
    }
}

// ============================ TT motor clamp ============================
// One clamp per side, modelled for the LEFT side (+Y); the right one is its mirror.
// The gearbox drops into a pocket open at the top: inboard wall (with a step that matches the
// motor clip), rear block with a slot that captures the end tab, an outboard finger beside the
// motor clip (forward of the wheel), and a thin base plate under it. A flat cap screwed down with
// M3 closes the top. The gearbox outer face and the shaft stay free for the wheel.
// The clamp bolts to the 20 mm floor grid with 3 vertical M3: one through a rear foot behind the
// gearbox, two through a front pad ahead of the motor can (the only nodes not under the gearbox).
// Optional extras, all M3 self-tapping into the gearbox's own holes: 2 screws through vertical
// slots (cover a hole spacing of lc_tt_dz) and 1 through the end tab.
lc_axle_z    = DRIVE_axle[1]; // axle height, set by the clamp only: Z = wheel_d / 2 (wheels 60..66 -> 30..33)
lc_fit       = 0.3;   // in-plane clearance around the gearbox (pocket walls, tab slot)
lc_fit_z     = 0.15;  // clearance under and over the gearbox (base plate, cap)
lc_tab_t     = 3;     // TT end-tab thickness (as modelled in v_tt_motor)
lc_tt_dz     = [14, 18];  // TT through-hole spacing range covered by the slots (nominal TT_hole_dz)
// Floor screws: grid nodes (multiples of grid_pitch). [rear foot, front pad inboard, front pad outboard].
lc_cl_bolts  = [[-220, 20], [-140, 20], [-140, 40]];
lc_cl_head_r = m3_head_d / 2 + 0.4;   // free radius around a screw head
lc_cl_foot_t = 6;                     // rear foot and front pad thickness (M3x12 into the 6 mm floor)
lc_cl_x      = [MOTOR_keepout[0][0], -142]; // rear block X0 (rear J2 boss just behind); front of the base
lc_cl_wall_y0 = 13.5;                 // inboard face of the clamp wall (8.5 mm wall, 9.5 mm from the spine)
lc_cl_wall_x = [lc_cl_bolts[0][0] + lc_cl_head_r, lc_cl_bolts[1][0] - lc_cl_head_r]; // wall clears both heads
lc_rb_y0     = lc_cl_bolts[0][1] + lc_cl_head_r;  // rear block inboard face behind the wall (clears the rear head)
lc_cl_rfoot  = [[lc_cl_bolts[0][0] - 4.5, lc_cl_x[0]], [lc_cl_wall_y0, lc_rb_y0 + 1]]; // rear foot x0 / x1 is lc_rb_x1
lc_cl_pad_x  = [lc_cl_bolts[1][0] - 4, lc_cl_bolts[1][0] + 6]; // front pad, in front of the motor can
lc_cl_finger_x  = [-153.5, lc_cl_wall_x[1]]; // outboard finger beside the motor clip, forward of the wheel
lc_cl_finger_y1 = 51.5;
lc_cap_t     = 4;
lc_cap_depth = 9;     // cap screw pilots: M3x12 through the 4 mm cap
lc_cl_r      = 2;     // rounding of the cap corners

// Gearbox envelope (left side), from the TT_* and DRIVE_* constants.
lc_gx = [DRIVE_axle[0] - TT_shaft_from_tab_end, DRIVE_axle[0] - TT_shaft_from_tab_end + TT_gearbox[0]];
lc_gy = [DRIVE_gearbox_face_y - TT_gearbox[1], DRIVE_gearbox_face_y];
lc_gz = [lc_axle_z - TT_gearbox[2] / 2, lc_axle_z + TT_gearbox[2] / 2];
lc_gmid      = (lc_gy[0] + lc_gy[1]) / 2;
lc_clip_x0   = lc_gx[1] - TT_clip_len;
lc_clip_y    = [lc_gmid - TT_clip_t / 2, lc_gmid + TT_clip_t / 2];
lc_tab_x0    = lc_gx[0] - TT_tab[0];
lc_tab_y     = [lc_gmid - lc_tab_t / 2, lc_gmid + lc_tab_t / 2];
lc_tab_hole_x  = lc_gx[0] - TT_tab[2];
lc_body_hole_x = lc_gx[0] + TT_hole_x;
// Derived clamp dimensions.
lc_cl_base_t = lc_gz[0] - lc_fit_z - lc_floor_top;  // base plate under the gearbox (2.2 at axle 31.5)
lc_cl_top    = lc_gz[1] + lc_fit_z;                 // top of the clamp body = cap underside
lc_cl_face_y      = lc_gy[0] - lc_fit;              // pocket inboard face (gearbox)
lc_cl_face_clip_y = lc_clip_y[0] - lc_fit;          // ... and along the thicker motor clip
lc_rb_x1     = lc_gx[0] - lc_fit;                   // rear block front face
lc_slot = [[lc_tab_x0 - lc_fit, lc_rb_x1 + 1],      // tab slot [x, y, z] ranges, open at the top
           [lc_tab_y[0] - lc_fit, lc_tab_y[1] + lc_fit],
           [lc_axle_z - TT_tab[1] / 2 - lc_fit_z, lc_cl_top + 1]];
lc_cl_finger_y0 = lc_clip_y[1] + lc_fit;
lc_wall_mid  = (lc_cl_wall_y0 + lc_cl_face_y) / 2;
lc_cap_screws = [[-217, (lc_slot[1][1] + DRIVE_gearbox_face_y) / 2],   // rear block, outboard post
                 [-205, lc_wall_mid], [-170, lc_wall_mid],             // clamp wall
                 [(lc_cl_finger_x[0] + lc_cl_finger_x[1]) / 2, (lc_cl_finger_y0 + lc_cl_finger_y1) / 2]]; // finger

// Sanity checks on the parameters (no geometry).
assert(lc_cl_base_t >= 0.6, "axle too low: no base plate under the gearbox (wheel < 60?)");
assert(lc_axle_z + DRIVE_wheel_d / 2 < z_deck, "drive wheel hits the upper carriage");
assert(lc_cl_top + lc_cap_t + m3_head_h < z_deck, "clamp cap screws hit the upper carriage");
assert(lc_axle_z + lc_tt_dz[1] / 2 + m3_clear_d / 2 < lc_cl_top, "body-hole slot breaks out of the wall top");
assert(lc_neck_r <= x_front_bay_rear - MOTOR_wheel_keepout_x[1], "neck fillet enters the wheel keep-out");
assert(lc_spine_hw <= 8 && lc_cl_wall_y0 > lc_spine_hw + 2, "spine too wide");
assert(lc_j1_depth >= J1_engage + 2, "J1 pilot too short");
assert(lc_sh_y0 > lc_clip_y[1] + 2 && x_front_bay_rear + lc_sh_t < lc_cl_finger_x[0], "shoulder wall hits the motor clamp");
for (b = lc_cl_bolts) assert(b[0] % grid_pitch == 0 && b[1] % grid_pitch == 0, "clamp bolt off the grid");
assert(lc_cl_wall_x[0] < lc_gx[0] - TT_tab[0] && lc_cl_wall_x[1] > lc_gx[1], "clamp wall shorter than the gearbox");
assert(lc_rb_y0 < lc_slot[1][0] - 4, "rear block too thin beside the tab slot");
echo(lc_tt_shaft = [lc_gx[0] + TT_shaft_from_tab_end, DRIVE_gearbox_face_y, lc_axle_z], DRIVE_axle = DRIVE_axle);

// Clamp plan outline (also the cap outline before rounding).
module lc_cl_plan2d() {
    lc_rect(lc_cl_x[0], lc_cl_wall_x[1], lc_rb_y0, DRIVE_gearbox_face_y);        // behind/beside the gearbox
    lc_rect(lc_cl_wall_x[0], lc_cl_wall_x[1], lc_cl_wall_y0, DRIVE_gearbox_face_y); // wall + pocket
    lc_rect(lc_cl_finger_x[0], lc_cl_finger_x[1], lc_cl_wall_y0, lc_cl_finger_y1);  // finger region
}
module lc_cl_wall2d() {
    lc_rect(lc_cl_wall_x[0], lc_clip_x0 - lc_fit, lc_cl_wall_y0, lc_cl_face_y);
    lc_rect(lc_clip_x0 - lc_fit - eps, lc_cl_wall_x[1], lc_cl_wall_y0, lc_cl_face_clip_y);
}

module lc_clamp_body() {
    h = lc_cl_top - lc_floor_top;
    difference() {
        translate([0, 0, lc_floor_top]) union() {
            linear_extrude(lc_cl_base_t) lc_cl_plan2d();                                          // base plate
            linear_extrude(lc_cl_foot_t) lc_rect(lc_cl_rfoot[0][0], lc_rb_x1, lc_cl_rfoot[1][0], lc_cl_rfoot[1][1]); // rear foot
            linear_extrude(lc_cl_foot_t) lc_rect(lc_cl_pad_x[0], lc_cl_pad_x[1], lc_cl_wall_y0, lc_cl_finger_y1);    // front pad
            linear_extrude(lc_cl_foot_t) lc_rect(lc_cl_finger_x[0], lc_cl_pad_x[1], lc_cl_finger_y0, lc_cl_finger_y1); // finger plinth
            linear_extrude(h) lc_cl_wall2d();                                                     // inboard wall
            linear_extrude(h) lc_rect(lc_cl_x[0], lc_rb_x1, lc_rb_y0, DRIVE_gearbox_face_y);     // rear block
            linear_extrude(h) lc_rect(lc_cl_wall_x[0], lc_rb_x1, lc_cl_wall_y0, DRIVE_gearbox_face_y);
            linear_extrude(h) lc_rect(lc_cl_finger_x[0], lc_cl_finger_x[1], lc_cl_finger_y0, lc_cl_finger_y1); // finger
        }
        // tab slot, open at the top
        translate([lc_slot[0][0], lc_slot[1][0], lc_slot[2][0]])
            cube([lc_slot[0][1] - lc_slot[0][0], lc_slot[1][1] - lc_slot[1][0], lc_slot[2][1] - lc_slot[2][0]]);
        // floor screws (heads on the rear foot / front pad, reachable from above with the cap on)
        for (b = lc_cl_bolts) translate([b[0], b[1], lc_floor_top + lc_cl_foot_t]) m3_clear(lc_cl_foot_t + 1);
        // cap screw pilots
        for (c = lc_cap_screws) translate([c[0], c[1], lc_cl_top]) m3_tap(lc_cap_depth);
        // optional M3 through the gearbox body holes: vertical slots in the wall
        for (s = [-1, 1]) hull() for (d = lc_tt_dz / 2)
            translate([lc_body_hole_x, lc_cl_wall_y0, lc_axle_z + s * d]) into_y(1) m3_clear(lc_cl_face_y - lc_cl_wall_y0 + 1);
        // optional M3 through the end tab: clearance up to the slot, pilot in the outboard post
        translate([lc_tab_hole_x, lc_cl_wall_y0, lc_axle_z]) into_y(1) m3_clear(lc_slot[1][0] - lc_cl_wall_y0 + 0.5);
        translate([lc_tab_hole_x, lc_slot[1][1], lc_axle_z]) into_y(1) m3_tap(DRIVE_gearbox_face_y - lc_slot[1][1] - 1.5);
    }
}

// Flat cap over the gearbox (left side). Through holes only, so the same print serves both
// sides: flip it over for the right clamp. It leaves the floor-screw heads uncovered.
module lc_cap2d() offset(r = lc_cl_r) offset(delta = -lc_cl_r) lc_cl_plan2d();
module lc_cap() {
    difference() {
        translate([0, 0, lc_cl_top]) linear_extrude(lc_cap_t) lc_cap2d();
        for (c = lc_cap_screws) translate([c[0], c[1], lc_cl_top + lc_cap_t]) m3_clear(lc_cap_t + 1);
    }
}

// ============================ assemblies ============================
module lc_clamps() for (s = [-1, 1]) lc_side(s) { lc_clamp_body(); lc_cap(); }
module lc_assembled() {
    lc_frame();
    lc_clamps();
}
module lc_vitamins() for (s = [-1, 1]) { v_tt_motor_placed(s); v_drive_wheel_placed(s); }
