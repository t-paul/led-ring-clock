// https://github.com/Irev-Dev/Round-Anything
use <Round-Anything/polyround.scad>
// https://github.com/rcolyer/threads-scad
use <rcolyer-threads/threads.scad>
// https://github.com/UBaer21/UB.scad
use <UB/libraries/ub.scad>

/* [Hidden] */
$fa = 2; $fs = 0.4;

/* [Part Selection] */
selection = 0; // [ 0:Assembly, 1:Bottom, 2:Plate, 3:Center ]

pattern = 1; // [ 0:Rosette, 1:Ellipse ]

/* [Parameters] */
nozzle_dia = 0.4;
layer_height = 0.15;

eps = 0.02;
tolerance= 0.35;
clock_id = 144;
clock_od = 158;

wall = 6 * nozzle_dia;
height_base = wall + 6;
height_spoke = 1;
height_led = 1.6 + 1;
height = height_base + height_spoke + height_led;

shape_r2 = 5;
shape_l1 = 5;
shape_l2 = shape_r2 + 1;

clock_spokes = 8;
clock_spoke_angle = 10;
clock_width = (clock_od - clock_id) / 2;

holder_ir = 1.8; // inner radius, e.g. ~1.8 for M3 screws

plate_height = 5 * layer_height;
plate_screw_height = height - 2;
plate_hole_dia = 60;

center_screw_height = plate_screw_height;

thread_pitch = 2.5;
thread_tooth_angle = 50;
thread_depth = sin(thread_tooth_angle) * thread_pitch;
thread_dia = clock_id - 2 * shape_l1 + 2 * tolerance;

parts = [
    [ "assembly",   [0, 0,  0 ], [   0, 0, 0], undef],
    [ "bottom",     [0, 0,  0 ], [   0, 0, 0], undef],
    [ "plate",      [0, 0, 40 ], [ 180, 0, 0], ["darkgray", 0.8]],
    [ "center",     [0, 0, 80 ], [ 180, 0, 0], undef]
];

function fragments(r=1) = ($fn > 0) ?
  ($fn >= 3 ? $fn : 3) :
  ceil(max(min(360.0 / $fa, r*2*PI / $fs), 5));

// Mounting hole positions for esp12f-led PCB
// https://aisler.net/torsten/finished/esp12f-led-controller/board
module pcb_holes() {
    x = 28 / 2;
    y = 25.5 / 2;
    for (xx = [-x, x], yy = [-y, y])
        translate([xx, yy])
            children();
}

module screw_hole(height, thread_dia = thread_dia, position = [0, 0, 0]) {
    ScrewHole(thread_dia, height, position = position, pitch = thread_pitch, tooth_angle = thread_tooth_angle, tolerance = tolerance)
        children();
} 

module screw_thread(height, thread_dia = thread_dia) {
    ScrewThread(thread_dia, height, pitch = thread_pitch, tooth_angle = thread_tooth_angle, tolerance = tolerance);
}

module holder(ir, r) {
    radiiPoints = [
        [ 0, 0, 0],
        [ 0, height, r],
        [ 2 * r, height, r],
        [ 2 * r, 0, 0]
    ];
    translate([ir, 0])
        polygon(polyRound(radiiPoints, fragments(r)));
}

module shape(w, h) {
    radiiPoints = [
        [ 0, 0, 0],
        [ 0, h, 0],
        [shape_l1 - tolerance, h, 0],
        [shape_l1 - tolerance, w, 0],
        [clock_width + shape_l1 + tolerance, w, 0],
        [clock_width + shape_l1 + tolerance, h, 0],
        [clock_width + shape_l1 + shape_l2, h, shape_r2],
        [clock_width + shape_l1 + shape_l2, 0, 0]
    ];
    polygon(polyRound(radiiPoints, fragments(clock_id)));
}

module t_shape() {
    translate([clock_id / 2 - shape_l1, 0])
        shape(height_base, height);
}

module t_spoke() {
    translate([clock_id / 2 - 2 * tolerance, height_base - tolerance])
        square([clock_width + 4 * tolerance, height_spoke + tolerance]);
}

module t_cut() {
    translate([clock_id / 2 - shape_l1 - eps, -eps])
        square([shape_l1 + clock_width + tolerance, height_base + 2 * eps]);
}

