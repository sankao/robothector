// rod_jig.scad: cutting jig for the 2 mm steel omni-wheel axles (any length via -D jig_len=...).
//
// The rod lies in a 90 deg V-groove, butted against a fixed stop, and a lid clamps it on both
// sides of a cut slot, so the short piece cannot fly off and the stock cannot spin. The slot is
// the disc thickness plus slot_clr per side, placed so the piece comes out jig_len +/- slot_clr
// wherever the disc runs inside it. Keep the disc light against the slot walls (PETG melts if a
// spinning disc rubs it) and cut in short bursts; the base is relieved around the cut so hot
// steel does not sit on plastic.
//
// Use: clamp the base in a vise; square the rod end; back the lid screws off half a turn; slide
// the rod in from the open end until it hits the stop; tighten; cut down through the lid slot;
// loosen, lift out the piece, deburr the stock's new end before the next piece.
//
//   openscad -D 'part="base"' -o base.stl cad/rod_jig.scad      (also: "lid", "plate", "assembled")
include <robothector_base.scad>

part = "plate";

jig_len  = OMNI_cassette_w - 0.5;   // 37: cut-piece length (the axle tolerance is 37 +/- 0.5)
rod_d    = OMNI_rod_d;              // 2
disc_t   = 1.1;                     // cut-off disc thickness (reinforced discs ~1.1, thin ones ~0.6)
slot_clr = 0.3;                     // per side: piece length is jig_len +/- slot_clr
proud    = 0.3;                     // rod top above the base top, so the lid clamps it
relief   = 3;                       // no plastic under the rod within this distance of the cut
stop_t   = 5;                       // stop wall
stock_l  = 35;                      // stock support beyond the slot
jw       = 30;                      // jig width (Y)
jh       = 12;                      // base height
jlid_t   = 5;                       // lid thickness
screw_y  = 9;                       // lid screws, |y| from the groove
label_t  = 0.6;

// derived
v_depth  = rod_d / 2 * sqrt(2) + rod_d / 2 - proud;     // groove apex below the base top
slot     = [jig_len - slot_clr, jig_len + disc_t + slot_clr];   // slot X range (stop face at X = 0)
x_end    = slot[1] + stock_l;
slot_z0  = jh - v_depth - 3;                             // slot bottom: 3 mm under the groove apex
screws   = [[jig_len * 0.25, screw_y], [jig_len * 0.75, -screw_y],
            [slot[1] + 9, -screw_y], [slot[1] + stock_l - 8, screw_y]];

assert(slot_z0 >= 4, "base too thin under the slot");
assert(screws[0][0] - m3_head_d / 2 > 0 && screws[3][0] + m3_head_d / 2 < x_end, "lid screws off the jig");
echo(jig = str("cut piece ", jig_len - slot_clr, "..", jig_len + slot_clr, " mm; slot ", slot[1] - slot[0], " mm wide"));

module jig_v_groove() {   // 90 deg V along +X from the stop face (X = 0) out through the open end
    // profile in (Y, Z), extruded along X: rotate([90, 0, 90]) maps 2D (u, v) and extrusion w to (w, u, v)
    rotate([90, 0, 90]) linear_extrude(x_end + 1)
        polygon([[0, jh - v_depth], [v_depth + 1, jh + 1], [-(v_depth + 1), jh + 1]]);
}
module jig_slot(z0, z1) translate([slot[0], -jw / 2 - 1, z0]) cube([slot[1] - slot[0], jw + 2, z1 - z0]);

module jig_base() {
    difference() {
        translate([-stop_t, -jw / 2, 0]) rbox([x_end + stop_t, jw, jh], 3);
        jig_v_groove();
        jig_slot(slot_z0, jh + 1);
        // relief: no plastic under the rod near the cut
        translate([slot[0] - relief, -v_depth - 0.5, jh - v_depth - 1.5]) cube([slot[1] - slot[0] + 2 * relief, 2 * v_depth + 1, v_depth + 2]);
        for (s = screws) translate([s[0], s[1], jh]) m3_tap(jh - 2);
    }
}
module jig_lid() {   // modelled in place on top of the base (Z = jh .. jh + jlid_t)
    difference() {
        translate([-stop_t, -jw / 2, jh]) rbox([x_end + stop_t, jw, jlid_t], 3);
        jig_slot(jh - 1, jh + jlid_t + 1);
        for (s = screws) translate([s[0], s[1], jh + jlid_t]) m3_clear(jlid_t + 1);
        // engraved length and an arrow at the slot
        translate([jig_len / 2, 0, jh + jlid_t - label_t]) linear_extrude(label_t + 1)
            text(str(jig_len), size = 6, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
        translate([(slot[0] + slot[1]) / 2, jw / 2 - 2, jh + jlid_t - label_t]) linear_extrude(label_t + 1)
            polygon([[0, 0], [-2.5, -4], [2.5, -4]]);
    }
}

if (part == "base") jig_base();
else if (part == "lid") translate([0, 0, jh + jlid_t]) rotate([180, 0, 0]) jig_lid();     // top face down
else if (part == "plate") { jig_base(); translate([0, jw + 8, jh + jlid_t]) rotate([180, 0, 0]) jig_lid(); }
else if (part == "assembled") {
    color("SteelBlue") jig_base();
    color("LightSteelBlue", 0.6) translate([0, 0, proud]) jig_lid();
    color("silver") translate([0, 0, jh - v_depth + rod_d / 2 * sqrt(2)]) rotate([0, 90, 0]) cylinder(d = rod_d, h = x_end + 20);
}
else assert(false, str("unknown part: ", part));
