#!/usr/bin/env bash
# render.sh [step ...]: render the assembly-manual step scenes of steps.scad to
# ../preview/manual/<step>.png (needs manual/stl/ from export_parts.sh). 6 in parallel.
set -u
cd "$(dirname "$0")" || exit 2
OUT=../preview/manual; mkdir -p "$OUT"
SCHEME=${SCHEME:-Tomorrow}
# step  camera rotation (rx,ry,rz; viewed with --viewall)
CAMS="hero:62,0,130
overview:62,0,130
cassette:68,0,122
cassettes_in:118,0,128
bumper:66,0,128
screen:66,0,226
faceplate_on:66,0,128
motor_clamp:58,0,118
clamps_on:56,0,214
j1:56,0,218
tray_fitout:52,0,118
tray_on:58,0,214
bank:56,0,130
lid:58,0,130
roof:60,0,130"
want=" $* "
printf '%s\n' "$CAMS" | while IFS=: read -r s rot; do
  [ $# -gt 0 ] && [ "${want#* $s }" = "$want" ] && continue
  echo "$s $rot"
done | xargs -P 6 -L 1 sh -c 'openscad -o "'"$OUT"'/$0.png" --imgsize=1800,1150 --autocenter --viewall \
    --colorscheme='"$SCHEME"' --camera=0,0,0,$1,500 -D "step=\"$0\"" steps.scad >/dev/null 2>&1 \
    && echo "OK   $0" || echo "FAIL $0"'
python3 trim.py "$OUT"/*.png >/dev/null