module t_debug() {
    t_shape();
    *t_spoke();
    #t_cut();
}

*!t_debug();

module ring() {
    difference() {
        union() {
            screw_hole(wall + height)
                rotate_extrude(convexity = 3)
                    t_shape();
            for (a = [0:1:clock_spokes-1])
                rotate((a + 0.5) * 360 / clock_spokes - clock_spoke_angle / 2)
                    rotate_extrude(angle = clock_spoke_angle)
                        t_spoke();
            translate([clock_od / 2 + shape_l2 + holder_ir, 0, 0])
                rotate_extrude()
                    holder(holder_ir, wall);
        }
        rotate(-clock_spoke_angle / 2)
            rotate_extrude(angle = clock_spoke_angle)
                t_cut();
        rotate([0, -90, 0])
            cylinder(r = wall - 2 * layer_height, h = clock_od);
    }
}

module pattern(count) {
    od = thread_dia - thread_depth - tolerance;
    intersection() {
        circle(d = od + 2 * eps);
        if (pattern == 0) {
            id = plate_hole_dia - 1 * wall + tolerance;
            //Rosette(id = id, od = od, wall = wall, ratio = ratio, rotations = 1, fn = fragments(id));
            Rosette(id = -id, od = od, wall = wall, ratio = -6.5, fn = fragments(id));
        } else {
            id = plate_hole_dia - 4 * wall;
            difference() {
                union() {
                    circle(d = plate_hole_dia + 2 * wall);
                    for (a = [0:1:count - 1])
                        rotate(a * 180 / count)
                            scale([1, id / od])
                                difference() {
                                    circle(d = od + 2 * wall);
                                    circle(d = od - 4 * wall);
                                }
                }
                circle(d = plate_hole_dia);
            }
        }
    }
}

module plate() {
    screw_hole(2 * plate_screw_height, plate_hole_dia) {
        linear_extrude(wall, convexity = 3)
            pattern(4);
        difference() {
            union() {
                cylinder(d = clock_od + 2, h = plate_height);
                translate([0, 0, eps]) screw_thread(plate_screw_height - eps);
            }
            translate([0, 0, -eps]) {
                linear_extrude(plate_screw_height + 2 * eps) {
                    difference() {
                        circle(d = thread_dia - thread_depth - 2 * wall);
                        circle(d = plate_hole_dia + 2 * wall);
                    }
                }
            }
        }
    }
}

module center() {
        r = 3;
        h = 8;
        cnt = 4;
        spiel = 0.2;
        bottom_screw_dia = 2;

        cylinder(h = wall, d = plate_hole_dia + 2 * wall);
        difference() {
            translate([0, 0, eps]) screw_thread(wall + height, plate_hole_dia);
            translate([0, 0, -eps]) cylinder(d = plate_hole_dia - 2 * wall, h = 100);
            translate([0, 0, height])
               for (a = [0:1:cnt - 1])
                    rotate([90, 0, a * 360 / cnt])
                        hull() {
                            translate([0, 0, plate_hole_dia / 4])
                                cylinder(r = 2, h = plate_hole_dia / 2);
                            translate([0, height, plate_hole_dia / 4])
                                cylinder(r = 2, h = plate_hole_dia / 2);
                        }
        }

        translate([0, 0, wall]) 
        pcb_holes()
            difference() {
                Strebe(d = bottom_screw_dia + 2 * wall, rad = r, h = h, single = true, spiel = spiel);
                translate([0, 0, eps]) LinEx(h + spiel + eps, bottom_screw_dia, scale2 = 1.2) WStern(r = 1.4);
            }
}

module part_select() {
    for (idx = [0:1:$children-1]) {
        if (selection == 0) {
            col = parts[idx][3];
            translate(parts[idx][1])
                rotate(parts[idx][2])
                    if (is_undef(col))
                        children(idx);
                    else
                        color(col[0], col[1])
                            children(idx);
        } else {
            if (selection == idx)
                children(idx);
        }
    }
}

part_select() {
    union() {
    }
    ring();
    plate();
    center();
}

*%translate([0, 0, 5])
linear_extrude(1)
difference() {
    circle(d = clock_od);
    circle(d = clock_id);
}
