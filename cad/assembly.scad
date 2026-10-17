// assembly.scad: every part in its assembled place, plus the ghost vitamins.
// Views:  -D show="all" (default) | "exploded" | "vitamins" | "parts"
// Each part's base file provides <prefix>assembled() and <prefix>vitamins().
include <robothector_base.scad>
include <vitamins.scad>
use <cabin_base.scad>
use <upper_carriage_base.scad>
use <lower_carriage_base.scad>

show = "all";
explode = 80;

module asm_cab(e = 0) { translate([e, 0, 0]) children(); }
module asm_uc(e = 0)  { translate([0, 0, e]) children(); }
module asm_lc(e = 0)  { translate([0, 0, 0]) children(); }

module assembly(e = 0, parts = true, vits = true) {
    if (parts) {
        asm_cab(e) color("SteelBlue", 0.9) cab_assembled();
        asm_uc(e)  color("DarkOrange", 0.9) uc_assembled();
        asm_lc(e)  color("DimGray", 0.9) lc_assembled();
    }
    if (vits) {
        asm_cab(e) cab_vitamins();
        asm_uc(e)  uc_vitamins();
        asm_lc(e)  lc_vitamins();
    }
}

if (show == "all")           assembly(0);
else if (show == "exploded") assembly(explode);
else if (show == "vitamins") assembly(0, parts = false);
else if (show == "parts")    assembly(0, vits = false);
