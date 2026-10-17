// lower_carriage.scad: printable parts of the lower carriage, each in print orientation on Z = 0.
//   openscad -D 'part="frame"' -o frame.stl cad/lower_carriage.scad
// Parts: "frame" (1x, floor down) | "tt_clamp" (1x, left, base down) |
//        "tt_clamp_mirror" (1x, right, base down) | "tt_cap" (2x, flat; flip one for the right side)
// Previews (not printable): "assembled" (frame + clamps + caps + ghost motors and wheels).
include <lower_carriage_base.scad>

part = "frame";

if (part == "frame")                translate([0, 0, -z_floor]) lc_frame();
else if (part == "tt_clamp")        translate([0, 0, -lc_floor_top]) lc_clamp_body();
else if (part == "tt_clamp_mirror") translate([0, 0, -lc_floor_top]) mirror([0, 1, 0]) lc_clamp_body();
else if (part == "tt_cap")          translate([0, 0, -lc_cl_top]) lc_cap();
else if (part == "assembled")       { color("DimGray") lc_frame(); color("SteelBlue") lc_clamps(); lc_vitamins(); }
else if (part == "clamp_detail")    { color("SteelBlue") lc_clamp_body(); color("LightBlue", 0.6) lc_cap(); v_tt_motor_placed(1); v_drive_wheel_placed(1); }
