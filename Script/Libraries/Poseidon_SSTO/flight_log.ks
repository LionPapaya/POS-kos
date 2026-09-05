// Structured flight telemetry for POS-kOS.
//
// Configure this before starting POS:
//   global POS_LOGGING_MODE is "none" | "low" | "medium" | "high".
//global POS_LOGGING_MODE is "none".
//global POS_LOGGING_MODE is "low".
global POS_LOGGING_MODE is "medium".
//global POS_LOGGING_MODE is "high".
//
// All normal-flight records use the same CSV schema so the local replay UI
// can replay either medium (one sample per second) or high (one sample per
// control tick) logs.  Deliberately do not call this library from aerodynamic
// trajectory simulations: simulations must remain free of logging overhead.

if not(defined POS_LOGGING_MODE) {
    // Preserve the old opt-in switch for existing launch scripts.  The old
    // flag meant "all diagnostics", which now corresponds to high.
    if defined POS_LOGGING_ENABLED and POS_LOGGING_ENABLED {
        global POS_LOGGING_MODE is "high".
    } else {
        global POS_LOGGING_MODE is "none".
    }
}

global POS_LOG_LEVEL is 0.
if POS_LOGGING_MODE = "low" { set POS_LOG_LEVEL to 1. }
if POS_LOGGING_MODE = "medium" { set POS_LOG_LEVEL to 2. }
if POS_LOGGING_MODE = "high" { set POS_LOG_LEVEL to 3. }

// The legacy boolean is kept false so old ad-hoc log statements do not create
// extra files outside the per-flight folder.  A true legacy setting above still
// selects the new high mode, whose structured per-tick CSV supersedes them.
set POS_LOGGING_ENABLED to false.

global POS_LOG_DIRECTORY is "/POS_logs".
global POS_LOG_FLIGHT_FILE is "".
global POS_LOG_EVENT_FILE is "".
// Version 2 adds the GPWS readouts to every detailed sample.
global POS_LOG_SCHEMA_VERSION is 2.
global POS_LOG_HEADERS_WRITTEN is false.
global POS_LOG_SESSION is "".
global POS_LOG_PROGRAM is "".
global POS_LOG_NEXT_SAMPLE_TIME is -1.
global POS_LOG_SAMPLE_INDEX is 0.
global POS_LOG_LAST_STEP is "".
global POS_LOG_LAST_SUBSTEP is "".
global POS_LOG_LAST_DAP_MODE is "".
global POS_LOG_LAST_STEERING_MODE is "".
global POS_LOG_LAST_GPWS_STATE is "".
global POS_LOG_LAST_GPWS_REASON is "".
global POS_LOG_RUNWAY is lex(
    "location","unknown","number","unknown","start_lat",0,"start_lng",0,
    "end_lat",0,"end_lng",0,"heading",0,"altitude",0
).
global POS_LOG_TARGET is lex("lat",0,"lng",0,"altitude",0).
global POS_LOG_ENTRY is lex(
    "reference_lat",0,"reference_lng",0,"reference_altitude",0,"reference_speed",0,
    "energy_reference",0,"energy_actual",0,"energy_error",0,"heading_error",0,
    "bank_command",0,"time_to_interface",0,"turn_side","","lift_to_drag",0
).

