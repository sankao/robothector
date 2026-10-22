// manual/steps.scad: one scene per assembly-manual step (-D 'step="..."'), built from the
// assembled-position meshes in manual/stl/ (export_parts.sh) plus the ghost vitamins.
// Colours: parts already fitted = DONE grey; parts added in this step = their assembly colour;
// screws = red glyphs on their insertion lines. render.sh holds the camera for each step.
include <../robothector_base.scad>
include <../vitamins.scad>
include <../cabin_base.scad>
include <../upper_carriage_base.scad>
include <../lower_carriage_base.scad>

step = "hero";
E = 50;                       // default explode distance

CAB  = "#3E7CB1";  CAB2 = "#2C5F8A";   // cabin (blue), darker for secondary cabin parts
UC   = "#E8862E";  UC2  = "#C46A1C";   // upper carriage (orange)
LC   = "#5B6670";  LC2  = "#7D8790";   // lower carriage (graphite)
DONE = "#C9CED3";                      // already assembled
SCR  = "#D64545";                      // screws

module P(n) import(str("stl/", n, ".stl"), convexity = 6);

// ---------- screw glyphs ----------
// p: point on the surface where the head seats; d: direction the screw travels (axis-aligned);
// l: screw length; lead: how far outside the head floats (exploded); m: 3 or 5.
module along(d) {
    if (d == [0, 0, 1]) children();
    else if (d == [0, 0, -1]) rotate([180, 0, 0]) children();
    else if (d == [1, 0, 0]) rotate([0, 90, 0]) children();
    else if (d == [-1, 0, 0]) rotate([0, -90, 0]) children();
    else if (d == [0, 1, 0]) rotate([-90, 0, 0]) children();
    else if (d == [0, -1, 0]) rotate([90, 0, 0]) children();
}
module screw(p, d, l, lead = 25, m = 3) {
    hd = m == 5 ? 8.5 : 5.5; hh = m == 5 ? 5 : 3; sd = m == 5 ? 5 : 3;
    color(SCR) translate(p) along(d) {
        translate([0, 0, -lead - hh]) cylinder(d = hd, h = hh, $fn = 24);           // head, floating out
        translate([0, 0, -lead]) cylinder(d = sd, h = l, $fn = 16);                 // shank
        translate([0, 0, -lead + l]) cylinder(d = 0.9, h = lead - l + l, $fn = 8);  // insertion line to depth l
    }
}

// ---------- groups ----------
module cabin_core(c = DONE, a = 1) color(c, a) { P("cab_body"); P("cab_cassette_l"); P("cab_cassette_r"); P("cab_bumper"); }
module cabin_front(c = DONE)  { color(c) { P("cab_faceplate"); P("cab_retainer"); } cab_screen_place() v_screen_unit(); }
module cabin_top(c = DONE)    color(c) { P("cab_roof"); P("cab_cam_bracket"); P("cab_cam_cradle"); P("cab_cam_clip"); }
module cabin_all(c = DONE)    { cabin_core(c); cabin_front(c); cabin_top(c); cab_cam_tilted() cab_cam_place0() v_cam3();
                                v_omni_wheel_placed(1); v_omni_wheel_placed(-1); }
module lc_all(c = DONE)       { color(c) { P("lc_frame"); P("lc_clamp_l"); P("lc_clamp_r"); P("lc_cap_l"); P("lc_cap_r"); }
                                for (s = [-1, 1]) { v_tt_motor_placed(s); v_drive_wheel_placed(s); } }
module uc_fitout(c = DONE)    { color(c) { P("uc_l298n_plate"); P("uc_pd_plate"); P("uc_stops"); P("uc_posts"); }
                                uc_l298n_placed(); uc_pd_placed(); }
module uc_bankset(c = DONE)   { color(c) { P("uc_pushers"); P("uc_clamp_knobs"); } v_bank_max_placed(); }
module uc_lidset(c = DONE)    { color(c) { P("uc_lid"); P("uc_speaker_ring"); P("uc_lid_knobs"); } uc_speaker_placed(); }
module uc_all(c = DONE)       { color(c) P("uc_tray"); uc_fitout(c); uc_bankset(c); uc_lidset(c); }

