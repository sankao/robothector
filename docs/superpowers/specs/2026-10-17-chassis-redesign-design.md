# Robothector chassis redesign: OpenSCAD design

Date: 2026-10-17. Status: draft for review (rev 2, after builder check).

## 1. Intent

The current truck body was printed ad hoc. It works, but it is hard to modify, the
2S 18650 holder + BMS is finicky, and nothing has a standard place to bolt new parts on.
We are redoing the whole truck body as a parametric OpenSCAD project inside this repo,
so that:

- the existing electronics (Pi 4 + Waveshare 4.3" DSI screen, Camera Module 3, L298N,
  2 TT motors, 2 omni-wheels) fit without hacks;
- power moves to an off-the-shelf USB-C power bank, so the BMS and 18650 holder disappear;
- adding a sensor, swapping the motor driver, or trying a different motor later means
  printing one small adapter part, not reprinting a chassis.

The robot is a toy for Hector (a kid), driven remotely. "Robust" means it survives
being driven into furniture, knocked off a step, and picked up by whatever part a
child grabs: the cabin, the cargo box, or a wheel.

## 2. Goals, non-goals, anti-goals

Goals, in priority order (from the user):
1. **Ease of printing**: every part prints on a Prusa MK3S+ with no support material.
2. **Robustness**: see §1. Thick walls, bumpers that take hits, and no thin tabs carrying load.
3. **Modularity**: a universal mounting grid on every free surface, adapter plates for
   components, swappable motor clamps, swappable omni-wheel cassettes, and an adjustable
   clamp for a power bank whose size is not yet known.

Non-goals (for now):
- Audio hardware (mic, amp) and the 2 mode buttons. Skipped, but the grid must leave room
  for them later. A **speaker mount is in scope** (upper carriage).
- PWM speed control, sensors themselves, light bar. Only their mounting points are in scope.
- Software changes.

Anti-goals (would make this a failure even if it "works"):
- Any part that needs supports, or has an unsupported bridge longer than 20 mm.
- Any component screwed straight into a chassis-specific hole pattern, which defeats
  the modularity goal.
- Parts that only fit together if printed at the exact nominal size (no clearances).
- Exceeding the current truck's overall footprint.

## 3. Constraints

| Constraint | Value |
|---|---|
| Printer | Prusa MK3S+, bed 250 × 210 × 210 mm. Every part must fit within **245 × 205 × 205**. |
| Filament | PETG recommended for impact and heat (Pi 4, L298N). PLA works with the same clearances. *(my call)* |
| Fasteners on hand | M3 socket screws 5–25 mm (plenty); M5 screws (lengths: **assumed 16–20 mm available**). **No heat-set inserts, no nuts.** |
| M3 holding | Self-tapping into undersized printed pilot holes. |
| M5 holding | **Modelled (printed) M5×0.8 threads** where the hole axis is vertical in the part's print orientation. Where it is horizontal, a Ø4.3 pilot that the screw self-taps into. Each M5 hole picks its mode with a parameter, and the fit coupon tests both modes in both orientations. |
| Tooling | OpenSCAD **2021.01** (apt), no BOSL2/threadlib, only MCAD. Thread geometry must be written in-house. Renders and STL checks follow the `openscad-cli` skill; slicing checks follow `prusaslicer-cli`. |
| Size | Keep the current truck's overall size. It was sized for the MK3S bed and for the Pi's width. The numbers below are **estimates from photos**; the global parameters are the single place to correct them. |

## 4. Components to accommodate

Datasheet values, used to build the reference models (the "ghost" parts):

