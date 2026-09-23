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
// Version 15 adds entry reference-segment telemetry so continuous energy
// interpolation and monotonic trajectory progress can be verified in flight.
// Version 16 adds live-state predictive entry-bank telemetry.
// Version 17 adds signed candidate range residuals and active authority.
// Version 18 adds prediction-freeze and post-handoff TEAM blend telemetry.
// Version 19 adds high-energy TEAM final guidance telemetry.
// Version 20 adds terminal route work, clean-loss learning and brake forecast.
// Version 21 adds current-turn extra distance and brake-protected energy.
global POS_LOG_SCHEMA_VERSION is 21.
global POS_LOG_HEADERS_WRITTEN is false.
global POS_LOG_SESSION is "".
global POS_LOG_PROGRAM is "".
global POS_LOG_NEXT_SAMPLE_TIME is -1.
global POS_LOG_SAMPLE_INDEX is 0.
global POS_LOG_LAST_STEP is "".
global POS_LOG_LAST_SUBSTEP is "".
global POS_LOG_LAST_DAP_MODE is "".
global POS_LOG_LAST_STEERING_MODE is "".
global POS_LOG_LAST_ENTRY_DISPLAY_MODE is "".
global POS_LOG_LAST_GPWS_STATE is "".
global POS_LOG_LAST_GPWS_REASON is "".
global POS_LOG_LAST_PDI_STATE is "".
global POS_LOG_LAST_PDI_SATURATED is "".
global POS_LOG_LAST_PDI_FLIP_READY is "".
global POS_LOG_LAST_PDI_TERMINAL_DESCENT is "".
global POS_LOG_LAST_RENDEZVOUS_STATE is "".
global POS_LOG_LAST_BODY is "".
global POS_LOG_PDI_FIELDS is list(
    "valid","converged","tgo","position_error","velocity_error","ignition_ut",
    "predicted_clearance","predicted_final_mass","iterations","solution_age",
    "vertical_margin","horizontal_speed","saturated","flip_ready","flip_committed",
    "plane_error","node_dv","node_approved","steer_x","steer_y","steer_z",
    "command_valid","command_age","guidance_failures","alignment_error",
    "terminal_hold_height","terminal_descent_committed"
).
global POS_LOG_PDI is lex().
for pdi_field in POS_LOG_PDI_FIELDS { POS_LOG_PDI:add(pdi_field,0). }
global POS_LOG_RENDEZVOUS_FIELDS is list("target_distance","relative_speed","plane_error","phase","docking_ready").
global POS_LOG_RENDEZVOUS is lex("target_distance",0,"relative_speed",0,"plane_error",0,"phase","inactive","docking_ready",false).
global POS_LOG_TERMINAL_PITCH_FEEDFORWARD is 0.
global POS_LOG_TERMINAL_PITCH_SATURATED is false.
global POS_LOG_TERMINAL_PREFLARE_PULLUP_ACTIVE is false.
global POS_LOG_TERMINAL_PREFLARE_PULLUP_FRACTION is 0.
global POS_LOG_TERMINAL_HANDOFF_BLEND_ACTIVE is false.
global POS_LOG_TERMINAL_HANDOFF_BLEND_ELAPSED is 0.
global POS_LOG_TERMINAL_HANDOFF_RAW_AOA is 0.
global POS_LOG_TERMINAL_HANDOFF_RAW_BANK is 0.
global POS_LOG_TERMINAL_HIGH_ENERGY_FINAL_ACTIVE is false.
global POS_LOG_TERMINAL_HIGH_ENERGY_DESIRED_VS is 0.
global POS_LOG_TERMINAL_HIGH_ENERGY_PITCH_COMMAND is 0.
global POS_LOG_TERMINAL_HIGH_ENERGY_PID_OUTPUT is 0.
global POS_LOG_TERMINAL_HIGH_ENERGY_TIME_TO_AIM is 0.

function flight_log_pdi_header {
    local columns is "".
    for field in POS_LOG_PDI_FIELDS { set columns to columns+",pdi_"+field. }
    return columns.
}

function flight_log_pdi_columns {
    local columns is "".
    for field in POS_LOG_PDI_FIELDS { set columns to columns+","+POS_LOG_PDI[field]. }
    return columns.
}

function flight_log_rendezvous_header {
    local columns is "".
    for field in POS_LOG_RENDEZVOUS_FIELDS { set columns to columns+",rendezvous_"+field. }
    return columns+",terminal_profile_pitch_feedforward,terminal_pitch_saturated,"+
        "terminal_preflare_pullup_active,terminal_preflare_pullup_fraction,"+
        "terminal_handoff_blend_active,terminal_handoff_blend_elapsed,"+
        "terminal_handoff_raw_aoa,terminal_handoff_raw_bank,"+
        "terminal_high_energy_final_active,terminal_high_energy_desired_vs,"+
        "terminal_high_energy_pitch_command,terminal_high_energy_pid_output,"+
        "terminal_high_energy_time_to_aim".
}

function flight_log_rendezvous_columns {
    local columns is "".
    for field in POS_LOG_RENDEZVOUS_FIELDS { set columns to columns+","+POS_LOG_RENDEZVOUS[field]. }
    return columns+","+POS_LOG_TERMINAL_PITCH_FEEDFORWARD+","+POS_LOG_TERMINAL_PITCH_SATURATED+","+
        POS_LOG_TERMINAL_PREFLARE_PULLUP_ACTIVE+","+POS_LOG_TERMINAL_PREFLARE_PULLUP_FRACTION+","+
        POS_LOG_TERMINAL_HANDOFF_BLEND_ACTIVE+","+POS_LOG_TERMINAL_HANDOFF_BLEND_ELAPSED+","+
        POS_LOG_TERMINAL_HANDOFF_RAW_AOA+","+POS_LOG_TERMINAL_HANDOFF_RAW_BANK+","+
        POS_LOG_TERMINAL_HIGH_ENERGY_FINAL_ACTIVE+","+POS_LOG_TERMINAL_HIGH_ENERGY_DESIRED_VS+","+
        POS_LOG_TERMINAL_HIGH_ENERGY_PITCH_COMMAND+","+POS_LOG_TERMINAL_HIGH_ENERGY_PID_OUTPUT+","+
        POS_LOG_TERMINAL_HIGH_ENERGY_TIME_TO_AIM.
}

// Appended only at the logger's existing sample cadence. The planner never
// consumes this observer and trajectories do not call the logger.
function flight_log_terminal_energy_header {
    return ",terminal_energy_capture,terminal_energy_drag_work,terminal_energy_turn_work,"+
        "terminal_energy_reserve,terminal_energy_clean_loss,terminal_energy_margin_rate,terminal_energy_brake_margin,"+
        "terminal_energy_turn_extra_distance,terminal_energy_turn_reserve".
}

