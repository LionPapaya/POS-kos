function remove_spaces {
    parameter input_string.
    
    local result_string is "".
    // Debugging: Log the input string
    log "Testing remove_spaces function. Input: '" + input_string + "'" to "0:/log.txt".
    
    
    for char in input_string {
        if not(char = " ") {
            set result_string to result_string + char.
        }
    }
      // Debugging: Log the output string (result after removing spaces)
    log "Result (no spaces): '" + result_string + "'" to "0:/log.txt".
    
    return result_string.
}
function time_to_alt {
  parameter cur_alt.
  parameter vv_dot.
  parameter tgt_alt.

  if vv_dot = 0 {
    return 0. // No movement, altitude won't change
  }

  if (tgt_alt > cur_alt and vv_dot < 0) or (tgt_alt < cur_alt and vv_dot > 0) {
    return 0. // Moving away from the target altitude
  }

  return (tgt_alt - cur_alt) / vv_dot.
}
function time_to_pos {
  parameter cur_pos. // Current position
  parameter tgt_pos. // Target position
  parameter gs is ship:airspeed. // Ground speed

  local distance to calcdistance_m(cur_pos,tgt_pos). // Compute distance to target

  if gs = 0 or distance = 0{
    return 0. // No movement, will never reach target
  }

  return distance / gs. // Time = Distance / Speed
}

local num_lex   is lexicon().

num_lex:add("0", 0).
num_lex:add("1", 1).
num_lex:add("2", 2).
num_lex:add("3", 3).
num_lex:add("4", 4).
num_lex:add("5", 5).
num_lex:add("6", 6).
num_lex:add("7", 7).
num_lex:add("8", 8).
num_lex:add("9", 9).
function str_to_num {
  parameter s.
  set s to remove_spaces(s).

  // Handle negative numbers
  if s:startswith("-") {
    return str_to_num(s:substring(1,s:length-1)) * -1.
  }

  // Scientific Notation
  local e is s:find("e").
  if e <> -1 {
    local m is s:substring(e+1,1).
    if m <> "+" and m <> "-" { return "NaN". }
    local p is s:split("e" + m).
    if p:length <> 2 { return "NaN". }
    local p0 is str_to_num(p[0]).
    local p1 is str_to_num(p[1]).
    if p0 = "NaN" or p1 = "NaN" { return "NaN". }
    if m = "+" {
      return p0 * 10^p1.
    } else {
      return (p0 / 10^p1).
    }
  }

  // Decimals
  if s:contains(".") {
    local p is s:split(".").
    if p:length <> 2 { return "NaN". }
    local p0 is str_to_num(p[0]).
    local p1 is str_to_num(p[1]).
    if p0 = "NaN" or p1 = "NaN" { return "NaN". }
    return p0 + (p1 / (10^p[1]:length)).
  }

  // Integers (match on tokens, and bit-shift)
  local val is 0.
  for i IN s:split(""):sublist(1,s:length) {
    if num_lex:haskey(i) { set val to val + num_lex[i]. } else { return "NaN". }
    set val TO val * 10.
  }
  return val / 10.

}
function calc_percentage {
    declare parameter part, whole.
    
    // Überprüfen, ob der "whole" Wert 0 ist, um Division durch 0 zu vermeiden
    if whole = 0 {
        
        return 0. // Rückgabe 0 oder eine alternative Fehlermeldung
    }

    // Prozentsatz berechnen
    set percentage to (part / whole) * 100.

    return percentage.
}
function calc_circle_distance{
  parameter radius,degrees.
  until degrees >= 0 and degrees < 360{
        if degrees >= 360 {
            set degrees to degrees - 360.
        } 
        if degrees < 0 {
            set degrees to degrees + 360.
        }   
    }
  local circumference is 2*(radius)*constant:pi.
  return (circumference/360)*abs(degrees).
}

function num_to_str {
 parameter
  number,  //input number
  ip,      //number of digits before the decimal point.
  dp.      //number of decimal places

 local string is "".
 local padder is "".
 local absNumber is abs(number).
 local index is ip-1.
 local firstNum is false.
 until firstNum or index = 0 { // stop adding spacers when the first number is found
  if mod(floor(absNumber/10^index),10) = 0 {
   set padder to padder +" ".
  }
  else {
   set firstNum to true.
  }
  set index to index-1.
 }.
 if dp = 0 {
  set string to string +round(absNumber).
 }.
 else {
//  set index to index-1.
  set string to string +floor(absNumber).
  set index to -1.
  set string to string +".".
  until index = -dp {
   set string to string +mod(floor(absNumber/10^index),10).
   set index to index-1.
  }.
  set string to string + mod(round(absNumber/10^index),10).
 }.
 if number < 0 {
  set string to padder +"-" +string.
 }
 else {
  set string to padder +" " +string.
 }.
 return string.
}.

