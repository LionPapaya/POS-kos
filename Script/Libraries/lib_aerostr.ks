
function aeroturn {
    declare parameter desired_heading. // Der gewünschte Kurs in Grad

    set heading_error to desired_heading - compass_for().

    // Normalisiere den Fehler
    until abs(heading_error) <= 180{
    if heading_error > 180 {
        set heading_error to heading_error - 360.
    } 
    if heading_error < -180 {
        set heading_error to heading_error + 360.
    }
    }
    
    if ship:altitude < AVES["MaxAeroturnalt"]{
    // Berechne die Gradänderung (Kursfehler)
    
    
    
    

    

    // Berechne die Rollwinkel basierend auf der Fluggeschwindigkeit
    set speed to ship:airspeed.
    set min_speed to AVES["Speed"]["MinSpeed"]. // Mindestgeschwindigkeit
    set max_speed to AVES["Speed"]["MaxSpeed"]. // Höchstgeschwindigkeit
    set speed_range to max_speed - min_speed.

    
    set roll_max to 60 - (speed - min_speed) / speed_range * 30.
    

    // Adjust roll_max further based on altitude (lower altitude -> higher roll value)
    set min_altitude to 0.  // Lowest altitude (e.g., 1,000 meters) for maximum roll
    set max_altitude to AVES["MaxAeroturnalt"]. // Maximum altitude (e.g., 60,000 meters) for minimum roll

    // Ensure altitude is within min/max bounds
    set altitude_adjustment_factor to (max_altitude - min(ship:altitude, max_altitude)) / (max_altitude - min_altitude).

    // Scale roll_max further based on altitude, ensuring it never exceeds the original roll_max
    set adjusted_roll_max to roll_max * (1 + (altitude_adjustment_factor * 0.5)).  // Apply a scaling factor of up to 50%

    // Ensure the roll_max doesn't exceed the original value
    set roll_max to min(roll_max, adjusted_roll_max).
    set pitch_max to 15 - (speed - min_speed) / speed_range * 10. 
    

    // Adjust pitch_max further based on altitude (lower altitude -> higher pitch authority)
    set min_altitude to 0.  // Lowest altitude (e.g., 1,000 meters) for maximum pitch
    set max_altitude to AVES["MaxAeroturnalt"]. // Maximum altitude (e.g., 60,000 meters) for minimum pitch

    // Ensure altitude is within min/max bounds
    set altitude_adjustment_factor to (max_altitude - min(ship:altitude, max_altitude)) / (max_altitude - min_altitude).

    // Scale pitch_max further based on altitude, ensuring it never exceeds the original pitch_max
    set adjusted_pitch_max to pitch_max * (1 + (altitude_adjustment_factor * 0.5)).  // Apply a scaling factor of up to 50%

    // Ensure the pitch_max doesn't exceed the original value
    set pitch_max to min(pitch_max, adjusted_pitch_max).
    if abs(heading_error) < 20{set roll_max to 15. set pitch_max to 5.}
    if abs(heading_error) < 10{set roll_max to 7. set pitch_max to 2.}
    if ship:altitude < 20000{
        set roll_max to 60 - (speed - min_speed) / speed_range * 20.
        set pitch_max to 15.
    }
    if heading_error < -5{
        set turn_side to "left".
    }else if heading_error > 5{
        set turn_side to "right".
    }else{
        set turn_side to "none".
        set turn_roll to 0.
    }
    
    if turn_side = "right"{
        
        if heading_error > 5 and compass_for()+ 5 < desired_heading{
            set turn_roll to (-roll_max).
        }
        
        set turn_heading to compass_for_prograde() + 1.
        if ship:altitude < 20000{
          set turn_heading to compass_for_prograde() + 5.
        }
        
        set turn_pitch to pitch_max.   
    }
    if turn_side = "left"{
        
        if heading_error < -5 and compass_for()- 5 > desired_heading{
          set turn_roll to (roll_max).
        }
        set turn_heading to compass_for_prograde() - 1.
        if ship:altitude < 20000{
          set turn_heading to compass_for_prograde() - 5.
        }
        set turn_pitch to pitch_max.   
    }
    
    }
    // Set turn_roll to 0 when any of the following conditions are met
    if  heading_error < -5 or heading_error > 5 or ship:altitude > AVES["MaxAeroturnalt"] or turn_side = "none" {
        set turn_roll to 0.
        set turn_pitch to 0.
        set turn_heading to desired_heading.
        
    }
    
    aerostr().
     
    
}
function aeroturn_force_dir {
    declare parameter desired_heading,turn_side. // Der gewünschte Kurs in Grad

    set heading_error to desired_heading - compass_for().

    // Normalisiere den Fehler
    until abs(heading_error) <= 180{
    if heading_error > 180 {
        set heading_error to heading_error - 360.
    } 
    if heading_error < -180 {
        set heading_error to heading_error + 360.
    }
    }
    
    if ship:altitude < AVES["MaxAeroturnalt"]{
    // Berechne die Gradänderung (Kursfehler)
       

    

    // Berechne die Rollwinkel basierend auf der Fluggeschwindigkeit
    set speed to ship:airspeed.
    set min_speed to AVES["Speed"]["MinSpeed"]. // Mindestgeschwindigkeit
    set max_speed to AVES["Speed"]["MaxSpeed"]. // Höchstgeschwindigkeit
    set speed_range to max_speed - min_speed.

    
    set roll_max to 60 - (speed - min_speed) / speed_range * 30.
    

    // Adjust roll_max further based on altitude (lower altitude -> higher roll value)
    set min_altitude to 0.  // Lowest altitude (e.g., 1,000 meters) for maximum roll
    set max_altitude to AVES["MaxAeroturnalt"]. // Maximum altitude (e.g., 60,000 meters) for minimum roll

    // Ensure altitude is within min/max bounds
    set altitude_adjustment_factor to (max_altitude - min(ship:altitude, max_altitude)) / (max_altitude - min_altitude).

    // Scale roll_max further based on altitude, ensuring it never exceeds the original roll_max
    set adjusted_roll_max to roll_max * (1 + (altitude_adjustment_factor * 0.5)).  // Apply a scaling factor of up to 50%

    // Ensure the roll_max doesn't exceed the original value
    set roll_max to min(roll_max, adjusted_roll_max).
    set pitch_max to 15 - (speed - min_speed) / speed_range * 10. 
    

    // Adjust pitch_max further based on altitude (lower altitude -> higher pitch authority)
    set min_altitude to 0.  // Lowest altitude (e.g., 1,000 meters) for maximum pitch
    set max_altitude to AVES["MaxAeroturnalt"]. // Maximum altitude (e.g., 60,000 meters) for minimum pitch

    // Ensure altitude is within min/max bounds
    set altitude_adjustment_factor to (max_altitude - min(ship:altitude, max_altitude)) / (max_altitude - min_altitude).

    // Scale pitch_max further based on altitude, ensuring it never exceeds the original pitch_max
    set adjusted_pitch_max to pitch_max * (1 + (altitude_adjustment_factor * 0.5)).  // Apply a scaling factor of up to 50%

    // Ensure the pitch_max doesn't exceed the original value
    set pitch_max to min(pitch_max, adjusted_pitch_max).
    
    if abs(heading_error) < 10{set roll_max to 7. set pitch_max to 2.}
    if ship:altitude < 20000{
        set roll_max to 60 - (speed - min_speed) / speed_range * 20.
        set pitch_max to 15.
    }
    
    
    if turn_side = "right"{
        
        
            set turn_roll to (-roll_max).
    
        
        set turn_heading to compass_for_prograde() + 1.
        if ship:altitude < 20000{
          set turn_heading to compass_for_prograde() + 5.
        }
        
        set turn_pitch to pitch_max.   
    }
    if turn_side = "left"{
        
        
          set turn_roll to (roll_max).
        
        set turn_heading to compass_for_prograde() - 1.
        if ship:altitude < 20000{
          set turn_heading to compass_for_prograde() - 5.
        }
        set turn_pitch to pitch_max.   
    }
    
    }
    // Set turn_roll to 0 when any of the following conditions are met
    if abs(heading_error)< 5 or ship:altitude > AVES["MaxAeroturnalt"] or turn_side = "none" {
        set turn_roll to 0.
        set turn_pitch to 0.
        set turn_heading to desired_heading.
        log_status("aeroteuning no roll force dir").
    }
    
    aerostr().
     
    
}
function aerostr{
  if not(defined turn_roll){
    set turn_roll to 0.
  }
  parameter aerostr_pitch is (distance_pitch+turn_pitch),
  aerostr_heading is turn_heading,
  
  aerostr_roll is turn_roll.
  checksrt_inputs(aerostr_pitch,aerostr_heading,aerostr_roll).  
  set targetPitch to aerostr_pitch.
  set targetDirection to aerostr_heading.
  set targetrole to aerostr_roll.
}
function checksrt_inputs{
  declare parameter input_pitch, input_heading, input_roll.
  set heading_err to input_heading - compass_for_prograde().
  if input_roll < -AVES["MaxRoll"]{
    set aerostr_roll to -AVES["MaxRoll"].
  }
  if input_roll > AVES["MaxRoll"]{
    set aerostr_roll to AVES["MaxRoll"].
  }
  if roll_for() < -AVES["MaxRoll"]{
    set aerostr_roll to -AVES["MaxRoll"].
  }
  if roll_for() > AVES["MaxRoll"]{
    set aerostr_roll to AVES["MaxRoll"].
  }
  if heading_err > AVES["MaxYaw"]{
    set aerostr_heading to compass_for_prograde() +AVES["MaxYaw"].
  }
  if heading_err < -AVES["MaxYaw"]{
    set aerostr_heading to compass_for_prograde() -AVES["MaxYaw"].
  }
  if input_pitch > AVES["MaxPitch"]{
    set aerostr_pitch to AVES["MaxPitch"].
  }
  if input_pitch < AVES["MinPitch"]{
    set aerostr_pitch to AVES["MinPitch"].
  }
  


}



