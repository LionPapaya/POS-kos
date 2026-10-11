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
// Version 22 adds below-glide-slope turn pitch and fast-turn diagnostics.
// Version 25 adds entry recovery clocks and completed-solve timing.
// Version 26 adds final descent recovery, mass speed scaling and fuel dump floors.
global POS_LOG_SCHEMA_VERSION is 26.
global POS_LOG_ENTRY_BASIC_UT is -1.
global POS_LOG_ENTRY_SOLVER_DURATION is 0.
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
global POS_LOG_ENTRY_TARGET_RECORDED is false.
global POS_LOG_LAST_ENVELOPE_STATE is "".
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
        "terminal_energy_turn_extra_distance,terminal_energy_turn_reserve,"+
        "terminal_turn_pitch_limit_active,terminal_turn_pitch_raw_bias,"+
        "terminal_turn_pitch_gs_altitude,terminal_turn_pitch_bank,terminal_fast_turn_active,"+
        "terminal_turn_model_mode,terminal_turn_model_rate,terminal_turn_model_radius,"+
        "terminal_turn_model_loss,terminal_turn_model_required_radius,"+
        "terminal_turn_sample_age,terminal_turn_sample_altitude,"+
        "terminal_turn_sample_speed,terminal_turn_sample_pending,"+
        "terminal_descent_recovery_active,terminal_descent_recovery_elapsed,"+
        "terminal_descent_tracking_error,terminal_recovery_throttle_floor,"+
        "terminal_mass_speed_scale,terminal_dump_lf_floor,terminal_dump_ox_floor,terminal_fuel_dump_active".
}

