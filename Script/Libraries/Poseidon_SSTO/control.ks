

global dap is lex().
if not (dap:haskey("setup_done")) {
    dap:add("setup_done", false).
}
if not (dap:haskey("setup")) {
    dap:add("setup", {
    // Add variables to the lexicon
    if not (dap:haskey("aerostr")) {
        local aero_str is lexicon().
        aero_str:add("targetPitch", 0).
        aero_str:add("targetRoll", 0).
        aero_str:add("targetDirection", 90).
        aero_str:add("turn_pitch", 0).
        aero_str:add("turn_heading", 90).
        aero_str:add("turn_roll", 0).
        aero_str:add("distance_pitch", 0).
        aero_str:add("aerostr_pitch", 0).
        aero_str:add("aerostr_roll", 0).
        aero_str:add("aerostr_heading", 90).
        dap:add("aerostr", aero_str).
    }

    if not (dap:haskey("aoa")) {
        local aoa_str is lexicon().
        aoa_str:add("aoa_pitch", 0).
        aoa_str:add("aoa_yaw", 90).
        aoa_str:add("aoa_roll", 0).
        aoa_str:add("target_aoa", 0).
        aoa_str:add("target_bank", 0).
        aoa_str:add("smooth_target_aoa", 0).
        aoa_str:add("smooth_target_bank", 0).
        aoa_str:add("base_pitch", 0).
        dap:add("aoa", aoa_str).
    }

    if not (dap:haskey("css")) {
        local css is lexicon().
        css:add("pitch_out", 0).
        css:add("yaw_out", 90).
        css:add("roll_out", 0).
        css:add("pitch_aoa_spd", 0.5).
        css:add("roll_aoa_spd", 1).
        css:add("pitch_aerostr_spd", 1).
        css:add("yaw_aerostr_spd", 0.8).
        css:add("roll_aerostr_spd", 0.7).
        css:add("last_roll",0).
        css:add("last_aoa",0).
        dap:add("css", css).
        
    }

    if not (dap:haskey("dap_mode")) {
        dap:add("dap_mode", "auto").
    }

    if not (dap:haskey("str_mode")) {
        dap:add("str_mode", "aerostr").
    }

    if not (dap:haskey("dap_mode_set")) {
        dap:add("dap_mode_set", lex("str_mode", "aerostr", "dapmode", "auto")).
    }

    if not (dap:haskey("l_t")) {
        dap:add("l_t",time:seconds).
    }
        if not (dap:haskey("dt")) {
        dap:add("dt",0.1).
    }
    set steeringmanager:pitchtorquefactor to 1.
    set steeringmanager:yawtorquefactor to 1.
    set steeringmanager:rollcontrolanglerange to 100.
    steeringManager:resetpids().
    
    lock dap_steering to heading(dap["aerostr"]["targetDirection"], dap["aerostr"]["targetPitch"], dap["aerostr"]["targetRoll"]).
    lock steering to dap_steering.
    lock throttle to dapthrottle.

    set dap["setup_done"] to true.
}).
}
if not (dap:haskey("update")) {
    dap:add("update", {
    if not dap["setup_done"]{
        setup_dap().
    }
    set dap["dt"] to time:seconds - dap["l_t"].
    set dap["l_t"] to time:seconds.
    if not(dap["dap_mode_set"]["dapmode"] = dap["dap_mode"] and dap["dap_mode_set"]["str_mode"] = dap["str_mode"]){
        if dap["dap_mode"] = "auto" and dap["str_mode"] = "aerostr"{
            dap:set_aerostr_auto().
        }else if dap["dap_mode"] = "auto" and dap["str_mode"] = "aoa"{
            dap:set_aoa_auto().
        }else if dap["dap_mode"] = "css"{
            dap:set_css().
        }else if dap["dap_mode"] = "off"{ 
            dap:set_off().
        }
    }
    if dap["dap_mode"] = "auto"{
        if SAS{
            sas off.
        }
        if dap["str_mode"] = "aerostr"{
            aerostr().
                set dap["aerostr"]["targetDirection"] to dap["aerostr"]["turn_heading"].
                set dap["aerostr"]["targetPitch"] to dap["aerostr"]["turn_pitch"]+dap["aerostr"]["distance_pitch"].
                set dap["aerostr"]["targetRoll"] to dap["aerostr"]["turn_roll"].
        }
        if dap["str_mode"] = "aoa"{           
            if ship:altitude > aves["teamALTITUDE"] {
                set dap["aoa"]["smooth_target_aoa"] to changeRate(dap["aoa"]["smooth_target_aoa"], dap["aoa"]["target_aoa"],dap["dt"], AVES["Pitch_rate"]["high"]).
                set dap["aoa"]["smooth_target_bank"] to changeRate(dap["aoa"]["smooth_target_bank"], dap["aoa"]["target_bank"],dap["dt"], AVES["Rotation_rate"]["high"]).
            } else {
                set dap["aoa"]["smooth_target_aoa"] to changeRate(dap["aoa"]["smooth_target_aoa"], dap["aoa"]["target_aoa"],dap["dt"], AVES["Pitch_rate"]["low"]).
                set dap["aoa"]["smooth_target_bank"] to changeRate(dap["aoa"]["smooth_target_bank"], dap["aoa"]["target_bank"],dap["dt"], AVES["Rotation_rate"]["low"]).
            }
            if dap["aoa"]["base_pitch"] = 0 {
                aoa_bank_management(dap["aoa"]["smooth_target_aoa"], dap["aoa"]["smooth_target_bank"]).
            } else {
                aoa_bank_management(dap["aoa"]["smooth_target_aoa"], dap["aoa"]["smooth_target_bank"], dap["aoa"]["base_pitch"]).
                set dap["aoa"]["base_pitch"] to 0.
            }
            log dap_steering to "0:/log.txt".
             
        
        }
    }
    if dap["dap_mode"] = "css"{
        if SAS{
            sas off.
        }
        local css_in is lex().
        css_in:add("pitch", SHIP:CONTROL:PILOTPITCH).
        css_in:add("yaw", SHIP:CONTROL:PILOTYAW).
        css_in:add("roll", SHIP:CONTROL:PILOTROLL).

        if dap["str_mode"] = "aoa"{
            if css_in["roll"] = 0{
                set css_in["roll"] to css_in["yaw"].
            }

            local aoa is dap["css"]["last_aoa"].
            local bank is dap["css"]["last_roll"].
            if css_in["pitch"] > 0.5{
                if ship:altitude > aves["teamALTITUDE"] {
                    set aoa to changeRate(dap["css"]["last_aoa"], dap["css"]["last_aoa"]+AVES["Pitch_rate"]["high"],dap["dt"], AVES["Pitch_rate"]["high"]).
                } else {
                    set aoa to changeRate(dap["css"]["last_aoa"], dap["css"]["last_aoa"]+AVES["Pitch_rate"]["low"],dap["dt"], AVES["Pitch_rate"]["low"]).
                }
            }else if css_in["pitch"] < -0.5{
                if ship:altitude > aves["teamALTITUDE"] {
                    set aoa to changeRate(dap["css"]["last_aoa"], dap["css"]["last_aoa"]-AVES["Pitch_rate"]["high"],dap["dt"], AVES["Pitch_rate"]["high"]).
                } else {
                    set aoa to changeRate(dap["css"]["last_aoa"], dap["css"]["last_aoa"]-AVES["Pitch_rate"]["low"],dap["dt"], AVES["Pitch_rate"]["low"]).
                }
            }else{
                set aoa to dap["css"]["last_aoa"].
            }
            if css_in["roll"] > 0.5{
                if ship:altitude > aves["teamALTITUDE"] {
                    set bank to changeRate(dap["css"]["last_roll"], dap["css"]["last_roll"]-AVES["Rotation_rate"]["high"],dap["dt"], AVES["Rotation_rate"]["high"]).
                } else {
                    set bank to changeRate(dap["css"]["last_roll"], dap["css"]["last_roll"]-AVES["Rotation_rate"]["low"],dap["dt"], AVES["Rotation_rate"]["low"]).
                }
            }else if css_in["roll"] < -0.5{
                if ship:altitude > aves["teamALTITUDE"] {
                    set bank to changeRate(dap["css"]["last_roll"], dap["css"]["last_roll"]+AVES["Rotation_rate"]["high"],dap["dt"], AVES["Rotation_rate"]["high"]).
                } else {
                    set bank to changeRate(dap["css"]["last_roll"], dap["css"]["last_roll"]+AVES["Rotation_rate"]["low"],dap["dt"], AVES["Rotation_rate"]["low"]).
                }
            }else{
                set bank to dap["css"]["last_roll"].
            }
            set dap["css"]["last_roll"] to bank.
            set dap["css"]["last_aoa"] to aoa.
            aoa_bank_management(aoa,bank,0,true).

            
        }
        if dap["str_mode"] = "aerostr"{
            set css_in["pitch"] to css_in["pitch"] * dap["css"]["pitch_aerostr_spd"].
            set css_in["yaw"] to css_in["yaw"] * dap["css"]["yaw_aerostr_spd"].
            set css_in["roll"] to css_in["roll"] * dap["css"]["roll_aerostr_spd"].

            SET dap["css"]["pitch_out"] TO css_in["pitch"] * 5 + pitch_for().
            SET dap["css"]["YAW_out"] TO css_in["yaw"] * 5 + compass_for().
            SET dap["css"]["roll_out"] TO css_in["roll"] * 5 + roll_for().


        }
    }
}).
}
if not (dap:haskey("set_aoa_auto")) {
    dap:add("set_aoa_auto", {
    if not dap["setup_done"]{
        setup_dap().
    }
    lock dap_steering to heading(dap["aoa"]["aoa_yaw"], dap["aoa"]["aoa_pitch"], dap["aoa"]["aoa_roll"]). 
    lock throttle to dapthrottle.
    set dap["dap_mode"] to "auto".
    set dap["str_mode"] to "aoa".
    set dap["dap_mode_set"]["dapmode"] to "auto".
    set dap["dap_mode_set"]["str_mode"] to "aoa".


}).
}
if not (dap:haskey("set_aerostr_auto")) {
    dap:add("set_aerostr_auto", {
    if not dap["setup_done"]{
        setup_dap().
    }
    lock dap_steering to heading(dap["aerostr"]["targetDirection"], dap["aerostr"]["targetPitch"], dap["aerostr"]["targetRoll"]). 
    lock throttle to dapthrottle.
    set dap["dap_mode"] to "auto".
    set dap["str_mode"] to "aerostr".
    set dap["dap_mode_set"]["dapmode"] to "auto".
    set dap["dap_mode_set"]["str_mode"] to "aerostr".

}).
}
if not (dap:haskey("set_off")) {
    dap:add("set_off", {
    if not dap["setup_done"]{
        setup_dap().
    }
    set dap["dap_mode"] to "off".  
    lock throttle to SHIP:CONTROL:PILOTMAINTHROTTLE.
    set dapthrottle to 0.
    unlock steering.
    sas on.

}).
}