// Function to calculate vertical glideslope distance
// Function to calculate vertical glideslope distance
function calculate_vertical_glideslope_alt {
     parameter horizontal_distance.
    set ship_altitude to ship:altitude.
    set ship_position to ship:geoPosition.
    set runway_start_position to runway_start.
     // Adjust the altitude reference dynamically based on horizontal distance
    set altitude_reference to runway_altitude.  // Example adjustment formula

    
    

    
    // Calculate the slope angle in radians
    
    

    // Calculate the vertical component from the glideslope
    set vertical_target to (horizontal_distance * AVES["Glideslope_Angle"]) + altitude_reference.
    
 
    return vertical_target.
}
function calculate_vertical_glideslope_distance {
   
    set ship_altitude to ship:altitude.
    set ship_position to ship:geoPosition.
    set runway_start_position to runway_start.
     // Adjust the altitude reference dynamically based on horizontal distance
    set altitude_reference to runway_altitude.  // Example adjustment formula

    // Calculate horizontal distance between ship and runway_start (in meters)
    set horizontal_distance to (calcdistance(ship_position, runway_start_position) * 1000).
    

    
    // Calculate the slope angle in radians
    
    

    // Calculate the vertical component from the glideslope
    set vertical_target to (horizontal_distance * AVES["Glideslope_Angle"]) + altitude_reference.
    

    
    
    // Calculate the vertical glideslope distance with the adjusted altitude reference
    set vertical_glideslope_distance to ship_altitude - vertical_target.
   
    
    return vertical_glideslope_distance.
}
// Function to calculate lateral glideslope distance
function calculate_lateral_glideslope_distance {
    set ship_position to latlng(ship:geoposition:lat, runway_start:lng).
    set runway_start_position to latlng(runway_start:lat, runway_start:lng).
    
    set distance_to_runway_start_line to (calcdistance(ship_position, runway_start_position)*1000).
    if runway_start:lat < ship:geoposition:lat{
        set distance_to_runway_start_line to distance_to_runway_start_line * (-1).
    }
    
    return distance_to_runway_start_line.
}
function smooth_pitch_adjustment {
    parameter desiredPitch.

    // Limit the rate of change in pitch for smoother adjustment
    set pitch_change_rate to AVES["pitch_change_rate"].  // Max pitch adjustment per iteration

    if abs(distance_pitch - desiredPitch) > pitch_change_rate {
        // Gradually increase or decrease distance_pitch towards desiredPitch
        if distance_pitch < desiredPitch {
            set distance_pitch to distance_pitch + pitch_change_rate.
        } else {
            set distance_pitch to distance_pitch - pitch_change_rate.
        }
    } else {
        // Set distance_pitch directly if close enough to desired pitch
        set distance_pitch to desiredPitch.
    }

    log_status("Adjusted distance_pitch smoothly").
}
function aggressive_overcorrect_for_prograde {
    parameter target_heading. // Target heading for runway_start alignment

    // Monitor the current prograde vector heading
    set prograde_heading to compass_for_prograde().

    // Calculate the difference between current heading and prograde
    set heading_difference to target_heading - prograde_heading.

    // More aggressive overcorrection if the prograde is not aligned with the target heading
    if abs(heading_difference) > 2 {
        // If the prograde is significantly to the left, turn right more aggressively
        if heading_difference > 0 {
            set aerostr_heading to compass_for() + 10.  // Larger adjustment
        }
        // If the prograde is significantly to the right, turn left more aggressively
        if heading_difference < 0 {
            set aerostr_heading to compass_for() - 10.  // Larger adjustment
        }
        log_status("Aggressive overcorrection for prograde alignment: heading difference: " + heading_difference).
    } else {
        // If the heading difference is small, maintain the target heading
        set aerostr_heading to runway_heading.
    }
}
