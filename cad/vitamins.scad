// vitamins.scad: ghost models of bought parts, for fit and interference checks only.
// They are envelopes (slightly generous), not exact models. Prefix v_.
// Local frames are documented per module. *_placed modules use the interface constants.
include <robothector_base.scad>

// ---------- Raspberry Pi 4 ----------
// Local: board bottom-left corner at origin, board in XY (85 x 56), components on +Z.
// USB/Ethernet end at +X (x = 85). GPIO header along the y = 56 edge.
PI4_holes = [[3.5, 3.5], [61.5, 3.5], [3.5, 52.5], [61.5, 52.5]];
module v_pi4() {
    color("green") difference() {
        rbox([85, 56, 1.4], 3);
        for (h = PI4_holes) translate([h[0], h[1], 1.4]) _bore(2.7, 2);
    }
    color("silver") {
        translate([65, 2, 1.4])  cube([22, 13.5, 16]);    // ethernet (overhangs ~2)
        translate([69, 22, 1.4]) cube([18, 14.5, 16]);    // USB pair
        translate([69, 40, 1.4]) cube([18, 14.5, 16]);    // USB pair
        translate([3.5, 50.5, 1.4]) cube([51, 5, 8.5]);   // GPIO header
        translate([3.5 + 7.7 - 4.5, -1, 1.4]) cube([9, 7.5, 3.5]);  // USB-C power
    }
}

// ---------- Waveshare 4.3" DSI + Pi 4 on its back ----------
// Local: origin at the centre of the glass front face; glass faces +Z (viewing direction);
// X along the 106 mm width (viewer's right = +X), Y up. The unit extends to -Z.
// The Pi's USB end overhangs the -X edge by about 1 mm (from the Waveshare drawing).
module v_screen() {
    color("black") translate([-SCREEN_board[0]/2, -SCREEN_board[1]/2, -SCREEN_t]) cube([SCREEN_board[0], SCREEN_board[1], SCREEN_t]);
    color("dimgray") translate([-SCREEN_active[0]/2, -SCREEN_active[1]/2, -0.2]) cube([SCREEN_active[0], SCREEN_active[1], 0.3]);
}
module v_screen_unit() {
    v_screen();
    // Pi 4 behind, component side facing away from the screen; holes on the screen's
    // inner pattern (58 x 49): x = -30.62 .. 27.38, y = -24.54 .. 24.5.
    translate([27.38 + 3.5, -24.54 - 3.5, -SCREEN_t - SCREEN_pillar]) mirror([1, 0, 0]) mirror([0, 0, 1]) v_pi4();
}
// Envelope used for keep-outs: the full unit box plus cable clearance behind it.
module v_screen_unit_envelope(with_cables = true) {
    translate([-SCREEN_unit[0]/2, -SCREEN_unit[1]/2, -SCREEN_unit[2] - (with_cables ? SCREEN_cable_clear : 0)])
        cube([SCREEN_unit[0], SCREEN_unit[1], SCREEN_unit[2] + (with_cables ? SCREEN_cable_clear : 0)]);
}

// ---------- Camera Module 3 ----------
// Local: board in XY, 25 wide (X) x 24 tall (Y), bottom-left corner at origin, lens on +Z.
// Holes M2 at (2,2), (23,2), (2,14.5), (23,14.5); lens axis at (12.5, 14.5).
CAM3_holes = [[2, 2], [23, 2], [2, 14.5], [23, 14.5]];
CAM3_lens  = [12.5, 14.5];
module v_cam3() {
    color("green") difference() {
        cube([25, 24, 1]);
        for (h = CAM3_holes) translate([h[0], h[1], 1]) _bore(2.2, 2);
    }
    color("black") translate([CAM3_lens[0] - 4.25, CAM3_lens[1] - 4.25, 1]) cube([8.5, 8.5, 5]);
    color("black") translate([CAM3_lens[0], CAM3_lens[1], 6]) cylinder(d = 7.5, h = 4.5);
    color("tan") translate([12.5 - 8, -2, 0]) cube([16, 4, 2]);   // ribbon connector at the bottom edge
}

// ---------- L298N module ----------
// Local: board bottom-left corner at origin, 43 x 43, components on +Z (27 tall).
L298N_size  = [43, 43];
L298N_holes = [[3, 3], [40, 3], [3, 40], [40, 40]];
module v_l298n() {
    color("red") difference() {
        cube([L298N_size[0], L298N_size[1], 1.6]);
        for (h = L298N_holes) translate([h[0], h[1], 1.6]) _bore(3.2, 2);
    }
    color("black") translate([10, 22, 1.6]) cube([23, 16, 25.4]);  // heatsink
    color("blue") {
        translate([0, 8, 1.6]) cube([8, 12, 11]);    // motor A terminal
        translate([35, 8, 1.6]) cube([8, 12, 11]);   // motor B terminal
        translate([12, 0, 1.6]) cube([16, 8, 11]);   // power terminal
    }
}