function flight_log_terminal_energy_columns {
    if not(defined terminal_route_debug) {
        return ",0,0,0,0,0,0,0,0,0".
    }
    return ","+terminal_route_debug["energy_capture"]+","+terminal_route_debug["energy_drag_work"]+","+
        terminal_route_debug["energy_turn_work"]+","+terminal_route_debug["energy_reserve"]+","+
        terminal_route_debug["energy_clean_loss"]+","+terminal_route_debug["energy_margin_rate"]+","+
        terminal_route_debug["energy_brake_margin"]+","+
        terminal_route_debug["energy_turn_extra_distance"]+","+terminal_route_debug["energy_turn_reserve"].
}

function flight_log_entry_predictive_header {
    return ",entry_predictive_plan_bank,entry_predictive_bank,entry_predictive_lower_bank,"+
        "entry_predictive_lower_range_error,entry_predictive_lower_miss,entry_predictive_upper_bank,"+
        "entry_predictive_upper_range_error,entry_predictive_upper_miss,entry_predictive_authority,"+
        "entry_predictive_sensitivity,entry_predictive_valid,entry_predictive_frozen,entry_predictive_elapsed,"+
        "entry_predictive_next_update".
}

function flight_log_entry_predictive_columns {
    return ","+POS_LOG_ENTRY["predictive_plan_bank"]+","+POS_LOG_ENTRY["predictive_bank"]+","+
        POS_LOG_ENTRY["predictive_lower_bank"]+","+POS_LOG_ENTRY["predictive_lower_range_error"]+","+
        POS_LOG_ENTRY["predictive_lower_miss"]+","+POS_LOG_ENTRY["predictive_upper_bank"]+","+
        POS_LOG_ENTRY["predictive_upper_range_error"]+","+POS_LOG_ENTRY["predictive_upper_miss"]+","+
        POS_LOG_ENTRY["predictive_authority"]+","+
        POS_LOG_ENTRY["predictive_sensitivity"]+","+POS_LOG_ENTRY["predictive_valid"]+","+
        POS_LOG_ENTRY["predictive_frozen"]+","+
        POS_LOG_ENTRY["predictive_elapsed"]+","+POS_LOG_ENTRY["predictive_next_update"].
}

function flight_log_capture_rendezvous {
    parameter target_vessel, phase, planned_nodes, docking_ready.
    if POS_LOG_LEVEL < 1 { return. }
    local distance is (target_vessel:position-ship:position):mag.
    local relative_speed is (target_vessel:velocity:orbit-ship:velocity:orbit):mag.
    local plane_error is abs(target_vessel:orbit:inclination-ship:orbit:inclination).
    local state is phase+"|"+docking_ready.
    if state <> POS_LOG_LAST_RENDEZVOUS_STATE {
        flight_log_event("rendezvous_state","phase="+phase+"|planned_nodes="+planned_nodes+"|docking_ready="+docking_ready).
        set POS_LOG_LAST_RENDEZVOUS_STATE to state.
    }
    if POS_LOG_LEVEL < 2 { return. }
    if POS_LOG_LEVEL = 2 and time:seconds < POS_LOG_NEXT_SAMPLE_TIME { return. }
    set POS_LOG_RENDEZVOUS["target_distance"] to distance.
    set POS_LOG_RENDEZVOUS["relative_speed"] to relative_speed.
    set POS_LOG_RENDEZVOUS["plane_error"] to plane_error.
    set POS_LOG_RENDEZVOUS["phase"] to phase.
    set POS_LOG_RENDEZVOUS["docking_ready"] to docking_ready.
}

function flight_log_capture_pdi {
    parameter telemetry, reason.
    if POS_LOG_LEVEL < 1 { return. }
    local state is telemetry["valid"]+"|"+telemetry["converged"]+"|"+reason.
    if state <> POS_LOG_LAST_PDI_STATE {
        flight_log_event("pdi_solution_state","state="+state).
        set POS_LOG_LAST_PDI_STATE to state.
    }
    if telemetry["saturated"]:tostring <> POS_LOG_LAST_PDI_SATURATED {
        flight_log_event("pdi_thrust_saturation","active="+telemetry["saturated"]+"|vertical_margin="+telemetry["vertical_margin"]).
        set POS_LOG_LAST_PDI_SATURATED to telemetry["saturated"]:tostring.
    }
    if telemetry["flip_ready"]:tostring <> POS_LOG_LAST_PDI_FLIP_READY {
        flight_log_event("pdi_flip_gate","ready="+telemetry["flip_ready"]+"|horizontal_speed="+telemetry["horizontal_speed"]).
        set POS_LOG_LAST_PDI_FLIP_READY to telemetry["flip_ready"]:tostring.
    }
    if telemetry["terminal_descent_committed"]:tostring <> POS_LOG_LAST_PDI_TERMINAL_DESCENT {
        flight_log_event("pdi_terminal_descent_commit","active="+telemetry["terminal_descent_committed"]+
            "|hold_height="+telemetry["terminal_hold_height"]+"|horizontal_speed="+telemetry["horizontal_speed"]).
        set POS_LOG_LAST_PDI_TERMINAL_DESCENT to telemetry["terminal_descent_committed"]:tostring.
    }
    if POS_LOG_LEVEL < 2 { return. }
    if POS_LOG_LEVEL = 2 and time:seconds < POS_LOG_NEXT_SAMPLE_TIME { return. }
    for field in POS_LOG_PDI_FIELDS { set POS_LOG_PDI[field] to telemetry[field]. }
}
global POS_LOG_RUNWAY is lex(
    "location","unknown","number","unknown","start_lat",0,"start_lng",0,
    "end_lat",0,"end_lng",0,"heading",0,"altitude",0
).
global POS_LOG_TARGET is lex("lat",0,"lng",0,"altitude",0).
global POS_LOG_ENTRY is lex(
    "reference_lat",0,"reference_lng",0,"reference_altitude",0,"reference_speed",0,
    "energy_reference",0,"energy_actual",0,"energy_error",0,"heading_error",0,
    "bank_command",0,"time_to_interface",0,"turn_side","","lift_to_drag",0,
    "segment_start_time",0,"segment_end_time",0,"segment_fraction",0,"segment_cross_track",0,
    "predictive_plan_bank",0,"predictive_bank",0,"predictive_lower_bank",0,
    "predictive_lower_range_error",0,"predictive_lower_miss",0,"predictive_upper_bank",0,
    "predictive_upper_range_error",0,"predictive_upper_miss",0,"predictive_authority",0,
    "predictive_sensitivity",0,"predictive_valid",false,"predictive_frozen",false,"predictive_elapsed",0,
    "predictive_next_update",0
).
// Vacuum guidance is captured only by the live landing script.  Keeping this
// state in the logger (rather than in the guidance calculations) preserves the
// no-logging contract of simulations and lets medium/high logs explain a
// missed landing or an early/late braking burn.
global POS_LOG_VACUUM is lex(
    "phase","inactive","target_lat",0,"target_lng",0,"target_altitude",0,
    "target_distance",0,"surface_clearance",0,"surface_speed",0,
    "vertical_speed_target",0,"throttle_command",0,"stopping_distance",0,
    "available_acceleration",0,"tail_contact",false,"gear_pitch_target",0
).
global POS_LOG_VACUUM_ASCENT is lex(
    "phase","inactive","target_altitude",0,"target_inclination",0,"launch_heading",0,
    "surface_clearance",0,"vertical_speed",0,"horizontal_speed",0,"target_pitch",0,
    "attitude_error",0,"nerv_twr",0,"rapier_kick_active",false,
    "predicted_apoapsis",0,"predicted_periapsis",0,"node_dv",0,"node_eta",0
).

