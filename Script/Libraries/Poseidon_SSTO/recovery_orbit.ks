// Pure recovery-orbit mathematics. No controls, logger, or vessel reads.
function recovery_orbit_config {
    return lex("target_ap",100000,"safe_clearance",10000,"reserve_fraction",0.1,
        "timeout",480,"progress_seconds",30,"minimum_gain",100,
        "assist_min_acceleration",0.5,"alignment",5,"pitch_rate",3,"pullup_aoa",15,"minimum_acceleration",0.2,
        "loss_allowance",200,"prediction_tick",2,"prediction_steps",240,
        "single_rapier_ato",false,"minimum_escape_height",35000,
        "minimum_escape_horizontal_speed",1600,"deorbit_pe",35000,
        "return_timeout",900,"return_alignment",5,"minimum_return_clearance",1000).
}

function recovery_apsides {
    parameter body_mu, radial_distance, radial_speed, tangent_speed.
    local specific_energy is (radial_speed^2+tangent_speed^2)/2-body_mu/radial_distance.
    local angular_momentum is radial_distance*tangent_speed.
    local eccentricity_squared is max(0,1+2*specific_energy*angular_momentum^2/body_mu^2).
    local orbit_eccentricity is sqrt(eccentricity_squared).
    local parameter_m is angular_momentum^2/body_mu.
    local peri_radius is parameter_m/(1+orbit_eccentricity).
    local apo_radius is 1e12.
    if specific_energy < 0 { set apo_radius to parameter_m/max(0.000001,1-orbit_eccentricity). }
    return lex("pe_radius",peri_radius,"ap_radius",apo_radius,"bound",specific_energy < 0,
        "eccentricity",orbit_eccentricity).
}

// Finite burn admission includes raise, coast and periapsis raise. This is a
// conservative two-dimensional approximation, not a FAR authority certificate.
// Current-pressure thrust and a supplied atmospheric drag bound are used;
// callers separately enforce attitude/terrain protection in actual flight.
function recovery_escape_prediction {
    parameter body_mu, body_radius, atmosphere_top, initial_height, initial_radial,
        initial_tangent, initial_mass, force_kn, flow_tps, fuel_seconds, pitch_deg,
        drag_mps2, cfg.
    local radius_now is body_radius+initial_height.
    local radial_now is initial_radial.
    local tangent_now is initial_tangent.
    local mass_now is initial_mass.
    local elapsed is 0.
    local powered_seconds is 0.
    local safe_radius is body_radius+atmosphere_top+cfg["safe_clearance"].
    local goal_radius is body_radius+max(cfg["target_ap"],atmosphere_top+cfg["safe_clearance"]+10000).
    local phase_now is "raise".
    local result is recovery_apsides(body_mu,radius_now,radial_now,tangent_now).
    local tick_seconds is cfg["prediction_tick"].
    local step_count is 0.
    until step_count >= cfg["prediction_steps"] {
        if result["bound"] and result["pe_radius"] >= safe_radius {
            return lex("possible",true,"burn_seconds",powered_seconds,"elapsed",elapsed,
                "predicted_ap",result["ap_radius"]-body_radius,
                "predicted_pe",result["pe_radius"]-body_radius,"pitch",pitch_deg,"reason","finite_burn_pass").
        }
        if radius_now < body_radius+cfg["minimum_return_clearance"] or not result["bound"] {
            return lex("possible",false,"reason","terrain_or_escape","pitch",pitch_deg).
        }
        if result["ap_radius"] >= goal_radius { set phase_now to "insert". }
        local thrust_pitch is pitch_deg.
        local powered is true.
        if phase_now = "insert" {
            set thrust_pitch to 0.
            local insertion_speed is sqrt(max(0,body_mu*(2/radius_now-2/(radius_now+safe_radius)))).
            local insertion_seconds is max(0,insertion_speed-tangent_now)/max(0.01,force_kn/mass_now).
            local apex_seconds is max(0,radial_now/max(0.1,body_mu/radius_now^2-tangent_now^2/radius_now)).
            if radius_now < safe_radius or (radial_now > 0 and apex_seconds > insertion_seconds/2+15) {
                set powered to false.
            }
        } else if radius_now < body_radius+atmosphere_top {
            local path_pitch is arcsin(max(-1,min(1,radial_now/max(1,sqrt(radial_now^2+tangent_now^2))))).
            set thrust_pitch to min(thrust_pitch,path_pitch+cfg["pullup_aoa"]).
        }
        local thrust_acceleration is 0.
        if powered {
            if powered_seconds+tick_seconds > fuel_seconds or mass_now-flow_tps*tick_seconds <= initial_mass*0.1 {
                return lex("possible",false,"reason","finite_burn_fuel","pitch",pitch_deg).
            }
            set thrust_acceleration to force_kn/mass_now.
            set powered_seconds to powered_seconds+tick_seconds.
            set mass_now to mass_now-flow_tps*tick_seconds.
        }
        local speed_now is max(1,sqrt(radial_now^2+tangent_now^2)).
        local drag_now is 0.
        if radius_now < body_radius+atmosphere_top { set drag_now to max(0,drag_mps2). }
        local radial_acceleration is tangent_now^2/radius_now-body_mu/radius_now^2+
            thrust_acceleration*sin(thrust_pitch)-drag_now*radial_now/speed_now.
        local tangent_acceleration is thrust_acceleration*cos(thrust_pitch)-
            radial_now*tangent_now/radius_now-drag_now*tangent_now/speed_now.
        set radius_now to radius_now+radial_now*tick_seconds+0.5*radial_acceleration*tick_seconds^2.
        set radial_now to radial_now+radial_acceleration*tick_seconds.
        set tangent_now to max(0,tangent_now+tangent_acceleration*tick_seconds).
        set elapsed to elapsed+tick_seconds.
        set result to recovery_apsides(body_mu,radius_now,radial_now,tangent_now).
        set step_count to step_count+1.
    }
    return lex("possible",false,"reason","finite_burn_time","pitch",pitch_deg,
        "predicted_ap",result["ap_radius"]-body_radius,"predicted_pe",result["pe_radius"]-body_radius).
}