// ---------- TT gearmotor ----------
// Local: origin on the shaft axis at the gearbox outer face. Shaft along +Y (out of the face).
// Gearbox body extends to -Y (TT_gearbox[1] thick). Long axis along +X towards the motor can.
// Z = 0 on the shaft axis (shaft centred in the 22.3 mm height).
module v_tt_motor() {
    L = TT_gearbox[0]; T = TT_gearbox[1]; H = TT_gearbox[2]; s0 = TT_shaft_from_tab_end;
    color("gold") difference() {
        union() {
            translate([-s0, -T, -H/2]) cube([L, T, H]);
            // motor clip region, a little thicker
            translate([-s0 + L - TT_clip_len, -T/2 - TT_clip_t/2, -H/2]) cube([TT_clip_len, TT_clip_t, H]);
            // end tab
            translate([-s0 - TT_tab[0], -T/2 - 1.5, -TT_tab[1]/2]) cube([TT_tab[0] + eps, 3, TT_tab[1]]);
        }
        for (z = [-TT_hole_dz/2, TT_hole_dz/2]) translate([-s0 + TT_hole_x, 1, z]) rotate([90, 0, 0]) cylinder(d = TT_hole_d, h = T + 2);
        translate([-s0 - TT_tab[2], 0, 0]) rotate([90, 0, 0]) cylinder(d = TT_hole_d, h = T + 2);
    }
    color("white") intersection() {           // D shaft
        rotate([-90, 0, 0]) cylinder(d = TT_shaft_d, h = TT_shaft_len);
        translate([-TT_shaft_d/2, 0, -TT_shaft_flat/2]) cube([TT_shaft_d, TT_shaft_len, TT_shaft_flat]);
    }
}
module _side(side) { if (side > 0) children(); else mirror([0, 1, 0]) children(); }
module v_tt_motor_placed(side) {
    _side(side) translate([DRIVE_axle[0], DRIVE_gearbox_face_y, DRIVE_axle[1]]) v_tt_motor();
}

// ---------- drive wheel ----------
// Local: axis along +Y, inner face at y = 0, outer face at y = DRIVE_wheel_w, centre at x = z = 0.
module v_drive_wheel() {
    color("dimgray") rotate([-90, 0, 0]) difference() {
        cylinder(d = DRIVE_wheel_d, h = DRIVE_wheel_w);
        translate([0, 0, -1]) cylinder(d = 6, h = DRIVE_wheel_w + 2);
    }
}
module v_drive_wheel_placed(side) {
    _side(side) translate([DRIVE_axle[0], DRIVE_wheel_y_in, DRIVE_axle[1]]) v_drive_wheel();
}

// ---------- omni wheel ----------
// Local: axis along Y, centred at the origin (width OMNI_wheel_w), rod hole on the axis.
module v_omni_wheel() {
    color("yellowgreen") rotate([90, 0, 0]) difference() {
        cylinder(d = OMNI_wheel_d, h = OMNI_wheel_w, center = true);
        cylinder(d = OMNI_rod_d + 0.1, h = OMNI_wheel_w + 2, center = true);
    }
}
module v_omni_wheel_placed(side) {
    _side(side) translate([OMNI_axle[0], (OMNI_well_y[0] + OMNI_well_y[1]) / 2, OMNI_axle[1]]) v_omni_wheel();
    // the 2 mm rod spanning the well, for reference
    _side(side) color("silver") translate([OMNI_axle[0], OMNI_well_y[0] + clr_slide, OMNI_axle[1]])
        rotate([-90, 0, 0]) cylinder(d = OMNI_rod_d, h = OMNI_cassette_w - 0.5);
}

// ---------- power bank ----------
// Local: centred in XY, bottom at z = 0, ports on the -X end face.
module v_bank(size = BANK_max) {
    color("lightslategray") translate([-size[0]/2, -size[1]/2, 0]) rbox(size, 6);
}
// Space the right-angle plugs need behind the port face.
module v_bank_plug_zone(size = BANK_max) {
    color("orange", 0.5) translate([-size[0]/2 - BANK_plug_clear, -size[1]/4, 2]) cube([BANK_plug_clear, size[1]/2, size[2] - 4]);
}
// Largest bank, sitting on the tray floor, port face at BANK_port_face_x.
module v_bank_max_placed() {
    translate([BANK_port_face_x + BANK_max[0]/2, (BANK_bay_y[0] + BANK_bay_y[1]) / 2, z_deck + uc_floor_t]) {
        v_bank(BANK_max);
        v_bank_plug_zone(BANK_max);
    }
}

// ---------- small boards ----------
// Speaker: local axis +Z, front (cone) face at z = 0 facing +Z, body to -Z.
module v_speaker(d = 40, h = 20) {
    color("black") translate([0, 0, -h]) cylinder(d = d, h = h);
}
// PD trigger board (CH224K class): local bottom-left corner at origin.
module v_pd_trigger() {
    color("purple") cube([30, 12, 1.6]);
    color("silver") translate([-1, 2, 1.6]) cube([9, 8, 3.3]);  // USB-C receptacle
    color("green") translate([24, 1, 1.6]) cube([6, 10, 6]);    // output terminal
}
