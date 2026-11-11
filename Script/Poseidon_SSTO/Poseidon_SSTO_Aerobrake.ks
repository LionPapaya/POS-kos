RUNONCEPATH("0:/Libraries/Poseidon_SSTO/gui_style.ks").
// Poseidon_SSTO/Poseidon_SSTO_Aerobrake.ks
// Hold the AVES entry AoA schedule and a pilot-selected bank through one
// atmospheric pass.  This assistant never deploys the air/wheel brakes.
set CONFIG:IPU to 2000.
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/flight_log.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/control.ks").
RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/lib_math.ks").
RUNONCEPATH("0:/Libraries/lib_aerostr.ks").
RUNONCEPATH("0:/Libraries/lib_aerosim.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/aerobrake.ks").

if not SHIP:BODY:atm:exists {
    clearScreen.
    print "Aerobraking requires a body with an atmosphere.".
} else if SHIP:periapsis >= SHIP:BODY:atm:height {
    clearScreen.
    print "Aerobraking not started.".
    print "Lower periapsis below " + round(SHIP:BODY:atm:height) + " m first.".
    print "Current periapsis: " + round(SHIP:periapsis) + " m.".
} else {
    flight_log_begin("aerobrake").
    flight_log_event("aerobrake_armed","periapsis=" + round(SHIP:periapsis,1) +
        "|apoapsis=" + round(SHIP:apoapsis,1) + "|atmosphere_top=" + round(SHIP:BODY:atm:height,1)).

    // AUTO has no pilot demand to restore. CSS and OFF remain pilot modes.
    dap:setup().
    local return_mode is dap["dap_mode"].
    local return_steering is dap["str_mode"].
    local cancelled is false.
    local prediction_tracker is aerobrake_prediction_tracker().
    local prediction is lex("status","waiting").
    local atmosphere_top is SHIP:BODY:atm:height.
    local aerobrake_running is true.
    local entered_atmosphere is SHIP:altitude < atmosphere_top.
    local handoff_to_pos3 is false.
    local aerobrake_phase is "coast_to_atmosphere".
    if entered_atmosphere {
        set aerobrake_phase to "aerobraking".
        flight_log_event("aerobrake_atmosphere_entry","altitude=" + round(SHIP:altitude,1)).
    }

    global aerobrake_gui is GUI(400).

    pos_gui_window_style(aerobrake_gui,400).
    set aerobrake_gui:style:width to 400.
    set aerobrake_gui:style:hstretch to true.
    local title_box is aerobrake_gui:addhbox().
    local title_label is title_box:addlabel("<size=20><b>AEROBRAKING</b></size>").
    set title_label:style:align to "center".
    local data_box is aerobrake_gui:addvbox().
    global aerobrake_phase_label is data_box:addlabel().
    global aerobrake_altitude_label is data_box:addlabel().
    global aerobrake_apsis_label is data_box:addlabel().
    global aerobrake_aoa_label is data_box:addlabel().
    global aerobrake_bank_label is data_box:addlabel().
    global aerobrake_bank_slider is data_box:addhslider(0,-120,120).
    set aerobrake_bank_slider:style:width to 360.
    local schedule_toggle is data_box:addcheckbox("Use AVES AoA schedule",true).
    local fixed_aoa_label is data_box:addlabel("Fixed AoA (schedule off):").
    local aoa_slider is data_box:addhslider(AVES["EGAOA"](SHIP:altitude),0,60).
    set aoa_slider:style:width to 360.
    local prediction_label is data_box:addlabel("Predicted final Ap: waiting").
    local prediction_note is data_box:addlabel("10 s steps | 2 s solve budget | 20 s refresh").
    local cancel_button is aerobrake_gui:addbutton("Cancel - return to POS").
    set cancel_button:onclick to { set cancelled to true. }.
    aerobrake_gui:show().

    set dapthrottle to 0.
    // setup() attaches aerostr locks even if cached mode already says AoA.
    // Explicitly attach our steering/throttle rather than relying on a change.
    dap:set_aoa_auto().
    set dap["aoa"]["base_pitch"] to 0.
    set dap["aoa"]["base_pitch_override"] to false.
    flight_log_event("aerobrake_control_ready","mode=auto|steering=aoa|bank=0").
    brakes off.

    until not aerobrake_running {
        // Cancellation wins over both control updates and automatic POS3 entry.
        if cancelled {
            set prediction["status"] to "cancelled".
            set aerobrake_phase to "cancelled".
            flight_log_event("aerobrake_cancelled","return_mode="+return_mode).
            break.
        }
        local requested_bank is max(-120,min(120,aerobrake_bank_slider:value)).
        local fixed_aoa is aoa_slider:value.
        local use_schedule is schedule_toggle:pressed.
        local requested_aoa is fixed_aoa.
        if use_schedule { set requested_aoa to AVES["EGAOA"](SHIP:altitude). }
        set dap["aoa"]["target_aoa"] to requested_aoa.
        set dap["aoa"]["target_bank"] to requested_bank.
        set dapthrottle to 0.
        // Reassert this every control tick: neither the assistant nor a stale
        // action-group state may deploy the combined air/wheel brake action.
        brakes off.
        dap:update().

        set aerobrake_phase_label:text to "Phase: " + aerobrake_phase.
        set aerobrake_altitude_label:text to "Altitude / atmosphere: " + round(SHIP:altitude) + " / " + round(atmosphere_top) + " m".
        set aerobrake_apsis_label:text to "Ap / Pe: " + round(SHIP:apoapsis) + " / " + round(SHIP:periapsis) + " m".
        set aerobrake_aoa_label:text to "AoA target / actual: " + round(requested_aoa,1) + " / " + round(calc_aoa(),1) + " deg".
        set fixed_aoa_label:text to "Fixed AoA (schedule off): " + round(fixed_aoa,1) + " deg".
        set aerobrake_bank_label:text to "Bank: " + round(requested_bank,1) + " deg  (-120 to +120)".

        if SHIP:apoapsis < atmosphere_top {
            set handoff_to_pos3 to true.
            set aerobrake_running to false.
            flight_log_event("aerobrake_pos3_handoff","apoapsis=" + round(SHIP:apoapsis,1) +
                "|altitude=" + round(SHIP:altitude,1) + "|bank=" + round(requested_bank,1)).
        } else {
            if not entered_atmosphere and SHIP:altitude < atmosphere_top {
                set entered_atmosphere to true.
                set aerobrake_phase to "aerobraking".
                flight_log_event("aerobrake_atmosphere_entry","altitude=" + round(SHIP:altitude,1) +
                    "|bank=" + round(requested_bank,1)).
            }
            if entered_atmosphere and SHIP:altitude >= atmosphere_top and SHIP:verticalspeed > 0 {
                set aerobrake_phase to "complete".
                set aerobrake_running to false.
                flight_log_event("aerobrake_atmosphere_exit","apoapsis=" + round(SHIP:apoapsis,1) +
                    "|periapsis=" + round(SHIP:periapsis,1) + "|bank=" + round(requested_bank,1)).
            }
        }

        // Keep predictor work behind the real control loop, with one bounded
        // integration step per tick. Input changes invalidate a running solve.
        if aerobrake_running and not cancelled {
            local prediction_due is aerobrake_prediction_due(prediction_tracker,
                requested_bank,fixed_aoa,use_schedule,KUNIVERSE:REALTIME).
            if prediction["status"] <> "waiting" and
                not aerobrake_prediction_matches(prediction,requested_bank,fixed_aoa,use_schedule) {
                set prediction["status"] to "inputs changed (stale)".
            }
            if prediction_due and prediction["status"] <> "running" {
                set prediction to aerobrake_prediction_begin(prediction_tracker,
                    requested_bank,fixed_aoa,use_schedule,KUNIVERSE:REALTIME).
            }
            aerobrake_prediction_step(prediction).
            if prediction["status"] = "complete" {
                set prediction_label:text to "Predicted final Ap: " + round(prediction["apoapsis"]) + " m".
            } else {
                set prediction_label:text to "Predicted final Ap: " + prediction["status"].
            }
        }
        flight_log_tick("aerobrake",aerobrake_phase,"bank_" + round(requested_bank,1)).
        wait 0.
    }

    // Dispose callbacks as well as hiding the panel: no assistant work survives.
    set prediction["status"] to "stopped".
    aerobrake_gui:dispose().
    aerobrake_release().
    if handoff_to_pos3 and not cancelled {
        // Release first, then explicitly give the new program AUTO/AoA.
        // Its first DAP update must attach fresh locks (cached mode is OFF).
        set dap["dap_mode"] to "auto".
        set dap["str_mode"] to "aoa".
        runpath("0:/POS3.ks").
    } else {
        set dap["str_mode"] to return_steering.
        if return_mode = "css" { dap:set_css(). }
        // Keep the launcher selector consistent; AUTO cannot retain our targets.
        if defined main_dap_mode_menu {
            if return_mode = "css" {
                set main_dap_mode_menu:index to 1.
            } else {
                set main_dap_mode_menu:index to 2.
            }
        }
        // Fall through to the caller; POS.ks resumes its menu and DAP service.
    }
}
