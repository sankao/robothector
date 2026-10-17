// upper_carriage_base.scad: Robothector upper carriage (cargo tray for the power electronics).
// Parameters and modules only, no top-level geometry. Every name here starts with uc_.
// Spec: docs/superpowers/specs/2026-10-17-chassis-redesign-design.md, sections 6 (J2, J3, P1, P3),
// 7.3 (bank clamp), 7.5 (speaker), 7 layout, 8 (upper carriage).
//
// Frame: global assembled frame (X forward, Y left, Z up, Z = 0 ground, X = 0 bulkhead plane).
// The tray and the lid are modelled in place. The small parts (clamp hardware, plates, speaker
// ring, knob) are modelled in their own print frame and placed by uc_*_placed / uc_clamp_set;
// upper_carriage.scad picks the print frame for export.
//
// Printed parts (per truck):
//   tray x1, lid x1, clamp_post x3, pusher x3, rear_stop x2, knob x5,
//   l298n_plate x1, pd_plate x1, speaker_ring x1
include <robothector_base.scad>
include <vitamins.scad>

// ============================ tray shell ==============================
uc_x_front = -clr_face;                                   // tray front face (bulkhead gap)
uc_wf_x    = [uc_x_front - uc_front_wall_t, uc_x_front];  // front wall X range
uc_in_x    = [x_rear + wall_t, uc_wf_x[0]];               // interior X range
uc_in_y    = body_w / 2 - wall_t;                         // interior |y| (side wall inner face)
uc_zf      = z_deck + uc_floor_t;                         // floor top
uc_r_out   = 6;                    // outer vertical-edge fillet radius (tray + lid plan)
uc_r_in    = uc_r_out - wall_t;    // inner fillet, same centre -> uniform 4 mm wall in the corners

// ============================ floor features ==========================
uc_strap_t = 4;                                        // strap slot width across Y (20 mm hook-and-loop)
uc_strap_y = BANK_bay_y[1] + 2 + uc_strap_t / 2;       // |y| of the slot centre, just outboard of the bay
uc_floor_excl = concat(                                // floor-grid exclusions [x0, x1, y0, y1]
    [for (h = J2_holes) [h[0] - 6, h[0] + 6, h[1] - 6, h[1] + 6]],
    [for (p = P3_holes) [p[0] - P3_d/2 - 2.5, p[0] + P3_d/2 + 2.5, p[1] - P3_d/2 - 2.5, p[1] + P3_d/2 + 2.5]],
    [for (sx = BANK_strap_x, s = [-1, 1])
        [sx - BANK_strap_w/2 - 3, sx + BANK_strap_w/2 + 3,
         s * uc_strap_y - uc_strap_t/2 - 3.5, s * uc_strap_y + uc_strap_t/2 + 3.5]]);

// ============================ walls ===================================
// Lid thumbscrews: vertical M3 pilots in corbel bosses on the rear wall's inner face.
uc_ts_pos    = [[x_rear + wall_t + 4, 55], [x_rear + wall_t + 4, -55]]; // [x, y] screw axes (outboard of the L298N plate)
uc_ts_boss_d = 9;                  // >= 2.5 x M3
uc_ts_boss_h = 12;                 // cylindrical part under the rim; 45 deg corbel below it
uc_ts_pilot  = 11;                 // pilot depth (M3x12 thumbscrew: lid 4 + 8)
// Charging-cable notch: open-top U in the right (-Y) wall; the lid closes it into a slot.
uc_chg_x = -195;                   // centre X, beside the bank's port end
uc_chg_w = 18;                     // >= 15
uc_chg_h = 12;                     // >= 10
// Rear-wall vent slots behind the L298N (its board's solder side faces the wall).
uc_vent_y = [-12, -6, 0, 6, 12];
uc_vent_w = 3;
uc_vent_z = [86, 114];
// Lid hooks: lips on the front wall's inner face, hook tabs on the lid.
uc_lip_d    = 3;                   // lip protrusion from the front wall inner face (-X)
uc_lip_h    = 6;                   // lip height (45 deg underside over uc_lip_d, then vertical)
uc_hook_y   = 34;                  // |y| centre of each hook (clear of P1 and the J3 heads)
uc_hook_w   = 20;
uc_hook_t   = 4;                   // hook tab thickness (X)
uc_hook_clr = 0.25;                // tab-to-lip clearance in X
uc_hook_gap = 0.4;                 // vertical gap between the nose and the lip underside
uc_hook_drop = 9;                  // tab length below the lid underside
uc_lid_slide = uc_lip_d + 0.5;     // the lid slides this far rearward to unhook

uc_wall_l_excl = [];                                         // left side wall: PD plate uses the grid
uc_wall_r_excl = [[uc_chg_x - uc_chg_w/2 - 4, uc_chg_x + uc_chg_w/2 + 4,
                   z_uc_top - uc_chg_h - 4, z_uc_top + 1]];  // charging notch
uc_wall_rear_excl = concat(
    [[uc_vent_y[0] - 3, uc_vent_y[len(uc_vent_y) - 1] + 3, uc_vent_z[0] - 2, uc_vent_z[1] + 2]],
    [for (p = uc_ts_pos) [p[1] - 6, p[1] + 6, 104, z_uc_top + 1]]);

