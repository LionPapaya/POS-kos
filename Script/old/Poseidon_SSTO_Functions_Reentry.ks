


function adjust_heading_based_on_glideslope {
    set total_distance_to_runway_start to calcdistance(ship:geoposition, runway_start).  // Calculate total distance
    set lateral_glideslope to calculate_lateral_glideslope_distance().  // Lateral distance off the runway_start

    // Calculate percentage of distance to the runway_start, this will control the scaling of corrections
    set distance_percentage to calc_percentage(total_distance_to_runway_start, 10000).  // Assuming max approach distance is 10km

    // The farther away the aircraft is, the larger the corrections
    if lateral_glideslope > 0 {
        // Aircraft is to the right of the runway_start (positive value), turn left to align
        if abs(lateral_glideslope) > 2000 {
            set heading_adjustment to heading_to_target(runway_start) - (2 * lateral_glideslope / 1000) * (distance_percentage / 100).  // Larger adjustment
            aeroturn(heading_adjustment).
            log_status("Very large correction to the left applied: " + heading_adjustment).
        } else if abs(lateral_glideslope) > 1000 {
            set heading_adjustment to heading_to_target(runway_start) - (1.2 * lateral_glideslope / 1000) * (distance_percentage / 100).  // Moderate adjustment
            aeroturn(heading_adjustment).
            log_status("Large correction to the left applied: " + heading_adjustment).
        } else if abs(lateral_glideslope) > 500 {
            set heading_adjustment to heading_to_target(runway_start) - (0.8 * lateral_glideslope / 1000) * (distance_percentage / 100).  // Smaller adjustment
            aeroturn(heading_adjustment).
            log_status("Moderate correction to the left applied: " + heading_adjustment).
        } else if abs(lateral_glideslope) > 100 {
            set heading_adjustment to heading_to_target(runway_start) - (0.2 * lateral_glideslope / 1000) * (distance_percentage / 100).  // Fine adjustment
            aeroturn(heading_adjustment).
            log_status("Fine correction to the left applied: " + heading_adjustment).
        } else if abs(lateral_glideslope) > 5 {
            set heading_adjustment to heading_to_target(runway_start) - (0.05 * lateral_glideslope / 1000) * (distance_percentage / 100).  // Very fine adjustment
            aeroturn(heading_adjustment).
            log_status("Very fine correction to the left applied: " + heading_adjustment).
        } else {
            set heading_adjustment to heading_to_target(runway_start).
            aeroturn(heading_adjustment).
            log_status("Minimal correction to the left applied, within 5 meters").
        }
    } else if lateral_glideslope < 0 {
        // Aircraft is to the left of the runway_start (negative value), turn right to align
        if abs(lateral_glideslope) > 2000 {
            set heading_adjustment to heading_to_target(runway_start) + (2 * abs(lateral_glideslope) / 1000) * (distance_percentage / 100).  // Larger adjustment
            aeroturn(heading_adjustment).
            log_status("Very large correction to the right applied: " + heading_adjustment).
        } else if abs(lateral_glideslope) > 1000 {
            set heading_adjustment to heading_to_target(runway_start) + (1.2 * abs(lateral_glideslope) / 1000) * (distance_percentage / 100).  // Moderate adjustment
            aeroturn(heading_adjustment).
            log_status("Large correction to the right applied: " + heading_adjustment).
        } else if abs(lateral_glideslope) > 500 {
            set heading_adjustment to heading_to_target(runway_start) + (0.8 * abs(lateral_glideslope) / 1000) * (distance_percentage / 100).  // Smaller adjustment
            aeroturn(heading_adjustment).
            log_status("Moderate correction to the right applied: " + heading_adjustment).
        } else if abs(lateral_glideslope) > 100 {
            set heading_adjustment to heading_to_target(runway_start) + (0.2 * abs(lateral_glideslope) / 1000) * (distance_percentage / 100).  // Fine adjustment
            aeroturn(heading_adjustment).
            log_status("Fine correction to the right applied: " + heading_adjustment).
        } else if abs(lateral_glideslope) > 5 {
            set heading_adjustment to heading_to_target(runway_start) + (0.05 * abs(lateral_glideslope) / 1000) * (distance_percentage / 100).  // Very fine adjustment
            aeroturn(heading_adjustment).
            log_status("Very fine correction to the right applied: " + heading_adjustment).
        } else {
            set heading_adjustment to heading_to_target(runway_start).
            aeroturn(heading_adjustment).
            log_status("Minimal correction to the right applied, within 5 meters").
        }
    }
}
