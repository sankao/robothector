// cabin_base.scad: CABIN parameters and modules (no top-level geometry).
// Spec: docs/superpowers/specs/2026-10-17-chassis-redesign-design.md, sections 6 and 8.
// Every part is modelled in the global assembled frame (X fwd, Y left, Z up, X = 0 bulkhead).
// Print orientations live only in cabin.scad.
include <robothector_base.scad>
include <vitamins.scad>

// Grid helpers (everything grid-related derives from grid_pitch):
// midpoint between the two grid nodes that bracket x, and distance from v to its nearest node.
function cab_between(x) = (floor(x / grid_pitch) + 0.5) * grid_pitch;
function cab_node_dist(v) = abs(v - round(v / grid_pitch) * grid_pitch);

// ======================= cabin layout parameters ===================
cab_wall_top   = z_cab_top - roof_t;        // 146: top of side walls + bulkhead
cab_floor_top  = z_floor + floor_t;         // 18
cab_front_wall = [x_cab_front - wall_t, x_cab_front]; // front lower wall X [101, 105]
cab_front_wall_top = faceplate_opening[1][0];          // 70
cab_in_y       = body_w/2 - wall_t;         // 66: inner face of the side walls
cab_well_front_fill = [OMNI_well_x[1], cab_front_wall[0]]; // X [99, 101]: closes the wells' front
cab_corner_r   = 3;      // outer vertical front edges (plan fillet)
cab_rear_chamfer = 1;    // outer vertical rear edges (chamfer; rear face mates the carriages)

// ---- screen + Pi unit (glass facing +X, unrotated: GPIO header up, USB-C down,
//      USB/Ethernet end at -Y). Touches: faceplate back (glass), corner lips (standoff tops).
cab_fp_t       = 6;                         // faceplate thickness (X [99, 105]); also the bezel lip depth
cab_fp_back_x  = x_cab_front - cab_fp_t;    // 99
cab_glass_x    = cab_fp_back_x;             // glass front bears on the faceplate back
cab_scr_z      = 109;                       // screen centre Z (unit Z 74..144, USB-C plug clears Z 70)
cab_scr_hw     = SCREEN_board[0]/2;         // 53
cab_scr_hh     = SCREEN_board[1]/2;         // 34
cab_board_back_x = cab_glass_x - SCREEN_t;  // 90.5
cab_fp_y       = faceplate_opening[0][1] - clr_slide;  // 65.75: faceplate half-width
cab_fp_z       = [faceplate_opening[1][0], faceplate_opening[1][1] - clr_face]; // Z [70, 145.8]
cab_fp_window_m = 0.5;                      // window margin around SCREEN_active (per side)
cab_fp_window_ch = 1.5;                     // 45 deg chamfer on the window front edge
cab_fp_cbore   = m3_head_h + 0.2;           // head counterbore depth in the faceplate face
cab_fp_screws  = [[60.5, 89], [60.5, 130]];      // [|y|, z] faceplate -> body pillars, M3 x 12 from the front
cab_fp_pilot   = 11;                        // pilot depth into the body pillars
cab_fp_pillar_x = [cab_fp_back_x - 13, cab_fp_back_x]; // body pillars X [86, 99]
cab_fp_pillar_y0 = 56.75;                   // pillar inner face |y|: 7.5 mm boss round the screw, Pi ports slide past
cab_pi_port_y  = 56.2;                       // |y| reached by the Pi's USB/Ethernet ports (v_screen_unit: 56.12)
cab_usbc_y     = [13.5, 26];                 // right-angle USB-C plug zone under the Pi (port y 15.2..24.2)
cab_usbc_face_z = cab_scr_z - 28.04 - 1;      // Pi USB-C port face (v_screen_unit, unrotated)
cab_usbc_x     = cab_glass_x - SCREEN_t - SCREEN_pillar - 1.4 - 3.5 / 2; // Pi USB-C port centre X (83.35)
cab_usbc_notch = [[cab_usbc_x - 8, cab_usbc_x + 8], cab_usbc_face_z - BANK_plug_clear - 2]; // notch in the +Y inner well wall top: x range, floor z
cab_fp_pillars = [[80, 98], [120, cab_wall_top]]; // [z0, z1] full section; 45 deg chin below z0
cab_fp_rail_d  = 7;                         // board locating rails on the faceplate back (X depth)
cab_fp_rail_hw = cab_scr_hw + 0.4;          // rail half-length in Y: out to the corner lips (53.4)
// Corner lips: the top/bottom rails run out to the screen's corner standoffs and overhang them;
// 4x M2.5 x 8 through the lips into the standoffs. The board's long edges sit under the lips, so
// the screen slides in end-on from +Y (the DSI-ribbon end), glass down, until it meets the -Y stops:
// everything on the Pi's long edges passes under the lips on the way. Lips print over supports.
cab_so         = [SCREEN_corner_holes[0]/2, SCREEN_corner_holes[1]/2]; // [|y|, |z - cab_scr_z|] standoff centres
cab_so_top_x   = cab_board_back_x - SCREEN_standoff[1];   // 86.5: standoff tops
cab_lip_gap    = 0.25;                       // lip underside above the standoff tops (slide clearance)
cab_m25_l      = 8;                          // the M2.5 screws on hand
cab_lip_t      = cab_m25_l - SCREEN_standoff[1];  // 4: the screw fills the standoff and stops at the board
cab_lip_x      = [cab_so_top_x - cab_lip_gap - cab_lip_t, cab_so_top_x - cab_lip_gap]; // X [82.25, 86.25]
cab_pi_edge_out = 2;                        // allowance for ports standing proud of the Pi's long edges
cab_lip_dz     = 56 / 2 + cab_pi_edge_out;   // 30: lip inner edge |z - cab_scr_z| (Pi long edges at 28)
cab_lip_y      = [cab_so[0] - 3.75, cab_fp_rail_hw];      // |y| [45.9, 53.4]
cab_stop_y     = [cab_scr_hw + 0.35, cab_scr_hw + 2.35];  // -Y end stops |y| [53.35, 55.35]