if not(dap:haskey("set_css")) {
    dap:add("set_css", {
    if not dap["setup_done"]{
        setup_dap().
    }
    set dap["dap_mode"] to "css".
    set dap["css"]["yaw_out"] to compass_for().
    set dap["css"]["pitch_out"] to pitch_for().
    set dap["css"]["roll_out"] to roll_for().
    set dap["css"]["last_roll"] to -roll_for().
    set dap["css"]["last_aoa"] to calc_aoa().
    lock dap_steering to heading(dap["css"]["yaw_out"], dap["css"]["pitch_out"], dap["css"]["roll_out"]).
    lock throttle to SHIP:CONTROL:PILOTMAINTHROTTLE.
    set dap["dap_mode_set"]["dapmode"] to "css".
    set dap["dap_mode_set"]["str_mode"] to dap["str_mode"].
}).
}




function rapierson{
    for rapiers in ship:partstitledpattern("R.A.P.I.E.R"){
        if not( rapiers:ignition){
            rapiers:ACTIVATE.
        }
    }
    set rapiers to true.

}
function rapiersoff{
    for rapiers in ship:partstitledpattern("R.A.P.I.E.R"){
        if rapiers:ignition{
            rapiers:SHUTDOWN.
        }
    }
     set rapiers to false.
}
function togglerapiermode{
    PARAMETER TGT_MODE IS "TOGGEL".
    if TGT_MODE = "TOGGEL"{
        for rapiers in ship:partstitledpattern("R.A.P.I.E.R"){
            rapiers:TOGGLEMODE().
                SET rapier_mode to RAPIERS:MODE.
        }

    }ELSE IF TGT_MODE = "AIR"{
        
        for rapiers in ship:partstitledpattern("R.A.P.I.E.R"){
            IF NOT rapiers:MODE = "AIRBREATHING"{
                rapiers:TOGGLEMODE().
            }
            SET rapier_mode to RAPIERS:MODE.
        }
    }ELSE IF TGT_MODE = "CLOSED"{
        for rapiers in ship:partstitledpattern("R.A.P.I.E.R"){
            IF NOT rapiers:MODE = "CLOSED"{
                rapiers:TOGGLEMODE().
            }
            SET rapier_mode to RAPIERS:MODE.
        }
    }
}   
function nervson{
    for nervs in ship:partstitledpattern("LV-N Atomic Rocket Motor"){
        if not( nervs:ignition){
            nervs:ACTIVATE.
        }
    }
    set nervs to true.
}
function nervsoff{
    for nervs in ship:partstitledpattern("LV-N Atomic Rocket Motor"){
        if nervs:ignition{
            nervs:SHUTDOWN.
        }
    }
    set nervs to false.
}