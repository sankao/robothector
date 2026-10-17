// fit_test.scad: print this first (PETG, 0.2 mm, no supports, see README for time).
// It tests every fit the chassis relies on, so the base parameters can be tuned
// before the big prints.
//  - Block, top face (vertical holes, as printed): M3 pilots 2.5/2.6/2.7/2.8,
//    a modelled M5 thread, and M5 pilots 4.1/4.3.
//  - Block, front face (horizontal holes, as printed): the same set, plus 2 mm rod
//    holes 2.0/2.2/2.4 running through the block.
//  - Dovetail notch block (clearances 0.15/0.25/0.35) + one tongue, at the J1 flank angle.
// Pick the smallest pilot that an M3 (or M5) can still drive by hand without cracking,
// the rod hole the 2 mm rod slides through freely, and the dovetail that slides without
// rattling. Then set m3_tap_d, m5_pilot_d, m5_mode_*, OMNI_rod_hole_d and clr_slide in
// robothector_base.scad.
include <robothector_base.scad>

part = "coupon";

m3_set = [2.5, 2.6, 2.7, 2.8];
m5_pilots = [4.1, 4.3];
rod_set = [2.0, 2.2, 2.4];
plate = [124, 40, 1.6];
cube_s = 10;                       // horizontal-hole test cubes (hole axis along Y, at mid-height)
boss_h = 10;                       // vertical-hole test bosses

module label(t, size = 3.2) {
    linear_extrude(1) text(t, size = size, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
}

// x positions: 4 M3, then M5 thread, M5 pilots 4.1 / 4.3, then the rod block
xs_m3 = [8, 22, 36, 50];
xs_m5 = [66, 82, 98];
x_rod = 114;

module hcube(x, w = cube_s) translate([x - w/2, 0, 0]) rbox([w, cube_s, cube_s], 1.5);
module test_block() {
    difference() {
        union() {
            // two thin rails tie the features together (labels sit on the middle strip)
            rbox([plate[0], 6, plate[2]], 1.5);
            translate([0, 15, 0]) rbox([plate[0], 9, plate[2]], 1.5);
            translate([0, 26, 0]) rbox([plate[0], 8, plate[2]], 1.5);
            for (x = [0, 57, plate[0] - 6]) translate([x, 0, 0]) rbox([6, 34, plate[2]], 1.5);   // cross ties
            for (x = xs_m3) hcube(x, 9);
            for (x = xs_m5) hcube(x, 11.5);
            translate([x_rod - 9, 0, 0]) rbox([18, cube_s, 7], 1.5);
            for (x = xs_m3) translate([x, 30, 0]) cylinder(d = 8.5, h = boss_h);
            for (x = xs_m5) translate([x, 30, 0]) cylinder(d = 11.5, h = boss_h);
        }
        // horizontal holes along +Y through the cubes
        for (i = [0 : 3]) translate([xs_m3[i], 0, cube_s/2]) into_y(1) _bore(m3_set[i], cube_s + 1);
        translate([xs_m5[0], 0, cube_s/2]) into_y(1) m5_thread(cube_s);
        for (i = [0 : 1]) translate([xs_m5[1 + i], 0, cube_s/2]) into_y(1) _bore(m5_pilots[i], cube_s + 1);
        for (i = [0 : 2]) translate([x_rod - 5 + 5 * i, 0, 3.5]) into_y(1) _bore(rod_set[i], cube_s + 1);
        // vertical holes in the bosses, 10 deep
        for (i = [0 : 3]) translate([xs_m3[i], 30, boss_h]) _bore(m3_set[i], 8);
        translate([xs_m5[0], 30, boss_h]) m5_thread(8);
        for (i = [0 : 1]) translate([xs_m5[1 + i], 30, boss_h]) _bore(m5_pilots[i], 8);
        // labels engraved in the plate between the rows
        for (i = [0 : 3]) translate([xs_m3[i], 19, plate[2] - 0.6]) label(str(m3_set[i]), 2.8);
        translate([xs_m5[0], 19, plate[2] - 0.6]) label("T5", 2.8);
        for (i = [0 : 1]) translate([xs_m5[1 + i], 19, plate[2] - 0.6]) label(str(m5_pilots[i]), 2.8);
        translate([x_rod, 19, plate[2] - 0.6]) label("2/2.2/2.4", 2.2);
        
    }
}

// Scaled J1 dovetail: same flank flare as the real tongue.
dt_flare = (J1_tongue_w[1] - J1_tongue_w[0]) / 2 / (J1_tongue_x[1] - J1_tongue_x[0]); // per mm
dt_len = 12; dt_w0 = 16; dt_h = 4;
function dt_pts(c = 0) = [[c > 0 ? 1 : 0, -(dt_w0/2 + c)], [c > 0 ? 1 : 0, dt_w0/2 + c],
                          [-dt_len - c, dt_w0/2 + dt_len * dt_flare + c], [-dt_len - c, -(dt_w0/2 + dt_len * dt_flare + c)]];
dt_clr = [0.15, 0.25, 0.35];

module dovetail_notch_block() {
    difference() {
        rbox([96, 24, dt_h], 2);
        for (i = [0 : 2]) translate([16 + 32 * i, 24, -1]) rotate([0, 0, 90]) linear_extrude(dt_h + 2) polygon(dt_pts(dt_clr[i]));
        for (i = [0 : 2]) translate([16 + 32 * i, 5, dt_h - 0.6]) label(str(dt_clr[i]), 2.6);
    }
}
module dovetail_tongue() {
    // handle + tongue; the tongue sticks out along -Y from the handle
    translate([0, 0, 0]) rbox([30, 16, dt_h], 2);
    translate([15, 16, 0]) rotate([0, 0, -90]) linear_extrude(dt_h) polygon(dt_pts(0));
}

if (part == "holes") test_block();
if (part == "dovetail") { dovetail_notch_block(); translate([94, 28, 0]) dovetail_tongue(); }
if (part == "coupon") {
    test_block();
    translate([0, plate[1] + 4, 0]) dovetail_notch_block();
    translate([94, plate[1] + 4 + 24 + 4, 0]) dovetail_tongue();
}
