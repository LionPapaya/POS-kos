function TEAM_guid_old{
    parameter team_input.
    parameter sim_in is current_simstate().
    parameter hacs is create_HAC().
    parameter rnw is lex("pos",runway_start,"head",runway_heading,"alt",runway_altitude).

    local HAC is lex("HAC1",hacs["HAC1"],"HAC2",hacs["HAC2"]).
    


    local team_internal is lex(
        //regarding current status
        "sim", clone_simstate(sim_in),
        "step", "s_trn", //valid step is "s_trn","bef","in","ex","fla","ROL"
        "ENMGT", true,

        //regarding current HAC and entry
        "active_hac",hacs[choose_hac()["active_hac"]],
        "active_hac_dir",choose_hac()["HAC_Direction"],
        "ercl_hac_alt",hacs["HAC_ERCL_ALT"],
        "ercl_hac_latlong",hacs["HAC_ERCL"],
        "hac_entry", lex(
            "alt",0,
            "latlng", hacs[choose_hac()["active_hac"]],
            "vel",0,
            "dist",0),
        "apch_mode","ovh",
        
        


        "dummy",0
    ).
    local out is lex(
        "s_trn",false,
        "enlow",false,
        "change_hac",false,
        "team_input",lex(
            "step",team_internal["step"],
            "enmgt",team_internal["ENMGT"],
            "active_hac",team_internal["active_hac"],
            "active_hac_dir",team_internal["active_hac_dir"],
            "apch_mode",team_internal["apch_mode"]
        ),
        "hac_entry_pos",team_internal["hac_entry"]["latlng"],
        "ercl_hac_latlong",team_internal["ercl_hac_latlong"],
        "algn_pos", latlng(0,0),
        "gs", true,
        "gear_cmd" , false,
        "airbrake_cmd", false,


        "dummy",0
    ).
    if not(team_input = lex()){
        set team_internal["step"] to team_input["step"].
        set team_internal["ENMGT"] to team_input["enmgt"].
        set team_internal["active_hac"] to team_input["active_hac"].
        set team_internal["active_hac_dir"] to team_input["active_hac_dir"].
        set team_internal["apch_mode"] to team_input["apch_mode"].
    }

    if team_internal["step"] = "bef"{
        //log team_internal["active_hac"] to log_team_sim.txt.
        local h_s is calc_hacstate(team_internal["active_hac"],AVES["HacRadius"],heading_between(team_internal["sim"]["latlong"],team_internal["active_hac"]),rnw["head"],team_internal["active_hac_dir"]).
        set team_internal["hac_entry"]["latlng"] to h_s["latlng"].
        set team_internal["hac_entry"]["alt"] to h_s["alt"].
        set team_internal["hac_entry"]["vel"] to h_s["vel"].
        set team_internal["hac_entry"]["dist"] to h_s["dist"].
        clearVecDraws().
        pos_arrow(h_s["latlng"],"HAC_entry",h_s["alt"],1).
        pos_arrow(team_internal["ercl_hac_latlong"],"ERCL_HAC",team_internal["ercl_hac_alt"],1).
        draw_vector(team_internal["ercl_hac_latlong"],team_internal["ercl_hac_alt"],rnw["pos"],rnw["alt"],RGB(1, 0, 0)," ",1).
        for angle in range(rnw["head"],compass_for(),20){
            local h_s is calc_hacstate(team_internal["active_hac"],AVES["HacRadius"],angle,rnw["head"],team_internal["active_hac_dir"]).
            pos_arrow(h_s["latlng"]," ",h_s["alt"],0.1).
        }

        

        
        if calcdistance_m(team_internal["hac_entry"]["latlng"],team_internal["sim"]["latlong"]) < 500{
            set team_internal["step"] to "in".
        }
    }   
    log "per ENMGT" to log_team_sim.txt.
    IF team_internal["STEP"] = "BEF"{
        LOCAL DIST IS CALCDISTANCE_M(team_internal["hac_entry"]["latlng"],team_internal["sim"]["latlong"]).
        IF DIST < 500 or team_internal["sim"]["altitude"] < team_internal["hac_entry"]["alt"]-100{
            set team_internal["step"] to "in".
            SET OUT["team_input"]["step"] TO "IN".
            RETURN OUT.
        }
        
    }
    if team_internal["ENMGT"]{
        local sim is clone_simstate(team_internal["sim"]).
        //log "pre_turn" to log_team_sim.txt.
        log team_internal["hac_entry"]["latlng"] to log_team_sim.txt.
        set sim to simulate_trajectory_hed_pos(sim,team_internal["hac_entry"]["latlng"]).
        //log "aft_turn" to log_team_sim.txt.
        log team_internal["hac_entry"]["latlng"] to log_team_sim.txt.
        log heading_between(sim["latlong"],team_internal["hac_entry"]["latlng"]) to log_team_sim.txt.
        log "per ENMGT" to log_team_sim.txt.
        //log compass_for_simstate(sim)+" , "+heading_between(team_internal["sim"]["latlong"],team_internal["hac_entry"]["latlng"]) to log_team_sim.txt.
        local pid is pidloop(0.29,0.43,0.3).
        set pid:maxoutput to 20.
        set pid:minoutput to 0.
        local vvdot is 0.
        local dist_ is calcdistance_m(team_internal["hac_entry"]["latlng"],sim["latlong"]).
        local old_dist is dist_.
        
        log sim to simstate.log.
        //log "pre_decent" to log_team_sim.txt.
        //log old_dist to log_team_sim.txt.
        //log dist_ to log_team_sim.txt.
        //log sim["altitude"] to log_team_sim.txt.
        //log team_internal["hac_entry"]["latlng"] to log_team_sim.txt.
        //log team_internal["hac_entry"]["alt"]-1000 to log_team_sim.txt.
        log sim["simtime"] to log_team_sim.txt.
        until old_dist < dist_ or sim["altitude"] < team_internal["hac_entry"]["alt"]-100{
            local dist is team_internal["hac_entry"]["dist"] + calcdistance_m(team_internal["hac_entry"]["latlng"],sim["latlong"]).
            local tgt_alt is calculate_glideslope_alt(dist).
            local tgt_vvdot is calc_vvdot(dist,team_internal["hac_entry"]["vel"],tgt_alt,sim["altitude"]).
            set pid:setpoint to tgt_vvdot.
            local old_alt is sim["altitude"].
            local aoa to pid:update(sim["simtime"],vvdot).
            set sim to simulate_trajectory_time(sim,0,"right",AVES["simulation"]["timestep"],aoa,AVES["simulation"]["timestep"]/3).
            local vvdot to (sim["altitude"]-old_alt)/AVES["simulation"]["timestep"].
            log sim["simtime"]+ ",(" +sim["latlong"]:lat+ ","+sim["latlong"]:lng+"),"+sim["altitude"]+","+sim["surfvel"]:mag to log_team_sim_.txt.
            //log"in loop" to log_team_sim.txt.
            set old_dist to dist_.
            set dist_ to calcdistance_m(team_internal["hac_entry"]["latlng"],sim["latlong"]).
        
        }
        log "aft_decent" to log_team_sim.txt.
        log old_dist + " , " + calcdistance_m(team_internal["hac_entry"]["latlng"],sim["latlong"]) to log_team_sim.txt.
        log team_internal["hac_entry"]["alt"] to log_team_sim.txt.
        log team_internal["hac_entry"]["alt"]:typename to log_team_sim.txt.
        log sim["altitude"] + " , " + (team_internal["hac_entry"]["alt"]-100) to log_team_sim.txt.
        
        log "aft_decent" to log_team_sim.txt.
        if sim["altitude"] < team_internal["hac_entry"]["alt"]-100 or sim["surfvel"]:mag < team_internal["hac_entry"]["vel"]{
            if brakes{
                set out["airbrakes_cmd"] to false.
                return out.
            }
            // to low energy switch to direct
            if team_internal["apch_mode"] = "ovh"{

                set team_internal["apch_mode"] to "dir".
                if choose_hac()["active_hac"] = "HAC2"{
                    set team_internal["active_hac"] to HAC["HAC1"].
                }else{
                    set team_internal["active_hac"] to HAC["HAC2"].
                }
                if team_internal["active_hac_dir"] = "Clockwise"{
                    set team_internal["active_hac_dir"] to "antiClockwise".
                }else{
                    set team_internal["active_hac_dir"] to "Clockwise".
                }
                local h_s is calc_hacstate(team_internal["active_hac"],AVES["HacRadius"],heading_between(sim["latlong"],team_internal["active_hac"]),rnw["head"],team_internal["active_hac_dir"]).
                set team_internal["hac_entry"]["latlng"] to h_s["latlng"].
                set team_internal["hac_entry"]["alt"] to h_s["alt"].
                set team_internal["hac_entry"]["vel"] to h_s["vel"].
                set team_internal["hac_entry"]["dist"] to h_s["dist"].
                set out:change_hac to true.
                log "1"to "log.txt".
                //log team_internal to "log.txt".
                //log out to "log.txt".
                //log sim to "log.txt".
                return out.

            }else{
                set out:enlow to true.
                
                set out["team_input"]["step"] to "ex".
                log "2"to "log.txt".
                //log team_internal to "log.txt".
                //log out to "log.txt".
                //log sim to "log.txt".
                return out.
            }
        }else if calcdistance_m(team_internal["hac_entry"]["latlng"],sim["latlong"]) < 1000 and sim["surfvel"]:mag > team_internal["hac_entry"]["vel"]{
            if sim["surfvel"]:mag < team_internal["hac_entry"]["vel"]+ AVES["TEAM_v_margin"]{
                SET OUT["team_input"]["step"] TO "BEF".
                log "4"to "log.txt".
                //log team_internal to "log.txt".
                //log out to "log.txt".
                //log sim to "log.txt".
                return out.

            }else if sim["surfvel"]:mag > team_internal["hac_entry"]["vel"]+ AVES["TEAM_v_margin"] or sim["altitude"] > team_internal["hac_entry"]["alt"]+100{
                set out["airbrake_cmd"] to true.    
                log "5"to "log.txt".
                //log team_internal to "log.txt".
                //log out to "log.txt".
                //log sim to "log.txt".
                return out.
                
            }
            

        }else{
            log "10"to "log.txt".
            log calcdistance_m(team_internal["hac_entry"]["latlng"],sim["latlong"]) to "log.txt".
            log sim["surfvel"]:mag to "log.txt".
            log team_internal["hac_entry"]["vel"] to "log.txt".
            set out["airbrake_cmd"] to false.
            //log out to "log.txt".
                //log sim to "log.txt".
                return out.
        }

    }

    if team_internal["step"] = "in"{
        if abs(heading_between(team_internal["sim"]["latlong"],rnw["pos"]) - compass_for_simstate(team_internal["sim"])) < 5{
        SET OUT["team_input"]["step"] TO "ex".
        log "7"to "log.txt".
        RETURN OUT.
        
        }
    }
    if team_internal["step"] = "ex"{
        set out["algn_pos"] to get_geoposition_along_heading(        
            rnw["pos"],        
            rnw["head"]+180,        
            (calcdistance_m(team_internal["sim"]["latlong"],rnw["pos"])*0.4)).
        LOCAL DIST IS CALCDISTANCE_M(team_internal["hac_entry"]["latlng"],team_internal["sim"]["latlong"]).
        if dist < AVES["glideslope"]["switch12"]{
            SET OUT["team_input"]["step"] TO "fla".
        }
        log "8"to "log.txt".
        RETURN OUT.
    }
    if Team_internal["step"] = "fla"{
        set out["gear_cmd"] to team_internal["sim"]["altitude"] - rnw["alt"] < 150.
        local alt_ovr_runway is team_internal["sim"]["altitude"] - rnw["alt"].
        if alt_ovr_runway < 100{
            set out["gs"] to false.
            if alt_ovr_runway < 15{
                SET OUT["team_input"]["step"] TO "rol".
                set out["airbrake_cmd"] to true.
            }

        }
    }


    log "9"to "log.txt".
    return out.
}



function TEAM_guid{
    
}