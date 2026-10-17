# Robothector Chassis Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Parametric OpenSCAD model of the 3-part Robothector truck (cabin, upper carriage, lower carriage), with print-ready STLs, all built on shared interface constants.

**Architecture:**
- Task 1 creates the single source of truth, `cad/robothector_base.scad`: frame, global dimensions, joint coordinates, and the fastener/grid/adapter library. It also creates ghost models of the bought parts and a check harness.
- Tasks 2–4 are independent part designs, each in its own `<part>_base.scad` + `<part>.scad`. They consume only Task 1's constants, so they run in parallel.
- Task 5 assembles everything and proves fit, printability and joint alignment.

**Tech Stack:** OpenSCAD 2021.01 (MCAD only), Python 3 check scripts, PrusaSlicer (Flatpak) for printability, `~/.claude/skills/openscad-cli/{scad_views.sh,stl_stats.py}`.

**Spec:** `docs/superpowers/specs/2026-10-17-chassis-redesign-design.md`. Read it in full; §6 (interfaces) and §7 (modularity) are binding.

## Global Constraints

- Frame: X forward, Y left, Z up. Z = 0 is the ground, X = 0 is the bulkhead plane, Y = 0 is the centreline. Parts are modelled in assembled position.
- Every printable must fit 245 × 205 × 205 mm, need no supports, have no bridge over 20 mm, and sit on Z = 0 in print orientation.
- Filament: PETG. Walls ≥ 4 mm on the main shells; floors as in the spec.
- No inserts and no nuts. M3 self-taps into Ø`m3_tap_d` (2.7) pilots. M5 uses `m5_hole(depth, mode)`: "thread" (modelled) or "pilot" (Ø4.3).
- Interface numbers come **only** from the constants in `robothector_base.scad`. Never retype a joint coordinate.
- Name prefixes: `cab_`, `uc_`, `lc_` for anything defined in part files; `v_` for vitamins. Base files contain no top-level geometry.
- `-D part="<name>"` on `<part>.scad` exports one printable in print orientation.

## Review Focus

1. **Pilot sizes drift with the printer.** Every hole size is a base parameter (`m3_tap_d`, `m5_pilot_d`, `clr_slide`, …) so that fit-coupon results change one number. Check: grep that no part file contains a literal 2.7, 3.4, 4.3 or 5.5.
2. **Mating faces with clearance must not overlap in assembly.** Interference check: pairwise intersection < 1 mm³ (Task 5, plus a self-check in each part task).
3. **Cables must pass the passages with plugs on:** a USB-A plug (16 × 8) and a USB-C right-angle plug (12 × 7). Test: P1/P2 opening sizes from the constants must exceed both, asserted in `fit_checks.scad`.
4. **The screen glass must sit behind the bezel lip and the bumper.** Test (Task 2): echo the glass front X < the face plate front X − 2, and the bumper front X ≥ the face front X + 15.
5. **Print orientation:** the big flat face goes down, and no part floats. Test: the check harness asserts min Z = 0 and bbox ≤ bed for every export.

---

### Task 1: Foundation: base library, vitamins, fit coupon, check harness (orchestrator, sequential)

**Files:**
- Create: `cad/robothector_base.scad`, `cad/vitamins.scad`, `cad/fit_test.scad`, `cad/fit_checks.scad`, `cad/tools/check_parts.py`, `cad/assembly.scad` (skeleton), `cad/README.md` (skeleton)

**Interfaces (produced, used by Tasks 2–5):**
- Constants: everything in spec §5.3 and §6, named `body_w, z_floor, z_deck, z_uc_top, lid_t, z_cab_top, roof_t, x_rear, x_cab_front, wall_t`, plus the `J1_*`, `J2_holes`, `J3_bolts`, `P1, P2, P3_holes, P3_d`, `OMNI_*`, `MOTOR_*`, `BANK_*`, `DRIVE_*` and `SCREEN_*` constants. See the file header for the full list.
- Modules (holes are negative solids along −Z, entry face at local z = 0, overshooting 0.5 above):
  - `m3_tap(depth)` and `m3_clear(depth, cbore=0)`
  - `m5_hole(depth, mode)` and `m5_clear(depth, cbore=0)`
  - `m5_thread(depth)`
  - `pilot(d_screw, depth)`
  - `grid_z(xr, yr, z_top, depth, excl=[])`, `grid_y(xr, zr, y_face, depth, dir, excl=[])` and `grid_x(yr, zr, x_face, depth, dir, excl=[])`: holes at global multiples of `grid_pitch`, kept `grid_edge` inside the ranges
  - `pointed_opening(w, h, depth)`: rectangle with a 45° top; local X is horizontal, local Y is up, extruded along −Z
  - `rbox(size, r)`: rounded vertical edges, corner at the origin
  - `adapter_plate(size, holes, standoff_h, hole_d, t)` and `slotted_plate(size, t)`
- Vitamins:
  - local-frame modules `v_pi4()`, `v_screen_unit()`, `v_cam3()`, `v_l298n()`, `v_tt_motor()`, `v_drive_wheel()`, `v_omni_wheel()`, `v_bank(size)`, `v_speaker(d,h)`, `v_pd_trigger()`;
  - placed versions `v_tt_motor_placed(side)`, `v_drive_wheel_placed(side)`, `v_omni_wheel_placed(side)` and `v_bank_max_placed()`, where side is +1 or −1.
