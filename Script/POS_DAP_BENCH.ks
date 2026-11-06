// PASSIVE DAP command math: synthetic lexicons and pose getters only.
// Never invokes dap:setup/update, steering/throttle locks, engines, or protection scans.
if defined dap or defined main_step or defined AVES { print "DAP benchmark needs a fresh idle CPU.". until false { wait 1. } }
set CONFIG:IPU to 2000.
RUNONCEPATH("0:/Libraries/lib_math.ks").
RUNONCEPATH("0:/Libraries/lib_aerostr.ks").
// control.ks top level registers callbacks; this benchmark never invokes them.
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/control.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/entry_nominal_profile.ks").
local bench_log is "0:/pos_dap_final_20261106.log".
log "START|"+time:seconds to bench_log.
global AVES is lex("MaxRoll",45,"MaxYaw",10,"MaxPitch",30,"MinPitch",-15,
  "teamALTITUDE",10000,"Pitch_rate",lex("high",5,"low",2),"Rotation_rate",lex("high",10,"low",4)).
global bench_altitude is 20000.
global turn_roll is 0.
global bench_heading_values is list(90,95).
global bench_roll_values is list(0,0).
global bench_heading_index is 0.
global bench_roll_index is 0.
function compass_for_prograde {
  local result_value is bench_heading_values[mod(bench_heading_index,bench_heading_values:length)].
  set bench_heading_index to bench_heading_index+1.
  return result_value.
}
function roll_for {
  local result_value is bench_roll_values[mod(bench_roll_index,bench_roll_values:length)].
  set bench_roll_index to bench_roll_index+1.
  return result_value.
}
function pitch_for_prograde { return 4. }
function bench_prepare {
  parameter seed_value.
  set bench_heading_index to 0. set bench_roll_index to 0.
  set bench_heading_values to list(mod(seed_value*13,360),mod(seed_value*13+5,360)).
  set bench_roll_values to list(mod(seed_value*29,181)-90,mod(seed_value*31,181)-90).
  set bench_altitude to 5000. if mod(seed_value,2)=0 { set bench_altitude to 20000. }
  set dap to lex("aerostr",lex("distance_pitch",seed_value/7,"turn_pitch",mod(seed_value*17,121)-60,
      "turn_heading",mod(seed_value*11,720)-180,"turn_roll",mod(seed_value*19,181)-90,
      "aerostr_pitch",seed_value/3,"aerostr_heading",seed_value*5,"aerostr_Roll",seed_value/2,
      "targetPitch",seed_value*3-45,"targetDirection",0,"targetRoll",seed_value*7-90),
    "aoa",lex("target_aoa",seed_value*2-30,"target_bank",seed_value*7-90,
      "aoa_pitch",0,"aoa_yaw",0,"aoa_roll",0,"smooth_target_aoa",seed_value/5,
      "smooth_target_bank",seed_value/3,"base_pitch",mod(seed_value,3)*5),
    "css",lex("pitch_out",0,"yaw_out",0,"roll_out",0),
    "envelope",lex("max_aoa",30,"max_bank",45),"dt",0.02).
  if mod(seed_value,11)=0 { set dap["aoa"]["target_bank"] to 45. set dap["aerostr"]["targetRoll"] to -45. }
  if mod(seed_value,13)=0 { set dap["aoa"]["target_bank"] to -45. set dap["aerostr"]["targetRoll"] to 45. }
  if mod(seed_value,17)=0 { set dap["aoa"]["target_aoa"] to 30. set dap["aerostr"]["targetPitch"] to 30. }
  if mod(seed_value,19)=0 { set dap["aerostr"]["targetPitch"] to -15. }
}
function bench_capture {
  local a is dap["aerostr"]. local b is dap["aoa"]. local c is dap["css"].
  return list(a["aerostr_pitch"],a["aerostr_heading"],a["aerostr_Roll"],
    a["targetPitch"],a["targetDirection"],a["targetRoll"],b["target_aoa"],b["target_bank"],
    b["aoa_pitch"],b["aoa_yaw"],b["aoa_roll"],c["pitch_out"],c["yaw_out"],c["roll_out"],
    bench_heading_index,bench_roll_index,b["smooth_target_aoa"],b["smooth_target_bank"],b["base_pitch"]).
}
function bench_lists_equal {
  parameter before_value,after_value.
  for item_index in range(0,before_value:length) {
    if before_value[item_index] <> after_value[item_index] { return false. }
  }
  return true.
}
function bench_measure {
  parameter callback,bench_cases,bench_count,bench_name,bench_variant,bench_round,bench_log.
  bench_prepare(7).
  local ignored_value is 0.
  local start_clock is time:seconds.
  for bench_index in range(0,bench_count) { set ignored_value to callback(bench_cases[mod(bench_index,bench_cases:length)]). }
  local end_clock is time:seconds.
  log "TIME|"+bench_name+"|"+bench_variant+"|"+bench_round+"|"+bench_count+"|"+(end_clock-start_clock) to bench_log.
}

RUNONCEPATH("0:/Libraries/Poseidon_SSTO/flight_log.ks").

function bench_trace_inputs {
parameter trace_index.
set dap["aoa"]["target_aoa"] to mod(trace_index*7,80)-10.
set dap["aoa"]["target_bank"] to mod(trace_index*13,181)-90.
set dap["aoa"]["base_pitch"] to 0. if mod(trace_index,3)=0 { set dap["aoa"]["base_pitch"] to 5. }
set dap["envelope"]["max_bank"] to 45. if mod(trace_index,5)=0 { set dap["envelope"]["max_bank"] to 20. }
set dap["dt"] to 0.02. if mod(trace_index,7)=0 { set dap["dt"] to 0.1. }
set bench_altitude to 5000. if mod(trace_index,2)=0 { set bench_altitude to 20000. }
}

function normalized_heading_error {
    parameter target_heading, current_heading.
    local error is target_heading - current_heading.
    until abs(error) <= 180 {
        if error > 180 { set error to error - 360. }
        if error < -180 { set error to error + 360. }
    }
    return error.
}

