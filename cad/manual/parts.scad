// manual/parts.scad: every printed sub-part in its ASSEMBLED position (global frame), one per
// `part` value. export_parts.sh renders them once to manual/stl/, so the step scenes in
// steps.scad can import meshes instead of re-running CGAL on the big parts.
include <../robothector_base.scad>
use <../cabin_base.scad>
use <../upper_carriage_base.scad>
use <../lower_carriage_base.scad>

part = "cab_body";

PARTS = ["cab_body", "cab_roof", "cab_faceplate", "cab_bumper", "cab_cassette_l", "cab_cassette_r",
         "cab_cam_bracket", "cab_cam_cradle", "cab_cam_clip",
         "uc_tray", "uc_lid", "uc_posts", "uc_pushers", "uc_clamp_knobs", "uc_lid_knobs", "uc_stops", "uc_l298n_plate", "uc_pd_plate",
         "uc_speaker_ring", "lc_frame", "lc_clamp_l", "lc_clamp_r", "lc_cap_l", "lc_cap_r"];

if (part == "list") echo(parts = PARTS);
else if (part == "cab_body") cab_body();
else if (part == "cab_roof") cab_roof();
else if (part == "cab_faceplate") cab_faceplate();
else if (part == "cab_bumper") cab_bumper();
else if (part == "cab_cassette_l") cab_cassette(0);
else if (part == "cab_cassette_r") mirror([0, 1, 0]) cab_cassette(0);
else if (part == "cab_cam_bracket") cab_cam_bracket();
else if (part == "cab_cam_cradle") cab_cam_tilted() cab_cam_cradle();
else if (part == "cab_cam_clip") cab_cam_tilted() cab_cam_clip();
else if (part == "uc_tray") uc_tray();
else if (part == "uc_lid") uc_lid();
else if (part == "uc_posts") uc_sub("posts");
else if (part == "uc_pushers") uc_sub("pushers");
else if (part == "uc_clamp_knobs") uc_clamp_set(BANK_max, "knob");
else if (part == "uc_lid_knobs") uc_lid_knobs();
else if (part == "uc_stops") uc_sub("stops");
else if (part == "uc_l298n_plate") uc_sub("l298n_plate");
else if (part == "uc_pd_plate") uc_sub("pd_plate");
else if (part == "uc_speaker_ring") uc_sub("speaker_ring");
else if (part == "lc_frame") lc_frame();
else if (part == "lc_clamp_l") lc_side(1) lc_clamp_body();
else if (part == "lc_clamp_r") lc_side(-1) lc_clamp_body();
else if (part == "lc_cap_l") lc_side(1) lc_cap();
else if (part == "lc_cap_r") lc_side(-1) lc_cap();
else assert(false, str("unknown part: ", part));