function flight_log_write_headers {
    if POS_LOG_HEADERS_WRITTEN { return. }
    log "schema,session,ut,mission_time,sample,program,step,substep,dap_mode,steering_mode,vessel_status,rapier_mode,rapiers_active,nervs_active,wheel_brakes,rcs_actual,sas_actual,latitude,longitude,altitude,radar_altitude,airspeed,surface_speed,vertical_speed,surface_velocity_x,surface_velocity_y,surface_velocity_z,acceleration_x,acceleration_y,acceleration_z,pitch,heading,roll,facing_x,facing_y,facing_z,mass,thrust,dynamic_pressure,mach,throttle_command,throttle_actual,aoa_actual,aoa_target,bank_target,smooth_aoa,smooth_bank,base_pitch,aerostr_target_pitch,aerostr_target_roll,aerostr_turn_pitch,aerostr_turn_heading,envelope_state,envelope_regime,envelope_max_aoa,envelope_max_bank,envelope_min_throttle,envelope_rcs_assist,gpws_state,gpws_worst_clearance,gpws_required_clearance,gpws_clearance_margin,gpws_clear_timer,gpws_next_scan_ut,gpws_pullup_active,terminal_phase,terminal_side,terminal_hold_laps,terminal_target_distance,terminal_remaining_distance,terminal_target_altitude,terminal_along_track,terminal_cross_track,terminal_energy_margin,terminal_target_energy,terminal_runway_heading_error,terminal_target_vs,terminal_pitch_bias,terminal_target_aoa,terminal_throttle,terminal_airbrake,terminal_gear,terminal_landing_stable,terminal_go_around_reason,terminal_pid_output,target_latitude,target_longitude,target_altitude,entry_reference_latitude,entry_reference_longitude,entry_reference_altitude,entry_reference_speed,entry_energy_reference,entry_energy_actual,entry_energy_error,entry_heading_error,entry_bank_command,entry_time_to_interface,entry_turn_side,entry_lift_to_drag,runway_start_latitude,runway_start_longitude,runway_end_latitude,runway_end_longitude,runway_heading,runway_altitude,dap_dt,aerostr_target_direction,aerostr_turn_roll,aerostr_distance_pitch,aerostr_pitch,aerostr_roll,aerostr_heading,aoa_pitch_command,aoa_yaw_command,aoa_roll_command,css_pitch_output,css_yaw_output,css_roll_output,css_last_roll,css_last_aoa,envelope_last_aoa,envelope_last_speed,envelope_last_pitch_error,envelope_pitchdown_timer,envelope_authority_timer,envelope_upset_timer,envelope_stable_timer,envelope_restore_steering" to POS_LOG_FLIGHT_FILE.
    log "schema,session,ut,mission_time,program,event,detail" to POS_LOG_EVENT_FILE.
    set POS_LOG_HEADERS_WRITTEN to true.
}

// Choose a brand-new directory before a flight starts.  Keeping each flight's
// two files together prevents accidental concatenation and makes the replay
// input unambiguous.  The current filesystem is always volume 0, so the
// calculation needs only the folder and file names.
function flight_log_choose_files {
    local log_root is "/POS_logs".
    if not exists(log_root) { createdir(log_root). }
    local sequence is 1.
    local relative_directory is log_root + "/flight_" + sequence.
    until not exists(relative_directory) {
        set sequence to sequence + 1.
        set relative_directory to log_root + "/flight_" + sequence.
    }
    createdir(relative_directory).
    set POS_LOG_DIRECTORY to relative_directory.
    set POS_LOG_FLIGHT_FILE to POS_LOG_DIRECTORY + "/flight.csv".
    set POS_LOG_EVENT_FILE to POS_LOG_DIRECTORY + "/events.csv".
    set POS_LOG_SESSION to "flight_" + sequence.
    set POS_LOG_HEADERS_WRITTEN to false.
}

// Events are intentionally a narrow, pipe-delimited detail field.  Do not put
// comma-separated free text here; these files are also valid CSV files.
function flight_log_event {
    parameter event_name, detail is "".
    if POS_LOG_LEVEL < 1 or POS_LOG_SESSION = "" { return. }
    local csv_detail is detail:replace(",",";").
    log POS_LOG_SCHEMA_VERSION + "," + POS_LOG_SESSION + "," + time:seconds + "," + missiontime + "," + POS_LOG_PROGRAM + "," + event_name + "," + csv_detail to POS_LOG_EVENT_FILE.
}

function flight_log_begin {
    parameter program_name.
    set POS_LOG_PROGRAM to program_name.
    if POS_LOG_LEVEL = 0 { return. }
    flight_log_choose_files().
    set POS_LOG_RUNWAY to lex(
        "location","unknown","number","unknown","start_lat",0,"start_lng",0,
        "end_lat",0,"end_lng",0,"heading",0,"altitude",0
    ).
    set POS_LOG_TARGET to lex("lat",0,"lng",0,"altitude",0).
    set POS_LOG_ENTRY to lex(
        "reference_lat",0,"reference_lng",0,"reference_altitude",0,"reference_speed",0,
        "energy_reference",0,"energy_actual",0,"energy_error",0,"heading_error",0,
        "bank_command",0,"time_to_interface",0,"turn_side","","lift_to_drag",0
    ).
    flight_log_write_headers().
    set POS_LOG_NEXT_SAMPLE_TIME to time:seconds.
    set POS_LOG_SAMPLE_INDEX to 0.
    set POS_LOG_LAST_STEP to "".
    set POS_LOG_LAST_SUBSTEP to "".
    set POS_LOG_LAST_DAP_MODE to "".
    set POS_LOG_LAST_STEERING_MODE to "".
    set POS_LOG_LAST_GPWS_STATE to "".
    set POS_LOG_LAST_GPWS_REASON to "".
    flight_log_event("flight_start","mode=" + POS_LOGGING_MODE + "|directory=" + POS_LOG_DIRECTORY).
}