FUNCtion bench_original_changeRate {
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

FUNCtion bench_candidate_changeRate {
    PARAMETER start, end, dt, changerate_.

    //clearScreen.
    //set Terminal:width to 301. 
    //set Terminal:HEIGHT to 300.
    //print start+","+end+","+dt+","+changerate_.
    
    // Calculate the amount to change based on the changerate and dt
    local change TO changerate_ * dt.
    
    // Adjust the start value towards the end, without overshooting
    IF start < end {
        RETURN MIN(start + change, end).  // Move towards end
    } ELSE {
        RETURN MAX(start - change, end).  // Move towards end
    }
    
    // Return the updated start value

}

function bench_run_original_changeRate { parameter bench_case. return bench_original_changeRate(bench_case[0],bench_case[1],bench_case[2],bench_case[3]).  }

function bench_run_candidate_changeRate { parameter bench_case. return bench_candidate_changeRate(bench_case[0],bench_case[1],bench_case[2],bench_case[3]).  }

function bench_run_production_changeRate { parameter bench_case. return changeRate(bench_case[0],bench_case[1],bench_case[2],bench_case[3]).  }

function bench_original_checksrt_inputs{
  declare parameter input_pitch, input_heading, input_roll.
  local heading_err to normalized_heading_error(input_heading,compass_for_prograde()).
  if input_roll < -AVES["MaxRoll"]{
    set dap["aerostr"]["aerostr_Roll"] to -AVES["MaxRoll"].
  }
  if input_roll > AVES["MaxRoll"]{
    set dap["aerostr"]["aerostr_Roll"] to AVES["MaxRoll"].
  }
  if roll_for() < -AVES["MaxRoll"]{
    set dap["aerostr"]["aerostr_Roll"] to -AVES["MaxRoll"].
  }
  if roll_for() > AVES["MaxRoll"]{
    set dap["aerostr"]["aerostr_Roll"] to AVES["MaxRoll"].
  }
  if heading_err > AVES["MaxYaw"]{
    set dap["aerostr"]["aerostr_heading"] to compass_for_prograde() +AVES["MaxYaw"].
  }
  if heading_err < -AVES["MaxYaw"]{
    set dap["aerostr"]["aerostr_heading"] to compass_for_prograde() -AVES["MaxYaw"].
  }
  if input_pitch > AVES["MaxPitch"]{
    set dap["aerostr"]["aerostr_pitch"] to AVES["MaxPitch"].
  }
  if input_pitch < AVES["MinPitch"]{
    set dap["aerostr"]["aerostr_pitch"] to AVES["MinPitch"].
  }
  


}

function bench_candidate_checksrt_inputs{
  declare parameter input_pitch, input_heading, input_roll.
  
  local aero_state is dap["aerostr"].
local heading_err to normalized_heading_error(input_heading,compass_for_prograde()).
  if input_roll < -AVES["MaxRoll"]{
    set aero_state["aerostr_Roll"] to -AVES["MaxRoll"].
  }
  if input_roll > AVES["MaxRoll"]{
    set aero_state["aerostr_Roll"] to AVES["MaxRoll"].
  }
  if roll_for() < -AVES["MaxRoll"]{
    set aero_state["aerostr_Roll"] to -AVES["MaxRoll"].
  }
  if roll_for() > AVES["MaxRoll"]{
    set aero_state["aerostr_Roll"] to AVES["MaxRoll"].
  }
  if heading_err > AVES["MaxYaw"]{
    set aero_state["aerostr_heading"] to compass_for_prograde() +AVES["MaxYaw"].
  }
  if heading_err < -AVES["MaxYaw"]{
    set aero_state["aerostr_heading"] to compass_for_prograde() -AVES["MaxYaw"].
  }
  if input_pitch > AVES["MaxPitch"]{
    set aero_state["aerostr_pitch"] to AVES["MaxPitch"].
  }
  if input_pitch < AVES["MinPitch"]{
    set aero_state["aerostr_pitch"] to AVES["MinPitch"].
  }
  


}

function bench_run_original_checksrt_inputs { parameter bench_case. bench_original_checksrt_inputs(bench_case[0],bench_case[1],bench_case[2]). return 0. }

function bench_run_candidate_checksrt_inputs { parameter bench_case. bench_candidate_checksrt_inputs(bench_case[0],bench_case[1],bench_case[2]). return 0. }

function bench_run_production_checksrt_inputs { parameter bench_case. checksrt_inputs(bench_case[0],bench_case[1],bench_case[2]). return 0. }

function bench_original_aerostr{
  if not(defined turn_roll){
    set turn_roll to 0.
  }
   set dap["aerostr"]["aerostr_pitch"] to (dap["aerostr"]["distance_pitch"]+dap["aerostr"]["turn_pitch"]).
   set dap["aerostr"]["aerostr_heading"] to dap["aerostr"]["turn_heading"].
    set dap["aerostr"]["aerostr_Roll"] to dap["aerostr"]["turn_roll"].

  bench_original_checksrt_inputs(dap["aerostr"]["aerostr_pitch"],dap["aerostr"]["aerostr_heading"],dap["aerostr"]["aerostr_Roll"]).  
  set dap["aerostr"]["targetPitch"] to dap["aerostr"]["aerostr_pitch"].
  set dap["aerostr"]["targetDirection"] to dap["aerostr"]["aerostr_heading"].
  set dap["aerostr"]["targetRoll"] to dap["aerostr"]["aerostr_Roll"].
}

function bench_candidate_aerostr{
  local aero_state is dap["aerostr"].

  if not(defined turn_roll){
    set turn_roll to 0.
  }
   set aero_state["aerostr_pitch"] to (aero_state["distance_pitch"]+aero_state["turn_pitch"]).
   set aero_state["aerostr_heading"] to aero_state["turn_heading"].
    set aero_state["aerostr_Roll"] to aero_state["turn_roll"].

  bench_candidate_checksrt_inputs(aero_state["aerostr_pitch"],aero_state["aerostr_heading"],aero_state["aerostr_Roll"]).  
  set aero_state["targetPitch"] to aero_state["aerostr_pitch"].
  set aero_state["targetDirection"] to aero_state["aerostr_heading"].
  set aero_state["targetRoll"] to aero_state["aerostr_Roll"].
}

function bench_run_original_aerostr { parameter bench_case. bench_original_aerostr(). return 0. }

function bench_run_candidate_aerostr { parameter bench_case. bench_candidate_aerostr(). return 0. }

function bench_run_production_aerostr { parameter bench_case. aerostr(). return 0. }

function bench_original_aoa_bank_management {
    parameter target_aoa, target_bank.
    parameter base_pitch is  pitch_for_prograde().
    parameter css is false.


    local theta to (target_bank / 90) * (constant:pi / 2).

    local aoa_pitch to target_aoa * cos(theta*constant:radtodeg).
    local aoa_yaw to target_aoa * sin(theta*constant:radtodeg) .

    local new_pitch to base_pitch + aoa_pitch.
    local new_yaw to compass_for_prograde() - aoa_yaw.

    if not(css){
        set dap["aoa"]["aoa_pitch"] to new_pitch.
        set dap["aoa"]["aoa_yaw"] to new_yaw.
        set dap["aoa"]["aoa_roll"] to target_bank.
    }else{
        set dap["css"]["pitch_out"] to new_pitch.
        set dap["css"]["yaw_out"] to new_yaw.
        set dap["css"]["roll_out"] to target_bank.
    }
}

function bench_candidate_aoa_bank_management {
    parameter target_aoa, target_bank.
    parameter base_pitch is  pitch_for_prograde().
    parameter css is false.


    local theta to (target_bank / 90) * (constant:pi / 2).

    local aoa_pitch to target_aoa * cos(theta*constant:radtodeg).
    local aoa_yaw to target_aoa * sin(theta*constant:radtodeg) .

    local new_pitch to base_pitch + aoa_pitch.
    local new_yaw to compass_for_prograde() - aoa_yaw.

    if not(css){
        local output_state is dap["aoa"].
        set output_state["aoa_pitch"] to new_pitch.
        set output_state["aoa_yaw"] to new_yaw.
        set output_state["aoa_roll"] to target_bank.
    }else{
        local output_state is dap["css"].
        set output_state["pitch_out"] to new_pitch.
        set output_state["yaw_out"] to new_yaw.
        set output_state["roll_out"] to target_bank.
    }
}

function bench_run_original_aoa_bank_management { parameter bench_case. bench_original_aoa_bank_management(bench_case[0],bench_case[1],bench_case[2],bench_case[3]). return 0. }

function bench_run_candidate_aoa_bank_management { parameter bench_case. bench_candidate_aoa_bank_management(bench_case[0],bench_case[1],bench_case[2],bench_case[3]). return 0. }

function bench_run_production_aoa_bank_management { parameter bench_case. aoa_bank_management(bench_case[0],bench_case[1],bench_case[2],bench_case[3]). return 0. }

function bench_original_envelope_apply_aoa_limits {
    set dap["aoa"]["target_aoa"] to min(dap["aoa"]["target_aoa"],dap["envelope"]["max_aoa"]).
    set dap["aoa"]["target_bank"] to envelope_clamp(dap["aoa"]["target_bank"],-dap["envelope"]["max_bank"],dap["envelope"]["max_bank"]).
}

function bench_candidate_envelope_apply_aoa_limits {
    local command_state is dap["aoa"].
    local maximum_bank is dap["envelope"]["max_bank"].
    set command_state["target_aoa"] to min(command_state["target_aoa"],dap["envelope"]["max_aoa"]).
    set command_state["target_bank"] to max(-maximum_bank,min(command_state["target_bank"],maximum_bank)).
}

function bench_run_original_envelope_apply_aoa_limits { parameter bench_case. bench_original_envelope_apply_aoa_limits(). return 0. }

function bench_run_candidate_envelope_apply_aoa_limits { parameter bench_case. bench_candidate_envelope_apply_aoa_limits(). return 0. }

function bench_run_production_envelope_apply_aoa_limits { parameter bench_case. envelope_apply_aoa_limits(). return 0. }

function bench_original_envelope_apply_aerostr_limits {
    set dap["aerostr"]["targetPitch"] to envelope_clamp(dap["aerostr"]["targetPitch"],AVES["MinPitch"],AVES["MaxPitch"]).
    set dap["aerostr"]["targetRoll"] to envelope_clamp(dap["aerostr"]["targetRoll"],-dap["envelope"]["max_bank"],dap["envelope"]["max_bank"]).
}

function bench_candidate_envelope_apply_aerostr_limits {
    local command_state is dap["aerostr"].
    local maximum_bank is dap["envelope"]["max_bank"].
    set command_state["targetPitch"] to max(AVES["MinPitch"],min(command_state["targetPitch"],AVES["MaxPitch"])).
    set command_state["targetRoll"] to max(-maximum_bank,min(command_state["targetRoll"],maximum_bank)).
}

function bench_run_original_envelope_apply_aerostr_limits { parameter bench_case. bench_original_envelope_apply_aerostr_limits(). return 0. }

function bench_run_candidate_envelope_apply_aerostr_limits { parameter bench_case. bench_candidate_envelope_apply_aerostr_limits(). return 0. }

function bench_run_production_envelope_apply_aerostr_limits { parameter bench_case. envelope_apply_aerostr_limits(). return 0. }

function bench_original_entry_nominal_range_at_energy {
    parameter energy_height_.
    if energy_height_ <= entry_nominal_energy_samples[0] {
        return entry_nominal_range_samples[0].
    }
    local last_index is entry_nominal_energy_samples:length-1.
    if energy_height_ >= entry_nominal_energy_samples[last_index] {
        return entry_nominal_range_samples[last_index].
    }
    for profile_index in range(1, entry_nominal_energy_samples:length) {
        local upper_energy is entry_nominal_energy_samples[profile_index].
        if energy_height_ <= upper_energy {
            local lower_energy is entry_nominal_energy_samples[profile_index-1].
            local fraction is (energy_height_-lower_energy)/(upper_energy-lower_energy).
            local lower_range is entry_nominal_range_samples[profile_index-1].
            local upper_range is entry_nominal_range_samples[profile_index].
            return lower_range+(upper_range-lower_range)*fraction.
        }
    }
    return entry_nominal_range_samples[last_index].
}

function bench_candidate_entry_nominal_range_at_energy {
    parameter energy_height_.
    if energy_height_ <= entry_nominal_energy_samples[0] {
        return entry_nominal_range_samples[0].
    }
    local last_index is entry_nominal_energy_samples:length-1.
    if energy_height_ >= entry_nominal_energy_samples[last_index] {
        return entry_nominal_range_samples[last_index].
    }
    // Lower bound: retain the first matching upper sample at exact knots.
    local lower_index is 1.
    local upper_index is last_index.
    until lower_index >= upper_index {
        local middle_index is floor((lower_index+upper_index)/2).
        if energy_height_ <= entry_nominal_energy_samples[middle_index] {
            set upper_index to middle_index.
        } else {
            set lower_index to middle_index+1.
        }
    }
    local upper_energy is entry_nominal_energy_samples[lower_index].
    local lower_energy is entry_nominal_energy_samples[lower_index-1].
    local fraction is (energy_height_-lower_energy)/(upper_energy-lower_energy).
    local lower_range is entry_nominal_range_samples[lower_index-1].
    local upper_range is entry_nominal_range_samples[lower_index].
    return lower_range+(upper_range-lower_range)*fraction.
}

function bench_run_original_entry_nominal_range_at_energy { parameter bench_case. return bench_original_entry_nominal_range_at_energy(bench_case[0]).  }

function bench_run_candidate_entry_nominal_range_at_energy { parameter bench_case. return bench_candidate_entry_nominal_range_at_energy(bench_case[0]).  }

function bench_run_production_entry_nominal_range_at_energy { parameter bench_case. return entry_nominal_range_at_energy(bench_case[0]).  }

function bench_original_dap_auto_aerostr_commands {
            bench_original_aerostr().
                set dap["aerostr"]["targetDirection"] to dap["aerostr"]["turn_heading"].
                set dap["aerostr"]["targetPitch"] to dap["aerostr"]["turn_pitch"]+dap["aerostr"]["distance_pitch"].
                set dap["aerostr"]["targetRoll"] to dap["aerostr"]["turn_roll"].
                bench_original_envelope_apply_aerostr_limits().
}

function bench_candidate_dap_auto_aerostr_commands {
            bench_candidate_aerostr().
                set dap["aerostr"]["targetDirection"] to dap["aerostr"]["turn_heading"].
                set dap["aerostr"]["targetPitch"] to dap["aerostr"]["turn_pitch"]+dap["aerostr"]["distance_pitch"].
                set dap["aerostr"]["targetRoll"] to dap["aerostr"]["turn_roll"].
                bench_candidate_envelope_apply_aerostr_limits().
}

function bench_run_original_dap_auto_aerostr_commands { parameter bench_case. bench_original_dap_auto_aerostr_commands(). return 0. }

function bench_run_candidate_dap_auto_aerostr_commands { parameter bench_case. bench_candidate_dap_auto_aerostr_commands(). return 0. }

function bench_production_dap_auto_aerostr_commands {
            aerostr().
                set dap["aerostr"]["targetDirection"] to dap["aerostr"]["turn_heading"].
                set dap["aerostr"]["targetPitch"] to dap["aerostr"]["turn_pitch"]+dap["aerostr"]["distance_pitch"].
                set dap["aerostr"]["targetRoll"] to dap["aerostr"]["turn_roll"].
                envelope_apply_aerostr_limits().
}

function bench_run_production_dap_auto_aerostr_commands { parameter bench_case. bench_production_dap_auto_aerostr_commands(). return 0. }

function bench_original_dap_auto_aoa_commands {

            bench_original_envelope_apply_aoa_limits().
            if bench_altitude > aves["teamALTITUDE"] {
                set dap["aoa"]["smooth_target_aoa"] to bench_original_changeRate(dap["aoa"]["smooth_target_aoa"], dap["aoa"]["target_aoa"],dap["dt"], AVES["Pitch_rate"]["high"]).
                set dap["aoa"]["smooth_target_bank"] to bench_original_changeRate(dap["aoa"]["smooth_target_bank"], dap["aoa"]["target_bank"],dap["dt"], AVES["Rotation_rate"]["high"]).
            } else {
                set dap["aoa"]["smooth_target_aoa"] to bench_original_changeRate(dap["aoa"]["smooth_target_aoa"], dap["aoa"]["target_aoa"],dap["dt"], AVES["Pitch_rate"]["low"]).
                set dap["aoa"]["smooth_target_bank"] to bench_original_changeRate(dap["aoa"]["smooth_target_bank"], dap["aoa"]["target_bank"],dap["dt"], AVES["Rotation_rate"]["low"]).
            }
            set dap["aoa"]["smooth_target_aoa"] to min(dap["aoa"]["smooth_target_aoa"],dap["envelope"]["max_aoa"]).
            set dap["aoa"]["smooth_target_bank"] to envelope_clamp(dap["aoa"]["smooth_target_bank"],-dap["envelope"]["max_bank"],dap["envelope"]["max_bank"]).
            if dap["aoa"]["base_pitch"] = 0 {
                bench_original_aoa_bank_management(dap["aoa"]["smooth_target_aoa"], dap["aoa"]["smooth_target_bank"]).
            } else {
                bench_original_aoa_bank_management(dap["aoa"]["smooth_target_aoa"], dap["aoa"]["smooth_target_bank"], dap["aoa"]["base_pitch"]).
                set dap["aoa"]["base_pitch"] to 0.
            }
            if defined ascent_alignment_debug and step = "ascent_alignment" {
                set dap["aoa"]["aoa_pitch"] to terrain_alignment_pitch(dap["aoa"]["aoa_pitch"],ascent_alignment_debug,AVES["Ascent"]).
            }
        
}

function bench_candidate_dap_auto_aoa_commands {

            bench_candidate_envelope_apply_aoa_limits().
            if bench_altitude > aves["teamALTITUDE"] {
                set dap["aoa"]["smooth_target_aoa"] to bench_candidate_changeRate(dap["aoa"]["smooth_target_aoa"], dap["aoa"]["target_aoa"],dap["dt"], AVES["Pitch_rate"]["high"]).
                set dap["aoa"]["smooth_target_bank"] to bench_candidate_changeRate(dap["aoa"]["smooth_target_bank"], dap["aoa"]["target_bank"],dap["dt"], AVES["Rotation_rate"]["high"]).
            } else {
                set dap["aoa"]["smooth_target_aoa"] to bench_candidate_changeRate(dap["aoa"]["smooth_target_aoa"], dap["aoa"]["target_aoa"],dap["dt"], AVES["Pitch_rate"]["low"]).
                set dap["aoa"]["smooth_target_bank"] to bench_candidate_changeRate(dap["aoa"]["smooth_target_bank"], dap["aoa"]["target_bank"],dap["dt"], AVES["Rotation_rate"]["low"]).
            }
            set dap["aoa"]["smooth_target_aoa"] to min(dap["aoa"]["smooth_target_aoa"],dap["envelope"]["max_aoa"]).
            set dap["aoa"]["smooth_target_bank"] to envelope_clamp(dap["aoa"]["smooth_target_bank"],-dap["envelope"]["max_bank"],dap["envelope"]["max_bank"]).
            if dap["aoa"]["base_pitch"] = 0 {
                bench_candidate_aoa_bank_management(dap["aoa"]["smooth_target_aoa"], dap["aoa"]["smooth_target_bank"]).
            } else {
                bench_candidate_aoa_bank_management(dap["aoa"]["smooth_target_aoa"], dap["aoa"]["smooth_target_bank"], dap["aoa"]["base_pitch"]).
                set dap["aoa"]["base_pitch"] to 0.
            }
            if defined ascent_alignment_debug and step = "ascent_alignment" {
                set dap["aoa"]["aoa_pitch"] to terrain_alignment_pitch(dap["aoa"]["aoa_pitch"],ascent_alignment_debug,AVES["Ascent"]).
            }
        
}

function bench_run_original_dap_auto_aoa_commands { parameter bench_case. bench_original_dap_auto_aoa_commands(). return 0. }

function bench_run_candidate_dap_auto_aoa_commands { parameter bench_case. bench_candidate_dap_auto_aoa_commands(). return 0. }

function bench_production_dap_auto_aoa_commands {

            envelope_apply_aoa_limits().
            if bench_altitude > aves["teamALTITUDE"] {
                set dap["aoa"]["smooth_target_aoa"] to changeRate(dap["aoa"]["smooth_target_aoa"], dap["aoa"]["target_aoa"],dap["dt"], AVES["Pitch_rate"]["high"]).
                set dap["aoa"]["smooth_target_bank"] to changeRate(dap["aoa"]["smooth_target_bank"], dap["aoa"]["target_bank"],dap["dt"], AVES["Rotation_rate"]["high"]).
            } else {
                set dap["aoa"]["smooth_target_aoa"] to changeRate(dap["aoa"]["smooth_target_aoa"], dap["aoa"]["target_aoa"],dap["dt"], AVES["Pitch_rate"]["low"]).
                set dap["aoa"]["smooth_target_bank"] to changeRate(dap["aoa"]["smooth_target_bank"], dap["aoa"]["target_bank"],dap["dt"], AVES["Rotation_rate"]["low"]).
            }
            set dap["aoa"]["smooth_target_aoa"] to min(dap["aoa"]["smooth_target_aoa"],dap["envelope"]["max_aoa"]).
            set dap["aoa"]["smooth_target_bank"] to envelope_clamp(dap["aoa"]["smooth_target_bank"],-dap["envelope"]["max_bank"],dap["envelope"]["max_bank"]).
            if dap["aoa"]["base_pitch"] = 0 {
                aoa_bank_management(dap["aoa"]["smooth_target_aoa"], dap["aoa"]["smooth_target_bank"]).
            } else {
                aoa_bank_management(dap["aoa"]["smooth_target_aoa"], dap["aoa"]["smooth_target_bank"], dap["aoa"]["base_pitch"]).
                set dap["aoa"]["base_pitch"] to 0.
            }
            if defined ascent_alignment_debug and step = "ascent_alignment" {
                set dap["aoa"]["aoa_pitch"] to terrain_alignment_pitch(dap["aoa"]["aoa_pitch"],ascent_alignment_debug,AVES["Ascent"]).
            }
        
}

function bench_run_production_dap_auto_aoa_commands { parameter bench_case. bench_production_dap_auto_aoa_commands(). return 0. }

function bench_cases_for {
  parameter bench_name.
  local bench_cases is list().
  for sample_index in range(0,128) {
    local sample_a is mod(sample_index*29,361)-180.
    local sample_b is mod(sample_index*37,721)-360.
    if bench_name = "changeRate" { bench_cases:add(list(sample_a,sample_b,mod(sample_index,7)/10,mod(sample_index,11)-2)). }
    else if bench_name = "checksrt_inputs" { bench_cases:add(list(sample_a,sample_b,mod(sample_index*43,181)-90)). }
    else if bench_name = "aoa_bank_management" { bench_cases:add(list(sample_a,sample_b,mod(sample_index*7,91)-45,mod(sample_index,2)=0)). }
    else if bench_name = "entry_nominal_range_at_energy" { bench_cases:add(list(100000+sample_index*1500.25)). }
    else { bench_cases:add(list()). }
  }
  if bench_name = "changeRate" {
    for edge_case in list(list(10,10,0.1,2),list(0,20,0,3),list(0,20,-0.1,3),list(0,20,10,3),list(20,0,10,3)) { bench_cases:add(edge_case). }
  }
  if bench_name = "checksrt_inputs" {
    for edge_case in list(list(30,180,45),list(-15,-180,-45),list(0,540,0),list(0,-540,0)) { bench_cases:add(edge_case). }
  }
  if bench_name = "aoa_bank_management" {
    for edge_case in list(list(0,0,0,false),list(10,90,0,false),list(-10,-90,5,true),list(20,180,-5,false),list(20,360,0,true)) { bench_cases:add(edge_case). }
  }
  return bench_cases.
}

{

print "Checking changeRate".

local bench_cases is bench_cases_for("changeRate").

local mismatch_count is 0.

local production_mismatch_count is 0.

local sample_index is 0.

for bench_case in bench_cases {

bench_prepare(sample_index).

local expected_value is bench_run_original_changeRate(bench_case).

local expected_state is bench_capture().

bench_prepare(sample_index).

local candidate_value is bench_run_candidate_changeRate(bench_case).

if expected_value <> candidate_value { set mismatch_count to mismatch_count+1. }

bench_prepare(sample_index).

local production_value is bench_run_production_changeRate(bench_case).

if expected_value <> production_value { set production_mismatch_count to production_mismatch_count+1. }

set sample_index to sample_index+1.

}

log "CHECK|changeRate|"+bench_cases:length+"|"+mismatch_count+"|"+production_mismatch_count to bench_log.

for bench_round in list(1,2,3) {

if bench_round = 2 { bench_measure(bench_run_production_changeRate@,bench_cases,4000,"changeRate","production",bench_round,bench_log). }

if true { bench_measure(bench_run_original_changeRate@,bench_cases,4000,"changeRate","original",bench_round,bench_log). }

if bench_round <> 2 { bench_measure(bench_run_production_changeRate@,bench_cases,4000,"changeRate","production",bench_round,bench_log). }

}

}

{

print "Checking checksrt_inputs".

local bench_cases is bench_cases_for("checksrt_inputs").

local mismatch_count is 0.

local production_mismatch_count is 0.

local sample_index is 0.

for bench_case in bench_cases {

bench_prepare(sample_index).

local expected_value is bench_run_original_checksrt_inputs(bench_case).

local expected_state is bench_capture().

bench_prepare(sample_index).

local candidate_value is bench_run_candidate_checksrt_inputs(bench_case).

if not bench_lists_equal(expected_state,bench_capture()) { set mismatch_count to mismatch_count+1. }

bench_prepare(sample_index).

local production_value is bench_run_production_checksrt_inputs(bench_case).

if not bench_lists_equal(expected_state,bench_capture()) { set production_mismatch_count to production_mismatch_count+1. }

set sample_index to sample_index+1.

}

log "CHECK|checksrt_inputs|"+bench_cases:length+"|"+mismatch_count+"|"+production_mismatch_count to bench_log.

for bench_round in list(1,2,3) {

if bench_round = 2 { bench_measure(bench_run_production_checksrt_inputs@,bench_cases,2000,"checksrt_inputs","production",bench_round,bench_log). }

if true { bench_measure(bench_run_original_checksrt_inputs@,bench_cases,2000,"checksrt_inputs","original",bench_round,bench_log). }

if bench_round <> 2 { bench_measure(bench_run_production_checksrt_inputs@,bench_cases,2000,"checksrt_inputs","production",bench_round,bench_log). }

}

}

{

print "Checking aerostr".

local bench_cases is bench_cases_for("aerostr").

local mismatch_count is 0.

local production_mismatch_count is 0.

local sample_index is 0.

for bench_case in bench_cases {

bench_prepare(sample_index).

local expected_value is bench_run_original_aerostr(bench_case).

local expected_state is bench_capture().

bench_prepare(sample_index).

local candidate_value is bench_run_candidate_aerostr(bench_case).

if not bench_lists_equal(expected_state,bench_capture()) { set mismatch_count to mismatch_count+1. }

bench_prepare(sample_index).

local production_value is bench_run_production_aerostr(bench_case).

if not bench_lists_equal(expected_state,bench_capture()) { set production_mismatch_count to production_mismatch_count+1. }

set sample_index to sample_index+1.

}

log "CHECK|aerostr|"+bench_cases:length+"|"+mismatch_count+"|"+production_mismatch_count to bench_log.

for bench_round in list(1,2,3) {

if bench_round = 2 { bench_measure(bench_run_production_aerostr@,bench_cases,2000,"aerostr","production",bench_round,bench_log). }

if true { bench_measure(bench_run_original_aerostr@,bench_cases,2000,"aerostr","original",bench_round,bench_log). }

if bench_round <> 2 { bench_measure(bench_run_production_aerostr@,bench_cases,2000,"aerostr","production",bench_round,bench_log). }

}

}

{

print "Checking aoa_bank_management".

local bench_cases is bench_cases_for("aoa_bank_management").

local mismatch_count is 0.

local production_mismatch_count is 0.

local sample_index is 0.

for bench_case in bench_cases {

bench_prepare(sample_index).

local expected_value is bench_run_original_aoa_bank_management(bench_case).

local expected_state is bench_capture().

bench_prepare(sample_index).

local candidate_value is bench_run_candidate_aoa_bank_management(bench_case).

if not bench_lists_equal(expected_state,bench_capture()) { set mismatch_count to mismatch_count+1. }

bench_prepare(sample_index).

local production_value is bench_run_production_aoa_bank_management(bench_case).

if not bench_lists_equal(expected_state,bench_capture()) { set production_mismatch_count to production_mismatch_count+1. }

set sample_index to sample_index+1.

}

log "CHECK|aoa_bank_management|"+bench_cases:length+"|"+mismatch_count+"|"+production_mismatch_count to bench_log.

for bench_round in list(1,2,3) {

if bench_round = 2 { bench_measure(bench_run_production_aoa_bank_management@,bench_cases,3000,"aoa_bank_management","production",bench_round,bench_log). }

if true { bench_measure(bench_run_original_aoa_bank_management@,bench_cases,3000,"aoa_bank_management","original",bench_round,bench_log). }

if bench_round <> 2 { bench_measure(bench_run_production_aoa_bank_management@,bench_cases,3000,"aoa_bank_management","production",bench_round,bench_log). }

}

}

{

print "Checking envelope_apply_aoa_limits".

local bench_cases is bench_cases_for("envelope_apply_aoa_limits").

local mismatch_count is 0.

local production_mismatch_count is 0.

local sample_index is 0.

for bench_case in bench_cases {

bench_prepare(sample_index).

local expected_value is bench_run_original_envelope_apply_aoa_limits(bench_case).

local expected_state is bench_capture().

bench_prepare(sample_index).

local candidate_value is bench_run_candidate_envelope_apply_aoa_limits(bench_case).

if not bench_lists_equal(expected_state,bench_capture()) { set mismatch_count to mismatch_count+1. }

bench_prepare(sample_index).

local production_value is bench_run_production_envelope_apply_aoa_limits(bench_case).

if not bench_lists_equal(expected_state,bench_capture()) { set production_mismatch_count to production_mismatch_count+1. }

set sample_index to sample_index+1.

}

log "CHECK|envelope_apply_aoa_limits|"+bench_cases:length+"|"+mismatch_count+"|"+production_mismatch_count to bench_log.

for bench_round in list(1,2,3) {

if bench_round = 2 { bench_measure(bench_run_production_envelope_apply_aoa_limits@,bench_cases,4000,"envelope_apply_aoa_limits","production",bench_round,bench_log). }

if true { bench_measure(bench_run_original_envelope_apply_aoa_limits@,bench_cases,4000,"envelope_apply_aoa_limits","original",bench_round,bench_log). }

if bench_round <> 2 { bench_measure(bench_run_production_envelope_apply_aoa_limits@,bench_cases,4000,"envelope_apply_aoa_limits","production",bench_round,bench_log). }

}

}

{

print "Checking envelope_apply_aerostr_limits".

local bench_cases is bench_cases_for("envelope_apply_aerostr_limits").

local mismatch_count is 0.

local production_mismatch_count is 0.

local sample_index is 0.

for bench_case in bench_cases {

bench_prepare(sample_index).

local expected_value is bench_run_original_envelope_apply_aerostr_limits(bench_case).

local expected_state is bench_capture().

bench_prepare(sample_index).

local candidate_value is bench_run_candidate_envelope_apply_aerostr_limits(bench_case).

if not bench_lists_equal(expected_state,bench_capture()) { set mismatch_count to mismatch_count+1. }

bench_prepare(sample_index).

local production_value is bench_run_production_envelope_apply_aerostr_limits(bench_case).

if not bench_lists_equal(expected_state,bench_capture()) { set production_mismatch_count to production_mismatch_count+1. }

set sample_index to sample_index+1.

}

log "CHECK|envelope_apply_aerostr_limits|"+bench_cases:length+"|"+mismatch_count+"|"+production_mismatch_count to bench_log.

for bench_round in list(1,2,3) {

if bench_round = 2 { bench_measure(bench_run_production_envelope_apply_aerostr_limits@,bench_cases,4000,"envelope_apply_aerostr_limits","production",bench_round,bench_log). }

if true { bench_measure(bench_run_original_envelope_apply_aerostr_limits@,bench_cases,4000,"envelope_apply_aerostr_limits","original",bench_round,bench_log). }

if bench_round <> 2 { bench_measure(bench_run_production_envelope_apply_aerostr_limits@,bench_cases,4000,"envelope_apply_aerostr_limits","production",bench_round,bench_log). }

}

}

{

print "Checking entry_nominal_range_at_energy".

local bench_cases is bench_cases_for("entry_nominal_range_at_energy").

local mismatch_count is 0.

local production_mismatch_count is 0.

local sample_index is 0.

for bench_case in bench_cases {

bench_prepare(sample_index).

local expected_value is bench_run_original_entry_nominal_range_at_energy(bench_case).

local expected_state is bench_capture().

bench_prepare(sample_index).

local candidate_value is bench_run_candidate_entry_nominal_range_at_energy(bench_case).

if expected_value <> candidate_value { set mismatch_count to mismatch_count+1. }

bench_prepare(sample_index).

local production_value is bench_run_production_entry_nominal_range_at_energy(bench_case).

if expected_value <> production_value { set production_mismatch_count to production_mismatch_count+1. }

set sample_index to sample_index+1.

}

log "CHECK|entry_nominal_range_at_energy|"+bench_cases:length+"|"+mismatch_count+"|"+production_mismatch_count to bench_log.

for bench_round in list(1,2,3) {

if bench_round = 2 { bench_measure(bench_run_production_entry_nominal_range_at_energy@,bench_cases,2000,"entry_nominal_range_at_energy","production",bench_round,bench_log). }

if true { bench_measure(bench_run_original_entry_nominal_range_at_energy@,bench_cases,2000,"entry_nominal_range_at_energy","original",bench_round,bench_log). }

if bench_round <> 2 { bench_measure(bench_run_production_entry_nominal_range_at_energy@,bench_cases,2000,"entry_nominal_range_at_energy","production",bench_round,bench_log). }

}

}

{

print "Checking dap_auto_aerostr_commands".

local bench_cases is bench_cases_for("dap_auto_aerostr_commands").

local mismatch_count is 0.

local production_mismatch_count is 0.

local sample_index is 0.

for bench_case in bench_cases {

bench_prepare(sample_index).

local expected_value is bench_run_original_dap_auto_aerostr_commands(bench_case).

local expected_state is bench_capture().

bench_prepare(sample_index).

local candidate_value is bench_run_candidate_dap_auto_aerostr_commands(bench_case).

if not bench_lists_equal(expected_state,bench_capture()) { set mismatch_count to mismatch_count+1. }

bench_prepare(sample_index).

local production_value is bench_run_production_dap_auto_aerostr_commands(bench_case).

if not bench_lists_equal(expected_state,bench_capture()) { set production_mismatch_count to production_mismatch_count+1. }

set sample_index to sample_index+1.

}

log "CHECK|dap_auto_aerostr_commands|"+bench_cases:length+"|"+mismatch_count+"|"+production_mismatch_count to bench_log.

for bench_round in list(1,2,3) {

if bench_round = 2 { bench_measure(bench_run_production_dap_auto_aerostr_commands@,bench_cases,1000,"dap_auto_aerostr_commands","production",bench_round,bench_log). }

if true { bench_measure(bench_run_original_dap_auto_aerostr_commands@,bench_cases,1000,"dap_auto_aerostr_commands","original",bench_round,bench_log). }

if bench_round <> 2 { bench_measure(bench_run_production_dap_auto_aerostr_commands@,bench_cases,1000,"dap_auto_aerostr_commands","production",bench_round,bench_log). }

}

}

{

print "Checking dap_auto_aoa_commands".

local bench_cases is bench_cases_for("dap_auto_aoa_commands").

local mismatch_count is 0.

local production_mismatch_count is 0.

local sample_index is 0.

for bench_case in bench_cases {

bench_prepare(sample_index).

local expected_value is bench_run_original_dap_auto_aoa_commands(bench_case).

local expected_state is bench_capture().

bench_prepare(sample_index).

local candidate_value is bench_run_candidate_dap_auto_aoa_commands(bench_case).

if not bench_lists_equal(expected_state,bench_capture()) { set mismatch_count to mismatch_count+1. }

bench_prepare(sample_index).

local production_value is bench_run_production_dap_auto_aoa_commands(bench_case).

if not bench_lists_equal(expected_state,bench_capture()) { set production_mismatch_count to production_mismatch_count+1. }

set sample_index to sample_index+1.

}

log "CHECK|dap_auto_aoa_commands|"+bench_cases:length+"|"+mismatch_count+"|"+production_mismatch_count to bench_log.

for bench_round in list(1,2,3) {

if bench_round = 2 { bench_measure(bench_run_production_dap_auto_aoa_commands@,bench_cases,1000,"dap_auto_aoa_commands","production",bench_round,bench_log). }

if true { bench_measure(bench_run_original_dap_auto_aoa_commands@,bench_cases,1000,"dap_auto_aoa_commands","original",bench_round,bench_log). }

if bench_round <> 2 { bench_measure(bench_run_production_dap_auto_aoa_commands@,bench_cases,1000,"dap_auto_aoa_commands","production",bench_round,bench_log). }

}

}

{
local expected_trace is list().
bench_prepare(10).
for trace_index in range(0,200) {
    bench_trace_inputs(trace_index).
    bench_original_dap_auto_aoa_commands().
    expected_trace:add(bench_capture()).
}
local trace_errors is 0.
bench_prepare(10).
for trace_index in range(0,200) {
    bench_trace_inputs(trace_index).
    bench_candidate_dap_auto_aoa_commands().
    if not bench_lists_equal(expected_trace[trace_index],bench_capture()) { set trace_errors to trace_errors+1. }
}
local production_trace_errors is 0.
bench_prepare(10).
for trace_index in range(0,200) {
    bench_trace_inputs(trace_index).
    bench_production_dap_auto_aoa_commands().
    if not bench_lists_equal(expected_trace[trace_index],bench_capture()) { set production_trace_errors to production_trace_errors+1. }
}
log "TRACE|auto_aoa|200|"+trace_errors+"|"+production_trace_errors to bench_log.
}

{
local saved_energies is entry_nominal_energy_samples.
local saved_ranges is entry_nominal_range_samples.
local exact_errors is 0. local production_exact_errors is 0. local query_count is 0.
for energy_value in saved_energies {
  for offset_value in list(-0.00001,0,0.00001) {
    local query_energy is energy_value+offset_value.
    if bench_original_entry_nominal_range_at_energy(query_energy) <> bench_candidate_entry_nominal_range_at_energy(query_energy) { set exact_errors to exact_errors+1. }
    if bench_original_entry_nominal_range_at_energy(query_energy) <> entry_nominal_range_at_energy(query_energy) { set production_exact_errors to production_exact_errors+1. }
    set query_count to query_count+1.
  }
}
for energy_table in list(list(1),list(1,2),list(1,2,2,4),list(1,1,1),list(-10,-2,7,80)) {
  set entry_nominal_energy_samples to energy_table.
  set entry_nominal_range_samples to list().
  for energy_index in range(0,energy_table:length) { entry_nominal_range_samples:add(energy_index*17+3). }
  for query_energy in list(-11,-10,-2,0,1,1.00001,1.99999,2,2.00001,3,4,7,80,81) {
    if bench_original_entry_nominal_range_at_energy(query_energy) <> bench_candidate_entry_nominal_range_at_energy(query_energy) { set exact_errors to exact_errors+1. }
    if bench_original_entry_nominal_range_at_energy(query_energy) <> entry_nominal_range_at_energy(query_energy) { set production_exact_errors to production_exact_errors+1. }
    set query_count to query_count+1.
  }
}
set entry_nominal_energy_samples to saved_energies.
set entry_nominal_range_samples to saved_ranges.
log "KNOTS|"+query_count+"|"+exact_errors+"|"+production_exact_errors to bench_log.
}
log "DONE|"+time:seconds to bench_log.
print "DAP BENCHMARK DONE".