// ---- J1 pads and J3 bosses on the bulkhead
cab_j1_pad_t   = 2;                         // head bears on bulkhead + pad = 6 mm
cab_j1_pad_r   = m5_head_d/2 + 1;
cab_j1_pad_ymax = cab_in_y - 1.5;           // pad stays clear of the side wall
cab_j1_screw_l = 20;                        // M5 x 20
cab_j3_boss_d  = 14;                        // >= 2.5 x 5
cab_j3_depth   = J3_engage + 5;             // pilot depth from X = 0 (>= J3_engage + 2); takes M5 x 16..20
cab_j3_screw_l = [16, 20];                   // M5 lengths the pilot accepts from the tray side
cab_j3_boss_x1 = cab_j3_depth + 2;          // boss front face X (2 mm closed end)

// ---- omni-wheel cassettes and wells
cab_cas_y0     = OMNI_well_y[0] + clr_slide;        // 28.25
cab_cas_x      = [OMNI_well_x[0] + 1, OMNI_well_x[1] - 1]; // X [34, 98]
cab_cas_gap    = 1.5;                       // wheel top -> cassette roof underside
cab_cas_roof_dz = OMNI_wheel_d/2 + cab_cas_gap;     // roof underside above the axle
cab_cas_cheek_r = 7;                        // material around the rod hole
cab_cas_block_x = 9;                        // corner screw blocks (outside the wheel circle)
cab_cas_block_dz = 20;                      // block underside above the axle
cab_cas_screw_x = [cab_cas_x[0] + cab_cas_block_x/2, cab_cas_x[1] - cab_cas_block_x/2]; // 38.5, 93.5
cab_cas_screw_dz = (cab_cas_block_dz + cab_cas_roof_dz) / 2;  // 25.25 above the axle
cab_cas_pilot  = 12;
cab_cas_r      = 2;                         // rounded vertical corners

// ---- bumper
cab_bump_z     = [16, 60];
cab_bump_hw    = body_w/2 - 2;              // 68
cab_bump_r     = 6;                         // plan radius of the front corners
cab_bump_ch    = 2;                         // chamfer on the front top/bottom edges
cab_bump_screws = [[24, 25], [24, 35], [-24, 25], [-24, 35]]; // [y, z], M3 x 20
cab_bump_cbore = 7;
cab_bump_pilot = 14;
cab_bump_col   = [[89, cab_front_wall[0]], [20, 28], 46]; // columns [x0,x1], [|y|0,|y|1], z top
cab_bump_grid_depth = 12;

// ---- roof
cab_roof_screws = [[8, 62], [45, 62], [92.5, 61]];  // [x, |y|], M3 x 12 down into pilots
cab_roof_pilot = 10;
cab_roof_boss  = 8;                          // square boss size
cab_roof_boss_z0 = cab_wall_top - cab_roof_pilot;   // 136
cab_ribbon_slot = [cab_between(70), 18, 3];  // [x centre, length (Y), width (X)]: between grid rows, over the Pi's component side
cab_vent_w     = 3;
cab_vent_gap   = 8;                          // centre spacing of a vent pair straddling a grid mid-line
cab_roof_vents = concat([for (y = [-38, -12, 14]) [cab_between(50), y]],   // centres, between grid rows
                        [for (y = [-38, 28]) [cab_between(70), y]]);       // (row x = 70 also carries the ribbon slot)
cab_roof_vent_l = 18;

// ---- side walls: vents (+Y, opposite the Pi's USB end) and debug slot (-Y, at the USB end)
cab_wall_vents_x = [for (m = [cab_between(50), cab_between(70)], s = [-1, 1]) m + s * cab_vent_gap / 2];
cab_wall_vent_z  = [88, 128];
cab_dbg_slot   = [69.5, 19, cab_scr_z, 56];  // [x centre, width, z centre, rect height]
cab_wall_grid_x = [4, 90];
cab_wall_grid_z = [72, cab_wall_top - 2];

// ---- camera bracket (roof, front edge), cradle and clip. Camera: board back at X cab_cam_x,
//      board bottom edge at Z cab_cam_z0, lens +X. Pivot axis along Y through cab_piv (x, z).
cab_cam_hole_d = 2.2;                        // Camera Module 3 mounting holes (missing in base)
cab_cam_pin_d  = cab_cam_hole_d - 0.3;       // printed locating pins
cab_cam_pin_hole_d = cab_cam_hole_d + 0.2;   // blind holes in the cradle for the pin tips
cab_cam_x      = 100;
cab_cam_z0     = 160;
cab_cam_tilt   = 10;                         // 0..30 deg down (default view)
cab_piv        = [91, 166];
cab_cr_hw      = 20.5;                       // cradle back plate half-width
cab_cr_z       = [cab_cam_z0 - 2, cab_cam_z0 + 28];
cab_cr_t       = 4;
cab_cr_win_hw  = 8;                          // window behind the camera board (pins at |y| 10.5)
cab_cr_cheek   = [cab_cr_hw, cab_cr_hw + 6];  // cradle cheek Y range (pivot side)
cab_ear_y      = [cab_cr_cheek[1] + 0.2, cab_cr_cheek[1] + 9.7]; // bracket ear Y range
cab_piv_r      = 8;
cab_clip_t     = 3;
cab_clip_win_hw = 8.3;
cab_clip_screw = [16.5, cab_cam_z0 + 16];    // [|y|, z]
cab_cam_base   = [[75, 104], [cab_ear_y[0], 45], 5];  // bracket base: x range, y range, thickness
cab_cam_foot   = [[74, 86], [14, cab_ear_y[0]]];      // extra foot reaching the node behind the cradle
cab_cam_base_holes = [for (n = [[4, 2], [5, 2], [4, 1]]) n * grid_pitch]; // roof grid nodes (80,40) (100,40) (80,20), M3 x 10