function flight_log_set_runway {
    parameter location_name, runway_number, start_position, end_position, heading_value, altitude_value.
    if POS_LOG_LEVEL < 1 { return. }
    set POS_LOG_RUNWAY["location"] to location_name.
    set POS_LOG_RUNWAY["number"] to runway_number.
    set POS_LOG_RUNWAY["start_lat"] to start_position:lat.
    set POS_LOG_RUNWAY["start_lng"] to start_position:lng.
    set POS_LOG_RUNWAY["end_lat"] to end_position:lat.
    set POS_LOG_RUNWAY["end_lng"] to end_position:lng.
    set POS_LOG_RUNWAY["heading"] to heading_value.
    set POS_LOG_RUNWAY["altitude"] to altitude_value.
    flight_log_event("runway_selected","location=" + location_name + "|runway=" + runway_number + "|heading=" + round(heading_value,2) + "|altitude=" + round(altitude_value,1)).
}

function flight_log_set_entry_target {
    parameter team_interface.
    if POS_LOG_LEVEL < 1 { return. }
    set POS_LOG_TARGET["lat"] to team_interface["target_latlng"]:lat.
    set POS_LOG_TARGET["lng"] to team_interface["target_latlng"]:lng.
    set POS_LOG_TARGET["altitude"] to team_interface["target_altitude"].
    flight_log_event("entry_target","latitude=" + round(POS_LOG_TARGET["lat"],6) + "|longitude=" + round(POS_LOG_TARGET["lng"],6) + "|altitude=" + round(POS_LOG_TARGET["altitude"],1)).
}

// This is called only after calc_entry_traj has returned.  The solver and every
// function it calls remain completely independent of the logging system.
function flight_log_entry_solver_result {
    parameter result.
    if POS_LOG_LEVEL < 1 { return. }
    local detail is "converged=" + result["converged"] + "|iterations=" + result["iterations"] + "|reason=" + result["error"]["str"].
    if result["converged"] { set detail to detail + "|bank=" + round(result["bank"],3). }
    if result["error"]:haskey("min_bank") { set detail to detail + "|min_bank=" + round(result["error"]["min_bank"],3). }
    flight_log_event("entry_solver",detail).
}

// Capture values produced by the live entry controller.  For medium this runs
// only on the tick that will write the next one-second sample; high captures
// each real control tick.  It is never called by the entry trajectory solver.
function flight_log_capture_entry_guidance {
    parameter reference_state, energy_reference, energy_actual, energy_error, heading_error, bank_command, time_to_interface, turn_side, lift_to_drag.
    if POS_LOG_LEVEL < 2 { return. }
    if POS_LOG_LEVEL = 2 and time:seconds < POS_LOG_NEXT_SAMPLE_TIME { return. }
    set POS_LOG_ENTRY["reference_lat"] to reference_state["latlong"]:lat.
    set POS_LOG_ENTRY["reference_lng"] to reference_state["latlong"]:lng.
    set POS_LOG_ENTRY["reference_altitude"] to reference_state["altitude"].
    set POS_LOG_ENTRY["reference_speed"] to reference_state["surfvel"]:mag.
    set POS_LOG_ENTRY["energy_reference"] to energy_reference.
    set POS_LOG_ENTRY["energy_actual"] to energy_actual.
    set POS_LOG_ENTRY["energy_error"] to energy_error.
    set POS_LOG_ENTRY["heading_error"] to heading_error.
    set POS_LOG_ENTRY["bank_command"] to bank_command.
    set POS_LOG_ENTRY["time_to_interface"] to time_to_interface.
    set POS_LOG_ENTRY["turn_side"] to turn_side.
    set POS_LOG_ENTRY["lift_to_drag"] to lift_to_drag.
}