// ============================ lid =====================================
uc_spk_x = -180;                   // speaker axis (grid node), over the bay's rear half, clear of the rear strap
uc_spk_y = 0;
uc_grille_r = 25.5;                // grille hole field radius (field >= 50 mm), inside the ring's diagonal nodes
uc_grille_d = 3.6;                 // grille holes (not fasteners)
uc_grille_p = 6;                   // hex pitch
uc_lid_excl = concat(
    [[uc_spk_x - uc_grille_r - 2, uc_spk_x + uc_grille_r + 2, uc_spk_y - 1, uc_spk_y + 1],   // grid nodes inside the
     [uc_spk_x - 1, uc_spk_x + 1, uc_spk_y - uc_grille_r - 2, uc_spk_y + uc_grille_r + 2]],  // grille: on its axes only
    [for (s = [-1, 1]) [uc_in_x[1] - uc_lip_d - uc_hook_clr - uc_hook_t - 5, uc_in_x[1] + 1,
                        s * uc_hook_y - uc_hook_w/2 - 4, s * uc_hook_y + uc_hook_w/2 + 4]],
    [for (p = uc_ts_pos) [p[0] - 6, p[0] + 6, p[1] - 6, p[1] + 6]]);

// ============================ speaker ring ============================
uc_speaker_d = 40;                 // speaker diameter (28..50)
uc_speaker_h = 20;                 // speaker depth (<= 20)
uc_spk_clr   = 0.3;                // radial clearance in the cup
uc_spk_gap   = 0.2;                // speaker front face below the lid underside
uc_spk_wall  = 2.5;
uc_spk_lip   = 2;                  // 45 deg retaining lip at the back of the cup
uc_spk_flange_t = 4;               // M3x8 = flange + lid
uc_spk_notch = 5;                  // wire notch width
// Ring bolt patterns (grid nodes relative to the axis); the first one that clears the cup is used.
uc_spk_bolt_sets = [[for (sx = [-1, 1], sy = [-1, 1]) [sx * grid_pitch, sy * grid_pitch]],       // up to ~44 mm speakers
                    [for (sx = [-1, 1], sy = [-1, 1]) [sx * 2 * grid_pitch, sy * grid_pitch]]];  // up to 50 mm
function uc_spk_bolts_for(d) = let(need = d / 2 + uc_spk_clr + uc_spk_wall + m3_head_d / 2 + 0.5,
    ok = [for (b = uc_spk_bolt_sets) if (min([for (q = b) norm(q)]) >= need) b]) len(ok) > 0 ? ok[0] : undef;
uc_spk_bolts = uc_spk_bolts_for(uc_speaker_d);

// ============================ bank clamp ==============================
// Clamp unit = clamp_post (2x M3 into two floor-grid rows, slotted along the push axis) + M3 set
// screw (self-taps into the post's horizontal pilot) + knob pressed on the screw head +
// pusher plate (captive cup for the screw tip, foam pad recess facing the bank).
// Local "push frame" of a unit: origin on the floor top, on the screw axis, at the upright's
// front (head-side) face; the screw pushes along -x; z up.
uc_screw_lengths = [5, 6, 8, 10, 12, 16, 20, 25]; // M3 lengths assumed on hand
uc_post_d    = 7;                  // upright depth along the screw = thread engagement
uc_post_w    = 12;
uc_post_h    = 18;
uc_axis_h    = 11;                 // set-screw axis above the floor top (pushes a 20 mm bank mid-height)
uc_ear_t     = 4;                  // base + rails thickness: M3x8 = rail + floor
uc_pusher_t  = 6;
uc_pusher_w  = 30;                 // fits the 60 mm minimum bank; stays between the post's rails
uc_pusher_h  = 16;
uc_cup_lip   = 1.6;                // tapped lip at the cup mouth (the tip threads through it ...)
uc_cup_len   = 2;                  // ... into a free chamber: the pusher is captive on the screw
uc_cup_depth = uc_cup_lip + uc_cup_len;
uc_foam_opts = [1, 2, 3];          // compressed foam pad thickness (pusher rim to bank) the layout may pick:
                                   // with 4 mm steps between screw lengths, the foam fills the gaps