// ======================= derived checks (echo + assert) ============
cab_fp_front_x     = x_cab_front;
cab_bumper_front_x = x_cab_front + bumper_d;
cab_j1_engage      = cab_j1_screw_l - (bulkhead_t + cab_j1_pad_t) - clr_face;
cab_cas_top_max    = OMNI_axle[1] + OMNI_adj + cab_cas_roof_dz + OMNI_roof_t;
echo(str("CAB glass front X = ", cab_glass_x, ", faceplate front X = ", cab_fp_front_x,
         ", lip = ", cab_fp_front_x - cab_glass_x, " mm"));
echo(str("CAB bumper front X = ", cab_bumper_front_x, " (>= faceplate front + 15 = ", cab_fp_front_x + 15, ")"));
echo(str("CAB J1 M5x", cab_j1_screw_l, " engagement = ", cab_j1_engage, " (min ", J1_engage, ")"));
echo(str("CAB cassette roof top at +adj = ", cab_cas_top_max, " (< ", OMNI_well_top_z, ")"));
assert(cab_glass_x <= cab_fp_front_x - 2, "glass front must sit >= 2 mm behind the faceplate front");
assert(cab_bumper_front_x >= cab_fp_front_x + 15, "bumper must stand >= 15 mm proud of the faceplate");
assert(cab_j1_engage >= J1_engage, "J1 M5 engagement too short");
assert(cab_j3_depth >= J3_engage + 2, "J3 pilot too shallow");
assert(cab_j3_screw_l[1] - uc_front_wall_t - clr_face <= cab_j3_depth - 0.5, "J3 M5 x 20 bottoms out");
echo(str("CAB J3 pilot depth = ", cab_j3_depth, " (M5x16..20 engage ", cab_j3_screw_l[0] - uc_front_wall_t - clr_face, "..", cab_j3_screw_l[1] - uc_front_wall_t - clr_face, ")"));
assert(cab_cas_top_max < OMNI_well_top_z, "cassette roof pokes above the well top");
assert(cab_scr_z - SCREEN_unit[1]/2 >= OMNI_well_top_z, "screen unit dips below Z 70");
assert(cab_scr_z + SCREEN_unit[1]/2 <= cab_fp_z[1], "screen unit above the faceplate top");
assert(cab_stop_y[1] < cab_fp_pillar_y0, "screen stops cannot slide out past the faceplate pillars");
assert(cab_lip_dz < cab_so[1], "lip inner edge past the standoff centre");
assert(cab_so[1] + SCREEN_standoff[0]/2 <= cab_scr_hh + clr_slide, "standoffs outside the rails");
assert(cab_so[0] + SCREEN_standoff[0]/2 <= cab_lip_y[1] && cab_so[0] - SCREEN_standoff[0]/2 >= cab_lip_y[0], "lip shorter than the standoff");
assert(cab_pi_port_y < cab_fp_pillar_y0, "Pi ports cannot slide out past the faceplate pillars");
assert(cab_usbc_notch[1] < OMNI_well_top_z && cab_usbc_notch[1] > cab_cas_top_max - 2, "USB-C notch floor out of range");
echo(str("CAB USB-C plug bottom Z = ", cab_usbc_face_z - BANK_plug_clear, ", notch floor Z = ", cab_usbc_notch[1]));
assert(cab_fp_screws[0][0] - cab_fp_pillar_y0 >= 2.5 * 3 / 2, "faceplate pillar boss < 2.5 x d");
assert(cab_cas_x[0] > OMNI_well_x[0] && cab_cas_x[1] < OMNI_well_x[1], "cassette longer than the well");
// grid: mounts sit on nodes, cut-outs stay clear of nodes
for (h = cab_cam_base_holes) assert(cab_node_dist(h[0]) == 0 && cab_node_dist(h[1]) == 0, str("camera base hole off-grid: ", h));
for (x = concat(cab_wall_vents_x, [for (v = cab_roof_vents) v[0]]))
    assert(cab_node_dist(x) >= grid_hole_d/2 + cab_vent_w/2 + 1, str("vent too close to a grid row: x = ", x));
assert(cab_node_dist(cab_ribbon_slot[0]) >= grid_hole_d/2 + cab_ribbon_slot[2]/2 + 1, "ribbon slot too close to a grid row");
for (s = cab_bump_screws, y = grid_vals([-cab_bump_hw + 2, cab_bump_hw - 2]), z = grid_vals(cab_bump_z))
    assert(norm([s[0] - y, s[1] - z]) >= m3_head_d/2 + grid_hole_d/2 + 1, str("bumper screw ", s, " hits grid node ", [y, z]));