function flight_log_terminal_energy_columns {
    if not(defined terminal_route_debug) {
        return ",0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,-1,0,0,-1,0,0,0,0,1,0,0,0".
    }
    local turn_pitch_active is 0.
    if terminal_route_debug["turn_pitch_limit_active"] { set turn_pitch_active to 1. }
    local fast_turn_active is 0.
    if terminal_route_debug["fast_turn_active"] { set fast_turn_active to 1. }
    local descent_recovery_active is 0.
    if terminal_route_debug["descent_recovery_active"] { set descent_recovery_active to 1. }
    local fuel_dump_active is 0.
    if terminal_route_debug["fuel_dump_active"] { set fuel_dump_active to 1. }
    return ","+terminal_route_debug["energy_capture"]+","+terminal_route_debug["energy_drag_work"]+","+
        terminal_route_debug["energy_turn_work"]+","+terminal_route_debug["energy_reserve"]+","+
        terminal_route_debug["energy_clean_loss"]+","+terminal_route_debug["energy_margin_rate"]+","+
        terminal_route_debug["energy_brake_margin"]+","+
        terminal_route_debug["energy_turn_extra_distance"]+","+terminal_route_debug["energy_turn_reserve"]+","+
        turn_pitch_active+","+terminal_route_debug["turn_pitch_raw_bias"]+","+
        terminal_route_debug["turn_pitch_gs_altitude"]+","+terminal_route_debug["turn_pitch_bank"]+","+
        fast_turn_active+","+terminal_route_debug["turn_model_mode"]+","+
        terminal_route_debug["turn_model_rate"]+","+terminal_route_debug["turn_model_radius"]+","+
        terminal_route_debug["turn_model_loss"]+","+terminal_route_debug["turn_model_required_radius"]+","+
        terminal_route_debug["turn_sample_age"]+","+terminal_route_debug["turn_sample_altitude"]+","+
        terminal_route_debug["turn_sample_speed"]+","+terminal_route_debug["turn_sample_pending"]+","+
        descent_recovery_active+","+terminal_route_debug["descent_recovery_elapsed"]+","+
        terminal_route_debug["descent_tracking_error"]+","+terminal_route_debug["recovery_throttle_floor"]+","+
        terminal_route_debug["mass_speed_scale"]+","+terminal_route_debug["dump_lf_floor"]+","+
        terminal_route_debug["dump_ox_floor"]+","+fuel_dump_active.
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
    log "schema,session,ut,mission_time,sample,program,body,step,substep,dap_mode,steering_mode,vessel_status,rapier_mode,rapiers_active,nervs_active,wheel_brakes,rcs_actual,sas_actual,latitude,longitude,altitude,radar_altitude,airspeed,surface_speed,vertical_speed,surface_velocity_x,surface_velocity_y,surface_velocity_z,acceleration_x,acceleration_y,acceleration_z,pitch,heading,roll,facing_x,facing_y,facing_z,mass,thrust,dynamic_pressure,mach,throttle_command,throttle_actual,aoa_actual,aoa_target,bank_target,smooth_aoa,smooth_bank,base_pitch,aerostr_target_pitch,aerostr_target_roll,aerostr_turn_pitch,aerostr_turn_heading,envelope_state,envelope_regime,envelope_max_aoa,envelope_max_bank,envelope_min_throttle,envelope_rcs_assist,gpws_state,gpws_worst_clearance,gpws_required_clearance,gpws_clearance_margin,gpws_clear_timer,gpws_next_scan_ut,gpws_pullup_active,terminal_phase,terminal_profile_region,terminal_profile_altitude,terminal_profile_gradient,terminal_profile_error,terminal_profile_feedforward_vs,terminal_side,terminal_hold_laps,terminal_target_distance,terminal_remaining_distance,terminal_target_altitude,terminal_along_track,terminal_cross_track,terminal_energy_margin,terminal_target_energy,terminal_runway_heading_error,terminal_target_vs,landing_target_vs,landing_flare_fraction,terminal_pitch_bias,terminal_target_aoa,terminal_throttle,terminal_airbrake,terminal_gear,terminal_landing_stable,terminal_go_around_reason,terminal_pid_output,target_latitude,target_longitude,target_altitude,entry_reference_latitude,entry_reference_longitude,entry_reference_altitude,entry_reference_speed,entry_energy_reference,entry_energy_actual,entry_energy_error,entry_heading_error,entry_bank_command,entry_time_to_interface,entry_turn_side,entry_lift_to_drag,entry_segment_start_time,entry_segment_end_time,entry_segment_fraction,entry_segment_cross_track,runway_start_latitude,runway_start_longitude,runway_end_latitude,runway_end_longitude,runway_heading,runway_altitude,dap_dt,aerostr_target_direction,aerostr_turn_roll,aerostr_distance_pitch,aerostr_pitch,aerostr_roll,aerostr_heading,aoa_pitch_command,aoa_yaw_command,aoa_roll_command,css_pitch_output,css_yaw_output,css_roll_output,css_last_roll,css_last_aoa,envelope_last_aoa,envelope_last_speed,envelope_last_pitch_error,envelope_pitchdown_timer,envelope_authority_timer,envelope_upset_timer,envelope_stable_timer,envelope_restore_steering,vacuum_phase,vacuum_target_latitude,vacuum_target_longitude,vacuum_target_altitude,vacuum_target_distance,vacuum_surface_clearance,vacuum_surface_speed,vacuum_target_vertical_speed,vacuum_throttle,vacuum_stopping_distance,vacuum_available_acceleration,vacuum_tail_contact,vacuum_gear_pitch_target" + flight_log_vacuum_ascent_header() + flight_log_pdi_header() + flight_log_rendezvous_header() + flight_log_entry_predictive_header() + flight_log_terminal_energy_header() + flight_log_entry_recovery_header() to POS_LOG_FLIGHT_FILE.
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
    set POS_LOG_ENTRY_BASIC_UT to -1.
    set POS_LOG_ENTRY_SOLVER_DURATION to 0.
    if POS_LOG_LEVEL = 0 { return. }
    flight_log_choose_files().
    set POS_LOG_RUNWAY to lex(
        "location","unknown","number","unknown","start_lat",0,"start_lng",0,
        "end_lat",0,"end_lng",0,"heading",0,"altitude",0
    ).
    set POS_LOG_TARGET to lex("lat",0,"lng",0,"altitude",0).
    set POS_LOG_ENTRY_TARGET_RECORDED to false.
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
    set POS_LOG_LAST_ENVELOPE_STATE to "".
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

// Recovery state is sampled only at the logger's existing medium/high cadence.
// Low mode records one decision event per basic update or completed solve.
function flight_log_entry_recovery_header {
    return ",entry_recovery_mode,entry_target_converged,entry_solver_retry_ut,"+
        "entry_basic_update_ut,entry_solver_duration,entry_basic_update_age,entry_rejected_candidates".
}

function flight_log_entry_recovery_columns {
    local recovery_mode is "inactive".
    local target_converged is false.
    local retry_ut is -1.
    local basic_ut is -1.
    local rejected_count is 0.
    if POS_LOG_PROGRAM = "reentry" {
        set recovery_mode to "planning".
        if defined basice_reentry_guidance {
            if basice_reentry_guidance { set recovery_mode to "basic". }
            else if defined entry_traj { set recovery_mode to "predictive". }
        }
        if defined val_tgt { set target_converged to val_tgt. }
        if defined entry_solver_next_retry_time { set retry_ut to entry_solver_next_retry_time. }
        if defined entry_basic_next_update { set basic_ut to entry_basic_next_update. }
        if defined entry_rejected_runways { set rejected_count to entry_rejected_runways:keys:length. }
    }
    local basic_age is -1.
    if POS_LOG_ENTRY_BASIC_UT >= 0 { set basic_age to time:seconds-POS_LOG_ENTRY_BASIC_UT. }
    return ","+recovery_mode+","+target_converged+","+retry_ut+","+basic_ut+","+
        POS_LOG_ENTRY_SOLVER_DURATION+","+basic_age+","+rejected_count.
}

function flight_log_entry_recovery {
    parameter recovery_phase, solve_duration.
    if POS_LOG_LEVEL < 1 { return. }
    if recovery_phase = "basic_update" { set POS_LOG_ENTRY_BASIC_UT to time:seconds. }
    if recovery_phase = "solver_complete" { set POS_LOG_ENTRY_SOLVER_DURATION to solve_duration. }
    flight_log_event("entry_recovery_update","phase="+recovery_phase+
        "|runway="+Location+"_"+runway_nr+"|solver_duration="+round(solve_duration,2)+
        "|aoa="+round(dap["aoa"]["target_aoa"],2)+
        "|bank="+round(dap["aoa"]["target_bank"],2)).
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
    local target_changed is POS_LOG_TARGET["lat"] <> team_interface["target_latlng"]:lat or
        POS_LOG_TARGET["lng"] <> team_interface["target_latlng"]:lng or
        POS_LOG_TARGET["altitude"] <> team_interface["target_altitude"].
    if POS_LOG_ENTRY_TARGET_RECORDED and not target_changed { return. }
    set POS_LOG_TARGET["lat"] to team_interface["target_latlng"]:lat.
    set POS_LOG_TARGET["lng"] to team_interface["target_latlng"]:lng.
    set POS_LOG_TARGET["altitude"] to team_interface["target_altitude"].
    set POS_LOG_ENTRY_TARGET_RECORDED to true.
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

// Record the compact V/SIT path result once per ordinary two-bank prediction
// update. This observer runs after sim_with_bank returns and is never called
// from a trajectory simulation.
function flight_log_entry_display_path {
    parameter path_result.
    parameter lower_bank.
    parameter upper_bank.
    parameter selected_bank.
    if POS_LOG_LEVEL < 1 { return. }
    local detail is "valid="+path_result["valid"]+"|reason="+path_result["reason"]+
        "|points="+path_result["points"]:length+"|lower_bank="+round(lower_bank,3)+
        "|upper_bank="+round(upper_bank,3)+"|selected_bank="+round(selected_bank,3).
    if path_result["valid"] {
        set detail to detail+"|weight="+round(path_result["weight"],4)+
            "|energy_min="+round(path_result["energy_min"],1)+
            "|energy_max="+round(path_result["energy_max"],1).
    }
    flight_log_event("entry_display_path",detail).
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
    log POS_LOG_SCHEMA_VERSION + "," + POS_LOG_SESSION + "," + time:seconds + "," + missiontime + "," + POS_LOG_SAMPLE_INDEX + "," + program_name + "," + ship:body:name + "," + current_step + "," + current_substep + "," + dap["dap_mode"] + "," + dap["str_mode"] + "," + ship:status + "," + rapier_mode + "," + rapiers + "," + nervs + "," + brakes + "," + RCS + "," + SAS + "," + ship:geoposition:lat + "," + ship:geoposition:lng + "," + ship:altitude + "," + alt:radar + "," + ship:airspeed + "," + surface_velocity:mag + "," + ship:verticalspeed + "," + surface_velocity:x + "," + surface_velocity:y + "," + surface_velocity:z + "," + acceleration:x + "," + acceleration:y + "," + acceleration:z + "," + pitch_for() + "," + compass_for() + "," + roll_for() + "," + facing_vec:x + "," + facing_vec:y + "," + facing_vec:z + "," + ship:mass + "," + ship:thrust + "," + ship:q + "," + ADDONS:FAR:mach + "," + dapthrottle + "," + throttle + "," + calc_aoa() + "," + dap["aoa"]["target_aoa"] + "," + dap["aoa"]["target_bank"] + "," + dap["aoa"]["smooth_target_aoa"] + "," + dap["aoa"]["smooth_target_bank"] + "," + dap["aoa"]["base_pitch"] + "," + dap["aerostr"]["targetPitch"] + "," + dap["aerostr"]["targetRoll"] + "," + dap["aerostr"]["turn_pitch"] + "," + dap["aerostr"]["turn_heading"] + "," + envelope["state"] + "," + envelope["regime"] + "," + envelope["max_aoa"] + "," + envelope["max_bank"] + "," + envelope["min_throttle"] + "," + envelope["rcs_assist"] + "," + envelope["terrain_state"] + "," + envelope["terrain_worst_clearance"] + "," + envelope["terrain_required_clearance"] + "," + gpws_clearance_margin + "," + envelope["terrain_clear_timer"] + "," + envelope["terrain_next_scan"] + "," + gpws_pullup_active + "," + terminal_phase + "," + terminal_profile_region + "," + terminal_profile_altitude + "," + terminal_profile_gradient + "," + terminal_profile_error + "," + terminal_profile_feedforward_vs + "," + terminal_side + "," + terminal_hold_laps + "," + terminal_target_distance + "," + terminal_remaining_distance + "," + terminal_target_altitude + "," + terminal_along_track + "," + terminal_cross_track + "," + terminal_energy_margin + "," + terminal_target_energy + "," + terminal_runway_heading_error + "," + terminal_target_vs + "," + landing_target_vs + "," + landing_flare_fraction + "," + terminal_pitch_bias + "," + terminal_target_aoa + "," + terminal_throttle + "," + terminal_airbrake + "," + terminal_gear + "," + terminal_landing_stable + "," + terminal_go_around_reason + "," + terminal_pid_output + "," + POS_LOG_TARGET["lat"] + "," + POS_LOG_TARGET["lng"] + "," + POS_LOG_TARGET["altitude"] + "," + POS_LOG_ENTRY["reference_lat"] + "," + POS_LOG_ENTRY["reference_lng"] + "," + POS_LOG_ENTRY["reference_altitude"] + "," + POS_LOG_ENTRY["reference_speed"] + "," + POS_LOG_ENTRY["energy_reference"] + "," + POS_LOG_ENTRY["energy_actual"] + "," + POS_LOG_ENTRY["energy_error"] + "," + POS_LOG_ENTRY["heading_error"] + "," + POS_LOG_ENTRY["bank_command"] + "," + POS_LOG_ENTRY["time_to_interface"] + "," + POS_LOG_ENTRY["turn_side"] + "," + POS_LOG_ENTRY["lift_to_drag"] + "," + POS_LOG_ENTRY["segment_start_time"] + "," + POS_LOG_ENTRY["segment_end_time"] + "," + POS_LOG_ENTRY["segment_fraction"] + "," + POS_LOG_ENTRY["segment_cross_track"] + "," + POS_LOG_RUNWAY["start_lat"] + "," + POS_LOG_RUNWAY["start_lng"] + "," + POS_LOG_RUNWAY["end_lat"] + "," + POS_LOG_RUNWAY["end_lng"] + "," + POS_LOG_RUNWAY["heading"] + "," + POS_LOG_RUNWAY["altitude"] + "," + dap["dt"] + "," + dap["aerostr"]["targetDirection"] + "," + dap["aerostr"]["turn_roll"] + "," + dap["aerostr"]["distance_pitch"] + "," + dap["aerostr"]["aerostr_pitch"] + "," + dap["aerostr"]["aerostr_roll"] + "," + dap["aerostr"]["aerostr_heading"] + "," + dap["aoa"]["aoa_pitch"] + "," + dap["aoa"]["aoa_yaw"] + "," + dap["aoa"]["aoa_roll"] + "," + dap["css"]["pitch_out"] + "," + dap["css"]["yaw_out"] + "," + dap["css"]["roll_out"] + "," + dap["css"]["last_roll"] + "," + dap["css"]["last_aoa"] + "," + envelope["last_aoa"] + "," + envelope["last_speed"] + "," + envelope["last_pitch_error"] + "," + envelope["pitchdown_timer"] + "," + envelope["authority_timer"] + "," + envelope["upset_timer"] + "," + envelope["stable_timer"] + "," + envelope["restore_steering"] + "," + vacuum_phase + "," + vacuum_target_latitude + "," + vacuum_target_longitude + "," + vacuum_target_altitude + "," + vacuum_target_distance + "," + vacuum_surface_clearance + "," + vacuum_surface_speed + "," + vacuum_target_vertical_speed + "," + vacuum_throttle + "," + vacuum_stopping_distance + "," + vacuum_available_acceleration + "," + vacuum_tail_contact + "," + vacuum_gear_pitch_target + "," + vacuum_ascent_phase + "," + vacuum_ascent_target_altitude + "," + vacuum_ascent_target_inclination + "," + vacuum_ascent_launch_heading + "," + vacuum_ascent_surface_clearance + "," + vacuum_ascent_vertical_speed + "," + vacuum_ascent_horizontal_speed + "," + vacuum_ascent_target_pitch + "," + vacuum_ascent_attitude_error + "," + vacuum_ascent_nerv_twr + "," + vacuum_ascent_rapier_kick_active + "," + vacuum_ascent_predicted_apoapsis + "," + vacuum_ascent_predicted_periapsis + "," + vacuum_ascent_node_dv + "," + vacuum_ascent_node_eta + flight_log_pdi_columns() + flight_log_rendezvous_columns() + flight_log_entry_predictive_columns() + flight_log_terminal_energy_columns() + flight_log_entry_recovery_columns() to POS_LOG_FLIGHT_FILE.
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
    if POS_LOG_LAST_ENVELOPE_STATE <> dap["envelope"]["state"] {
        set POS_LOG_LAST_ENVELOPE_STATE to dap["envelope"]["state"].
        flight_log_event("envelope_state","value="+POS_LOG_LAST_ENVELOPE_STATE+
            "|regime="+dap["envelope"]["regime"]+"|aoa="+round(calc_aoa(),2)+
            "|bank="+round(roll_for(),2)+"|pitch="+round(pitch_for(),2)+
            "|altitude="+round(ship:altitude,1)).
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
    if defined abort_state and abort_state:haskey("managed") and abort_state["managed"] {
        flight_log_recovery_sample(abort_state).
    }
    if defined abort_state and abort_state:haskey("active") and abort_state["active"] and
       abort_state["mode"] = "contingency_abort" {
        flight_log_contingency_sample(abort_state).
    }
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

// Takeoff evidence uses events.csv without changing the flight.csv schema.
// Low: predictions and transitions. Medium: 1 Hz. High: each physics tick.
// Called only from the real ascent executive, never aerodynamic predictors.
function flight_log_takeoff_prediction {
    parameter estimate, prediction_phase.
    if POS_LOG_LEVEL = 0 { return. }
    flight_log_event("takeoff_prediction","phase="+prediction_phase+
        "|reason="+estimate["reason"]+"|model_valid="+estimate["model_valid"]+
        "|sufficient="+estimate["sufficient"]+"|mass_t="+estimate["mass_t"]+
        "|nominal_propulsion_assumed="+estimate["nominal_propulsion_assumed"]+
        "|rotate_mps="+AVES["Speed"]["Rotate"]+"|liftoff_mps="+estimate["liftoff_speed_mps"]+
        "|rotation_m="+estimate["rotation_distance_m"]+"|liftoff_m="+estimate["liftoff_distance_m"]+
        "|climb_m="+estimate["climb_distance_m"]+"|screen_height_m="+estimate["screen_height_m"]+
        "|required_m="+estimate["required_runway_m"]+"|required_departure_m="+estimate["required_departure_m"]+
        "|departure_status="+estimate["departure_status"]+"|departure_evidence="+estimate["departure_evidence"]+
        "|liftoff_fits="+estimate["liftoff_fits"]+"|screen_fits="+estimate["screen_fits"]+
        "|estimated_feasible="+estimate["estimated_feasible"]+"|screen_beyond_runway_m="+estimate["screen_beyond_runway_m"]+
        "|remaining_m="+estimate["remaining_runway_m"]+
        "|margin_m="+estimate["runway_margin_m"]+"|distance_margin_fraction="+estimate["distance_margin_fraction"]+
        "|reference_stop_at_rotation_m="+estimate["reference_stop_at_rotation_m"]+
        "|stop_reference_valid="+estimate["stop_reference_valid"]).
}

function flight_log_takeoff_observe {
    parameter evidence, estimate, roll_start_position, release_ut, ascent_phase.
    if POS_LOG_LEVEL = 0 { return. }
    local transition is "".
    if not evidence["released"] {
        set evidence["released"] to true.
        set transition to "brake_release".
    } else if not evidence["rotated"] and ascent_phase = "rotate" {
        set evidence["rotated"] to true.
        set transition to "rotation".
    } else if not evidence["airborne"] and ship:status = "FLYING" and ship:verticalspeed > 0.3 {
        set evidence["airborne"] to true.
        set transition to "liftoff".
    } else if evidence["airborne"] and ship:altitude - evidence["base_altitude_m"] >= estimate["screen_height_m"] {
        set evidence["screen_reached"] to true.
        set transition to "screen_height".
    }
    local sample_due is POS_LOG_LEVEL >= 2 and time:seconds >= evidence["next_sample"].
    if transition = "" and not sample_due { return. }
    local detail is "phase="+ascent_phase+"|elapsed_s="+(time:seconds-release_ut)+
        "|roll_m="+calcdistance_m(roll_start_position,ship:geoposition)+
        "|speed_mps="+ship:airspeed+"|vs_mps="+ship:verticalspeed+
        "|height_m="+(ship:altitude-evidence["base_altitude_m"])+
        "|pitch_deg="+pitch_for()+"|mass_t="+ship:mass+"|thrust_kn="+ship:thrust+
        "|status="+ship:status+"|predicted_liftoff_m="+estimate["liftoff_distance_m"]+
        "|predicted_required_m="+estimate["required_runway_m"]+
        "|predicted_departure_m="+estimate["required_departure_m"]+
        "|departure_status="+estimate["departure_status"]+"|departure_evidence="+estimate["departure_evidence"].
    if transition <> "" { flight_log_event("takeoff_"+transition,detail). }
    if sample_due {
        set evidence["next_sample"] to time:seconds+0.02.
        if POS_LOG_LEVEL = 2 { set evidence["next_sample"] to time:seconds+1. }
        flight_log_event("takeoff_sample",detail).
    }
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

// Called only behind flight_log_tick's existing medium/high cadence gate.
// No terrain queries or predictions: observe the executive's cached decision.
function flight_log_contingency_sample {
    parameter state.
    local detail is "phase="+state["phase"]+"|altitude="+ship:altitude+
        "|speed="+ship:airspeed+"|vs="+ship:verticalspeed+
        "|mass="+ship:mass+"|lf="+ship:liquidfuel+"|ox="+ship:oxidizer+
        "|rapiers_out="+state["scenario"]["rapiers_out"]+
        "|nervs_out="+state["scenario"]["nervs_out"]+
        "|throttle="+ship:control:mainthrottle+
        "|gpws="+dap["envelope"]["terrain_state"]+
        "|bottom_height="+ship:bounds:bottomalt+"|bank="+roll_for().
    if state:haskey("recovery_reason") {
        set detail to detail+"|recovery_reason="+state["recovery_reason"].
    }
    if state:haskey("released_lf_reserve") {
        set detail to detail+"|released_lf_reserve="+state["released_lf_reserve"].
    }
    if state:haskey("emergency_aoa") {
        set detail to detail+"|emergency_aoa="+state["emergency_aoa"].
        if state:haskey("emergency_desired_vs") {
            set detail to detail+"|emergency_desired_vs="+state["emergency_desired_vs"]+
                "|emergency_bottom_clearance="+state["emergency_bottom_clearance"].
        }
        set detail to detail+"|emergency_replan_ut="+state["emergency_replan_ut"].
    }
    if state["target"]["selected"] {
        set detail to detail+"|kind="+state["target"]["kind"]+
            "|range="+state["target"]["distance_m"]+"|energy_margin="+state["target"]["margin"].
        if state["target"]:haskey("emergency") {
            set detail to detail+"|emergency="+state["target"]["emergency"]+
                "|risk_score="+state["target"]["score"]+"|relief="+state["target"]["relief"]+
                "|ridge="+state["target"]["ridge"]+"|water_fraction="+state["target"]["water_fraction"].
        }
    }
    if state:haskey("nerv_power") {
        set detail to detail+"|nerv_available_thrust_kn="+state["nerv_power"]["thrust_kn"]+
            "|nerv_acceleration="+state["nerv_power"]["acceleration"]+
            "|nerv_isp="+state["nerv_power"]["isp"]+"|nerv_dv="+state["nerv_power"]["dv"]+
            "|nerv_vacuum_dv="+state["nerv_power"]["vacuum_dv"]+
            "|lf_reserve="+state["lf_reserve"]+"|assist_height="+state["assist_height"]+
            "|apoapsis="+ship:apoapsis+"|periapsis="+ship:periapsis.
        if state["target"]["selected"] and state["target"]:haskey("unpowered_margin") {
            set detail to detail+"|unpowered_margin="+state["target"]["unpowered_margin"].
        }
        if state["entry_target"]["selected"] {
            set detail to detail+"|entry_range="+state["entry_target"]["distance_m"]+
                "|entry_margin="+state["entry_target"]["margin"].
        }
        if state:haskey("orbit_budget") {
            set detail to detail+"|orbit_required_dv="+state["orbit_budget"]["required_dv"]+
                "|orbit_dv_margin="+state["orbit_budget"]["margin"].
        }
        if state:haskey("orbit_pitch") { set detail to detail+"|orbit_pitch="+state["orbit_pitch"]. }
        if state:haskey("orbit_alignment") { set detail to detail+"|orbit_alignment="+state["orbit_alignment"]. }
    }
    if state:haskey("ditch_aoa") {
        set detail to detail+"|ditch_aoa="+state["ditch_aoa"]+"|bottom_height="+ship:bounds:bottomalt.
    }
    flight_log_event("contingency_sample",detail).
}

// Passive RTLS evidence. Low records state transitions; medium samples at
// 1 Hz and high once per control tick. Never called from a predictor.
function flight_log_rtls_observe {
    parameter state, evidence.
    if POS_LOG_LEVEL = 0 { return. }
    if evidence["phase"] <> state["phase"] or evidence["active"] <> state["active"] {
        flight_log_event("rtls_phase","from="+evidence["phase"]+"|to="+state["phase"]+
            "|source_step="+state["source_step"]+"|submode="+state["submode"]+
            "|active="+state["active"]+"|success="+state["result"]["success"]+
            "|reason="+state["result"]["reason"]).
        set evidence["phase"] to state["phase"].
        set evidence["active"] to state["active"].
    }
    if POS_LOG_LEVEL < 2 or not state["active"] { return. }
    if POS_LOG_LEVEL = 2 and time:seconds < evidence["next_sample"] { return. }
    if POS_LOG_LEVEL = 2 { set evidence["next_sample"] to time:seconds+1. }
    flight_log_event("rtls_sample","phase="+state["phase"]+"|source_step="+state["source_step"]+
        "|submode="+state["submode"]+"|rapiers_out="+state["scenario"]["rapiers_out"]+
        "|nervs_out="+state["scenario"]["nervs_out"]+"|altitude="+ship:altitude+
        "|speed="+ship:airspeed+"|vs="+ship:verticalspeed+"|mass="+ship:mass+
        "|lf="+ship:liquidfuel+"|ox="+ship:oxidizer+"|throttle_command="+dapthrottle+
        "|throttle_actual="+ship:control:mainthrottle+"|heading="+compass_for_prograde()+
        "|bank_target="+dap["aoa"]["target_bank"]+"|aoa_target="+dap["aoa"]["target_aoa"]+
        "|location="+state["target"]["location"]+"|runway="+state["target"]["runway_num"]+
        "|handoff_started="+state["handoff"]["started"]).
}

// Cached executive fields only. This helper does not query parts, terrain,
// aerodynamic addons or predictors; the caller owns the sample cadence.
function flight_log_recovery_fields {
    parameter cached, prefix, names.
    local detail is "".
    for field_name in names {
        if cached:haskey(field_name) {
            set detail to detail+"|"+prefix+field_name+"="+cached[field_name].
        }
    }
    return detail.
}

function flight_log_recovery_sample {
    parameter state.
    if POS_LOG_LEVEL < 2 { return. }
    local detail is "mode="+state["mode"]+"|phase="+state["phase"]+
        "|source_step="+state["source_step"]+"|active="+state["active"]+
        "|lf="+ship:liquidfuel+"|ox="+ship:oxidizer+
        "|altitude="+ship:altitude+"|speed="+ship:airspeed+"|vs="+ship:verticalspeed+
        "|apoapsis="+ship:apoapsis+"|periapsis="+ship:periapsis+
        "|thrust="+ship:thrust+"|throttle_command="+dapthrottle+
        "|throttle_actual="+ship:control:mainthrottle+
        "|aoa_command="+dap["aoa"]["target_aoa"]+"|bank_command="+dap["aoa"]["target_bank"].
    set detail to detail+flight_log_recovery_fields(state,"",list(
        "current_step","ascent_phase","current_ascent_phase","nominal_cutoff","lf_reserve","ox_reserve",
        "orbit_attempted","orbit_abandoned","suppress_orbit","committed",
        "assist_acceleration","alignment","orbit_alignment","orbit_pitch","burn_started","burn_deadline",
        "return_burn_started","return_burn_deadline","capture_gate_since",
        "burn_seconds","burn_started_ut","return_started_ut","orbit_started_ut","escape_pitch",
        "energy_height","energy_margin","progress_speed","progress_climb","pitch","entry_verified",
        "aed_intent","aed_energy","aed_energy_margin","aed_distance","aed_heading_error",
        "aed_assist_time","aed_assist_dv","aed_assist_lf","aed_assist_ox",
        "aed_capture_since","aed_committed","aed_powered","aed_candidate","aed_search_cycles",
        "aed_turn_distance","aed_turn_ready","aed_deadline_logged","aed_desired_vs","aed_airbrake",
        "aed_capture_valid","aed_capture_reason","aed_propulsion_mode","aed_power_retry_until",
        "aed_air_retry_after","aed_bank_limit","aed_steep_bank","aed_runway_distance",
        "aed_terminal_required","aed_capture_height" )).
    if state:haskey("aed_search") {
        set detail to detail+flight_log_recovery_fields(state["aed_search"],"aed_search_",list(
            "index","family","started","complete","reason" )).
    }
    for cache_name in list("power","nerv_power","orbit_budget","ato_budget","edr_budget","budget","aed","capture","gates","orbit_prediction","return_plan") {
        if state:haskey(cache_name) {
            set detail to detail+flight_log_recovery_fields(state[cache_name],cache_name+"_",list(
                "thrust","thrust_kn","acceleration","dv","mass_flow","lf_flow","ox_flow",
                "healthy_rapiers","healthy_nervs","burn_time","isp","vacuum_isp",
                "required_dv","margin","possible","reason","predicted_apoapsis","predicted_periapsis",
                "apoapsis","periapsis","duration","elapsed","time_to_entry","time_to_apoapsis",
                "energy_height","energy_margin","position","heading","altitude","speed","sink",
                "capture_altitude","capture_speed","capture_distance","stable_since","valid",
                "predicted_ap","predicted_pe","burn_seconds","pitch","window_ut","entry_speed",
                "entry_slope","footprint","vacuum_dv","vacuum_thrust" )).
        }
    }
    if state:haskey("target") {
        set detail to detail+flight_log_recovery_fields(state["target"],"target_",list(
            "selected","location","runway_num","heading","altitude","distance_m","margin","reason","provisional" )).
        if state["target"]:haskey("capture_interface") {
            set detail to detail+flight_log_recovery_fields(state["target"]["capture_interface"],"target_capture_",list(
                "target_altitude","target_speed","altitude_tolerance","speed_tolerance","heading_tolerance" )).
        }
        if state["target"]:haskey("screen") {
            set detail to detail+flight_log_recovery_fields(state["target"]["screen"],"target_screen_",list(
                "energy_margin","shortage_margin","excess_margin","turn_cost","range_margin","possible","reason" )).
        }
    }
    if state:haskey("capture_interface") {
        set detail to detail+flight_log_recovery_fields(state["capture_interface"],"capture_",list(
            "target_altitude","target_speed","altitude_tolerance","speed_tolerance","heading_tolerance" )).
    }
    if state:haskey("result") {
        set detail to detail+flight_log_recovery_fields(state["result"],"outcome_",list("success","reason" )).
    }
    if state:haskey("engines") {
        for family_name in list("rapier","nerv") {
            if state["engines"]:haskey(family_name) {
                local family is state["engines"][family_name].
                set detail to detail+flight_log_recovery_fields(family,family_name+"_",list("installed","working","failed" )).
                if family:haskey("failed_ids") {
                    for failed_id in family["failed_ids"]:keys {
                        set detail to detail+"|failed_"+family_name+"_"+failed_id+"=true".
                    }
                }
            }
        }
    }
    if defined recovery_engines {
        for engine_id in recovery_engines:keys {
            set detail to detail+flight_log_recovery_fields(recovery_engines[engine_id],"engine_"+engine_id+"_",list(
                "kind","failed","isolated","desired","original_limit","limit","side" )).
        }
    }
    flight_log_event("recovery_sample",detail).
}