uc_foam_recess = 1;
uc_tip_gap   = 0.5;                // min gap pusher back face to post
uc_travel_min = 0.3;               // min remaining travel at the clamped position
uc_head_h    = m3_head_h - 0.3;    // nominal M3 socket head height
uc_knob_d    = 13;
uc_knob_cap  = 0.6;                // 3 layers: keeps the knob short where the head is near a wall
uc_knob_len  = uc_knob_cap + uc_head_h;
uc_knob_pocket_d = m3_head_d - 0.8; // press fit on the knurled head (0.1 under nominal)
uc_key_d     = 3.0;                // a 2.5 mm hex key still reaches the socket through the cap
// Feet: two rails at cross offset +-grid_pitch (on two grid rows), slotted along the push axis.
// The rails run from just short of the bank face (rear end) to just short of the wall in the
// max-bank case (front end), so the slot is as long as the max bank allows (12.8 mm, not
// grid_slot_len: see uc_cl_solve, the set screw's travel covers the rest of each 20 mm step).
uc_rail_dy   = grid_pitch;
uc_rail_w    = m3_clear_d + 2 * 2.6;
uc_rail_x    = [-(uc_post_d + uc_tip_gap + uc_pusher_t + uc_foam_opts[0]) + 0.5, 6.2]; // local x range
uc_rail_y    = uc_rail_dy + uc_rail_w / 2;                                             // outer |y|
uc_slot      = [uc_rail_x[0] + 2 + m3_clear_d / 2, uc_rail_x[1] - 2 - m3_clear_d / 2]; // bolt centre range
// Rear stops (port end corner posts): 2x M3 along X (X -200, -220), slotted grid_slot_len in Y
// so a stop can sit at any |y| (the bank pushes on it along X only).
uc_stop_gap  = 0.5;                // stop face to bank port face
uc_stop_slot = grid_slot_len / 2;  // +- around the slot centre
uc_stop_w    = 2 * (uc_stop_slot + m3_clear_d / 2 + 2);   // Y
uc_stop_h    = 15;                 // top below the L298N motor terminals (Z 86.5)
uc_stop_cb   = 3;                  // head channel depth: M3x16 = (stop - channel) + floor
uc_stop_face = BANK_port_face_x - uc_stop_gap;
uc_stop_node = floor((uc_stop_face - m3_head_d / 2 - 2) / grid_pitch) * grid_pitch; // front bolt X
uc_stop_front = uc_stop_face - uc_stop_node;         // local x of the contact face
uc_stop_back  = -grid_pitch - (m3_head_d / 2 + 2);   // local x of the back face (2nd bolt at x = -grid_pitch)

// ============================ L298N plate =============================
// A frame on the rear-wall grid: the board's solder side faces the wall through a window,
// the board sits on 4 corner bosses (pilot slots +-1 mm radial: pattern uncertain).
uc_l298n_zc     = 100;             // board centre Z (grid node)
uc_l298n_plate_t = 4;              // M3x8 = plate + rear wall; board back at x_rear + wall_t + 4
uc_l298n_plate_size = [89, 49];    // Y x Z
uc_l298n_plate_v0 = -24.5;         // plate bottom edge (Z 75.5: clears the J2 rear heads, Z <= 74.3)
uc_l298n_boss_d = 9;
uc_l298n_slot   = 1;
uc_l298n_grid   = [for (y = [-2, 2], z = [-1, 1]) [y * grid_pitch, z * grid_pitch]]; // rear-wall nodes used (y +-40, Z 80/120)
uc_l298n_xb     = uc_in_x[0] + uc_l298n_plate_t;              // board back face X

// ============================ PD trigger plate ========================
uc_pd_xc = -200;                   // plate centre X on the left (+Y) wall (grid column)
uc_pd_zc = 100;                    // grid row used
uc_pd_t  = 4;                      // M3x8 = plate + wall
uc_pd_size = [34, 49];             // X x Z
uc_pd_holes = [[0, -grid_pitch], [0, grid_pitch]]; // [u, v] of the two grid screws (Z 80, 120)
uc_pd_board = [30, 12];
uc_pd_rail_t = 1.6;
uc_pd_rail_h = 1.5;
uc_pd_rail_l = 20;
uc_tie_w = 5;                      // zip-tie slot length (along u), ties up to 4.8 wide
uc_tie_t = 2.5;                    // slot width
uc_tie_v = uc_pd_board[1] / 2 + 0.3 + uc_pd_rail_t + 1.5 + uc_tie_t / 2; // slot centre |v|
uc_tie_groove = 1.6;               // groove on the wall side for the tie

// ============================ helpers =================================
function uc_overlaps(a, b) = a[0] < b[1] && b[0] < a[1];
module uc_rrect(x0, x1, y, r) translate([x0 + r, -y + r]) offset(r = r) square([x1 - x0 - 2 * r, 2 * y - 2 * r]);