// ======================= helpers ===================================
module cab_mirror_y() { children(); mirror([0, 1, 0]) children(); }
// Plan outline of the body and roof: rounded front corners, chamfered rear corners.
module cab_plan() {
    c = cab_rear_chamfer; r = cab_corner_r; hw = body_w/2;
    hull() {
        translate([0, -(hw - c)]) square([c, 2 * (hw - c)]);
        translate([c, -hw]) square([eps, body_w]);
        for (s = [-1, 1]) translate([x_cab_front - r, s * (hw - r)]) circle(r = r);
    }
}
// 2D shape in the (Y, Z) plane, extruded along +X from x0 by t.
module cab_yz(x0, t) translate([x0, 0, 0]) rotate([90, 0, 90]) linear_extrude(t) children();
// 2D shape in the (X, Z) plane, extruded along +Y from y0 by t.
module cab_xz(y0, t) translate([0, y0 + t, 0]) rotate([90, 0, 0]) linear_extrude(t) children();
// Rounded slot through a wall: centres a and b in the local 2D plane.
module cab_slot2d(a, b, w) hull() { translate(a) circle(d = w); translate(b) circle(d = w); }
// Placement of the screen + Pi unit (v_screen_unit local frame -> glass faces +X).
module cab_screen_place() translate([cab_glass_x, 0, cab_scr_z]) rotate([90, 0, 90]) children();
// Camera tilt about the pivot axis (Y), positive = lens down.
module cab_cam_tilted(t = cab_cam_tilt)
    translate([cab_piv[0], 0, cab_piv[1]]) rotate([0, t, 0]) translate([-cab_piv[0], 0, -cab_piv[1]]) children();
// Camera Module 3 placement at tilt 0 (v_cam3 local frame -> lens +X, connector down).
module cab_cam_place0() translate([cab_cam_x, -25/2, cab_cam_z0]) rotate([90, 0, 90]) children();

// ======================= BODY ======================================
module cab_body_shell() {
    hw = body_w/2;
    intersection() {
        translate([0, 0, z_floor - eps]) linear_extrude(cab_wall_top - z_floor + 2 * eps) cab_plan();
        union() {
            // floor (wells are cut later)
            translate([0, -hw, z_floor]) cube([x_cab_front, body_w, floor_t]);
            // side walls
            cab_mirror_y() translate([0, cab_in_y, z_floor]) cube([x_cab_front, wall_t, cab_wall_top - z_floor]);
            // bulkhead
            translate([0, -hw, z_floor]) cube([bulkhead_t, body_w, cab_wall_top - z_floor]);
            // front lower wall
            translate([cab_front_wall[0], -hw, z_floor]) cube([wall_t, body_w, cab_front_wall_top - z_floor]);
            cab_mirror_y() {
                // well front fill, inner well wall, rear cross wall
                translate([cab_well_front_fill[0], OMNI_well_y[0], z_floor])
                    cube([cab_well_front_fill[1] - cab_well_front_fill[0] + eps, OMNI_well_y[1] - OMNI_well_y[0] + eps, OMNI_well_top_z - z_floor]);
                translate([OMNI_rear_wall_x[0], OMNI_inner_wall_y[0], z_floor])
                    cube([cab_front_wall[0] - OMNI_rear_wall_x[0] + eps, OMNI_inner_wall_y[1] - OMNI_inner_wall_y[0], OMNI_well_top_z - z_floor]);
                translate([OMNI_rear_wall_x[0], OMNI_inner_wall_y[0], z_floor])
                    cube([OMNI_rear_wall_x[1] - OMNI_rear_wall_x[0], OMNI_well_y[1] - OMNI_inner_wall_y[0] + eps, OMNI_well_top_z - z_floor]);
            }
        }
    }
}

module cab_tongue() {
    translate([0, 0, J1_tongue_z[0]]) linear_extrude(J1_tongue_z[1] - J1_tongue_z[0]) polygon(j1_tongue_pts(0));
}

// J1 head pads (inner bulkhead face), 45 deg chin below, clipped clear of the side wall.
module cab_j1_pads() {
    for (b = J1_bolts) intersection() {
        hull() {
            translate([bulkhead_t - eps, b[0], b[1]]) rotate([0, 90, 0]) cylinder(r = cab_j1_pad_r, h = cab_j1_pad_t + eps);
            translate([bulkhead_t - eps, b[0], b[1] - cab_j1_pad_t]) rotate([0, 90, 0]) cylinder(r = cab_j1_pad_r, h = eps);
        }
        translate([0, -cab_j1_pad_ymax, 0]) cube([20, 2 * cab_j1_pad_ymax, 200]);
    }
}

// J3 bosses (inner bulkhead face) with a 45 deg chin.
module cab_j3_bosses() {
    r = cab_j3_boss_d/2; L = cab_j3_boss_x1 - bulkhead_t;
    for (b = J3_bolts) hull() {
        translate([bulkhead_t - eps, b[0], b[1]]) rotate([0, 90, 0]) cylinder(r = r, h = L + eps);
        translate([bulkhead_t - eps, b[0], b[1] - L]) rotate([0, 90, 0]) cylinder(r = r, h = eps);
    }
}

