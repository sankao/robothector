// interference.scad: intersection of two assemblies (or vitamin sets), in place.
// openscad -D 'a="cab"' -D 'b="lc"' -o out.stl tools/interference.scad
// Names: cab, uc, lc (printed parts) and cab_v, uc_v, lc_v (their ghost vitamins).
// An empty result means no interference; OpenSCAD then writes no STL.
include <../robothector_base.scad>
include <../vitamins.scad>
use <../cabin_base.scad>
use <../upper_carriage_base.scad>
use <../lower_carriage_base.scad>

a = "cab";
b = "lc";

module pick(n) {
    if (n == "cab") cab_assembled();
    else if (n == "uc") uc_assembled();
    else if (n == "lc") lc_assembled();
    else if (n == "cab_v") cab_vitamins();
    else if (n == "uc_v") uc_vitamins();
    else if (n == "lc_v") lc_vitamins();
}

intersection() { pick(a); pick(b); }