// ============================ tray ====================================
// Walls only (Z uc_zf..z_uc_top); the floor slab is separate so each takes only its own holes
// (keeps OpenCSG previews working: one difference with every grid hole overflows its normalizer).
module uc_tray_walls() {
    difference() {
        translate([0, 0, uc_zf]) linear_extrude(z_uc_top - uc_zf) uc_rrect(x_rear, uc_x_front, body_w / 2, uc_r_out);
        translate([0, 0, uc_zf - 1]) linear_extrude(z_uc_top - uc_zf + 2) uc_rrect(uc_in_x[0], uc_in_x[1], uc_in_y, uc_r_in);
    }
}
module uc_tray_floor_slab() translate([0, 0, z_deck]) linear_extrude(uc_floor_t) uc_rrect(x_rear, uc_x_front, body_w / 2, uc_r_out);
// Corbel boss for a lid thumbscrew: cylinder under the rim plus a 45 deg underside into the wall.
module uc_ts_corbel(p) {
    r = uc_ts_boss_d / 2;
    zb = z_uc_top - uc_ts_boss_h;
    reach = p[0] + r - uc_in_x[0];
    difference() {
        hull() {
            translate([p[0], p[1], zb]) cylinder(r = r, h = uc_ts_boss_h);
            translate([uc_in_x[0] - 1, p[1] - r, zb - reach]) cube([1, 2 * r, uc_ts_boss_h + reach]);
        }
        translate([p[0], p[1], z_uc_top]) m3_tap(uc_ts_pilot);
    }
}
// Lip on the front wall inner face that the lid hook slides under (45 deg underside).
module uc_front_lip(s) {
    xw = uc_in_x[1]; zl = z_uc_top - uc_lip_h; w = uc_hook_w + 4;
    translate([0, s * uc_hook_y + w / 2, 0]) rotate([90, 0, 0]) linear_extrude(w)
        polygon([[xw + 1, zl], [xw, zl], [xw - uc_lip_d, zl + uc_lip_d], [xw - uc_lip_d, z_uc_top], [xw + 1, z_uc_top]]);
}
module uc_strap_slot(sx, y) {
    hull() for (dx = [-1, 1]) translate([sx + dx * (BANK_strap_w - uc_strap_t) / 2, y, z_deck - 1])
        cylinder(d = uc_strap_t, h = uc_floor_t + 2);
}
module uc_charge_notch() {
    r = 3;
    hull() {
        for (dx = [-1, 1]) translate([uc_chg_x + dx * (uc_chg_w / 2 - r), -body_w / 2 - 1, z_uc_top - uc_chg_h + r])
            rotate([-90, 0, 0]) cylinder(r = r, h = wall_t + 2);
        translate([uc_chg_x - uc_chg_w / 2, -body_w / 2 - 1, z_uc_top]) cube([uc_chg_w, wall_t + 2, 1]);
    }
}
module uc_rear_vents() {
    r = uc_vent_w / 2;
    for (y = uc_vent_y) hull() for (z = [uc_vent_z[0] + r, uc_vent_z[1] - r])
        translate([x_rear - 1, y, z]) rotate([0, 90, 0]) cylinder(r = r, h = wall_t + 2);
}
module uc_tray() {
    // floor: J2 (heads on the floor top), P3, strap slots, grid
    difference() {
        uc_tray_floor_slab();
        for (h = J2_holes) translate([h[0], h[1], uc_zf]) m3_clear(uc_floor_t + 0.5);
        for (p = P3_holes) translate([p[0], p[1], z_deck - 1]) cylinder(d = P3_d, h = uc_floor_t + 2);
        for (sx = BANK_strap_x, s = [-1, 1]) uc_strap_slot(sx, s * uc_strap_y);
        grid_z(uc_in_x, [-uc_in_y, uc_in_y], uc_zf, uc_floor_t + 0.5, excl = uc_floor_excl);
    }
    difference() {
        union() {
            uc_tray_walls();
            for (p = uc_ts_pos) uc_ts_corbel(p);
            for (s = [-1, 1]) uc_front_lip(s);
        }
        // side walls
        grid_y(uc_in_x, [uc_zf, z_uc_top],  body_w / 2, wall_t + 0.5, -1, excl = uc_wall_l_excl);
        grid_y(uc_in_x, [uc_zf, z_uc_top], -body_w / 2, wall_t + 0.5,  1, excl = uc_wall_r_excl);
        uc_charge_notch();
        // rear wall
        grid_x([-uc_in_y, uc_in_y], [uc_zf, z_uc_top], x_rear, wall_t + 0.5, 1, excl = uc_wall_rear_excl);
        uc_rear_vents();
        // front wall: J3 (2x M5 along X, heads inside) and P1
        for (b = J3_bolts) translate([uc_x_front, b[0], b[1]]) into_x(-1) m5_clear(uc_front_wall_t + 0.5);
        passage_x(P1, uc_x_front, uc_front_wall_t + 0.5, -1);
    }
}

// ============================ lid =====================================
function uc_nose_z(x) = (z_uc_top - uc_lip_h - uc_hook_gap) + (uc_in_x[1] - x); // parallel to the lip underside
module uc_lid_hook(s) {
    xw = uc_in_x[1];
    xt = xw - uc_lip_d - uc_hook_clr;            // tab front face
    zb = z_uc_top - uc_hook_drop;                // tab and nose bottom
    xn = xw - 0.5;                               // nose front face
    translate([0, s * uc_hook_y + uc_hook_w / 2, 0]) rotate([90, 0, 0]) linear_extrude(uc_hook_w)
        polygon([[xt - uc_hook_t, zb], [xn, zb], [xn, uc_nose_z(xn)], [xt, uc_nose_z(xt)],
                 [xt, z_uc_top + 1], [xt - uc_hook_t, z_uc_top + 1]]);
}
module uc_grille_holes() {
    n = ceil(uc_grille_r / uc_grille_p) + 1;
    for (i = [-n : n], j = [-n : n]) {
        x = (i + (j % 2 == 0 ? 0 : 0.5)) * uc_grille_p;
        y = j * uc_grille_p * sin(60);
        if (norm([x, y]) <= uc_grille_r - uc_grille_d / 2)
            translate([uc_spk_x + x, uc_spk_y + y, z_uc_top - 1]) cylinder(d = uc_grille_d, h = lid_t + 2, $fn = 16);
    }
}
module uc_lid() {
    difference() {
        translate([0, 0, z_uc_top]) linear_extrude(lid_t) uc_rrect(x_rear, uc_x_front, body_w / 2, uc_r_out);
        grid_z(uc_in_x, [-uc_in_y, uc_in_y], z_uc_top + lid_t, lid_t + 0.5, excl = uc_lid_excl);
        uc_grille_holes();
        for (p = uc_ts_pos) translate([p[0], p[1], z_uc_top + lid_t]) m3_clear(lid_t + 0.5);
    }
    difference() {
        for (s = [-1, 1]) uc_lid_hook(s);
        translate([x_rear, -body_w, z_uc_top]) cube([-x_rear, 2 * body_w, 10]);  // trim the tab tops to the lid
    }
}