// Faceplate pillars at the front corners, above the wells; 45 deg chin into the side wall.
module cab_fp_pillars() {
    w = cab_in_y - cab_fp_pillar_y0;   // 10
    lx = cab_fp_pillar_x[1] - cab_fp_pillar_x[0];
    cab_mirror_y() for (p = cab_fp_pillars) {
        translate([cab_fp_pillar_x[0], cab_fp_pillar_y0, p[0]]) cube([lx, w + 1, p[1] - p[0]]);
        hull() {
            translate([cab_fp_pillar_x[0], cab_fp_pillar_y0, p[0]]) cube([lx, w + 1, eps]);
            translate([cab_fp_pillar_x[0], cab_in_y, p[0] - w]) cube([lx, 1, eps]);
        }
    }
}

// Roof bosses: rear corners (bulkhead + side wall) and mid side walls, 45 deg chins.
// The front roof pilots sit in the upper faceplate pillars.
module cab_roof_bosses() {
    b = cab_roof_boss; z0 = cab_roof_boss_z0;
    cab_mirror_y() for (p = cab_roof_screws) if (p[0] < cab_fp_pillar_x[0]) {
        x0 = max(bulkhead_t, p[0] - b/2);
        translate([x0, cab_in_y - b, z0]) cube([b, b + 1, cab_wall_top - z0]);
        hull() {
            translate([x0, cab_in_y - b, z0]) cube([b, b + 1, eps]);
            if (x0 <= bulkhead_t) translate([bulkhead_t - eps, cab_in_y, z0 - b]) cube([eps, 1, b]);
            else translate([x0, cab_in_y, z0 - b]) cube([b, 1, eps]);
        }
    }
}

// Bumper columns (from the floor) at the front ends of the inner well walls.
module cab_bumper_columns() {
    c = cab_bump_col;
    cab_mirror_y() translate([c[0][0], c[1][0], z_floor]) cube([c[0][1] - c[0][0] + eps, c[1][1] - c[1][0], c[2] - z_floor]);
}

module cab_body_solid() {
    cab_body_shell();
    cab_tongue();
    cab_j1_pads();
    cab_j3_bosses();
    cab_fp_pillars();
    cab_roof_bosses();
    cab_bumper_columns();
}

// ---- body cuts
module cab_body_cuts() {
    hw = body_w/2;
    // wells: open at the bottom (floor removed); the cabin interior above is already open
    cab_mirror_y() translate([OMNI_well_x[0], OMNI_well_y[0], z_floor - 1])
        cube([OMNI_well_x[1] - OMNI_well_x[0], OMNI_well_y[1] - OMNI_well_y[0], floor_t + 1 + eps]);
    // notch in the +Y inner well wall top for the Pi's right-angle USB-C plug
    translate([cab_usbc_notch[0][0], OMNI_inner_wall_y[0] - 1, cab_usbc_notch[1]])
        cube([cab_usbc_notch[0][1] - cab_usbc_notch[0][0], OMNI_inner_wall_y[1] - OMNI_inner_wall_y[0] + 1 + eps, 10]);
    // cable passages
    passage_x(P1, bulkhead_t, bulkhead_t + 1, -1);
    passage_x(P2, bulkhead_t, bulkhead_t + 1, -1);
    // J1: M5 clearance along X, heads on the pads inside the cabin
    for (b = J1_bolts) translate([bulkhead_t + cab_j1_pad_t, b[0], b[1]]) into_x(-1) m5_clear(bulkhead_t + cab_j1_pad_t + 1);
    // J3: M5 pilots from the bulkhead rear face (X = 0) going +X
    for (b = J3_bolts) translate([0, b[0], b[1]]) into_x(1) m5_hole(cab_j3_depth, J3_m5_mode);
    // cassette screw slots (+/- OMNI_adj) through the side wall and the inner well wall
    cab_mirror_y() for (x = cab_cas_screw_x) {
        z = OMNI_axle[1] + cab_cas_screw_dz;
        hull() for (dz = [-OMNI_adj, OMNI_adj])
            translate([x, OMNI_inner_wall_y[0] - 1, z + dz]) rotate([-90, 0, 0])
                cylinder(d = m3_clear_d, h = hw - OMNI_inner_wall_y[0] + 2, $fn = 16);
    }
    // faceplate pilots (horizontal, from the pillar front faces)
    cab_mirror_y() for (s = cab_fp_screws) translate([cab_fp_back_x, s[0], s[1]]) into_x(-1) m3_tap(cab_fp_pilot);
    // roof pilots (vertical, from the wall tops)
    cab_mirror_y() for (p = cab_roof_screws) translate([p[0], p[1], cab_wall_top]) m3_tap(cab_roof_pilot);
    // bumper pilots (horizontal, into the front wall + columns)
    for (s = cab_bump_screws) translate([x_cab_front, s[0], s[1]]) into_x(-1) m3_tap(cab_bump_pilot);
    // floor grid: between the wells, and behind them
    grid_z([OMNI_well_x[0], cab_bump_col[0][0]], [-OMNI_inner_wall_y[0], OMNI_inner_wall_y[0]], cab_floor_top, floor_t + 1);
    grid_z([bulkhead_t, OMNI_rear_wall_x[0]], [-cab_in_y, cab_in_y], cab_floor_top, floor_t + 1);
    // side-wall grid patches above the wells
    roof_ex = [for (p = cab_roof_screws) if (p[0] < cab_fp_pillar_x[0]) [p[0] - 7, p[0] + 7, cab_roof_boss_z0 - cab_roof_boss - 3, 200]];
    dbg = cab_dbg_slot;
    dbg_ex = [[dbg[0] - dbg[1]/2 - 3, dbg[0] + dbg[1]/2 + 3, 0, 200]];
    grid_y(cab_wall_grid_x, cab_wall_grid_z,  hw, wall_t + 1, -1, roof_ex);
    grid_y(cab_wall_grid_x, cab_wall_grid_z, -hw, wall_t + 1,  1, concat(roof_ex, dbg_ex));
    // vents in the +Y wall, across from the Pi
    for (x = cab_wall_vents_x) translate([0, hw + 0.5, 0]) rotate([90, 0, 0])
        linear_extrude(wall_t + 1) cab_slot2d([x, cab_wall_vent_z[0]], [x, cab_wall_vent_z[1]], cab_vent_w);
    // debug slot in the -Y wall at the Pi's USB / Ethernet end (flat top = opening_flat <= max_bridge)
    translate([dbg[0], -hw, dbg[2]]) into_y(1) pointed_opening(dbg[1], dbg[3], wall_t + 1);
}

