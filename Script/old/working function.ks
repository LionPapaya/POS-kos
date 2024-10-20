






//THSI IS NOT WORKING JUST TO SAVE THE FUNCTION
function aeroturn_with_radius {
    declare parameter desired_heading, turn_radius.  // New second parameter: turn_radius in meters

    // Log the initial function call
    log "Aeroturn called. Desired Heading: " + desired_heading + " | Turn Radius: " + turn_radius to "0:/log.txt".
    
    // Only activate if the speed is between 120 m/s and 600 m/s and altitude is below 20,000 meters
    if ship:airspeed < 120 or ship:airspeed > 600 or ship:altitude > 20000 {
        // If conditions are not met, fallback to the regular aeroturn function
        log "Conditions not met. Falling back to aeroturn. Speed: " + ship:airspeed + " | Altitude: " + ship:altitude to "0:/log.txt".
        //aeroturn(desired_heading).
        return.
    }

    set heading_error to desired_heading - compass_for().

    // Normalize the heading error
    if heading_error > 180 {
        set heading_error to heading_error - 360.
    } 
    if heading_error < -180 {
        set heading_error to heading_error + 360.
    }
    set deg2rad to constant:pi / 180.
    // Log the heading error
    log "Heading Error: " + heading_error to "0:/log.txt".
    if defined turn_roll and not(turn_roll = 0 ){
        set roll_angle_rad to abs(turn_roll) * deg2rad.  // Convert roll to radians
        set actual_turn_radius to (ship:airspeed^2) / (9.81 * tan(roll_angle_rad)).
        log "Actual Turn Radius: " + actual_turn_radius + " meters." to "0:/log.txt".
    } else {
        log "Turn roll is undefined or zero. Setting actual turn radius to a straight path." to "0:/log.txt".
        set actual_turn_radius to 9999999.  // Essentially a straight path, infinite turn radius
    }

    // Log the actual turn radius
    log "Actual Turn Radius: " + actual_turn_radius + " meters." to "0:/log.txt".

    // Adjust roll and pitch based on actual vs desired turn radius
    set roll_max to 60.  // Maximum roll angle (degrees)
    set pitch_max to 15.  // Maximum pitch angle (degrees)

    // Log the roll and pitch adjustments
    log "Initial Roll Max: " + roll_max + " | Initial Pitch Max: " + pitch_max to "0:/log.txt".
    
    // Adjust roll and pitch limits based on the difference between actual and desired turn radius
    set radius_error to desired_heading - actual_turn_radius.

    // Log the radius error
    log "Radius Error: " + radius_error to "0:/log.txt".

    // If we are turning too sharply, reduce roll and pitch
    if actual_turn_radius < turn_radius {
        set roll_max to roll_max * 0.5.  // Reduce roll by 50% when turn radius is exceeded
        set pitch_max to pitch_max * 0.5.  // Reduce pitch as well
        log "Turn too sharp, reducing roll and pitch by 50%. New Roll Max: " + roll_max + " | New Pitch Max: " + pitch_max to "0:/log.txt".
    }

    // If we are not turning sharply enough, increase roll and pitch
    if actual_turn_radius > turn_radius {
        set roll_max to min(60, roll_max * 1.5).  // Increase roll up to a maximum of 60 degrees
        set pitch_max to min(15, pitch_max * 1.5).  // Increase pitch accordingly
        log "Turn not sharp enough, increasing roll and pitch by 50%. New Roll Max: " + roll_max + " | New Pitch Max: " + pitch_max to "0:/log.txt".
    }

    // Determine turn direction (left or right)
    if heading_error < 0 {
        set turn_side to "left".
    } else if heading_error > 0 {
        set turn_side to "right".
    } else {
        set turn_side to "none".
        set turn_roll to 0.
    }

    // Log the turn direction
    log "Turn Side: " + turn_side to "0:/log.txt".

    // Set roll and pitch based on turn direction
    if turn_side = "right" {
        if heading_error > 5 {
            set turn_roll to -roll_max.
        }
        set turn_heading to compass_for_prograde() + 1.
        set turn_pitch to pitch_max.
        log "Turning Right. Roll: " + turn_roll + " | Pitch: " + turn_pitch to "0:/log.txt".
    }
    if turn_side = "left" {
        if heading_error < -5 {
            set turn_roll to roll_max.
        }
        set turn_heading to compass_for_prograde() - 1.
        set turn_pitch to pitch_max.
        log "Turning Left. Roll: " + turn_roll + " | Pitch: " + turn_pitch to "0:/log.txt".
    }

    // Deactivate turn roll and pitch if conditions are not met
    if abs(heading_error) < 5 {
        set turn_roll to 0.
        set turn_pitch to 0.
        set turn_heading to desired_heading.
        log "Heading Error is less than 5 degrees. Deactivating turn. Heading locked to: " + turn_heading to "0:/log.txt".
    }
    
    // Log the final roll and pitch
    log "Final Roll: " + turn_roll + " | Final Pitch: " + turn_pitch + " | Final Heading: " + turn_heading to "0:/log.txt".

    aerostr().  // Existing control for aerodynamics
} 
////// NOW WORING STUFF AGAIN