// ============================ knob ====================================
// Print frame: cap on z = 0, head pocket opening at z = uc_knob_len.
module uc_knob() {
    difference() {
        cylinder(d = uc_knob_d, h = uc_knob_len);
        translate([0, 0, uc_knob_cap]) cylinder(d = uc_knob_pocket_d, h = uc_knob_len);
        translate([0, 0, -1]) cylinder(d = uc_key_d, h = uc_knob_len + 2);
        for (a = [0 : 36 : 359]) rotate(a) translate([uc_knob_d / 2 + 0.3, 0, -1]) cylinder(r = 1.1, h = uc_knob_len + 2, $fn = 12);
    }
}

// ============================ clamp hardware ==========================
// clamp_post, in its push frame (= print frame: base on z = 0).
module uc_clamp_post() {
    difference() {
        union() {
            translate([-uc_post_d, -uc_post_w / 2, 0]) rbox([uc_post_d, uc_post_w, uc_post_h], 1.5);
            // base under the upright and the knob, joining the two rails (the pusher rides between the rails)
            translate([-uc_post_d, -uc_rail_y, 0]) rbox([uc_rail_x[1] + uc_post_d, 2 * uc_rail_y, uc_ear_t], 2);
            for (s = [-1, 1]) translate([uc_rail_x[0], s * uc_rail_dy - uc_rail_w / 2, 0])
                rbox([uc_rail_x[1] - uc_rail_x[0], uc_rail_w, uc_ear_t], 2);
        }
        translate([0, 0, uc_axis_h]) into_x(-1) m3_tap(uc_post_d + 0.5);          // set-screw pilot
        for (s = [-1, 1]) hull() for (x = uc_slot) translate([x, s * uc_rail_dy, uc_ear_t]) m3_clear(uc_ear_t + 0.5); // floor-bolt slots
    }
}
// pusher, print frame: back face (screw side) on z = 0, bank face up, cup on the z axis.
module uc_pusher_print() {
    difference() {
        translate([-uc_pusher_w / 2, -uc_pusher_h / 2, 0]) rbox([uc_pusher_w, uc_pusher_h, uc_pusher_t], 2);
        translate([0, 0, uc_cup_lip]) pilot(3, uc_cup_lip);                        // tapped lip
        translate([0, 0, uc_cup_depth]) _bore(m3_clear_d, uc_cup_len);             // free chamber
        translate([-(uc_pusher_w - 6) / 2, -(uc_pusher_h - 6) / 2, uc_pusher_t - uc_foam_recess])
            rbox([uc_pusher_w - 6, uc_pusher_h - 6, uc_foam_recess + 1], 1.5);    // foam pad recess
    }
}
// pusher in the push frame: back face at x = 0 facing +x, bank face at x = -uc_pusher_t, centred on the axis.
module uc_pusher_local() rotate([90, 0, -90]) uc_pusher_print();
// rear_stop, print frame = local frame: bolts at (0, +-5) on z = 0, contact face at +x.
// rear_stop, print frame = local frame: base on z = 0, contact face at +x, bolts at x = 0 and
// x = -grid_pitch in slots y = -uc_stop_slot..+uc_stop_slot (solid block, heads on top).
module uc_rear_stop() {
    difference() {
        translate([uc_stop_back, -uc_stop_w / 2, 0]) rbox([uc_stop_front - uc_stop_back, uc_stop_w, uc_stop_h], 2);
        for (x = [0, -grid_pitch]) hull() for (y = [-uc_stop_slot, uc_stop_slot])
            translate([x, y, uc_stop_h]) m3_clear(uc_stop_h + 0.5, cbore = uc_stop_cb);
    }
}

// ---- clamp layout, computed for any bank size b = [L, W, H] -------------------------------
// The bank sits on the floor, centred in Y, port face at BANK_port_face_x against the rear stops.
// Each clamp is solved along its outward coordinate (X for the front clamp, |Y| for the side ones):
// face = bank face, wall = inner wall face, nodes = usable grid rows for the floor bolts.
// Returns [foam, node, screw length, p] with p = post front face (the post slides on its slots,
// so p is continuous: node - p must fall in uc_slot). Preference: thinnest foam, longest screw,
// bolt row nearest the bank, post as close to the bank as possible (most travel left).
// Coarse step 20 mm = slot (12.8) + set-screw travel; the sweep in the report proves coverage.
function uc_cl_back(face, foam) = face + foam + uc_pusher_t;                // pusher back face
function uc_cl_tip(face, foam)  = uc_cl_back(face, foam) - uc_cup_depth;    // screw tip
function uc_cl_solve(face, wall, nodes) = let(
    sols = [for (foam = uc_foam_opts, i = [len(uc_screw_lengths) - 1 : -1 : 0], n = nodes)
              let(L = uc_screw_lengths[i], back = uc_cl_back(face, foam), hb = back - uc_cup_depth + L,
                  lo = max(back + uc_tip_gap + uc_post_d, n - uc_slot[1]),
                  hi = min(n - uc_slot[0], hb - uc_travel_min, wall - 0.3 - uc_rail_x[1]))
              if (lo <= hi && hb + uc_knob_len <= wall - 0.3) [foam, n, L, lo]])
    len(sols) > 0 ? sols[0] : undef;
