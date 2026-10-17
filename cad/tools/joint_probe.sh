#!/usr/bin/env bash
# joint_probe.sh [shift]: run the bolt probes for J1/J2/J3. shift=0 expects "aligned" for all;
# shift=2 (negative control) expects "material hit" for all.
cd "$(dirname "$0")" || exit 2
shift_mm=${1:-0}; rc=0
for j in J1 J2 J3; do
  out=$(mktemp --suffix=.stl); rm -f "$out"
  openscad -o "$out" -D "j=\"$j\"" -D "shift=$shift_mm" joint_probe.scad >/dev/null 2>&1
  if [ -s "$out" ]; then echo "$j: material hit (shift $shift_mm)"; [ "$shift_mm" = 0 ] && rc=1
  else echo "$j: aligned, probe clear (shift $shift_mm)"; [ "$shift_mm" != 0 ] && rc=1; fi
  rm -f "$out"
done
exit $rc