module cab_body() difference() { cab_body_solid(); cab_body_cuts(); }

// ======================= ROOF ======================================
module cab_roof() {
    z0 = cab_wall_top;
    rs = [for (p = cab_roof_screws, s = [-1, 1]) [p[0], s * p[1]]];
    ex = [for (p = rs) [p[0] - 5, p[0] + 5, p[1] - 5, p[1] + 5]];
    difference() {
        translate([0, 0, z0]) linear_extrude(roof_t) cab_plan();
        for (p = rs) translate([p[0], p[1], z_cab_top]) m3_clear(roof_t + 1);
        grid_z([0, x_cab_front], [-body_w/2, body_w/2], z_cab_top, roof_t + 1, ex);
        // camera ribbon slot (above the Pi's component side, behind the screen unit)
        rb = cab_ribbon_slot;
        translate([0, 0, z0 - 1]) linear_extrude(roof_t + 2)
            cab_slot2d([rb[0], -(rb[1] - rb[2])/2], [rb[0], (rb[1] - rb[2])/2], rb[2]);
        // vents over the Pi
        for (v = cab_roof_vents) translate([0, 0, z0 - 1]) linear_extrude(roof_t + 2)
            cab_slot2d([v[0], v[1] - (cab_roof_vent_l - cab_vent_w)/2], [v[0], v[1] + (cab_roof_vent_l - cab_vent_w)/2], cab_vent_w);
    }
}

// ======================= FACEPLATE =================================
// Plate X [99, 105] between the side walls, Z 70..145.8. Bezel window on SCREEN_active.
// Back: board locating rails (bottom/top) ending in 4 corner lips over the screen's standoffs,
// plus -Y end stops. The screen slides in from +Y under the lips (see "Corner lips" above).
module cab_faceplate() {
    x0 = cab_fp_back_x; t = cab_fp_t; hy = cab_fp_y; z = cab_fp_z;
    w = [SCREEN_active[0] + 2 * cab_fp_window_m, SCREEN_active[1] + 2 * cab_fp_window_m];
    ch = cab_fp_window_ch;
    difference() {
        union() {
            // plate, 1 mm chamfer round the front perimeter
            hull() {
                cab_yz(x0, t - 1) translate([-hy, z[0]]) square([2 * hy, z[1] - z[0]]);
                cab_yz(x0 + t - 1, 1) translate([-hy + 1, z[0] + 1]) square([2 * hy - 2, z[1] - z[0] - 2]);
            }
            // locating rails (board Z cab_scr_z +/- cab_scr_hh, clr_slide)
            cab_yz(x0 - cab_fp_rail_d, cab_fp_rail_d + eps) {
                translate([-cab_fp_rail_hw, z[0]]) square([2 * cab_fp_rail_hw, cab_scr_z - cab_scr_hh - clr_slide - z[0]]);
                translate([-cab_fp_rail_hw, cab_scr_z + cab_scr_hh + clr_slide]) square([2 * cab_fp_rail_hw, z[1] - cab_scr_z - cab_scr_hh - clr_slide]);
            }
            // corner towers: rail wall up to the lip, lip over the standoff; -Y towers carry the end stops
            rz = cab_scr_hh + clr_slide;   // rail inner face, |z - cab_scr_z|
            for (sy = [-1, 1], sz = [-1, 1]) {
                ya = sy > 0 ? cab_lip_y[0] : -cab_stop_y[1];
                yb = sy > 0 ? cab_lip_y[1] : -cab_lip_y[0];
                ze = sz > 0 ? z[1] : z[0];
                cab_yz(cab_lip_x[0], x0 - cab_lip_x[0] + eps) {
                    translate([ya, min(cab_scr_z + sz * rz, ze)]) square([yb - ya, abs(ze - cab_scr_z) - rz]);
                    if (sy < 0) translate([-cab_stop_y[1], min(cab_scr_z + sz * cab_lip_dz, ze)])
                        square([cab_stop_y[1] - cab_stop_y[0], abs(ze - cab_scr_z) - cab_lip_dz]);
                }
                cab_yz(cab_lip_x[0], cab_lip_t)
                    translate([ya, min(cab_scr_z + sz * cab_lip_dz, cab_scr_z + sz * rz)]) square([yb - ya, rz - cab_lip_dz]);
            }
        }
        // window + 45 deg front chamfer
        translate([x0 - 1, -w[0]/2, cab_scr_z - w[1]/2]) cube([t + 2, w[0], w[1]]);
        hull() {
            translate([x_cab_front - ch, -w[0]/2, cab_scr_z - w[1]/2]) cube([eps, w[0], w[1]]);
            translate([x_cab_front, -w[0]/2 - ch, cab_scr_z - w[1]/2 - ch]) cube([1, w[0] + 2 * ch, w[1] + 2 * ch]);
        }
        // body screws, heads counterbored in the face
        cab_mirror_y() for (s = cab_fp_screws) translate([x_cab_front, s[0], s[1]]) into_x(-1) m3_clear(t + 1, cab_fp_cbore);
        // M2.5 clearance through the lips, on the standoffs
        for (sy = [-1, 1], sz = [-1, 1]) translate([cab_lip_x[0], sy * cab_so[0], cab_scr_z + sz * cab_so[1]])
            into_x(1) _bore(m25_clear_d, cab_lip_t + 1);
    }
}