function uc_bank_xr(b) = [BANK_port_face_x, BANK_port_face_x + b[0]];
function uc_node_ok(x, y) = !_in_rects(x, y, uc_floor_excl)
    && len([for (g = grid_vals(uc_in_x)) if (g == x) 1]) == 1
    && len([for (g = grid_vals([-uc_in_y, uc_in_y])) if (g == y) 1]) == 1;
function uc_front_sol(b) = uc_cl_solve(uc_bank_xr(b)[1], uc_in_x[1],
    [for (x = grid_vals(uc_in_x)) if (uc_node_ok(x, uc_rail_dy) && uc_node_ok(x, -uc_rail_dy)) x]);
function uc_side_sol(b) = let(c = uc_side_x(b)) uc_cl_solve(b[1] / 2, uc_in_y,
    [for (y = grid_vals([0, uc_in_y])) if (len([for (s = [-1, 1], d = [-1, 1]) if (!uc_node_ok(c + d * uc_rail_dy, s * y)) 1]) == 0) y]);
// X position of the side clamps (screw axis, a grid column since the rails sit at +-grid_pitch):
// the column nearest the bank's middle whose pusher and rails stay clear of the strap bands and the
// J2 heads, with >= 20 mm of the pusher on the bank's flat side (6 mm corner radius).
function uc_side_x(b) = let(
    xr = uc_bank_xr(b), xc = (xr[0] + xr[1]) / 2, flat = [xr[0] + 6, xr[1] - 6],
    straps = [for (sx = BANK_strap_x) [sx - BANK_strap_w / 2 - 0.5, sx + BANK_strap_w / 2 + 0.5]],
    j2 = [for (h = J2_holes) if (abs(h[1]) > BANK_bay_y[1]) [h[0] - m3_head_d / 2 - 1, h[0] + m3_head_d / 2 + 1]],
    cands = [for (x = grid_vals([xr[0], xr[1]], grid_pitch, 0))
                 if (min(x + uc_pusher_w / 2, flat[1]) - max(x - uc_pusher_w / 2, flat[0]) >= 20
                  && x >= flat[0] && x <= flat[1]
                  && len([for (sb = straps) if (uc_overlaps([x - uc_pusher_w / 2, x + uc_pusher_w / 2], sb)
                                                || uc_overlaps([x - uc_rail_y, x + uc_rail_y], sb)) 1]) == 0
                  && len([for (jb = j2) if (uc_overlaps([x - uc_rail_y, x + uc_rail_y], jb)) 1]) == 0) x],
    d = [for (c = cands) abs(c - xc)])
    len(cands) == 0 ? undef : [for (i = [0 : len(cands) - 1]) if (d[i] == min(d)) cands[i]][0];
// Rear stop Y centre: inner edge just outside the plug zone (|y| < W/4); bolts on the nearest grid row.
function uc_stop_yc(b) = b[1] / 4 + uc_stop_w / 2 + 0.5;
function uc_stop_yn(b) = round(uc_stop_yc(b) / grid_pitch) * grid_pitch;

