// upper_carriage.scad: printable parts of the upper carriage, each in print orientation, on Z = 0.
//   openscad -D 'part="lid"' -o lid.stl cad/upper_carriage.scad
// Parts: tray | lid | clamp_post | pusher | rear_stop | knob | l298n_plate | pd_plate | speaker_ring
// Views (not printable): assembled (parts + vitamins) | parts | small_bank | max_bank
include <upper_carriage_base.scad>

part = "tray";
ears = true;   // mouse ears on the tray and lid (cut off after printing); -D ears=false for plain parts
uc_ear_pts = ears_rect(x_rear, -clr_face, -body_w / 2, body_w / 2);

if (part == "tray")              { translate([0, 0, -z_deck]) uc_tray(); if (ears) mouse_ears(uc_ear_pts); }   // floor down
else if (part == "lid")          { translate([0, 0, z_uc_top + lid_t]) rotate([180, 0, 0]) uc_lid(); if (ears) mouse_ears(uc_ear_pts); } // top face down, hooks up
else if (part == "clamp_post")   uc_clamp_post();                                              // base down
else if (part == "pusher")       uc_pusher_print();                                            // screw side down
else if (part == "rear_stop")    uc_rear_stop();                                               // base down
else if (part == "knob")         uc_knob();                                                    // cap down
else if (part == "l298n_plate")  uc_l298n_plate();                                             // wall side down
else if (part == "pd_plate")     uc_pd_plate();                                                // wall side down
else if (part == "speaker_ring") uc_speaker_ring();                                            // flange (lid side) down
else if (part == "assembled")    { color("DarkOrange", 0.85) uc_assembled(); uc_vitamins(); }
else if (part == "parts")        uc_assembled();
else if (part == "open")         { color("DarkOrange") { uc_tray(); uc_l298n_plate_placed(); uc_pd_plate_placed(); }
                                   color("Gold") uc_clamp_set(BANK_max); color("silver") uc_clamp_set(BANK_max, "screw");
                                   uc_vitamins(); uc_clamp_report(BANK_max); }
else if (part == "small_bank")   uc_bank_demo([100, 60, 20]);
else if (part == "max_bank")     uc_bank_demo(BANK_max);
else assert(false, str("unknown part: ", part));
