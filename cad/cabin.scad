// cabin.scad: printable cabin parts, each in its print orientation, sitting on Z = 0.
//   openscad -D 'part="body"' -o body.stl cabin.scad
// Printables (orientation):
//   body             upright, floor on the bed
//   roof             flat, underside on the bed
//   faceplate        face down
//   screen_retainer  flat (front face down)
//   bumper           rear face down, grid face up
//   omni_cassette    roof down (print 2; the -Y one is the same part turned round)
//   camera_bracket   base down
//   camera_cradle    front face down
//   camera_clip      front face down, pins up
// Views (not printables): "assembled" = printed parts in place, "assembled_vit" = + ghost vitamins.
//   -D cab_cam_tilt=30 / -D 'adj=4' to check the extremes.
include <cabin_base.scad>

part = "body";
ears = true;   // mouse ears on the body's corners (cut off after printing); -D ears=false for a plain body
cab_ear_pts = [for (x = [0, x_cab_front], y = [-body_w / 2, body_w / 2]) [x, y]];
adj  = 0;

module cab_print_x_down(x_face) translate([0, 0, x_face]) rotate([0, 90, 0]) children();   // +X face on the bed
module cab_print_x_up(x_face)   translate([0, 0, -x_face]) rotate([0, -90, 0]) children(); // +X face up, x_face on the bed

if (part == "body")                 { translate([0, 0, -z_floor]) cab_body(); if (ears) mouse_ears(cab_ear_pts); }
else if (part == "roof")            translate([0, 0, -cab_wall_top]) cab_roof();
else if (part == "faceplate")       cab_print_x_down(x_cab_front) cab_faceplate();
else if (part == "screen_retainer") cab_print_x_down(cab_ret_x[1]) cab_retainer();
else if (part == "bumper")          cab_print_x_up(x_cab_front) cab_bumper();
else if (part == "omni_cassette")   translate([0, 0, OMNI_axle[1] + cab_cas_roof_dz + OMNI_roof_t]) rotate([180, 0, 0]) cab_cassette(0);
else if (part == "camera_bracket")  translate([0, 0, -z_cab_top]) cab_cam_bracket();
else if (part == "camera_cradle")   cab_print_x_down(cab_cam_x) cab_cam_cradle();
else if (part == "camera_clip")     cab_print_x_down(cab_cam_x + 1 + cab_clip_t) cab_cam_clip();
else if (part == "assembled")       cab_assembled(cab_cam_tilt, adj);
else if (part == "assembled_vit")   { cab_assembled(cab_cam_tilt, adj); cab_vitamins(cab_cam_tilt); }
