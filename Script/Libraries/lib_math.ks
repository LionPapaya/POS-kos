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
  until radius >= 0 and radius < 360{
        if radius >= 360 {
            set radius to radius - 360.
        } 
        if radius < 0 {
            set radius to radius + 360.
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