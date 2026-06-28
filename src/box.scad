module box_base () {
    cube([box_width, box_depth, box_height]);
}

module empty_box () {
    difference () {
        box_base();
        up(box_wall_thickness)
        right(box_wall_thickness)
        back(box_wall_thickness)
        cube([
            box_width - box_wall_thickness * 2, 
            box_depth - box_wall_thickness * 2,
            box_height - box_wall_thickness
        ]);
    }
}

module empty_box_with_nut () {
    union () {
        empty_box();
        up(box_height - (frenchfinity_1_0_slot_distance_top * 2))
            back(box_depth)
            nut(box_width, false);
    }
}

module empty_box_with_nut_and_text () {
    labels = hintFileName([
        final_version_prefix_calculated,
        [
            str("w", box_width),
            str("d", box_depth)
        ],
        [
            str("h", box_height),
            str("wt", box_wall_thickness)
        ],
    ]);

    difference() {
        empty_box_with_nut();
        // Back face, adaptively sized so every line stays below the cleat and
        // inside the part (the old fixed-size loop dropped lines on short boxes).
        labelBlockVertical(labels, box_width / 2, box_depth, box_width, 2, box_height - 17);
    }
}
    
module feature_box () {
    module box_with_wall_thickness_cut_from_top (){
        intersection() {
            cube([box_width * 2, box_depth * 2, box_height- box_wall_thickness]);
            empty_box_with_nut_and_text();
        }
    }

    module box_with_added_rounded_corners_on_top () {
        box_with_wall_thickness_cut_from_top();
            up(box_height - box_wall_thickness)
                rounded_square(box_width, box_depth, box_wall_thickness);
    }


   box_with_added_rounded_corners_on_top();    
}