| Part | Key dimensions | Source |
|---|---|---|
| Raspberry Pi 4 | 85 × 56 board, M2.5 holes on 58 × 49, 3.5 mm from the edges | RPi drawing |
| Waveshare 4.3" DSI LCD (capacitive, 800×480) | Board 106.0 × 68.0, thickness 14.05. Enclosure holes at the 4 corners on **99.30 × 61.80** (3.35 mm from the sides, 3.1 mm from the top/bottom). Pi holes on 58 × 49, 25.62 mm from the left edge and 22.38 mm from the right, 9.50 mm from the top. The Pi bolts to the back on copper pillars, and its USB end overhangs the right edge by ≈1 mm. | Waveshare Exterior-Size drawing |
| Screen + Pi unit (envelope) | **108 × 70 × 45 deep**, plus 25 mm of cable clearance behind it. Pillar height not yet measured, so this is parametric. | derived |
| Camera Module 3 | 25 × 24 × 11.5, M2 holes on 21 × 12.5. 15 cm ribbon (present). | RPi drawing |
| L298N module | ≈43 × 43 × 27 tall (heatsink), M3 holes ≈37 × 37 | typical; parametric |
| TT gearmotor (yellow 1:48) | Gearbox 64.4 long × 22.3 wide × 18.7 thick (22.6 at the motor clip). Shaft Ø5.5 with 3.7 mm flats, 9.1 mm long. 3 holes Ø2.8: two through the body near the motor end and one in the end tab. The shaft sits 11.0 mm from the tab end of the gearbox and is centred in the 22.3 width. | SunFounder drawing |
| Drive wheel | Ø63 (soft, approximate), 26 wide *(width assumed standard TT wheel)* | user |
| Omni-wheel | Ø58, **2 mm steel rod axle**. Width ≤ 29 *(assumed)*. | user |
| Power bank | **Unknown model.** Design envelope: from 100 × 60 × 20 up to **155 × 90 × 32**, ports on one short end. | user + my call |
| PD trigger board | CH224K-class, ≈30 × 12 × 6, set to 9 V (or 12 V) | wiki 2026-05-09 |
| Speaker | Ø28–50, ≤ 20 deep | design envelope |

Power topology is unchanged from the 2026-05-09 decision. One USB-C port goes to the PD trigger
and then to the L298N; a second port goes to the Pi. No boost converter and no BMS: the
bank's own protection replaces the BMS. Caveat: some banks drop all ports to 5 V when two are
in use. If yours does, use a single PD port and a 5 V/3 A buck converter for the Pi. The grid
has room for one (§7). Right-angle USB-C/USB-A plugs are assumed (≈12 mm behind the bank's port
face instead of 30 mm for straight plugs).

## 5. Architecture

### 5.1 Reference frame (shared by every file)

- **X** points forward (cabin at +X). **Y** points left. **Z** points up.
- **Z = 0** is the ground. **X = 0** is the bulkhead plane: the cabin's rear face, which
  touches the front of both carriages. **Y = 0** is the centreline.
- Every part file models its part **in this assembly frame** (assembled position).
  Print orientation is a separate transform, applied only in the print/export file.

### 5.2 Layout

```
 SIDE VIEW (front to the right)                                    Z
                                     +---------------------+ 150  roof (separate part)
                                     |  [camera bracket]   |
 +===================================+ 131 lid             |
 | UPPER CARRIAGE (tray)    [spk]    |   screen + Pi       |# face plate (separate)
 | [L298N]| bank bay -195..-10   J3=>|   behind face       |#
 +-----------------------------------+ 67                  |#
 | LOWER CARRIAGE            J1 M5 =>|  bulkhead           +--+
 |rear| TT motors | front bay (grid) |                     |  | front bumper
 |wall|  (O) Ø63                     |   omni cassette (o) |  | (separate)
 +----+--( )-----------+====dovetail=====+--------( )------+--+  12
 ====== ground ===================================================== 0
 X: -240    -200     -160         -30   0     [33..99] 66     105  120
```

```
 TOP VIEW (front to the right)
 +------------------------------------+---------------------+
 |##wheel##|                          | omni cassette (well)|
 |  motor  |   front bay (grid),      |                     |
 |  zone   |   full width 140         |  cabin 140 wide     |
 |  ±41    |                          |                     |
 |##wheel##|                          | omni cassette (well)|
 +------------------------------------+---------------------+
  -240  -200  -160                     0                   105
```