function flight_log_write_sample {
    parameter program_name, current_step, current_substep.
    local terminal_phase is "inactive".
    local terminal_side is "".
    local terminal_hold_laps is 0.
    local terminal_target_distance is 0.
    local terminal_remaining_distance is 0.
    local terminal_target_altitude is 0.
    local terminal_along_track is 0.
    local terminal_cross_track is 0.
    local terminal_energy_margin is 0.
    local terminal_target_energy is 0.
    local terminal_runway_heading_error is 0.
    local terminal_target_vs is 0.
    local terminal_pitch_bias is 0.
    local terminal_target_aoa is 0.
    local terminal_throttle is 0.
    local terminal_airbrake is false.
    local terminal_gear is false.
    local terminal_landing_stable is false.
    local terminal_go_around_reason is "".
    local terminal_pid_output is "none".
    if defined terminal_route_debug {
        set terminal_phase to terminal_route_debug["phase"].
        set terminal_side to terminal_route_debug["side"].
        set terminal_hold_laps to terminal_route_debug["hold_laps"].
        set terminal_target_distance to terminal_route_debug["target_distance"].
        set terminal_remaining_distance to terminal_route_debug["remaining_distance"].
        set terminal_target_altitude to terminal_route_debug["target_altitude"].
        set terminal_along_track to terminal_route_debug["along_track"].
        set terminal_cross_track to terminal_route_debug["cross_track"].
        set terminal_energy_margin to terminal_route_debug["energy_margin"].
        set terminal_target_energy to terminal_route_debug["target_energy"].
        set terminal_runway_heading_error to terminal_route_debug["runway_heading_error"].
        set terminal_target_vs to terminal_route_debug["desired_vertical_speed"].
        set terminal_pitch_bias to terminal_route_debug["pitch_bias"].
        set terminal_target_aoa to terminal_route_debug["target_aoa"].
        set terminal_throttle to terminal_route_debug["throttle"].
        set terminal_airbrake to terminal_route_debug["airbrake"].
        set terminal_gear to terminal_route_debug["gear"].
        set terminal_landing_stable to terminal_route_debug["landing_stable"].
        set terminal_go_around_reason to terminal_route_debug["go_around_reason"].
        set terminal_pid_output to terminal_route_debug["Pid_log"].
    }
    local surface_velocity is ship:velocity:surface.
    local acceleration is ship:sensors:acc.
    local facing_vec is ship:facing:vector.
    local envelope is dap["envelope"].
    local gpws_clearance_margin is envelope["terrain_worst_clearance"] - envelope["terrain_required_clearance"].
    local gpws_pullup_active is envelope["state"] = "terrain_pullup".
    log POS_LOG_SCHEMA_VERSION + "," + POS_LOG_SESSION + "," + time:seconds + "," + missiontime + "," + POS_LOG_SAMPLE_INDEX + "," + program_name + "," + current_step + "," + current_substep + "," + dap["dap_mode"] + "," + dap["str_mode"] + "," + ship:status + "," + rapier_mode + "," + rapiers + "," + nervs + "," + brakes + "," + RCS + "," + SAS + "," + ship:geoposition:lat + "," + ship:geoposition:lng + "," + ship:altitude + "," + alt:radar + "," + ship:airspeed + "," + surface_velocity:mag + "," + ship:verticalspeed + "," + surface_velocity:x + "," + surface_velocity:y + "," + surface_velocity:z + "," + acceleration:x + "," + acceleration:y + "," + acceleration:z + "," + pitch_for() + "," + compass_for() + "," + roll_for() + "," + facing_vec:x + "," + facing_vec:y + "," + facing_vec:z + "," + ship:mass + "," + ship:thrust + "," + ship:q + "," + ADDONS:FAR:mach + "," + dapthrottle + "," + throttle + "," + calc_aoa() + "," + dap["aoa"]["target_aoa"] + "," + dap["aoa"]["target_bank"] + "," + dap["aoa"]["smooth_target_aoa"] + "," + dap["aoa"]["smooth_target_bank"] + "," + dap["aoa"]["base_pitch"] + "," + dap["aerostr"]["targetPitch"] + "," + dap["aerostr"]["targetRoll"] + "," + dap["aerostr"]["turn_pitch"] + "," + dap["aerostr"]["turn_heading"] + "," + envelope["state"] + "," + envelope["regime"] + "," + envelope["max_aoa"] + "," + envelope["max_bank"] + "," + envelope["min_throttle"] + "," + envelope["rcs_assist"] + "," + envelope["terrain_state"] + "," + envelope["terrain_worst_clearance"] + "," + envelope["terrain_required_clearance"] + "," + gpws_clearance_margin + "," + envelope["terrain_clear_timer"] + "," + envelope["terrain_next_scan"] + "," + gpws_pullup_active + "," + terminal_phase + "," + terminal_side + "," + terminal_hold_laps + "," + terminal_target_distance + "," + terminal_remaining_distance + "," + terminal_target_altitude + "," + terminal_along_track + "," + terminal_cross_track + "," + terminal_energy_margin + "," + terminal_target_energy + "," + terminal_runway_heading_error + "," + terminal_target_vs + "," + terminal_pitch_bias + "," + terminal_target_aoa + "," + terminal_throttle + "," + terminal_airbrake + "," + terminal_gear + "," + terminal_landing_stable + "," + terminal_go_around_reason + "," + terminal_pid_output + "," + POS_LOG_TARGET["lat"] + "," + POS_LOG_TARGET["lng"] + "," + POS_LOG_TARGET["altitude"] + "," + POS_LOG_ENTRY["reference_lat"] + "," + POS_LOG_ENTRY["reference_lng"] + "," + POS_LOG_ENTRY["reference_altitude"] + "," + POS_LOG_ENTRY["reference_speed"] + "," + POS_LOG_ENTRY["energy_reference"] + "," + POS_LOG_ENTRY["energy_actual"] + "," + POS_LOG_ENTRY["energy_error"] + "," + POS_LOG_ENTRY["heading_error"] + "," + POS_LOG_ENTRY["bank_command"] + "," + POS_LOG_ENTRY["time_to_interface"] + "," + POS_LOG_ENTRY["turn_side"] + "," + POS_LOG_ENTRY["lift_to_drag"] + "," + POS_LOG_RUNWAY["start_lat"] + "," + POS_LOG_RUNWAY["start_lng"] + "," + POS_LOG_RUNWAY["end_lat"] + "," + POS_LOG_RUNWAY["end_lng"] + "," + POS_LOG_RUNWAY["heading"] + "," + POS_LOG_RUNWAY["altitude"] + "," + dap["dt"] + "," + dap["aerostr"]["targetDirection"] + "," + dap["aerostr"]["turn_roll"] + "," + dap["aerostr"]["distance_pitch"] + "," + dap["aerostr"]["aerostr_pitch"] + "," + dap["aerostr"]["aerostr_roll"] + "," + dap["aerostr"]["aerostr_heading"] + "," + dap["aoa"]["aoa_pitch"] + "," + dap["aoa"]["aoa_yaw"] + "," + dap["aoa"]["aoa_roll"] + "," + dap["css"]["pitch_out"] + "," + dap["css"]["yaw_out"] + "," + dap["css"]["roll_out"] + "," + dap["css"]["last_roll"] + "," + dap["css"]["last_aoa"] + "," + envelope["last_aoa"] + "," + envelope["last_speed"] + "," + envelope["last_pitch_error"] + "," + envelope["pitchdown_timer"] + "," + envelope["authority_timer"] + "," + envelope["upset_timer"] + "," + envelope["stable_timer"] + "," + envelope["restore_steering"] to POS_LOG_FLIGHT_FILE.
    set POS_LOG_SAMPLE_INDEX to POS_LOG_SAMPLE_INDEX + 1.
}