// Print-only breakaway supports under the 4 corner lips (cabin.scad adds them to the faceplate
// printable; never in the assembly): a grid of thin walls standing on the faceplate back, one layer
// (0.2 mm) short of the lip and clear of the tower and stop faces. Twist them out with pliers.
cab_sup_w   = 0.8;
cab_sup_gap = 0.2;
module cab_fp_lip_supports() {
    rz = cab_scr_hh + clr_slide; side = 0.5; w = cab_sup_w;
    x0 = cab_lip_x[1] + cab_sup_gap; x1 = cab_fp_back_x + eps;
    for (sy = [-1, 1], sz = [-1, 1]) {
        ya = sy > 0 ? cab_lip_y[0] : -cab_stop_y[0] + side;
        yb = sy > 0 ? cab_lip_y[1] : -cab_lip_y[0];
        za = sz > 0 ? cab_scr_z + cab_lip_dz : cab_scr_z - rz + side;   // lower Z bound of the comb
        zb = sz > 0 ? cab_scr_z + rz - side : cab_scr_z - cab_lip_dz;   // upper Z bound
        translate([x0, 0, 0]) {
            for (i = [0:2]) let(yc = ya + w/2 + (yb - ya - w) * i / 2)   // 3 walls across Y
                translate([0, yc - w/2, za]) cube([x1 - x0, w, zb - za]);
            for (zc = [za + w/2, zb - w/2])                             // 2 walls along Y
                translate([0, ya, zc - w/2]) cube([x1 - x0, yb - ya, w]);
        }
    }
}

// ======================= BUMPER ====================================
// Sacrificial, X [105, 120]; bolted to the front lower wall (4x M3 x 20, heads counterbored).
module cab_bumper() {
    x0 = x_cab_front; x1 = x_cab_front + bumper_d; z = cab_bump_z; hw = cab_bump_hw;
    r = cab_bump_r; c = cab_bump_ch;
    difference() {
        intersection() {
            translate([0, 0, z[0]]) linear_extrude(z[1] - z[0]) hull() {
                translate([x0, -hw + 1]) square([eps, 2 * hw - 2]);
                translate([x0 + 1, -hw]) square([eps, 2 * hw]);
                for (s = [-1, 1]) translate([x1 - r, s * (hw - r)]) circle(r = r);
            }
            cab_xz(-hw - 1, 2 * hw + 2)
                polygon([[x0, z[0]], [x1 - c, z[0]], [x1, z[0] + c], [x1, z[1] - c], [x1 - c, z[1]], [x0, z[1]]]);
        }
        for (s = cab_bump_screws) translate([x1, s[0], s[1]]) into_x(-1) m3_clear(bumper_d + 1, cab_bump_cbore);
        grid_x([-hw + 2, hw - 2], z, x1, cab_bump_grid_depth, -1);
    }
}

// ======================= OMNI CASSETTE =============================
// Inverted U for the +Y well (mirror for -Y). adj = ride-height offset (-OMNI_adj..+OMNI_adj).
// The 2 mm rod runs through both cheeks and is trapped by the well walls.
module cab_cassette(adj = 0) {
    za = OMNI_axle[1] + adj;
    y0 = cab_cas_y0; w = OMNI_cassette_w; y1 = y0 + w;
    x = cab_cas_x; L = x[1] - x[0];
    zr = za + cab_cas_roof_dz;
    difference() {
        intersection() {
            union() {
                translate([x[0], y0, zr]) cube([L, w, OMNI_roof_t]);
                for (yc = [y0, y1 - OMNI_cheek_t]) cab_xz(yc, OMNI_cheek_t) hull() {
                    translate([OMNI_axle[0], za]) circle(r = cab_cas_cheek_r);
                    translate([x[0], za + cab_cas_block_dz - 2]) square([L, zr - za - cab_cas_block_dz + 2 + eps]);
                }
                for (xb = [x[0], x[1] - cab_cas_block_x])
                    translate([xb, y0, za + cab_cas_block_dz]) cube([cab_cas_block_x, w, zr - za - cab_cas_block_dz + eps]);
            }
            translate([0, 0, za - 20]) linear_extrude(OMNI_wheel_d + 20)
                translate([x[0], y0]) offset(r = cab_cas_r) offset(delta = -cab_cas_r) square([L, w]);
        }
        translate([OMNI_axle[0], y0 - 1, za]) rotate([-90, 0, 0]) cylinder(d = OMNI_rod_hole_d, h = w + 2);
        for (xs = cab_cas_screw_x) {
            translate([xs, y1, za + cab_cas_screw_dz]) into_y(-1) m3_tap(cab_cas_pilot);
            translate([xs, y0, za + cab_cas_screw_dz]) into_y(1) m3_tap(cab_cas_pilot);
        }
    }
}