function flight_log_vacuum_ascent_header {
    return ",vacuum_ascent_phase,vacuum_ascent_target_altitude,vacuum_ascent_target_inclination,"+
        "vacuum_ascent_launch_heading,vacuum_ascent_surface_clearance,vacuum_ascent_vertical_speed,"+
        "vacuum_ascent_horizontal_speed,vacuum_ascent_target_pitch,vacuum_ascent_attitude_error,"+
        "vacuum_ascent_nerv_twr,vacuum_ascent_rapier_kick_active,vacuum_ascent_predicted_apoapsis,"+
        "vacuum_ascent_predicted_periapsis,vacuum_ascent_node_dv,vacuum_ascent_node_eta".
}

function flight_log_write_headers {
    if POS_LOG_HEADERS_WRITTEN { return. }
    log "schema,session,ut,mission_time,sample,program,body,step,substep,dap_mode,steering_mode,vessel_status,rapier_mode,rapiers_active,nervs_active,wheel_brakes,rcs_actual,sas_actual,latitude,longitude,altitude,radar_altitude,airspeed,surface_speed,vertical_speed,surface_velocity_x,surface_velocity_y,surface_velocity_z,acceleration_x,acceleration_y,acceleration_z,pitch,heading,roll,facing_x,facing_y,facing_z,mass,thrust,dynamic_pressure,mach,throttle_command,throttle_actual,aoa_actual,aoa_target,bank_target,smooth_aoa,smooth_bank,base_pitch,aerostr_target_pitch,aerostr_target_roll,aerostr_turn_pitch,aerostr_turn_heading,envelope_state,envelope_regime,envelope_max_aoa,envelope_max_bank,envelope_min_throttle,envelope_rcs_assist,gpws_state,gpws_worst_clearance,gpws_required_clearance,gpws_clearance_margin,gpws_clear_timer,gpws_next_scan_ut,gpws_pullup_active,terminal_phase,terminal_profile_region,terminal_profile_altitude,terminal_profile_gradient,terminal_profile_error,terminal_profile_feedforward_vs,terminal_side,terminal_hold_laps,terminal_target_distance,terminal_remaining_distance,terminal_target_altitude,terminal_along_track,terminal_cross_track,terminal_energy_margin,terminal_target_energy,terminal_runway_heading_error,terminal_target_vs,landing_target_vs,landing_flare_fraction,terminal_pitch_bias,terminal_target_aoa,terminal_throttle,terminal_airbrake,terminal_gear,terminal_landing_stable,terminal_go_around_reason,terminal_pid_output,target_latitude,target_longitude,target_altitude,entry_reference_latitude,entry_reference_longitude,entry_reference_altitude,entry_reference_speed,entry_energy_reference,entry_energy_actual,entry_energy_error,entry_heading_error,entry_bank_command,entry_time_to_interface,entry_turn_side,entry_lift_to_drag,entry_segment_start_time,entry_segment_end_time,entry_segment_fraction,entry_segment_cross_track,runway_start_latitude,runway_start_longitude,runway_end_latitude,runway_end_longitude,runway_heading,runway_altitude,dap_dt,aerostr_target_direction,aerostr_turn_roll,aerostr_distance_pitch,aerostr_pitch,aerostr_roll,aerostr_heading,aoa_pitch_command,aoa_yaw_command,aoa_roll_command,css_pitch_output,css_yaw_output,css_roll_output,css_last_roll,css_last_aoa,envelope_last_aoa,envelope_last_speed,envelope_last_pitch_error,envelope_pitchdown_timer,envelope_authority_timer,envelope_upset_timer,envelope_stable_timer,envelope_restore_steering,vacuum_phase,vacuum_target_latitude,vacuum_target_longitude,vacuum_target_altitude,vacuum_target_distance,vacuum_surface_clearance,vacuum_surface_speed,vacuum_target_vertical_speed,vacuum_throttle,vacuum_stopping_distance,vacuum_available_acceleration,vacuum_tail_contact,vacuum_gear_pitch_target" + flight_log_vacuum_ascent_header() + flight_log_pdi_header() + flight_log_rendezvous_header() + flight_log_entry_predictive_header() + flight_log_terminal_energy_header() to POS_LOG_FLIGHT_FILE.
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
// approach_brake events record mode, protection and command changes at every log
// level; existing airspeed, wheel_brakes, terminal_airbrake and energy samples
// provide the medium/high-rate trace without changing the sample schema.
function flight_log_approach_brake {
    parameter control_mode, change_reason, brake_command, speed_reference,
        engage_speed, release_speed, energy_error, brake_margin is 0,
        required_energy is 0, turn_extra_distance is 0, turn_reserve is 0.
    if POS_LOG_LEVEL < 1 { return. }
    flight_log_event("approach_brake","mode="+control_mode+"|reason="+change_reason+
        "|command="+brake_command+"|airspeed="+round(ship:airspeed,2)+
        "|reference_speed="+speed_reference+"|engage_speed="+engage_speed+
        "|release_speed="+release_speed+"|energy_margin="+round(energy_error,2)+
        "|brake_margin="+round(brake_margin,2)+"|required_energy="+round(required_energy,2)+
        "|turn_extra_distance="+round(turn_extra_distance,2)+"|turn_reserve="+round(turn_reserve,2)+
        "|vertical_speed="+round(ship:verticalspeed,2)+"|vessel_status="+ship:status).
}

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
        "bank_command",0,"time_to_interface",0,"turn_side","","lift_to_drag",0,
        "segment_start_time",0,"segment_end_time",0,"segment_fraction",0,"segment_cross_track",0,
        "predictive_plan_bank",0,"predictive_bank",0,"predictive_lower_bank",0,
        "predictive_lower_range_error",0,"predictive_lower_miss",0,"predictive_upper_bank",0,
        "predictive_upper_range_error",0,"predictive_upper_miss",0,"predictive_authority",0,
        "predictive_sensitivity",0,"predictive_valid",false,"predictive_frozen",false,"predictive_elapsed",0,
        "predictive_next_update",0
    ).
    set POS_LOG_VACUUM to lex(
        "phase","inactive","target_lat",0,"target_lng",0,"target_altitude",0,
        "target_distance",0,"surface_clearance",0,"surface_speed",0,
        "vertical_speed_target",0,"throttle_command",0,"stopping_distance",0,
        "available_acceleration",0,"tail_contact",false,"gear_pitch_target",0
    ).
    set POS_LOG_VACUUM_ASCENT to lex(
        "phase","inactive","target_altitude",0,"target_inclination",0,"launch_heading",0,
        "surface_clearance",0,"vertical_speed",0,"horizontal_speed",0,"target_pitch",0,
        "attitude_error",0,"nerv_twr",0,"rapier_kick_active",false,
        "predicted_apoapsis",0,"predicted_periapsis",0,"node_dv",0,"node_eta",0
    ).
    flight_log_write_headers().
    set POS_LOG_NEXT_SAMPLE_TIME to time:seconds.
    set POS_LOG_SAMPLE_INDEX to 0.
    set POS_LOG_LAST_STEP to "".
    set POS_LOG_LAST_SUBSTEP to "".
    set POS_LOG_LAST_DAP_MODE to "".
    set POS_LOG_LAST_STEERING_MODE to "".
    set POS_LOG_LAST_ENTRY_DISPLAY_MODE to "".
    set POS_LOG_LAST_GPWS_STATE to "".
    set POS_LOG_LAST_GPWS_REASON to "".
    set POS_LOG_LAST_PDI_STATE to "".
    set POS_LOG_LAST_PDI_SATURATED to "".
    set POS_LOG_LAST_PDI_FLIP_READY to "".
    set POS_LOG_LAST_PDI_TERMINAL_DESCENT to "".
    set POS_LOG_LAST_RENDEZVOUS_STATE to "".
    set POS_LOG_LAST_BODY to ship:body:name.
    for field in POS_LOG_PDI_FIELDS { set POS_LOG_PDI[field] to 0. }
    set POS_LOG_RENDEZVOUS to lex("target_distance",0,"relative_speed",0,"plane_error",0,"phase","inactive","docking_ready",false).
    // Record the configured VM budget once at low cost. This lets a later
    // replay distinguish guidance behavior from a differently configured CPU.
    flight_log_event("flight_start","mode=" + POS_LOGGING_MODE + "|body=" + POS_LOG_LAST_BODY +
        "|directory=" + POS_LOG_DIRECTORY + "|ipu=" + CONFIG:IPU).
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
    flight_log_event("entry_target","latitude=" + round(POS_LOG_TARGET["lat"],6) +
        "|longitude=" + round(POS_LOG_TARGET["lng"],6) +
        "|altitude=" + round(POS_LOG_TARGET["altitude"],1) +
        "|ercl_latitude=" + round(team_interface["ercl_target"]:lat,6) +
        "|ercl_longitude=" + round(team_interface["ercl_target"]:lng,6) +
        "|ercl_distance=" + round(team_interface["ercl_distance"],1) +
        "|approach_bearing=" + round(team_interface["approach_bearing"],2) +
        "|lateral_offset=" + round(team_interface["lateral_offset"],1) +
        "|box_tolerance=" + round(team_interface["team_interface_box"]["dist_tolerance"],1)).
}