| Assembly | Parts (each prints separately) |
|---|---|
| **Cabin** | cabin body (with bulkhead and dovetail tongue), roof, face plate, front bumper, 2 omni-wheel cassettes, camera bracket |
| **Upper carriage** | tray, lid, power-bank clamp posts and pusher plates, L298N plate, PD-trigger plate, speaker ring |
| **Lower carriage** | frame (floor, front-bay walls, motor zone, rear bumper wall), 2 TT motor clamps |

### 5.3 Global dimensions (initial values; all are parameters in `robothector_base.scad`)

| Parameter | Value | Note |
|---|---|---|
| `body_w` | 140 | overall width; the wheels sit **inside** this width, protected by the body *(estimate, confirm)* |
| `z_floor` | 12 | underside of every floor (ground clearance) |
| `z_deck` | 67 | top of the lower carriage = underside of the upper carriage; 4 mm above the drive-wheel top |
| `z_uc_top` | 127 | top rim of the upper carriage tray; the lid covers 127–131 (4 mm, a grid surface) |
| `z_cab_top` | 150 | top of the cabin roof (body walls to 146, roof 146–150) |
| `x_rear` | -240 | rear face of both carriages; the lower carriage's rear wall doubles as the rear bumper |
| `x_cab_front` | 105 | cabin front face; the bumper occupies 105–120 |
| Drive axle | X = -200, Z = 31.5 | wheel spans Y ±43…±69; gearbox outer face at Y = ±41 |
| Omni axle | X = 66, Z = 29 | adjustable ±4 mm in the cassette slots (levels the chassis) |
| Wheelbase | 266 | |
| Overall | ≈ 360 L × 140 W × 150 H (+ roof accessories) | |

The lower carriage is **full width (Y ±70) from X = -160 to 0** (the "front bay"). From
X = -240 to -160 it is **a narrow motor zone, Y ±41**, so the drive wheels sit inside the
body width. The upper carriage is full width along its whole length. It sits above the
wheel tops and acts as the mudguard. *(my call: no wheel arches to print, and the lower
carriage gains a big grid bay.)*

**Drive wheel size range:** the TT clamp supports wheels of about Ø60–66. That puts the axle
at Z 30–33: the gearbox stays above the floor (Z 18) and the wheel top stays below `z_deck`.
Wheels outside this range need a new `z_deck` (a parameter change and a reprint), not just a
new clamp.

## 6. Interfaces (fixed; both sides of each joint must match these exactly)

Every interface coordinate below is defined **once** in `robothector_base.scad` as named
constants or lists (`J1_*`, `J2_*`, `J3_*`, `P*_*`, `OMNI_*`, `MOTOR_*`), and both mating
parts use them. Default clearance is 0.25 mm per side on sliding fits and 0.2 mm between bolted
mating faces (the carriages stop at X = -0.2).

### Load case that sizes J1 and J3

When a child lifts the robot by the cabin, the carriages droop at the rear. That pivots the
joint about its bottom edge: the bottom of the bulkhead face goes into compression, and the
**top of the joint goes into tension** along X. Pressing down on the cabin reverses this.
J1 therefore needs an X-tension member at the bottom (the dovetail) and another at the top
(the M5 bolts, loaded axially). J3 adds a second top tie through the upper carriage.

### J1: cabin ↔ lower carriage (structural)

1. **Dovetail tongue (floor level).** The cabin floor continues rearward as a plan-view
   dovetail tongue: X ∈ [-30, 0], Z ∈ [12, 22], 80 wide at X = 0 and 96 wide at X = -30.
   The lower carriage floor (Z 12–18) has a matching through-notch, 0.25 mm per side larger.
   Both parts print flat, so there is no overhang. The tongue takes the bottom X-tension,
   side-to-side shear, and alignment.
2. **2× M5 along X**, at (Y, Z) = (±60, 55). The heads sit **inside the cabin**, against the
   bulkhead's inner face (X = 4). The screws pass through Ø5.5 holes in the bulkhead and screw
   into the front-end columns of the lower carriage side walls. Those columns are thickened to
   Y ±[52, 70] over X ∈ [-20, 0] and up to `z_deck`, and give at least 12 mm of engagement.
   The holes are horizontal in the lower carriage's print orientation, so the default mode is a
   Ø4.3 self-tap pilot; a modelled thread is possible if the fit coupon shows it prints well.
   Screw: M5×16–20. These carry top tension axially, and vertical shear in the shank.
