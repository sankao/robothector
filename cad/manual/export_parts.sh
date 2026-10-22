#!/usr/bin/env bash
# export_parts.sh: render every assembled-position sub-part of parts.scad to manual/stl/ (8 in parallel).
# Re-run after any design change, then render.sh.
set -u
cd "$(dirname "$0")" || exit 2
mkdir -p stl
parts=$(openscad -o /dev/stdout --export-format echo -D 'part="list"' parts.scad 2>&1 | sed -n 's/.*parts = \[\(.*\)\].*/\1/p' | tr -d '" ' | tr ',' ' ')
[ -n "$parts" ] || { echo "could not list parts"; exit 1; }
printf '%s\n' $parts | xargs -P 8 -I{} sh -c \
  'openscad -o stl/{}.stl --export-format binstl -D "part=\"{}\"" parts.scad >/dev/null 2>&1 && echo "OK   {}" || echo "FAIL {}"'