function flight_log_set_vacuum_target {
    parameter target_position, terrain_altitude, landing_heading.
    if POS_LOG_LEVEL < 1 { return. }
    set POS_LOG_TARGET["lat"] to target_position:lat.
    set POS_LOG_TARGET["lng"] to target_position:lng.
    set POS_LOG_TARGET["altitude"] to terrain_altitude.
    set POS_LOG_VACUUM["target_lat"] to target_position:lat.
    set POS_LOG_VACUUM["target_lng"] to target_position:lng.
    set POS_LOG_VACUUM["target_altitude"] to terrain_altitude.
    flight_log_event("vacuum_target","latitude=" + round(target_position:lat,6) + "|longitude=" + round(target_position:lng,6) + "|altitude=" + round(terrain_altitude,1) + "|heading=" + round(landing_heading,1)).
}

function flight_log_set_vacuum_ascent_target {
    parameter target_altitude, target_inclination, launch_heading.
    if POS_LOG_LEVEL < 1 { return. }
    set POS_LOG_VACUUM_ASCENT["target_altitude"] to target_altitude.
    set POS_LOG_VACUUM_ASCENT["target_inclination"] to target_inclination.
    set POS_LOG_VACUUM_ASCENT["launch_heading"] to launch_heading.
    flight_log_event("vacuum_ascent_target","altitude="+round(target_altitude,1)+"|inclination="+
        round(target_inclination,3)+"|heading="+round(launch_heading,3)).
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

// Observe only actual GUI page transitions from the live reentry loop.  Low
// logging pays one string comparison per tick and one event per transition;
// medium/high retain their existing sample cadence.  This is never called by
// the entry trajectory solver or any offline trajectory simulation.
function flight_log_entry_display_mode {
    parameter display_mode, energy_height, range_remaining.
    if POS_LOG_LEVEL < 1 { return. }
    if display_mode = POS_LOG_LAST_ENTRY_DISPLAY_MODE { return. }
    flight_log_event("entry_display_mode","value="+display_mode+
        "|altitude="+round(ship:altitude,1)+"|airspeed="+round(ship:airspeed,1)+
        "|energy_height="+round(energy_height,1)+"|range_remaining="+round(range_remaining,1)).
    set POS_LOG_LAST_ENTRY_DISPLAY_MODE to display_mode.
}

// Record only completed live guidance predictions.  This observer is called
// outside sim_with_bank so logging remains absent from all trajectory models.
function flight_log_entry_prediction {
    parameter plan_bank, command_bank, lower_bank, lower_range_error, lower_miss.
    parameter upper_bank, upper_range_error, upper_miss, authority.
    parameter sensitivity, valid_solution, frozen, elapsed_time, next_update.
    if POS_LOG_LEVEL < 1 { return. }
    set POS_LOG_ENTRY["predictive_plan_bank"] to plan_bank.
    set POS_LOG_ENTRY["predictive_bank"] to command_bank.
    set POS_LOG_ENTRY["predictive_lower_bank"] to lower_bank.
    set POS_LOG_ENTRY["predictive_lower_range_error"] to lower_range_error.
    set POS_LOG_ENTRY["predictive_lower_miss"] to lower_miss.
    set POS_LOG_ENTRY["predictive_upper_bank"] to upper_bank.
    set POS_LOG_ENTRY["predictive_upper_range_error"] to upper_range_error.
    set POS_LOG_ENTRY["predictive_upper_miss"] to upper_miss.
    set POS_LOG_ENTRY["predictive_authority"] to authority.
    set POS_LOG_ENTRY["predictive_sensitivity"] to sensitivity.
    set POS_LOG_ENTRY["predictive_valid"] to valid_solution.
    set POS_LOG_ENTRY["predictive_frozen"] to frozen.
    set POS_LOG_ENTRY["predictive_elapsed"] to elapsed_time.
    set POS_LOG_ENTRY["predictive_next_update"] to next_update.
    flight_log_event("entry_bank_prediction","valid="+valid_solution+"|frozen="+frozen+"|plan_bank="+round(plan_bank,3)+
        "|command_bank="+round(command_bank,3)+"|lower_bank="+round(lower_bank,3)+
        "|lower_range_error="+round(lower_range_error,1)+"|lower_miss="+round(lower_miss,1)+
        "|upper_bank="+round(upper_bank,3)+"|upper_range_error="+round(upper_range_error,1)+
        "|upper_miss="+round(upper_miss,1)+"|authority="+round(authority,3)+
        "|sensitivity="+round(sensitivity,3)+
        "|elapsed="+round(elapsed_time,3)).
}

// Capture values produced by the live entry controller.  For medium this runs
// only on the tick that will write the next one-second sample; high captures
// each real control tick.  It is never called by the entry trajectory solver.
function flight_log_capture_entry_guidance {
    parameter reference_state, energy_reference, energy_actual, energy_error, heading_error, bank_command, time_to_interface, turn_side, lift_to_drag, segment_start_time, segment_end_time, segment_fraction, segment_cross_track.
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
    set POS_LOG_ENTRY["segment_start_time"] to segment_start_time.
    set POS_LOG_ENTRY["segment_end_time"] to segment_end_time.
    set POS_LOG_ENTRY["segment_fraction"] to segment_fraction.
    set POS_LOG_ENTRY["segment_cross_track"] to segment_cross_track.
}

// Called exclusively from the live vacuum landing loop.  The same rate gate
// as entry guidance keeps medium logs to one capture per second and high logs
// at one capture per control tick.
function flight_log_capture_vacuum_guidance {
    parameter phase, target_distance, surface_clearance, surface_speed, vertical_speed_target, throttle_command, stopping_distance, available_acceleration, tail_contact, gear_pitch_target.
    if POS_LOG_LEVEL < 2 { return. }
    if POS_LOG_LEVEL = 2 and time:seconds < POS_LOG_NEXT_SAMPLE_TIME { return. }
    set POS_LOG_VACUUM["phase"] to phase.
    set POS_LOG_VACUUM["target_distance"] to target_distance.
    set POS_LOG_VACUUM["surface_clearance"] to surface_clearance.
    set POS_LOG_VACUUM["surface_speed"] to surface_speed.
    set POS_LOG_VACUUM["vertical_speed_target"] to vertical_speed_target.
    set POS_LOG_VACUUM["throttle_command"] to throttle_command.
    set POS_LOG_VACUUM["stopping_distance"] to stopping_distance.
    set POS_LOG_VACUUM["available_acceleration"] to available_acceleration.
    set POS_LOG_VACUUM["tail_contact"] to tail_contact.
    set POS_LOG_VACUUM["gear_pitch_target"] to gear_pitch_target.
}

// Called only from the live vacuum-ascent loop.  The rate gate preserves the
// established low/medium/high cost model: no samples at low, one per second
// at medium, and one per control tick at high.
function flight_log_capture_vacuum_ascent {
    parameter phase, target_altitude, target_inclination, launch_heading, surface_clearance, vertical_speed, horizontal_speed, target_pitch, attitude_error, nerv_twr, rapier_kick_active, predicted_apoapsis, predicted_periapsis, node_dv, node_eta.
    if POS_LOG_LEVEL < 2 { return. }
    if POS_LOG_LEVEL = 2 and time:seconds < POS_LOG_NEXT_SAMPLE_TIME { return. }
    set POS_LOG_VACUUM_ASCENT["phase"] to phase.
    set POS_LOG_VACUUM_ASCENT["target_altitude"] to target_altitude.
    set POS_LOG_VACUUM_ASCENT["target_inclination"] to target_inclination.
    set POS_LOG_VACUUM_ASCENT["launch_heading"] to launch_heading.
    set POS_LOG_VACUUM_ASCENT["surface_clearance"] to surface_clearance.
    set POS_LOG_VACUUM_ASCENT["vertical_speed"] to vertical_speed.
    set POS_LOG_VACUUM_ASCENT["horizontal_speed"] to horizontal_speed.
    set POS_LOG_VACUUM_ASCENT["target_pitch"] to target_pitch.
    set POS_LOG_VACUUM_ASCENT["attitude_error"] to attitude_error.
    set POS_LOG_VACUUM_ASCENT["nerv_twr"] to nerv_twr.
    set POS_LOG_VACUUM_ASCENT["rapier_kick_active"] to rapier_kick_active.
    set POS_LOG_VACUUM_ASCENT["predicted_apoapsis"] to predicted_apoapsis.
    set POS_LOG_VACUUM_ASCENT["predicted_periapsis"] to predicted_periapsis.
    set POS_LOG_VACUUM_ASCENT["node_dv"] to node_dv.
    set POS_LOG_VACUUM_ASCENT["node_eta"] to node_eta.
}

function flight_log_write_sample {
    parameter program_name, current_step, current_substep.
    local terminal_phase is "inactive".
    local terminal_profile_region is "inactive".
    local terminal_profile_altitude is 0.
    local terminal_profile_gradient is 0.
    local terminal_profile_error is 0.
    local terminal_profile_feedforward_vs is 0.
    local terminal_profile_pitch_feedforward is 0.
    local terminal_pitch_saturated is false.
    local terminal_preflare_pullup_active is false.
    local terminal_preflare_pullup_fraction is 0.
    local terminal_handoff_blend_active is false.
    local terminal_handoff_blend_elapsed is 0.
    local terminal_handoff_raw_aoa is 0.
    local terminal_handoff_raw_bank is 0.
    local terminal_high_energy_final_active is false.
    local terminal_high_energy_desired_vs is 0.
    local terminal_high_energy_pitch_command is 0.
    local terminal_high_energy_pid_output is 0.
    local terminal_high_energy_time_to_aim is 0.
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
    local landing_target_vs is 0.
    local landing_flare_fraction is 0.
    local terminal_pitch_bias is 0.
    local terminal_target_aoa is 0.
    local terminal_throttle is 0.
    local terminal_airbrake is false.
    local terminal_gear is false.
    local terminal_landing_stable is false.
    local terminal_go_around_reason is "".
    local terminal_pid_output is "none".
    local vacuum_phase is "inactive".
    local vacuum_target_latitude is 0.
    local vacuum_target_longitude is 0.
    local vacuum_target_altitude is 0.
    local vacuum_target_distance is 0.
    local vacuum_surface_clearance is 0.
    local vacuum_surface_speed is 0.
    local vacuum_target_vertical_speed is 0.
    local vacuum_throttle is 0.
    local vacuum_stopping_distance is 0.
    local vacuum_available_acceleration is 0.
    local vacuum_tail_contact is false.
    local vacuum_gear_pitch_target is 0.
    local vacuum_ascent_phase is "inactive".
    local vacuum_ascent_target_altitude is 0.
    local vacuum_ascent_target_inclination is 0.
    local vacuum_ascent_launch_heading is 0.
    local vacuum_ascent_surface_clearance is 0.
    local vacuum_ascent_vertical_speed is 0.
    local vacuum_ascent_horizontal_speed is 0.
    local vacuum_ascent_target_pitch is 0.
    local vacuum_ascent_attitude_error is 0.
    local vacuum_ascent_nerv_twr is 0.
    local vacuum_ascent_rapier_kick_active is false.
    local vacuum_ascent_predicted_apoapsis is 0.
    local vacuum_ascent_predicted_periapsis is 0.
    local vacuum_ascent_node_dv is 0.
    local vacuum_ascent_node_eta is 0.
    if defined terminal_route_debug {
        set terminal_phase to terminal_route_debug["phase"].
        set terminal_profile_region to terminal_route_debug["profile_region"].
        set terminal_profile_altitude to terminal_route_debug["profile_altitude"].
        set terminal_profile_gradient to terminal_route_debug["profile_gradient"].
        set terminal_profile_error to terminal_route_debug["profile_error"].
        set terminal_profile_feedforward_vs to terminal_route_debug["profile_feedforward_vs"].
        set terminal_profile_pitch_feedforward to terminal_route_debug["profile_pitch_feedforward"].
        set terminal_pitch_saturated to terminal_route_debug["pitch_saturated"].
        set terminal_preflare_pullup_active to terminal_route_debug["preflare_pullup_active"].
        set terminal_preflare_pullup_fraction to terminal_route_debug["preflare_pullup_fraction"].
        set terminal_handoff_blend_active to terminal_route_debug["handoff_blend_active"].
        set terminal_handoff_blend_elapsed to terminal_route_debug["handoff_blend_elapsed"].
        set terminal_handoff_raw_aoa to terminal_route_debug["handoff_raw_target_aoa"].
        set terminal_handoff_raw_bank to terminal_route_debug["handoff_raw_target_bank"].
        set terminal_high_energy_final_active to terminal_route_debug["high_energy_final_active"].
        set terminal_high_energy_desired_vs to terminal_route_debug["high_energy_desired_vs"].
        set terminal_high_energy_pitch_command to terminal_route_debug["high_energy_pitch_command"].
        set terminal_high_energy_pid_output to terminal_route_debug["high_energy_pid_output"].
        set terminal_high_energy_time_to_aim to terminal_route_debug["high_energy_time_to_aim"].
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
        set landing_target_vs to terminal_route_debug["landing_desired_vs"].
        set landing_flare_fraction to terminal_route_debug["landing_flare_fraction"].
        set terminal_pitch_bias to terminal_route_debug["pitch_bias"].
        set terminal_target_aoa to terminal_route_debug["target_aoa"].
        set terminal_throttle to terminal_route_debug["throttle"].
        set terminal_airbrake to terminal_route_debug["airbrake"].
        set terminal_gear to terminal_route_debug["gear"].
        set terminal_landing_stable to terminal_route_debug["landing_stable"].
        set terminal_go_around_reason to terminal_route_debug["go_around_reason"].
        set terminal_pid_output to terminal_route_debug["Pid_log"].
    }
    if defined POS_LOG_VACUUM {
        set vacuum_phase to POS_LOG_VACUUM["phase"].
        set vacuum_target_latitude to POS_LOG_VACUUM["target_lat"].
        set vacuum_target_longitude to POS_LOG_VACUUM["target_lng"].
        set vacuum_target_altitude to POS_LOG_VACUUM["target_altitude"].
        set vacuum_target_distance to POS_LOG_VACUUM["target_distance"].
        set vacuum_surface_clearance to POS_LOG_VACUUM["surface_clearance"].
        set vacuum_surface_speed to POS_LOG_VACUUM["surface_speed"].
        set vacuum_target_vertical_speed to POS_LOG_VACUUM["vertical_speed_target"].
        set vacuum_throttle to POS_LOG_VACUUM["throttle_command"].
        set vacuum_stopping_distance to POS_LOG_VACUUM["stopping_distance"].
        set vacuum_available_acceleration to POS_LOG_VACUUM["available_acceleration"].
        set vacuum_tail_contact to POS_LOG_VACUUM["tail_contact"].
        set vacuum_gear_pitch_target to POS_LOG_VACUUM["gear_pitch_target"].
    }
    if defined POS_LOG_VACUUM_ASCENT {
        set vacuum_ascent_phase to POS_LOG_VACUUM_ASCENT["phase"].
        set vacuum_ascent_target_altitude to POS_LOG_VACUUM_ASCENT["target_altitude"].
        set vacuum_ascent_target_inclination to POS_LOG_VACUUM_ASCENT["target_inclination"].
        set vacuum_ascent_launch_heading to POS_LOG_VACUUM_ASCENT["launch_heading"].
        set vacuum_ascent_surface_clearance to POS_LOG_VACUUM_ASCENT["surface_clearance"].
        set vacuum_ascent_vertical_speed to POS_LOG_VACUUM_ASCENT["vertical_speed"].
        set vacuum_ascent_horizontal_speed to POS_LOG_VACUUM_ASCENT["horizontal_speed"].
        set vacuum_ascent_target_pitch to POS_LOG_VACUUM_ASCENT["target_pitch"].
        set vacuum_ascent_attitude_error to POS_LOG_VACUUM_ASCENT["attitude_error"].
        set vacuum_ascent_nerv_twr to POS_LOG_VACUUM_ASCENT["nerv_twr"].
        set vacuum_ascent_rapier_kick_active to POS_LOG_VACUUM_ASCENT["rapier_kick_active"].
        set vacuum_ascent_predicted_apoapsis to POS_LOG_VACUUM_ASCENT["predicted_apoapsis"].
        set vacuum_ascent_predicted_periapsis to POS_LOG_VACUUM_ASCENT["predicted_periapsis"].
        set vacuum_ascent_node_dv to POS_LOG_VACUUM_ASCENT["node_dv"].
        set vacuum_ascent_node_eta to POS_LOG_VACUUM_ASCENT["node_eta"].
    }
    local surface_velocity is ship:velocity:surface.
    local acceleration is ship:sensors:acc.
    local facing_vec is ship:facing:vector.
    local envelope is dap["envelope"].
    local gpws_clearance_margin is envelope["terrain_worst_clearance"] - envelope["terrain_required_clearance"].
    local gpws_pullup_active is envelope["state"] = "terrain_pullup".
    set POS_LOG_TERMINAL_PITCH_FEEDFORWARD to terminal_profile_pitch_feedforward.
    set POS_LOG_TERMINAL_PITCH_SATURATED to terminal_pitch_saturated.
    set POS_LOG_TERMINAL_PREFLARE_PULLUP_ACTIVE to terminal_preflare_pullup_active.
    set POS_LOG_TERMINAL_PREFLARE_PULLUP_FRACTION to terminal_preflare_pullup_fraction.
    set POS_LOG_TERMINAL_HANDOFF_BLEND_ACTIVE to terminal_handoff_blend_active.
    set POS_LOG_TERMINAL_HANDOFF_BLEND_ELAPSED to terminal_handoff_blend_elapsed.
    set POS_LOG_TERMINAL_HANDOFF_RAW_AOA to terminal_handoff_raw_aoa.
    set POS_LOG_TERMINAL_HANDOFF_RAW_BANK to terminal_handoff_raw_bank.
    set POS_LOG_TERMINAL_HIGH_ENERGY_FINAL_ACTIVE to terminal_high_energy_final_active.
    set POS_LOG_TERMINAL_HIGH_ENERGY_DESIRED_VS to terminal_high_energy_desired_vs.
    set POS_LOG_TERMINAL_HIGH_ENERGY_PITCH_COMMAND to terminal_high_energy_pitch_command.
    set POS_LOG_TERMINAL_HIGH_ENERGY_PID_OUTPUT to terminal_high_energy_pid_output.
    set POS_LOG_TERMINAL_HIGH_ENERGY_TIME_TO_AIM to terminal_high_energy_time_to_aim.
    log POS_LOG_SCHEMA_VERSION + "," + POS_LOG_SESSION + "," + time:seconds + "," + missiontime + "," + POS_LOG_SAMPLE_INDEX + "," + program_name + "," + ship:body:name + "," + current_step + "," + current_substep + "," + dap["dap_mode"] + "," + dap["str_mode"] + "," + ship:status + "," + rapier_mode + "," + rapiers + "," + nervs + "," + brakes + "," + RCS + "," + SAS + "," + ship:geoposition:lat + "," + ship:geoposition:lng + "," + ship:altitude + "," + alt:radar + "," + ship:airspeed + "," + surface_velocity:mag + "," + ship:verticalspeed + "," + surface_velocity:x + "," + surface_velocity:y + "," + surface_velocity:z + "," + acceleration:x + "," + acceleration:y + "," + acceleration:z + "," + pitch_for() + "," + compass_for() + "," + roll_for() + "," + facing_vec:x + "," + facing_vec:y + "," + facing_vec:z + "," + ship:mass + "," + ship:thrust + "," + ship:q + "," + ADDONS:FAR:mach + "," + dapthrottle + "," + throttle + "," + calc_aoa() + "," + dap["aoa"]["target_aoa"] + "," + dap["aoa"]["target_bank"] + "," + dap["aoa"]["smooth_target_aoa"] + "," + dap["aoa"]["smooth_target_bank"] + "," + dap["aoa"]["base_pitch"] + "," + dap["aerostr"]["targetPitch"] + "," + dap["aerostr"]["targetRoll"] + "," + dap["aerostr"]["turn_pitch"] + "," + dap["aerostr"]["turn_heading"] + "," + envelope["state"] + "," + envelope["regime"] + "," + envelope["max_aoa"] + "," + envelope["max_bank"] + "," + envelope["min_throttle"] + "," + envelope["rcs_assist"] + "," + envelope["terrain_state"] + "," + envelope["terrain_worst_clearance"] + "," + envelope["terrain_required_clearance"] + "," + gpws_clearance_margin + "," + envelope["terrain_clear_timer"] + "," + envelope["terrain_next_scan"] + "," + gpws_pullup_active + "," + terminal_phase + "," + terminal_profile_region + "," + terminal_profile_altitude + "," + terminal_profile_gradient + "," + terminal_profile_error + "," + terminal_profile_feedforward_vs + "," + terminal_side + "," + terminal_hold_laps + "," + terminal_target_distance + "," + terminal_remaining_distance + "," + terminal_target_altitude + "," + terminal_along_track + "," + terminal_cross_track + "," + terminal_energy_margin + "," + terminal_target_energy + "," + terminal_runway_heading_error + "," + terminal_target_vs + "," + landing_target_vs + "," + landing_flare_fraction + "," + terminal_pitch_bias + "," + terminal_target_aoa + "," + terminal_throttle + "," + terminal_airbrake + "," + terminal_gear + "," + terminal_landing_stable + "," + terminal_go_around_reason + "," + terminal_pid_output + "," + POS_LOG_TARGET["lat"] + "," + POS_LOG_TARGET["lng"] + "," + POS_LOG_TARGET["altitude"] + "," + POS_LOG_ENTRY["reference_lat"] + "," + POS_LOG_ENTRY["reference_lng"] + "," + POS_LOG_ENTRY["reference_altitude"] + "," + POS_LOG_ENTRY["reference_speed"] + "," + POS_LOG_ENTRY["energy_reference"] + "," + POS_LOG_ENTRY["energy_actual"] + "," + POS_LOG_ENTRY["energy_error"] + "," + POS_LOG_ENTRY["heading_error"] + "," + POS_LOG_ENTRY["bank_command"] + "," + POS_LOG_ENTRY["time_to_interface"] + "," + POS_LOG_ENTRY["turn_side"] + "," + POS_LOG_ENTRY["lift_to_drag"] + "," + POS_LOG_ENTRY["segment_start_time"] + "," + POS_LOG_ENTRY["segment_end_time"] + "," + POS_LOG_ENTRY["segment_fraction"] + "," + POS_LOG_ENTRY["segment_cross_track"] + "," + POS_LOG_RUNWAY["start_lat"] + "," + POS_LOG_RUNWAY["start_lng"] + "," + POS_LOG_RUNWAY["end_lat"] + "," + POS_LOG_RUNWAY["end_lng"] + "," + POS_LOG_RUNWAY["heading"] + "," + POS_LOG_RUNWAY["altitude"] + "," + dap["dt"] + "," + dap["aerostr"]["targetDirection"] + "," + dap["aerostr"]["turn_roll"] + "," + dap["aerostr"]["distance_pitch"] + "," + dap["aerostr"]["aerostr_pitch"] + "," + dap["aerostr"]["aerostr_roll"] + "," + dap["aerostr"]["aerostr_heading"] + "," + dap["aoa"]["aoa_pitch"] + "," + dap["aoa"]["aoa_yaw"] + "," + dap["aoa"]["aoa_roll"] + "," + dap["css"]["pitch_out"] + "," + dap["css"]["yaw_out"] + "," + dap["css"]["roll_out"] + "," + dap["css"]["last_roll"] + "," + dap["css"]["last_aoa"] + "," + envelope["last_aoa"] + "," + envelope["last_speed"] + "," + envelope["last_pitch_error"] + "," + envelope["pitchdown_timer"] + "," + envelope["authority_timer"] + "," + envelope["upset_timer"] + "," + envelope["stable_timer"] + "," + envelope["restore_steering"] + "," + vacuum_phase + "," + vacuum_target_latitude + "," + vacuum_target_longitude + "," + vacuum_target_altitude + "," + vacuum_target_distance + "," + vacuum_surface_clearance + "," + vacuum_surface_speed + "," + vacuum_target_vertical_speed + "," + vacuum_throttle + "," + vacuum_stopping_distance + "," + vacuum_available_acceleration + "," + vacuum_tail_contact + "," + vacuum_gear_pitch_target + "," + vacuum_ascent_phase + "," + vacuum_ascent_target_altitude + "," + vacuum_ascent_target_inclination + "," + vacuum_ascent_launch_heading + "," + vacuum_ascent_surface_clearance + "," + vacuum_ascent_vertical_speed + "," + vacuum_ascent_horizontal_speed + "," + vacuum_ascent_target_pitch + "," + vacuum_ascent_attitude_error + "," + vacuum_ascent_nerv_twr + "," + vacuum_ascent_rapier_kick_active + "," + vacuum_ascent_predicted_apoapsis + "," + vacuum_ascent_predicted_periapsis + "," + vacuum_ascent_node_dv + "," + vacuum_ascent_node_eta + flight_log_pdi_columns() + flight_log_rendezvous_columns() + flight_log_entry_predictive_columns() + flight_log_terminal_energy_columns() to POS_LOG_FLIGHT_FILE.
    set POS_LOG_SAMPLE_INDEX to POS_LOG_SAMPLE_INDEX + 1.
}

// One lightweight hook per real-flight loop.  At none it returns immediately;
// at low it only compares the four state strings; medium writes once a second;
// high writes every tick.  Expensive ship/DAP values are read only by
// flight_log_write_sample after a sample is actually due.
function flight_log_tick {
    parameter program_name, current_step, current_substep.
    if POS_LOG_LEVEL = 0 { return. }
    if POS_LOG_LAST_BODY <> ship:body:name {
        flight_log_event("body_changed","from=" + POS_LOG_LAST_BODY + "|to=" + ship:body:name).
        set POS_LOG_LAST_BODY to ship:body:name.
    }
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

// Observed maneuver phases (not private upstream state names). Runs only in
// real-flight execution. Low logs transitions; medium samples at 1 Hz; high
// samples once per physics tick. Samples share events.csv for schema stability.
function flight_log_maneuver_observe {
    parameter maneuver, half_time, evidence.
    if POS_LOG_LEVEL = 0 { return. }
    local phase is "aligning".
    if ship:control:mainthrottle > 0 { set phase to "burning". }
    else if evidence["burn_seen"] { set phase to "cutoff". }
    else if warp > 0 { set phase to "coasting". }
    else if vang(ship:facing:vector,maneuver:deltav) <= 0.5 { set phase to "waiting". }
    if phase <> evidence["phase"] {
        flight_log_event("maneuver_phase","from="+evidence["phase"]+"|to="+phase+"|eta="+maneuver:eta+"|dv="+maneuver:deltav:mag).
        set evidence["phase"] to phase.
    }
    if POS_LOG_LEVEL < 2 { return. }
    if time:seconds < evidence["next_sample"] { return. }
    local sample_period is 0.02.
    if POS_LOG_LEVEL = 2 { set sample_period to 1. }
    set evidence["next_sample"] to time:seconds+sample_period.
    flight_log_event("maneuver_sample","phase="+phase+"|eta="+maneuver:eta+"|dv="+maneuver:deltav:mag+"|alignment_deg="+vang(ship:facing:vector,maneuver:deltav)+"|throttle="+ship:control:mainthrottle+"|mass="+ship:mass+"|available_thrust="+ship:availablethrust+"|half_burn_s="+half_time+"|apoapsis="+ship:apoapsis+"|periapsis="+ship:periapsis+"|inclination="+ship:orbit:inclination).
}

function flight_log_rcs_observe {
    parameter apsis, target_altitude, evidence.
    if POS_LOG_LEVEL < 2 { return. }
    if time:seconds < evidence["next_sample"] { return. }
    local sample_period is 0.02.
    if POS_LOG_LEVEL = 2 { set sample_period to 1. }
    set evidence["next_sample"] to time:seconds+sample_period.
    local actual is ship:apoapsis.
    if apsis = "periapsis" { set actual to ship:periapsis. }
    flight_log_event("rcs_correction_sample","apsis="+apsis+"|target_m="+target_altitude+"|actual_m="+actual+"|error_m="+(actual-target_altitude)+"|fore="+ship:control:fore+"|mass="+ship:mass).
}
