#!/usr/bin/env bash
# export_all.sh: export and check every printable into cad/stl/ (print orientation, on Z = 0).
# Run after changing any parameter (e.g. fit-coupon results in robothector_base.scad).
set -u
cd "$(dirname "$0")/.." || exit 2
rc=0
python3 tools/check_parts.py fit_test.scad coupon || rc=1
python3 tools/check_parts.py cabin.scad body roof faceplate bumper omni_cassette \
    camera_bracket camera_cradle camera_clip || rc=1
python3 tools/check_parts.py upper_carriage.scad tray lid clamp_post pusher rear_stop knob \
    l298n_plate pd_plate speaker_ring || rc=1
python3 tools/check_parts.py lower_carriage.scad frame tt_clamp tt_clamp_mirror tt_cap || rc=1
python3 tools/check_parts.py rod_jig.scad base lid || rc=1
exit $rc