3. The lower carriage side walls and the floor's front edge (outside the notch) bear on the
   bulkhead's rear face at X = 0. The bolt preload closes this face along the full height.
4. **Assembly:**
   1. Stand the cabin on the table without its roof.
   2. Lower the lower carriage straight down so its floor notch drops over the tongue.
   3. Drive both M5 screws from inside the cabin; there is room for a ball-end hex key from
      the open top.

### J2: upper carriage ↔ lower carriage

The upper carriage floor (Z 67–71) rests on every lower-carriage top surface at Z = 67.
It is fixed by **6× M3, vertical**, with heads inside the upper carriage, at
(X, Y) = (-45, ±62), (-150, ±62), (-229, ±30). They pass through Ø3.4 holes into Ø2.7
self-tap pilots that go at least 10 mm deep into lower-carriage bosses. The rear pair sits in
a boss on the front of the rear bumper wall (clear of the tray's rear wall). None of these heads may lie under the battery bay or inside the tray's
side walls (inner face at Y ±66).

### J3: upper carriage ↔ cabin bulkhead (structural top tie)

**2× M5 along X**, with heads inside the upper carriage, at (Y, Z) = (±50, 100). They pass
through Ø5.5 holes in the tray's front wall (X ∈ [-4.2, -0.2]) into Ø4.3 self-tap pilots that
go at least 12 mm deep into bulkhead bosses on the cabin's inner side. The heads must clear
the bank bay (X ≤ -10).

### Cable passages

| Id | Where | Size | Purpose |
|---|---|---|---|
| P1 | Bulkhead **and** tray front wall, centred Y = 0, Z = 95 | 40 W × 24 H rectangle with a 45° top narrowing to a 16 mm flat | Pi USB-C power, GPIO jumpers to the L298N, future I2S |
| P2 | Bulkhead, centred Y = 0, Z = 42 (into the lower carriage front bay) | 40 W × 20 H with a 45° top | future sensors, alternate battery or driver location |
| P3 | Tray floor, Ø16 at (-215, 0) and (-30, 40) | | motor wires down to the motor zone; front-bay access |

The lower carriage has **no front wall**: the bulkhead closes it.

### Drive motor interface (lower carriage)

- **Keep-out zone:** no frame structure in X ∈ [-222, -140], Y ±[18, 41.5], Z ∈ [18, 45],
  and nothing outboard of Y ±41.5 in X ∈ [-236, -164] below `z_deck`. This space belongs to
  the motor clamps, the motors and the wheels.
- **Frame members there:** the motor zone is
  - a 6 mm floor with the grid,
  - a central spine rib (Y ±[-8, 8] at most, up to Z 45), and
  - the 8 mm rear bumper wall (X ∈ [-240, -232], Y ±41, up to `z_deck`).

  The upper carriage, bolted on top at J2, closes the box section.
- **Mounting:** motors attach only through **clamps that bolt to the floor grid**. So the
  floor grid is the motor mounting standard: a JGA25-370 or N20 needs only a new clamp. The TT
  clamp puts the gearbox outer face at Y = ±41 and the shaft at X = -200, Z = 31.5.

### Omni-wheel interface (cabin)

- **Wells:** the cabin has two rectangular wells, X ∈ [33, 99], Y ±[28, 66], open at the
  bottom **and** at the top into the cabin interior, so the body has no bridge.
  - The outer face of each well is the cabin side wall (Y ±[66, 70]).
  - The inner face is a wall at Y ±[24, 28] that rises from the floor to Z 70.
  - A cross wall at X ∈ [29, 33] closes the rear of each well.
- **Cassette:** each wheel lives in a separate **cassette**, an inverted U: a 3 mm roof and
  two 3 mm cheeks, 37.5 wide in Y.
  - It prints roof-down, so there is no overhang.
  - The rod runs through Ø2.2 holes in the cheeks and is trapped at both ends by the well
    walls (the rod is about 37 long, and the well walls have no holes). That means **no
    collar is needed**.
  - It is fixed by 2× M3 per cheek along Y. The screws pass through **vertical slots
    (±4 mm)** in the side wall and the inner well wall, into pilots in the cheeks, and set
    the ride height.
  - The cassette's roof top must stay below Z 70, under the screen unit.
- A different wheel (wider, castor, larger) only needs a new cassette.

## 7. Modularity system (applies to all parts)

1. **Universal grid:** M3 self-tap pilot holes (Ø2.7), on a **20 mm pitch, aligned to
   the global frame** (X, Y, Z at multiples of 20). *(Rev 3, 2026-10-17: was 10 mm; cut to a
   quarter of the holes for print time at the user's request. Mounts that need finer positions
   use slots ≥ 20 mm long in their feet.)* So any adapter fits any grid surface on
   any part. Each grid surface is at least 4 mm thick, and holes stay at least 4 mm from
   edges and walls. Grid surfaces:
   - cabin: floor (between and behind the wells), roof (top), side-wall patches above the
     wells, bumper front face;
   - upper carriage: whole floor, both side walls, rear wall, lid;
   - lower carriage: front bay floor and walls, motor zone floor.
2. **Adapter plates:** `adapter_plate(size, holes, standoff_h, hole_d)` in the base library
   generates a plate with M3 clearance slots on the 10 mm grid, plus standoffs at any
   component's own hole coordinates. Adding a component means one call with its hole list.
   A `slotted_plate()` covers boards with unknown or odd hole patterns.
3. **Power bank clamp** *(user's idea, made generic)*:
   - **Bay:** X ∈ [-195, -10], Y ∈ [-50, 50], for banks up to 155 × 90 × 32. The ports
     face the rear (−X), towards the electronics.
   - **Rear stops:** 2 corner posts, which leave the middle of the port face open for
     right-angle plugs.
   - **Front pusher:** a clamp post bolts to the floor grid at any 10 mm position (coarse).
     It carries a horizontal M3 self-tap boss for a "set screw" up to 25 mm, giving about
     15 mm of travel (fine). The screw pushes a **pusher plate** that has a captive cup for
     the screw tip and a recess for a foam pad.
   - **Y clamping:** the same post + pusher on one side, a post or the wall on the other.
   - **Z hold-down:** a 20 mm hook-and-loop strap through **floor through-slots** at
     X ≈ -40 and ≈ -140. These lie over the open front bay of the lower carriage, so the
     strap passes under the tray floor and no channel is needed.
4. **Motor clamps:** see §6, drive motor interface.
5. **Speaker:** a grille (≥ Ø50) in the **lid**, over the bank bay's rear half (a bank ≤ 32
   tall leaves 24 mm under the lid). A `speaker_ring(d)` adapter covers Ø28–50
   speakers and bolts to the lid's grid. The wire must be long enough to lift the lid off.
6. **Spare capacity:** the lower carriage front bay (X -160…0, 140 wide, about 49 tall) is
   empty grid space. It suits a buck converter, IMU, future audio boards, the L298N, or the
   power bank itself for a lower centre of gravity.

Default electronics layout (upper carriage interior X ∈ [-236, -4], Y ±66, Z 71–127):
- the L298N on its plate on the **rear wall grid**, standing vertical with the heatsink
  facing forward (occupies X ∈ [-236, -205]), with vent slots in the rear wall behind it;
- the PD trigger on a side-wall grid near the rear;
- the bank bay as in item 3.

## 8. Per-part requirements

### Cabin (body + roof + face plate + bumper + omni cassettes + camera bracket)

**Body:**
- Prints upright: floor on the bed, **open top, open front above Z = 70**. This avoids
  bridging over the screen opening, the wells and the roof.
- Walls are 4 mm; the floor is 6 mm (Z 12–18).
- It includes:
  - the bulkhead (X ∈ [0, 4]) with P1, P2, the J1 holes and the J3 bosses;
  - the J1 dovetail tongue;
  - the wheel wells (§6);
  - roof bosses at the wall tops;
  - a front lower wall (X ∈ [101, 105], Z 12–70) that carries the bumper and closes the
    wells' front.

**Roof** (Z 146–150):
- Prints flat and bolts to the wall-top bosses with M3 (vertical pilots).
- Carries the roof grid, a ribbon slot for the camera near the front, and Pi vents.

**Face plate:**
- Closes the front opening: Y ±66, Z 70–146.
- Prints face down.
- The screen + Pi unit hangs from the plate's back by the screen's 4 corner holes
  (99.3 × 61.8), so it comes out as one assembly.
- The bezel window shows the active area. Its lip stands **2 mm proud of the glass**,
  and the bumper stands 15 mm proud of the face, to protect the glass.
- It bolts on from the front with M3 and must be removable without removing anything else.

**Bumper:**
- Separate and sacrificial: X ∈ [105, 120], Z ≈ 20–60, full width.
- Bolted to the front lower wall.
- Its front face carries grid holes for sensors.

**Omni cassettes:** see §6.

**Camera bracket:**
- Bolts to the roof grid at the front edge, with tilt adjustable from 0 to 30° down.
- Its lens must clear the face plate's top edge.

**Cable access:**
- the USB-C power cable reaches the Pi;
- GPIO jumpers reach the header;
- the camera ribbon reaches the CSI port;
- a vertical slot in the side wall at the Pi's USB/Ethernet end gives debugging access;
- the J1 M5 heads (inside the rear corners) can be reached from the open top.

### Upper carriage (tray + lid + clamp hardware + plates + speaker ring)

**Tray:**
- Prints floor down: open top, 4 mm walls, 4 mm floor (Z 67–71).
- The front wall carries P1 and J3; the floor carries J2, P3 and the strap slots; the rear
  wall carries the L298N grid and vents.

**Lid** (Z 127–131):
- Prints flat, carries a grid and the speaker grille.
- Must be removable to swap or charge the bank. Prefer front hook tabs plus 1–2 M3
  thumb-screws at the rear, but the fixing method is the builder's call.
- A rear- or side-wall slot (≥ 15 × 10) lets a charging cable reach the bank with the lid on.

**Clamp hardware, L298N plate, PD-trigger plate, speaker ring:** see §7.

### Lower carriage (frame + motor clamps)

**Frame:**
- Prints floor down, open top, no front wall.
- Floor: 6 mm (Z 12–18) with the J1 dovetail notch.
- Front bay side walls: Y ±[64, 70], up to Z 67, with the J1 columns at their front ends.
- Motor zone and rear bumper wall: see §6. The rear wall has rounded corners.
- A gusseted, filleted transition at X = -160, where the plan narrows from 140 to 82.
- Bosses for J2.

**TT clamps:**
- The motor lies along X with its can pointing forward. Gearbox and can span roughly
  X ∈ [-216, -147].
- The clamp holds the motor by its two body through-holes (M3×25 through the gearbox into
  the clamp) and by the end tab.
- It bolts to the floor grid; the axle height is set by the clamp, not the frame.

## 9. Files and conventions

```
cad/
  README.md                 print table (part, orientation, time, screws), assembly order, BOM
  robothector_base.scad     global params, interface constants, fastener + grid + adapter library, M5 thread
  vitamins.scad             ghost models: Pi 4, screen+Pi unit, Camera Module 3, L298N, TT motor,
                            drive wheel, omni wheel, power bank envelope, speaker
  fit_test.scad             test coupon: M3 pilots 2.5/2.6/2.7/2.8 (vertical + horizontal),
                            M5 thread and M5 pilot (vertical + horizontal), Ø2 rod holes, dovetail sample
  cabin_base.scad           modules only (no top-level calls)
  cabin.scad                part = "body" | "roof" | "faceplate" | "bumper" | "omni_cassette" | "camera_bracket"
  upper_carriage_base.scad
  upper_carriage.scad       part = "tray" | "lid" | "clamp_post" | "pusher" | "l298n_plate" | ...
  lower_carriage_base.scad
  lower_carriage.scad       part = "frame" | "tt_clamp"
  assembly.scad             every part in its assembled place + ghost vitamins, exploded view option
  stl/                      exported STLs (one per printed part, already in print orientation)
  preview/                  PNG renders
```

- Base files contain parameters and modules only (no instantiation), per the openscad-cli skill.
- **Name prefixes:** cabin `cab_`, upper carriage `uc_`, lower carriage `lc_`. Unprefixed
  names belong only to `robothector_base.scad` and `vitamins.scad`. This prevents collisions
  in `assembly.scad`.
- Every dimension that a later upgrade might change sits at the top of its base file and
  is commented with what it touches.
- `<part>.scad` with `-D part="x"` exports one printable in print orientation, sitting on Z = 0.

## 10. Verification (definition of done)

1. Every STL exports with `Simple: yes` (manifold) and fits 245 × 205 × 205.
2. **Interference:** in `assembly.scad`, the pairwise `intersection()` of mating parts,
   and of each part with its ghost vitamins (with the maximum 155 × 90 × 32 bank, the TT
   motors and both wheel types), renders empty or to a volume below 1 mm³. This is checked
   with `stl_stats.py`.
3. **Interfaces:** J1/J2/J3 hole axes coincide across parts. This is checked numerically by
   echoing the coordinates both sides use, which must come from the same constants.
4. **Printability:** each part slices in PrusaSlicer (MK3S+, 0.2 mm, PETG) with supports
   disabled. A layer-by-layer look at the overhang-sensitive areas shows no unsupported
   islands, and no bridge exceeds 20 mm. Print times go in the README.
5. Renders of each part plus assembly views (iso, front, side, top, exploded) go in `preview/`.
6. The user prints `fit_test.scad` first, and the chosen pilot and thread sizes are fed back
   into the base parameters before printing the big parts.

## 11. Decisions

The user decided:
- the 3-part split, with the parts' roles as described;
- the Waveshare 4.3" DSI with the Pi bolted to its back;
- a USB-C power bank instead of 18650 + BMS, with the model unknown, so it gets a flexible
  set-screw/pusher clamp;
- 58 mm omni-wheels on a 2 mm rod;
- ≈63 mm drive wheels;
- keeping the current overall size;
- M3 self-tap in undersized holes, M5 with printed threads for the sturdy joints,
  and no inserts;
- skipping audio and buttons, but keeping a flexible speaker mount in the carriage.

My calls (open to change):
- Coordinate frame and all numbers in §5.3. These are estimates until the user confirms
  the current overall L × W × H.
- **Screen faces forward** as the truck's "windshield/face", in a swappable face plate.
- Wheels inside the body width. The upper carriage rides above the drive wheels as a
  mudguard, and the lower carriage narrows around them.
- The motor zone has no side rails; motors mount through floor-grid clamps (fixes a clash
  between the TT gearbox and the rail).
- J1 is a dovetail plus 2× M5 along X, sized for the lift-by-cabin case. J3 is upgraded to
  2× M5 as a second top tie. (Rev 1's 45° corbels would have pushed the joint open when
  tightened, so they were dropped.)
- The M5 thread mode follows the print orientation: modelled threads in vertical holes,
  self-tap pilots in horizontal holes. Both J1 and J3 holes are horizontal, so they default to
  pilots; this can be switched once the coupon is tested.
- Omni-wheels sit in printed cassettes that trap the rod, so no collar is needed.
- The lower carriage's rear wall is the rear bumper, so there's no extra part and no extra
  length.
- Bank envelope limited to 155 × 90 × 32, ports facing rear, right-angle plugs.
- L298N on the tray's rear wall; speaker in the lid.
- The 20 mm M3 grid (rev 3; was 10 mm) as the single mounting standard.
- Camera on a tilting roof bracket.
- PETG.

Left to the part builders: internal ribbing, fillets, vent patterns, and the exact shapes
of clamps/brackets/cassettes/plates, as long as §6 and §10 hold.