function draw_vector {
    declare parameter start_location.
    declare parameter start_alt.
    declare parameter end_location.
    declare parameter end_alt.
    declare parameter color is RGB(1, 0, 0).
    declare parameter name is "Vector". 
    parameter wdh is 2.

  // Convert geocoordinates to position vectors and add altitude
    local start to start_location:position + V(0, 0, start_alt).
    local end to end_location:position + V(0, 0, end_alt).

    // Calculate the vector from the start position to the end position
    local vector_to_end to end-start.

    // Draw the vector
    vecdraw(
      start,
      vector_to_end,
      color,
      name,
      1,
      true,
      wdh
    ).
}
FUNCTION pos_arrow {
	PARAMETER pos.
	PARAMETER lab.
	PARAMETER len IS 5000.
	PARAMETER wdh IS 3.
	
	LOCAL start IS pos:POSITION.
	LOCAL end IS (pos:POSITION - SHIP:ORBIT:BODY:POSITION).
	
  set end  to  end:NORMALIZED*len.
	VECDRAW(
      start,//{return start.},
      end,//{return end.},
      RGB(1,0,0),
      lab,
      1,
      TRUE,
      wdh
    ).
}
//draw a vector  with label centered on the ship and scaled to 30 times its length
FUNCTION arrow_ship {
	PARAMETER vec.
	PARAMETER lab.
	
	VECDRAW(
      v(0,0,0),
      vec,
      RGB(1,0,0),
      lab,
      30,
      TRUE,
      0.02
    ).

}
function positive_difference {
    parameter value1.
    parameter value2.

    // Calculate the difference and ensure it is positive
    local difference is abs(value1 - value2).

    return difference.
}
function find_closest_entry {
    parameter entries.
    parameter target_time.

    local closest_time is -1.
    local min_difference is 1e+308. // Set to a large number to ensure the first entry is always closer.
    local closest_entry is lex().

    for key in entries:keys {
        local entry_time is key.
        if key:ISTYPE("STRING") {
            set entry_time to str_to_num(key).
        }
        local difference is abs(entry_time - target_time).

        if difference < min_difference {
            set min_difference to difference.
            set closest_time to entry_time.
            set closest_entry to entries[key].
        }
    }

    return closest_entry.
}
//converts a position vector to Geocoordinates
function vec2pos {
	parameter posvec.
	//sphere coordinates relative to xyz-coordinates
	local lat is 90 - vang(v(0,1,0), posvec).
	//circle coordinates relative to xz-coordinates
	local equatvec is v(posvec:x, 0, posvec:z).
	local phi is vang(v(1,0,0), equatvec).
	if equatvec:z < 0 {
		set phi to 360 - phi.
	}
	//angle between x-axis and geocoordinates
	local alpha is vang(v(1,0,0), latlng(0,0):position - ship:body:position).
	if (latlng(0,0):position - ship:body:position):z >= 0 {
		set alpha to 360 - alpha.
	}
	return latlng(lat, phi + alpha).
}
FUNCTION rodrigues {
	DECLARE PARAMETER inVector.	//	Expects a vector
	DECLARE PARAMETER zvec.		//	Expects a vector
	DECLARE PARAMETER alph.	//	Expects a scalar
	DECLARe PARAMETER swch IS 1.
	
	SET zvec TO zvec:NORMALIZED.
	
	LOCAL outVector IS inVector*COS(alph).
	IF (swch=1) {
		SET outVector TO outVector + VCRS(zvec, inVector)*SIN(alph).
	}
	ELSE {
		SET outVector TO outVector + CROSS(zvec, inVector)*SIN(alph).
	}
	SET outVector TO outVector + zvec*VDOT(zvec, inVector)*(1-COS(alph)).
	
	RETURN outVector.
}
FUNCTION CROSS {
	DECLARE PARAMETER v1.
	DECLARE PARAMETER v2.
	
	LOCAL out IS VCRS(vecYZ(v1), vecYZ(v2)).
	RETURN vecYZ(out).
}
FUNCTION vecYZ {
	DECLARE PARAMETER input.	//	Expects a vector
	LOCAL output IS V(input:X, input:Z, input:Y).
	RETURN output.
}
function lerp {
    parameter start, end, t.
    return start + (end - start) * t.
}
FUNCtion changeRate {
    PARAMETER start, end, dt, changerate_.

    //clearScreen.
    //set Terminal:width to 301. 
    //set Terminal:HEIGHT to 300.
    //print start+","+end+","+dt+","+changerate_.
    
    // Calculate the amount to change based on the changerate and dt
    local change TO changerate_ * dt.
    
    // Adjust the start value towards the end, without overshooting
    IF start < end {
        SET start TO MIN(start + change, end).  // Move towards end
    } ELSE {
        SET start TO MAX(start - change, end).  // Move towards end
    }
    
    // Return the updated start value
    RETURN start.
}
function avg{
  parameter a is list().
  parameter weight is "none".
  local sum is 0.
  local count is 0.
  for b in range(0,a:length-1){
    if weight = "none"{
      set sum to sum + a[b].
      set count to count + 1.
    }else{
      set sum to sum + a[b]*weight[b].
      set count to count + weight[b].
    }
  }
  return sum/count.

}
function merge_lex {
    parameter lex1, lex2.

    for key in lex2:keys {
        set lex1[key] to lex2[key].
    }

    return lex1.
}
function normalize_latlng {
    parameter latlng_.
    local lat is latlng_:lat.
    local lng is latlng_:lng.

    // Normalize latitude to be within -90 to 90 degrees
    until abs(lat) <= 90 {
        if lat > 90 {
            set lat to 180 - lat.
        } else if lat < -90 {
            set lat to -180 - lat.
        }
    }

    // Normalize longitude to be within -180 to 180 degrees
    until abs(lng) <= 180 {
        if lng > 180 {
            set lng to lng - 360.
        } else if lng < -180 {
            set lng to lng + 360.
        }
    }

    return latlng(lat, lng).
}
FUNCTION find_zero_input {
    PARAMETER x1, y1, x2, y2.
    
    local b is x2-x1.
    if b = 0 {
        return x2.
    }
    LOCAL m IS (y2 - y1) / b.
    

    RETURN -y1 / m + x1.
}
FUNCTION FindClosestTimeStep {
    PARAMETER data.            // Lexicon { time_step : distance }
    PARAMETER targetDistance.  // Target distance to match
    LOCAL closestTime TO 0.
    LOCAL minDiff TO 99999999999999.
    FOR time_ IN data:KEYS {
        LOCAL distance TO data[time_].  // Directly access stored distance
        LOCAL diff TO ABS(distance - targetDistance).
        IF diff < minDiff {
            set minDiff TO diff.
            set closestTime TO time_.
        }
    }
    RETURN closestTime.
}
function calculate_spacecraft_energy{
  parameter alt_ is ship:altitude.
  parameter vel is ship:airspeed.
  parameter mass_ is ship:mass.
  parameter bod_mass is body:mass.
  parameter bod_rad is body:RADIUS.



  local distance_from_center to bod_rad + alt_.

  local gravitational_potential_energy to (constant:G * bod_mass * mass) / distance_from_center.


  local kinetic_energy to 0.5 * mass_ * (vel*vel).


  local total_mechanical_energy to kinetic_energy + gravitational_potential_energy.

  return total_mechanical_energy.

}
function invert_in_range{
  parameter in,min_,max_.
  local diff_min is abs(in-min_).
  local diff_max is abs(in-max_).
  if diff_max > diff_min{
    return max_-diff_min.
  }else if diff_max < diff_min{
    return min_+diff_max.
  }else {
    return in.
  }
}
function tanh_approx {
    parameter x.
    return x / (1 + abs(x)).
}
function lin_interpol {
    parameter d.
    parameter i_d.
    parameter i_v.
    parameter f_d.
    parameter f_v.

    // Calculate the velocity using linear interpolation
    //local velocity is initial_velocity + (final_velocity - initial_velocity) * ((distance - initial_distance) / (final_distance - initial_distance)).

    local a is i_v + (f_v - i_v) * ((d - i_d) / (f_d - i_d)).

    return a.
}