// One lightweight hook per real-flight loop.  At none it returns immediately;
// at low it only compares the four state strings; medium writes once a second;
// high writes every tick.  Expensive ship/DAP values are read only by
// flight_log_write_sample after a sample is actually due.
function flight_log_tick {
    parameter program_name, current_step, current_substep.
    if POS_LOG_LEVEL = 0 { return. }
    if POS_LOG_LAST_STEP <> current_step {
        set POS_LOG_LAST_STEP to current_step.
        flight_log_event("step","value=" + current_step).
    }
    if POS_LOG_LAST_SUBSTEP <> current_substep {
        set POS_LOG_LAST_SUBSTEP to current_substep.
        flight_log_event("substep","value=" + current_substep).
    }
    if POS_LOG_LAST_DAP_MODE <> dap["dap_mode"] {
        set POS_LOG_LAST_DAP_MODE to dap["dap_mode"].
        flight_log_event("dap_mode","value=" + dap["dap_mode"]).
    }
    if POS_LOG_LAST_STEERING_MODE <> dap["str_mode"] {
        set POS_LOG_LAST_STEERING_MODE to dap["str_mode"].
        flight_log_event("steering_mode","value=" + dap["str_mode"]).
    }
    if POS_LOG_LAST_GPWS_STATE <> dap["envelope"]["terrain_state"] or POS_LOG_LAST_GPWS_REASON <> dap["envelope"]["terrain_inhibit_reason"] {
        set POS_LOG_LAST_GPWS_STATE to dap["envelope"]["terrain_state"].
        set POS_LOG_LAST_GPWS_REASON to dap["envelope"]["terrain_inhibit_reason"].
        flight_log_event("gpws_state","value=" + dap["envelope"]["terrain_state"] + "|reason=" + dap["envelope"]["terrain_inhibit_reason"] + "|clearance=" + round(dap["envelope"]["terrain_worst_clearance"],1) + "|required=" + round(dap["envelope"]["terrain_required_clearance"],1)).
    }
    if POS_LOG_LEVEL < 2 { return. }
    if POS_LOG_LEVEL = 2 and time:seconds < POS_LOG_NEXT_SAMPLE_TIME { return. }
    if POS_LOG_LEVEL = 2 { set POS_LOG_NEXT_SAMPLE_TIME to time:seconds + 1. }
    flight_log_write_sample(program_name,current_step,current_substep).
}