// ======================= CAMERA ====================================
// Bracket: base on the roof grid (3x M3 x 10 at grid nodes) + one ear carrying the pivot pilot.
module cab_cam_bracket() {
    bx = cab_cam_base[0]; by = cab_cam_base[1]; bt = cab_cam_base[2]; ey = cab_ear_y;
    difference() {
        union() {
            translate([bx[0], by[0], z_cab_top]) rbox([bx[1] - bx[0], by[1] - by[0], bt], 2);
            translate([cab_cam_foot[0][0], cab_cam_foot[1][0], z_cab_top])
                rbox([cab_cam_foot[0][1] - cab_cam_foot[0][0], cab_cam_foot[1][1] - cab_cam_foot[1][0] + 2, bt], 2);
            cab_xz(ey[0], ey[1] - ey[0]) hull() {
                translate(cab_piv) circle(r = cab_piv_r);
                translate([cab_piv[0] - cab_piv_r + 1, z_cab_top]) square([2 * cab_piv_r, bt + 1]);
            }
        }
        translate([cab_piv[0], ey[0], cab_piv[1]]) into_y(1) m3_tap(ey[1] - ey[0] + 1);
        for (h = cab_cam_base_holes) translate([h[0], h[1], z_cab_top + bt]) m3_clear(bt + 1);
    }
}
// Cradle (tilt 0): back plate behind the camera, pin holes, pivot cheek, clip-screw bosses.
module cab_cam_cradle() {
    x1 = cab_cam_x; x0 = x1 - cab_cr_t; z = cab_cr_z; boss_l = 5;
    difference() {
        union() {
            cab_yz(x0, cab_cr_t) translate([-cab_cr_hw, z[0]]) offset(r = 2) offset(delta = -2) square([2 * cab_cr_hw, z[1] - z[0]]);
            cab_xz(cab_cr_cheek[0] - eps, cab_cr_cheek[1] - cab_cr_cheek[0] + eps) hull() {
                translate(cab_piv) circle(r = cab_piv_r);
                translate([x0, z[0]]) square([cab_cr_t, z[1] - z[0]]);
            }
            cab_mirror_y() translate([x0 - boss_l, cab_clip_screw[0], cab_clip_screw[1]])
                rotate([0, 90, 0]) cylinder(d = 8, h = boss_l + eps);
        }
        // pivot clearance through the cheek (head on the inner face)
        translate([cab_piv[0], cab_cr_cheek[0], cab_piv[1]]) into_y(1) m3_clear(cab_cr_cheek[1] - cab_cr_cheek[0] + 1);
        // clip pilots
        cab_mirror_y() translate([x1, cab_clip_screw[0], cab_clip_screw[1]]) into_x(-1) m3_tap(cab_cr_t + boss_l - 0.5);
        // blind holes for the clip's pins
        for (h = CAM3_holes) translate([x1, -25/2 + h[0], cab_cam_z0 + h[1]]) into_x(-1) _bore(cab_cam_pin_hole_d, 2);
        // window behind the camera board (parts on its back, FPC connector), open at the bottom:
        // a through cut, so it prints without a bridge
        translate([x0 - 1, -cab_cr_win_hw, z[0] - 1]) cube([cab_cr_t + 2, 2 * cab_cr_win_hw, cab_cam_z0 + 22 - z[0] + 1]);
    }
}
// Clip: U-frame over the board front (lens window open at the bottom for the FPC),
// pins through the camera's holes, 2x M3 x 12 into the cradle.
module cab_cam_clip() {
    x0 = cab_cam_x + 1; t = cab_clip_t; z = cab_cr_z;
    difference() {
        union() {
            cab_yz(x0, t) difference() {
                translate([-cab_cr_hw, z[0]]) offset(r = 2) offset(delta = -2) square([2 * cab_cr_hw, z[1] - z[0]]);
                translate([-cab_clip_win_hw, z[0] - 1]) square([2 * cab_clip_win_hw, cab_cam_z0 + 22 - z[0] + 1]);
            }
            cab_mirror_y() translate([cab_cam_x, cab_clip_screw[0], cab_clip_screw[1]]) rotate([0, 90, 0]) cylinder(d = 7, h = 1 + eps);
            for (h = CAM3_holes) translate([cab_cam_x - 1.5, -25/2 + h[0], cab_cam_z0 + h[1]])
                rotate([0, 90, 0]) cylinder(d = cab_cam_pin_d, h = 2.5 + eps);
        }
        cab_mirror_y() translate([x0 + t, cab_clip_screw[0], cab_clip_screw[1]]) into_x(-1) m3_clear(t + 2);
    }
}

// ======================= ASSEMBLY ==================================
module cab_assembled(tilt = cab_cam_tilt, adj = 0) {
    color("SteelBlue") cab_body();
    color("LightSteelBlue") cab_roof();
    color("CadetBlue") cab_faceplate();
    color("OrangeRed") cab_bumper();
    color("Goldenrod") { cab_cassette(adj); mirror([0, 1, 0]) cab_cassette(adj); }
    color("DarkCyan") cab_cam_bracket();
    cab_cam_tilted(tilt) { color("Teal") cab_cam_cradle(); color("PowderBlue") cab_cam_clip(); }
}
module cab_vitamins(tilt = cab_cam_tilt) {
    cab_screen_place() v_screen_unit();
    cab_cam_tilted(tilt) cab_cam_place0() v_cam3();
    v_omni_wheel_placed(1);
    v_omni_wheel_placed(-1);
}
