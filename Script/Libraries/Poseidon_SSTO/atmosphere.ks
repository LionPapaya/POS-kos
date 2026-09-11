// Pure atmospheric guidance mathematics shared by live control and the onboard
// FAR predictor. No flight logger, engine commands, or DAP updates belong here.
function entry_heading_error {
    parameter angle.
    return mod(mod(angle+180,360)+360,360)-180.
}

function entry_command_aoa {
    parameter altitude, speed.
    local normal is AVES["EGAOA"](altitude).
    local cfg is AVES["Entry"].
    local blend is max(0,min(1,(speed-cfg["high_speed"])/(cfg["full_high_speed"]-cfg["high_speed"]))).
    return normal+(max(normal,cfg["high_aoa"])-normal)*blend.
}

function atmospheric_heat_proxy {
    parameter speed, q_kpa.
    return sqrt(max(0,q_kpa)/AVES["Entry"]["heat_reference_q_kpa"])*
        (speed/AVES["Entry"]["heat_reference_speed"])^2.
}

function atmospheric_metrics {
    parameter position, velocity, surface_velocity, aero_accel, q_kpa, mu, radius.
    local r is position:mag.
    local energy is velocity:sqrmagnitude/2-mu/r.
    local h2 is vcrs(position,velocity):sqrmagnitude.
    local ecc is sqrt(max(0,1+2*energy*h2/mu^2)).
    local periapsis is h2/(mu*(1+ecc))-radius.
    local apoapsis is -1.
    if energy < -0.001 { set apoapsis to -mu/energy-periapsis-2*radius. }
    return lex("energy",energy,"energy_rate",vdot(aero_accel,velocity),
        "eccentricity",ecc,"periapsis",periapsis,"apoapsis",apoapsis,
        "altitude",r-radius,"vertical_speed",vdot(velocity,position:normalized),
        "speed",surface_velocity:mag,"q_kpa",q_kpa,"aero_g",aero_accel:mag/9.80665,
        "heat_proxy",atmospheric_heat_proxy(surface_velocity:mag,q_kpa)).
}

function atmospheric_load_reason {
    parameter metrics, margin is 1.
    if metrics["heat_proxy"] >= AVES["Entry"]["max_heat_proxy"]*margin { return "heating_proxy". }
    if metrics["q_kpa"] >= AVES["Entry"]["max_q_kpa"]*margin { return "dynamic_pressure". }
    if metrics["aero_g"] >= AVES["Entry"]["max_aero_g"]*margin { return "aerodynamic_load". }
    return "normal".
}

function aerobrake_command {
    parameter metrics, target_pe, exit_latched, mu, radius.
    local cfg is AVES["Aerobrake"].
    local reason is atmospheric_load_reason(metrics).
    local exiting is exit_latched or reason <> "normal".
    // Predict continued energy loss during the pullout response. A real exit
    // is confirmed separately by altitude and outward velocity, never by Ap.
    local exit_energy is -mu/(2*radius+max(0,metrics["periapsis"])+cfg["exit_apoapsis_floor"]).
    if metrics["energy"]+min(0,metrics["energy_rate"])*cfg["pullout_lead"] <= exit_energy {
        set exiting to true. set reason to "exit_energy_reserve".
    }
    if metrics["altitude"]+min(0,metrics["vertical_speed"])*cfg["pullout_lead"] <= cfg["floor_altitude"] {
        set exiting to true. set reason to "altitude_reserve".
    }
    if exit_latched and reason = "normal" { set reason to "exit_latched". }
    local desired_vs is max(-cfg["max_sink"],min(150,(target_pe+2000-metrics["altitude"])/20)).
    local bank is max(0,min(cfg["max_bank"],30+(metrics["vertical_speed"]-desired_vs)*cfg["vertical_gain"])).
    if exiting { set bank to 0. }
    return lex("exiting",exiting,"reason",reason,"bank",bank,"aoa",cfg["aoa"]).
}

// At a fixed radius and radial speed, solve the transverse speed needed for
// the requested periapsis. Valid for elliptic and hyperbolic incoming orbits.
function aerobrake_periapsis_velocity {
    parameter position, velocity, target_radius, mu.
    local r is position:mag.
    if target_radius <= 0 or r <= target_radius+1 { return lex("valid",false). }
    local radial is vdot(velocity,position:normalized).
    local tangent is velocity-position:normalized*radial.
    if tangent:mag < 1 { return lex("valid",false). }
    local speed2 is (radial^2+2*mu*(1/target_radius-1/r))/(r^2/target_radius^2-1).
    if speed2 < 0 { return lex("valid",false). }
    return lex("valid",true,"velocity",position:normalized*radial+tangent:normalized*sqrt(speed2)).
}

function entry_geo_unit {
    parameter point.
    return v(cos(point:lat)*cos(point:lng),sin(point:lat),cos(point:lat)*sin(point:lng)).
}

// Convex spherical polygon, projected about the queried point. This avoids
// the longitude seam and pole errors in planar lat/lng area comparisons.
// A footprint spanning more than a hemisphere is not a trustworthy local box.
function entry_point_in_footprint {
    parameter point, polygon.
    if polygon:length < 3 { return false. }
    local centre is entry_geo_unit(point).
    local east is v(-sin(point:lng),0,cos(point:lng)).
    local north is v(-sin(point:lat)*cos(point:lng),cos(point:lat),-sin(point:lat)*sin(point:lng)).
    local projected is list().
    for vertex in polygon {
        local unit is entry_geo_unit(vertex).
        local denom is vdot(unit,centre).
        if denom <= 0.01 { return false. }
        projected:add(v(vdot(unit,east)/denom,vdot(unit,north)/denom,0)).
    }
    local positive is false. local negative is false. local area is 0.
    local i is 0.
    until i >= projected:length {
        local a is projected[i]. local b is projected[mod(i+1,projected:length)].
        local cross is a:x*b:y-a:y*b:x.
        set area to area+cross.
        if cross > 0.000000001 { set positive to true. }
        if cross < -0.000000001 { set negative to true. }
        set i to i+1.
    }
    return abs(area) > 0.000000001 and not(positive and negative).
}
