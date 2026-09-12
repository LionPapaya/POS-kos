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
    aerobrake_gui:show().

    set dapthrottle to 0.
    set dap["dap_mode"] to "auto".
    set dap["str_mode"] to "aoa".
    set dap["aoa"]["base_pitch"] to 0.
    brakes off.

    until not aerobrake_running {
        local requested_bank is max(-120,min(120,aerobrake_bank_slider:value)).
        local requested_aoa is AVES["EGAOA"](SHIP:altitude).
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

        flight_log_tick("aerobrake",aerobrake_phase,"bank_" + round(requested_bank,1)).
        wait 0.
    }

    aerobrake_gui:hide().
    brakes off.
    if handoff_to_pos3 {
        runpath("0:/POS3.ks").
    } else {
        // Release steering and return control to the POS launcher/menu.
        dap:set_off().
    }
}