- Harness: `python3 cad/tools/check_parts.py cad/<file>.scad <part> [<part>...]` exports `cad/stl/<file>-<part>.stl`, then prints one OK/FAIL line per part covering manifold, bbox ≤ 245×205×205 and min Z = 0. The exit code is non-zero on any FAIL.

- [ ] **Step 1:** Write `fit_checks.scad`. It holds `assert()` statements over the constants: the P1 opening exceeds 16 × 8; J2 heads clear the tray walls (|y| + m3_head_d/2 < body_w/2 − wall_t); J3 heads lie at X > BANK bay front; the omni well width ≥ omni_wheel_w + 2 × cassette cheek + 2 × clr_slide; the drive wheel top < z_deck; and the motor keep-out excludes the J2 rear holes. Run `openscad -o /tmp/x.echo cad/fit_checks.scad` and expect a failure (base missing).
- [ ] **Step 2:** Write `robothector_base.scad` with the constants and modules above. Re-run and expect no assertion failures.
- [ ] **Step 3:** Write `vitamins.scad`. Render `assembly.scad`, which shows only the vitamins at this stage, and eyeball the iso PNG: the wheels sit on Z = 0, and the motors' gearbox faces are at Y = ±41.
- [ ] **Step 4:** Write `fit_test.scad` (one coupon, ≤ 120 × 60, print ≤ 1 h):
  - M3 pilots 2.5/2.6/2.7/2.8, vertical and horizontal;
  - M5 thread and M5 pilot 4.1/4.3, vertical and horizontal;
  - Ø2.0/2.2/2.4 rod holes;
  - a 20 mm dovetail pair at 0.15/0.25/0.35 clearance.

  Check it with `check_parts.py cad/fit_test.scad coupon` (expect OK) and slice it to confirm the print time.
- [ ] **Step 5:** Write `check_parts.py` and the `assembly.scad` skeleton, with `show = "all" | "exploded" | "vitamins"`, using `use <cabin_base.scad>` etc. guarded so missing files can be stubbed.

### Tasks 2–4: Part designs (three parallel subagents, after Task 1)

All three subagents get the spec, this plan, and the Task 1 files. Each must:

**Provide these modules:**
- `<prefix>assembled()`: the union of all its printed parts in assembled position;
- `<prefix>vitamins()`: the ghosts it owns, placed.

**Pass these checks:**
- `check_parts.py` OK for every part;
- a self-interference check against `v_*_placed` ghosts and its own sub-parts: < 1 mm³ intersection;
- a PrusaSlicer slice (0.2 mm, PETG, supports off) per part, with the time recorded;
- iso/top/front/side PNGs in `cad/preview/<part>/`, looked at before finishing.

**Report back:**
- the part list with orientation, time and screws;
- any constant it needed that is missing from the base. It must **not** edit `robothector_base.scad`; it reports the missing constant instead.

**Must not** commit.

#### Task 2: Cabin (`cad/cabin_base.scad`, `cad/cabin.scad`)

Parts: body, roof, faceplate, bumper, omni_cassette, camera_bracket (spec §6, omni-wheel interface, and §8, cabin).

Extra tests:
- echo assertions for Review Focus 4;
- the J1 tongue, J1 bolt holes, J3 bosses and P1/P2 positions are built only from `J1_*`, `J3_bolts`, `P1`, `P2`;
- the body bbox stays inside X ∈ [J1 tongue rear, x_cab_front], Y ±body_w/2, Z [z_floor, z_cab_top − roof_t].

#### Task 3: Upper carriage (`cad/upper_carriage_base.scad`, `cad/upper_carriage.scad`)

Parts: tray, lid, clamp_post, pusher, rear_stop, l298n_plate, pd_plate, speaker_ring (spec §7.3, §7.5 and §8, upper carriage).

Extra test: `v_bank_max_placed()` plus clamp hardware at its fully clamped position shows no interference with the tray, and the right-angle plug zone (12 mm behind the port face) is free.

#### Task 4: Lower carriage (`cad/lower_carriage_base.scad`, `cad/lower_carriage.scad`)

Parts: frame, tt_clamp (spec §6, drive motor interface, and §8, lower carriage).

Extra tests:
- `v_tt_motor_placed(±1)` and `v_drive_wheel_placed(±1)` against the frame and clamps: < 1 mm³;
- the shaft is at `DRIVE_axle`;
- the TT hole spacing is uncertain (≈15–17.5 mm), so the clamp holds the gearbox by its shape (snug pocket) and its screw holes are slots that cover 14–18 mm.

### Task 5: Integration (orchestrator)

**Files:** modify `cad/assembly.scad` and `cad/README.md`; create `cad/tools/interference.scad`.

- [ ] **Step 1:** `interference.scad` with `-D a=… -D b=…` renders the intersection of two assemblies. Run it for cabin×lc, cabin×uc and uc×lc, and for each assembly against the other assemblies' vitamins. Expect every STL volume < 1 mm³.
- [ ] **Step 2:** Echo-compare the joint hole axes; both sides must print identical coordinates.
- [ ] **Step 3:** Render the assembly views (iso, side, top, front, exploded) to `cad/preview/assembly/`, and look at them.
- [ ] **Step 4:** Complete the README: print table, screw BOM (counts per length), assembly order (J1 → J2 → J3), and the fit-coupon procedure.
- [ ] **Step 5:** Request the user's review, and commit only on their go-ahead.
