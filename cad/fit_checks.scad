// fit_checks.scad: assertions over the shared constants (no geometry).
// Run: openscad -o /tmp/fit_checks.echo cad/fit_checks.scad   (any assert failure aborts)
include <robothector_base.scad>

// P1/P2 must pass a USB-A plug (16 x 8) and a right-angle USB-C plug (12 x 7).
for (p = [P1, P2]) assert(p[2] > 16 && p[3] > 8, str("passage too small: ", p));

// Passage pointed tops stay inside the walls that carry them.
assert(P1[1] + P1[3]/2 + (P1[2] - opening_flat)/2 < z_uc_top - 3, "P1 top too close to tray rim");
assert(P2[1] + P2[3]/2 + (P2[2] - opening_flat)/2 < z_deck - 2, "P2 top above the lower carriage");
assert(opening_flat <= max_bridge, "opening flat top exceeds max bridge");

// J2 screw heads must clear the tray side walls (inner face at body_w/2 - wall_t).
for (h = J2_holes) assert(abs(h[1]) + m3_head_d/2 < body_w/2 - wall_t, str("J2 head hits tray wall: ", h));
// J2 heads must clear the tray front and rear walls too.
for (h = J2_holes) assert(h[0] - m3_head_d/2 > x_rear + wall_t && h[0] + m3_head_d/2 < -(uc_front_wall_t + clr_face),
                          str("J2 head hits tray end wall: ", h));
// J2 holes must not be under the bank bay.
for (h = J2_holes) assert(!(h[0] > BANK_bay_x[0] && h[0] < BANK_bay_x[1] && abs(h[1]) < BANK_bay_y[1]),
                          str("J2 hole under bank bay: ", h));
// J2 holes must stay out of the drive motor keep-out zone.
for (h = J2_holes) assert(!(h[0] > MOTOR_keepout[0][0] && h[0] < MOTOR_keepout[0][1]
                            && abs(h[1]) > MOTOR_keepout[1][0] && abs(h[1]) < MOTOR_keepout[1][1]),
                          str("J2 hole in motor keep-out: ", h));

// J3 heads (inside the tray, behind its front wall) must not reach into the bank bay.
assert(-(uc_front_wall_t + clr_face) - m5_head_h > BANK_bay_x[1] - 1, "J3 heads reach into the bank bay");
for (b = J3_bolts) assert(abs(b[0]) + m5_head_d/2 < body_w/2 - wall_t, "J3 head hits tray side wall");
for (b = J3_bolts) assert(abs(b[0]) - m5_head_d/2 > P1[2]/2, "J3 bolt collides with P1");

// J1 bolt heads sit inside the cabin, clear of the side wall and above the floor.
for (b = J1_bolts) assert(abs(b[0]) + m5_head_d/2 < body_w/2 - wall_t, "J1 head hits cabin side wall");
for (b = J1_bolts) assert(b[1] - m5_head_d/2 > z_floor + floor_t, "J1 head below cabin floor top");
for (b = J1_bolts) assert(abs(b[0]) > J1_col_y[0] + 4 && abs(b[0]) < J1_col_y[1] - 4, "J1 bolt not inside its column");
assert(J1_col_y[0] > J1_tongue_w[1]/2 + clr_slide, "J1 columns overlap the dovetail notch");

// Omni well holds wheel + two cassette cheeks + clearances.
assert(OMNI_well_y[1] - OMNI_well_y[0] >= OMNI_wheel_w + 2*OMNI_cheek_t + 2*clr_slide + 1,
       "omni well too narrow");
assert(OMNI_axle[1] + OMNI_wheel_d/2 + OMNI_adj + OMNI_roof_t < OMNI_well_top_z, "omni cassette pokes above well top");
assert(OMNI_well_x[1] - OMNI_well_x[0] >= OMNI_wheel_d + 4, "omni well too short");
assert(OMNI_axle[1] - OMNI_wheel_d/2 < 0.5 && OMNI_axle[1] - OMNI_wheel_d/2 > -0.5, "omni wheel not on the ground");

// Drive wheel sits on the ground, under the deck, inside the body width.
assert(abs(DRIVE_axle[1] - DRIVE_wheel_d/2) < 0.5, "drive wheel not on the ground");
assert(DRIVE_axle[1] + DRIVE_wheel_d/2 < z_deck - 2, "drive wheel hits the upper carriage");
assert(DRIVE_wheel_y_in + DRIVE_wheel_w <= body_w/2, "drive wheel sticks out of the body");
assert(DRIVE_wheel_y_in > DRIVE_gearbox_face_y + 1, "drive wheel rubs the gearbox face");
assert(DRIVE_axle[0] - DRIVE_wheel_d/2 > x_rear + 5, "drive wheel pokes out of the rear");
assert(DRIVE_axle[0] + DRIVE_wheel_d/2 < x_front_bay_rear - 5, "drive wheel hits the front bay walls");

// Bank bay holds the maximum bank, the plug zone and a clamp.
assert(BANK_bay_x[1] - BANK_port_face_x - BANK_max[0] >= 15, "no room for the front pusher");
assert(BANK_port_face_x - BANK_bay_x[0] >= BANK_plug_clear, "no room for right-angle plugs");
assert(BANK_bay_y[1] - BANK_bay_y[0] >= BANK_max[1] + 8, "bank bay too narrow for the side pusher");
assert(z_deck + uc_floor_t + BANK_max[2] + 20 <= z_uc_top, "no room for the lid speaker over the bank");

// Every part family fits on the bed.
assert(-x_rear <= bed[0], "carriage too long for the bed");
assert(x_cab_front - J1_tongue_x[0] <= bed[0] && body_w <= bed[1], "cabin footprint too big");
assert(z_cab_top - roof_t - z_floor <= bed[2], "cabin too tall");

echo("fit_checks: all assertions passed");