function recovery_return_burn {
    parameter body_mu, body_radius, height_m, tangent_mps, target_pe_m,
        acceleration_mps2, available_dv.
    local radius_now is body_radius+height_m.
    local pe_radius is body_radius+target_pe_m.
    local return_speed is sqrt(max(0,body_mu*(2/radius_now-2/(radius_now+pe_radius)))).
    local delta_speed is max(0,tangent_mps-return_speed).
    local duration is delta_speed/max(0.001,acceleration_mps2).
    return lex("dv",delta_speed,"burn_seconds",duration,
        "possible",acceleration_mps2 > 0.01 and available_dv >= delta_speed+20).
}

// Coast the proposed post-burn state to a descending atmospheric crossing.
// Earth/Kerbin rotation is removed from the integrated angular travel.
function recovery_return_prediction {
    parameter body_mu, body_radius, atmosphere_top, initial_height, initial_radial,
        initial_tangent, rotation_rps, maximum_seconds.
    local radius_now is body_radius+initial_height.
    local radial_now is initial_radial.
    local tangent_now is initial_tangent.
    local angle_travel is 0.
    local elapsed is 0.
    local tick_seconds is 2.
    until elapsed >= maximum_seconds {
        if radius_now <= body_radius+atmosphere_top and radial_now < 0 {
            local speed_now is sqrt(radial_now^2+tangent_now^2).
            local entry_slope is arcsin(radial_now/max(1,speed_now)).
            return lex("possible",entry_slope >= -15 and speed_now < 3000,
                "seconds",elapsed,"downrange",angle_travel*body_radius,
                "entry_speed",speed_now,"entry_slope",entry_slope).
        }
        local radial_acceleration is tangent_now^2/radius_now-body_mu/radius_now^2.
        set angle_travel to angle_travel+(tangent_now/radius_now-rotation_rps)*tick_seconds.
        set radius_now to radius_now+radial_now*tick_seconds+0.5*radial_acceleration*tick_seconds^2.
        set tangent_now to max(0,tangent_now-radial_now*tangent_now/radius_now*tick_seconds).
        set radial_now to radial_now+radial_acceleration*tick_seconds.
        set elapsed to elapsed+tick_seconds.
    }
    return lex("possible",false,"reason","return_crossing_timeout").
}