// ---------- scenes ----------
if (step == "hero") {
    cabin_core(CAB); cabin_front(CAB2); cabin_top(CAB2);
    cab_cam_tilted() cab_cam_place0() v_cam3(); v_omni_wheel_placed(1); v_omni_wheel_placed(-1);
    lc_all(LC); uc_all(UC);
}
else if (step == "overview") {          // the three assemblies pulled apart
    translate([1.6 * E, 0, 0]) { cabin_core(CAB); cabin_front(CAB2); cabin_top(CAB2);
        cab_cam_tilted() cab_cam_place0() v_cam3(); v_omni_wheel_placed(1); v_omni_wheel_placed(-1); }
    translate([0, 0, 1.6 * E]) uc_all(UC);
    lc_all(LC);
}
else if (step == "cassette") {           // wheel + rod into one cassette (left well), exploded
    color(CAB) P("cab_cassette_l");
    translate([0, 0, -45]) v_omni_wheel_placed(1);
    color("silver") translate([OMNI_axle[0], OMNI_well_y[0] + 75, OMNI_axle[1] - 45]) rotate([-90, 0, 0]) cylinder(d = OMNI_rod_d, h = OMNI_cassette_w - 0.5);
    color(SCR) translate([OMNI_axle[0], OMNI_well_y[0] + 2, OMNI_axle[1] - 45]) rotate([-90, 0, 0]) cylinder(d = 0.9, h = 73, $fn = 8);
}
else if (step == "cassettes_in") {       // cassettes up into the wells from below
    color(DONE) P("cab_body");
    for (s = [-1, 1]) translate([0, 0, -55]) {
        color(CAB) P(s > 0 ? "cab_cassette_l" : "cab_cassette_r");
        v_omni_wheel_placed(s);
    }
    for (s = [-1, 1], x = cab_cas_screw_x) {
        screw([x, s * body_w / 2, OMNI_axle[1] + cab_cas_screw_dz], [0, -s, 0], 16, 22);          // outer wall
        screw([x, s * OMNI_inner_wall_y[0], OMNI_axle[1] + cab_cas_screw_dz], [0, s, 0], 16, 22); // inner wall
    }
}
else if (step == "bumper") {
    color(DONE) { P("cab_body"); P("cab_cassette_l"); P("cab_cassette_r"); }
    v_omni_wheel_placed(1); v_omni_wheel_placed(-1);
    translate([E, 0, 0]) color(CAB) P("cab_bumper");
    for (s = cab_bump_screws) screw([x_cab_front + bumper_d + E, s[0], s[1]], [-1, 0, 0], 20, 25);
}
else if (step == "screen") {             // the faceplate / screen / retainer sandwich, exploded along X
    translate([2 * E, 0, 0]) color(CAB) P("cab_faceplate");
    translate([E, 0, 0]) cab_screen_place() v_screen_unit();
    color(CAB2) P("cab_retainer");
    for (sy = [-1, 1]) screw([cab_ret_x[0], sy * cab_ret_screw[0], cab_ret_screw[1]], [1, 0, 0], 16, 30);
}
else if (step == "faceplate_on") {
    cabin_core(DONE); v_omni_wheel_placed(1); v_omni_wheel_placed(-1);
    translate([E, 0, 0]) cabin_front(CAB);
    for (sy = [-1, 1], s = cab_fp_screws) screw([x_cab_front + E, sy * s[0], s[1]], [-1, 0, 0], 12, 30);
}
else if (step == "motor_clamp") {        // left clamp: motor drops in, cap on top
    color(LC) P("lc_clamp_l");
    translate([0, 0, 35]) v_tt_motor_placed(1);
    translate([0, 0, 75]) color(LC2) P("lc_cap_l");
    for (c = lc_cap_screws) screw([c[0], c[1], lc_cl_top + lc_cap_t + 75], [0, 0, -1], 12, 20);
}
else if (step == "clamps_on") {
    color(DONE) P("lc_frame");
    for (s = [-1, 1]) translate([0, 0, 40]) {
        color(LC) { P(s > 0 ? "lc_clamp_l" : "lc_clamp_r"); P(s > 0 ? "lc_cap_l" : "lc_cap_r"); }
        v_tt_motor_placed(s);
    }
    for (s = [-1, 1]) translate([0, s * 35, 0]) v_drive_wheel_placed(s);
    for (s = [-1, 1], b = lc_cl_bolts) screw([b[0], s * b[1], z_floor + floor_t + lc_cl_foot_t + 40], [0, 0, -1], 12, 20);
}
else if (step == "j1") {                 // frame lowered onto the cabin's dovetail tongue
    cabin_core(DONE); cabin_front(DONE); v_omni_wheel_placed(1); v_omni_wheel_placed(-1);
    translate([0, 0, 1.4 * E]) lc_all(LC);
    for (b = J1_bolts) screw([bulkhead_t + 2, b[0], b[1]], [-1, 0, 0], 20, 40, 5);
}
else if (step == "tray_fitout") {
    color(DONE) P("uc_tray");
    translate([0, 0, 45]) uc_fitout(UC);
}
else if (step == "tray_on") {
    cabin_core(DONE); cabin_front(DONE); v_omni_wheel_placed(1); v_omni_wheel_placed(-1); lc_all(DONE);
    translate([0, 0, 1.6 * E]) { color(UC) P("uc_tray"); uc_fitout(UC2); }
    for (h = J2_holes) screw([h[0], h[1], z_deck + uc_floor_t + 1.6 * E], [0, 0, -1], 16, 25);
    for (b = J3_bolts) screw([-(uc_front_wall_t + clr_face), b[0], b[1]], [1, 0, 0], 20, 35, 5);
}
else if (step == "bank") {
    cabin_core(DONE); cabin_front(DONE); lc_all(DONE); color(DONE) P("uc_tray"); uc_fitout(DONE);
    translate([0, 0, 1.4 * E]) uc_bankset(UC);
}
else if (step == "lid") {
    cabin_core(DONE); cabin_front(DONE); lc_all(DONE); color(DONE) P("uc_tray"); uc_fitout(DONE); uc_bankset(DONE);
    translate([0, 0, 1.2 * E]) uc_lidset(UC);
}
else if (step == "roof") {
    cabin_core(DONE); cabin_front(DONE); lc_all(DONE); uc_all(DONE);
    translate([0, 0, E]) color(CAB) P("cab_roof");
    translate([0, 0, 2 * E]) { color(CAB2) { P("cab_cam_bracket"); P("cab_cam_cradle"); P("cab_cam_clip"); }
                               cab_cam_tilted() cab_cam_place0() v_cam3(); }
    for (sy = [-1, 1], r = cab_roof_screws) screw([r[0], sy * r[1], z_cab_top + E], [0, 0, -1], 12, 20);
    for (h = cab_cam_base_holes) screw([h[0], h[1], z_cab_top + cab_cam_base[2] + 2 * E], [0, 0, -1], 10, 18);
}
else assert(false, str("unknown step: ", step));
