// joint_probe.scad: proves the J1/J2/J3 holes line up across parts.
// Each joint gets a "bolt probe": a rod slightly thinner than the self-tap pilot, running
// from the screw-head seat to the end of the required engagement. If the clearance hole
// and the pilot in the mating part are coaxial, the probe touches no material.
// openscad -D 'j="J1"' -o out.stl tools/joint_probe.scad   (no STL written = aligned)
include <../robothector_base.scad>
use <../cabin_base.scad>
use <../upper_carriage_base.scad>
use <../lower_carriage_base.scad>

j = "J1";
shift = 0;   // negative control: -D shift=2 must make every joint report material
probe_m5 = m5_pilot_d - 0.3;
probe_m3 = m3_tap_d - 0.3;

module probes(which) {
    if (which == "J1")   // heads on the bulkhead pad inside the cabin, screw runs -X into the lower carriage
        for (b = J1_bolts) translate([bulkhead_t + 1.9, b[0], b[1]]) into_x(-1)
            _bore(probe_m5, bulkhead_t + 1.9 + J1_engage);
    if (which == "J2")   // heads on the tray floor, screws run -Z into the lower carriage bosses
        for (h = J2_holes) translate([h[0], h[1], z_deck + uc_floor_t - 0.1])
            _bore(probe_m3, uc_floor_t - 0.1 + J2_engage);
    if (which == "J3")   // heads inside the tray front wall, screws run +X into the bulkhead bosses
        for (b = J3_bolts) translate([-(uc_front_wall_t + clr_face) + 0.1, b[0], b[1]]) into_x(1)
            _bore(probe_m5, uc_front_wall_t + clr_face - 0.1 + J3_engage);
}

module mates(which) {
    if (which == "J1") { cab_assembled(); lc_assembled(); }
    if (which == "J2") { uc_assembled(); lc_assembled(); }
    if (which == "J3") { uc_assembled(); cab_assembled(); }
}

intersection() { translate([0, shift, 0]) probes(j); mates(j); }