// One clamp unit placed: node = [x, y] of the local origin (upright front face on the screw axis),
// ang = push direction (0: -X, 90: -Y, -90: +Y), back = pusher back face relative to it (local x, < 0),
// len = set screw length.
module uc_clamp_unit(node, ang, back, len, what = "all") {
    hb = back - uc_cup_depth + len;          // screw head underside (local x)
    translate([node[0], node[1], uc_zf]) rotate(ang) {
        if (what == "all" || what == "post")   uc_clamp_post();
        if (what == "all" || what == "pusher") translate([back, 0, uc_axis_h]) uc_pusher_local();
        if (what == "all" || what == "knob")   translate([hb + uc_knob_len, 0, uc_axis_h]) rotate([0, -90, 0]) uc_knob();
        if (what == "screw") translate([back - uc_cup_depth, 0, uc_axis_h]) {    // ghost set screw (previews only)
            rotate([0, 90, 0]) cylinder(d = 3, h = len, $fn = 12);
            translate([len, 0, 0]) rotate([0, 90, 0]) cylinder(d = m3_head_d - 0.7, h = uc_head_h, $fn = 16);
        }
    }
}
module uc_clamp_set(b = BANK_max, what = "all") {
    xr = uc_bank_xr(b);
    fr = uc_front_sol(b);                    // [foam, bolt row, len, post position]
    sd = uc_side_sol(b);
    sx = uc_side_x(b);
    assert(fr != undef, str("no front clamp solution for bank ", b));
    assert(sd != undef, str("no side clamp solution for bank ", b));
    assert(sx != undef, str("no side clamp position for bank ", b));
    // front (X) clamp
    uc_clamp_unit([fr[3], 0], 0, uc_cl_back(xr[1], fr[0]) - fr[3], fr[2], what);
    // side (Y) clamps, one per side
    for (s = [-1, 1])
        uc_clamp_unit([sx, s * sd[3]], s * 90, uc_cl_back(b[1] / 2, sd[0]) - sd[3], sd[2], what);
    // rear stops
    if (what == "all" || what == "stop")
        for (s = [-1, 1]) translate([uc_stop_node, s * uc_stop_yc(b), uc_zf]) uc_rear_stop();
    // every floor bolt must land on a live floor-grid node
    bolts = concat([for (s = [-1, 1]) [fr[1], s * uc_rail_dy]],
                   [for (s = [-1, 1], d = [-1, 1]) [sx + d * uc_rail_dy, s * sd[1]]],
                   [for (s = [-1, 1], x = [0, -grid_pitch]) [uc_stop_node + x, s * uc_stop_yn(b)]]);
    for (q = bolts) assert(uc_node_ok(q[0], q[1]), str("clamp bolt not on a floor grid node: ", q));
    assert(fr[1] - fr[3] >= uc_slot[0] - 1e-6 && fr[1] - fr[3] <= uc_slot[1] + 1e-6, "front bolt outside its slot");
    assert(sd[1] - sd[3] >= uc_slot[0] - 1e-6 && sd[1] - sd[3] <= uc_slot[1] + 1e-6, "side bolt outside its slot");
    assert(uc_stop_yc(b) - uc_stop_w / 2 <= b[1] / 2 - 6 - 4, "rear stops touch < 4 mm of the bank's flat port face");
    assert(abs(uc_stop_yc(b) - uc_stop_yn(b)) <= uc_stop_slot, "rear stop slot too short");
}
module uc_clamp_report(b) {
    xr = uc_bank_xr(b); fr = uc_front_sol(b); sd = uc_side_sol(b); sx = uc_side_x(b);
    echo(str("UC_CLAMP bank=", b,
             " | rear_stops bolts x=", uc_stop_node, "/", uc_stop_node - grid_pitch, " y=+-", uc_stop_yn(b),
             " (stop centre |y| ", uc_stop_yc(b), ")",
             " | front post bolts x=", fr[1], " y=+-", uc_rail_dy, " (post face x=", fr[3], ", slot pos ", fr[1] - fr[3],
             ") screw M3x", fr[2], " foam ", fr[0], " travel left ", uc_cl_tip(xr[1], fr[0]) + fr[2] - fr[3],
             " | side posts axis x=", sx, " bolts x=", sx - uc_rail_dy, "/", sx + uc_rail_dy, " y=+-", sd[1],
             " (post face |y|=", sd[3], ", slot pos ", sd[1] - sd[3], ") screw M3x", sd[2], " foam ", sd[0],
             " travel left ", uc_cl_tip(b[1] / 2, sd[0]) + sd[2] - sd[3]));
}

// ============================ L298N plate =============================
// Print frame: u = global Y, v = global Z - uc_l298n_zc, z = distance from the rear wall face.
module uc_l298n_plate() {
    hp = [for (h = L298N_holes) [h[0] - L298N_size[0] / 2, h[1] - L298N_size[1] / 2]];
    difference() {
        translate([-uc_l298n_plate_size[0] / 2, uc_l298n_plate_v0, 0])
            rbox([uc_l298n_plate_size[0], uc_l298n_plate_size[1], uc_l298n_plate_t], 4);
        // window under the board's solder side, keeping the four corner bosses
        translate([0, 0, -1]) linear_extrude(uc_l298n_plate_t + 2) difference() {
            square(L298N_size, center = true);
            for (h = hp) translate(h) circle(d = uc_l298n_boss_d);
            for (h = hp) translate(h) rotate(atan2(h[1], h[0])) translate([0, -uc_l298n_boss_d / 2]) square([10, uc_l298n_boss_d]);
        }
        // board screws: M3 pilots, slotted +-uc_l298n_slot along the diagonal (pattern uncertain)
        for (h = hp) let(n = h / norm(h)) hull() for (k = [-1, 1])
            translate([h[0] + k * uc_l298n_slot * n[0], h[1] + k * uc_l298n_slot * n[1], uc_l298n_plate_t]) m3_tap(uc_l298n_plate_t + 1);
        // to the rear-wall grid
        for (p = uc_l298n_grid) translate([p[0], p[1], uc_l298n_plate_t]) m3_clear(uc_l298n_plate_t + 1);
    }
}
module uc_l298n_plate_placed() translate([uc_in_x[0], 0, uc_l298n_zc]) rotate([90, 0, 90]) uc_l298n_plate();
module uc_l298n_placed()
    translate([uc_l298n_xb, -L298N_size[0] / 2, uc_l298n_zc - L298N_size[1] / 2]) rotate([90, 0, 90]) v_l298n();

// ============================ PD trigger plate ========================
// Print frame: u = global X - uc_pd_xc, v = global Z - uc_pd_zc, z = distance from the left wall face.
// The board sits between two rails, held by one zip tie through two slots (tie closes behind the plate).
module uc_pd_plate() {
    difference() {
        union() {
            translate([-uc_pd_size[0] / 2, -uc_pd_size[1] / 2, 0]) rbox([uc_pd_size[0], uc_pd_size[1], uc_pd_t], 3);
            for (s = [-1, 1]) translate([-uc_pd_rail_l / 2, s > 0 ? uc_pd_board[1] / 2 + 0.3 : -uc_pd_board[1] / 2 - 0.3 - uc_pd_rail_t, uc_pd_t - eps])
                cube([uc_pd_rail_l, uc_pd_rail_t, uc_pd_rail_h + eps]);
        }
        for (h = uc_pd_holes) translate([h[0], h[1], uc_pd_t]) m3_clear(uc_pd_t + 1);
        for (s = [-1, 1]) translate([-uc_tie_w / 2, s * uc_tie_v - uc_tie_t / 2, -1]) cube([uc_tie_w, uc_tie_t, uc_pd_t + 2]);
        translate([-uc_tie_w / 2, -uc_tie_v - uc_tie_t / 2, -1]) cube([uc_tie_w, 2 * uc_tie_v + uc_tie_t, 1 + uc_tie_groove]);
    }
}
module uc_pd_frame() translate([uc_pd_xc, uc_in_y, uc_pd_zc]) rotate([90, 0, 0]) children();
module uc_pd_plate_placed() uc_pd_frame() uc_pd_plate();
// USB-C receptacle towards +X (the bank), output terminal towards the L298N.
module uc_pd_placed() uc_pd_frame() translate([uc_pd_board[0] / 2, uc_pd_board[1] / 2, uc_pd_t]) rotate([0, 0, 180]) v_pd_trigger();

// ============================ speaker ring ============================
// Print frame: lid side (flange) on z = 0, cup rising to the 45 deg back lip. z = z_uc_top - Z.
module uc_speaker_ring(d = uc_speaker_d, h = uc_speaker_h) {
    ri = d / 2 + uc_spk_clr;
    ro = ri + uc_spk_wall;
    zl = h + uc_spk_gap;                 // speaker back face
    zc = zl + uc_spk_lip;
    assert(uc_spk_bolts != undef, "speaker too big for the ring bolt patterns");
    difference() {
        union() {
            hull() for (p = uc_spk_bolts) translate(p) cylinder(r = 6, h = uc_spk_flange_t);
            cylinder(r = ro, h = zc);
        }
        translate([0, 0, -1]) cylinder(r = ri, h = zl + 1);
        translate([0, 0, zl - eps]) cylinder(r1 = ri, r2 = ri - uc_spk_lip, h = uc_spk_lip + 2 * eps);
        translate([0, 0, zc - 1]) cylinder(r = ri - uc_spk_lip, h = 3);
        translate([ri - 1, -uc_spk_notch / 2, zl - 6]) cube([uc_spk_wall + 2, uc_spk_notch, 10]);   // wire notch
        for (p = uc_spk_bolts) translate([p[0], p[1], uc_spk_flange_t]) m3_clear(uc_spk_flange_t + 1);
    }
}
module uc_speaker_ring_placed() translate([uc_spk_x, uc_spk_y, z_uc_top]) rotate([180, 0, 0]) uc_speaker_ring();
module uc_speaker_placed() translate([uc_spk_x, uc_spk_y, z_uc_top - uc_spk_gap]) v_speaker(uc_speaker_d, uc_speaker_h);

// ============================ lid knobs ===============================
module uc_lid_knobs() for (p = uc_ts_pos) translate([p[0], p[1], z_uc_top + lid_t + uc_knob_len]) rotate([180, 0, 0]) uc_knob();

// ============================ assemblies ==============================
// Sub-assemblies by name, in place (used by the self-interference check).
module uc_sub(n) {
    if (n == "tray") uc_tray();
    else if (n == "lid") uc_lid();
    else if (n == "posts") uc_clamp_set(BANK_max, "post");
    else if (n == "pushers") uc_clamp_set(BANK_max, "pusher");
    else if (n == "knobs") { uc_clamp_set(BANK_max, "knob"); uc_lid_knobs(); }
    else if (n == "stops") uc_clamp_set(BANK_max, "stop");
    else if (n == "l298n_plate") uc_l298n_plate_placed();
    else if (n == "pd_plate") uc_pd_plate_placed();
    else if (n == "speaker_ring") uc_speaker_ring_placed();
}
module uc_assembled() {
    // render(): the tray's grid holes plus another assembly's holes overflow OpenCSG's normalizer
    // in assembly.scad previews; costs ~70 s of CGAL per preview, no-op for STL / CGAL renders.
    render(convexity = 6) uc_tray();
    uc_lid();
    uc_clamp_set(BANK_max);
    uc_lid_knobs();
    uc_l298n_plate_placed();
    uc_pd_plate_placed();
    uc_speaker_ring_placed();
}
module uc_vitamins() {
    v_bank_max_placed();
    uc_l298n_placed();
    uc_pd_placed();
    uc_speaker_placed();
}
// Preview helper: the tray (no lid) with the clamp set for any bank, and that bank's ghost.
module uc_bank_demo(b) {
    uc_clamp_report(b);
    color("DarkOrange") uc_tray();
    color("Gold") uc_clamp_set(b);
    color("silver") uc_clamp_set(b, "screw");
    translate([BANK_port_face_x + b[0] / 2, (BANK_bay_y[0] + BANK_bay_y[1]) / 2, uc_zf]) { v_bank(b); v_bank_plug_zone(b); }
}
