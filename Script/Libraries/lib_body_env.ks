global body_environment_loaded is true.

// Body environment for atmospheric guidance.
// Kerbin keeps the historical altitude gates. Other atmospheres are mapped
// from the live kOS body: atmosphere height, pressure and oxygen.
// Vehicle limits stay in AVES. This file only describes the body.

function body_is_kerbin {
    return ship:body:name = "Kerbin".
}

function body_has_atmosphere {
    return ship:body:atm:exists.
}

// Jet mode is useful only where the air contains oxygen. Kerbin is forced
// true so a renamed-atmosphere test cannot change the flown RAPIER mode.
function body_breathable {
    if body_is_kerbin() { return true. }
    if not body_has_atmosphere() { return false. }
    return ship:body:atm:oxygen.
}

// Requested "AIR" becomes closed cycle when the body cannot feed the intakes.
function body_landing_rapier_command {
    parameter requested.
    if requested = "closed" or requested = "CLOSED" { return "CLOSED". }
    if body_breathable() { return "AIR". }
    return "CLOSED".
}

function body_env_init {
    if not (defined body_kerbin_pressure_alts) {
        global body_kerbin_pressure_alts is list().
        global body_kerbin_pressure_vals is list().
    }
    if body_kerbin_pressure_alts:length > 0 { return. }
    if not (defined Kerbin) { return. }
    if not Kerbin:atm:exists { return. }
    local alt_ is 0.
    until alt_ > 70000 {
        body_kerbin_pressure_alts:add(alt_).
        body_kerbin_pressure_vals:add(Kerbin:atm:altitudepressure(alt_)).
        set alt_ to alt_ + 1000.
    }
}

function body_kerbin_pressure_at {
    parameter kerbin_alt.
    body_env_init().
    if not (defined body_kerbin_pressure_alts) { return 0. }
    if body_kerbin_pressure_alts:length < 2 { return 0. }
    if kerbin_alt <= 0 { return body_kerbin_pressure_vals[0]. }
    local last is body_kerbin_pressure_alts:length - 1.
    if kerbin_alt >= body_kerbin_pressure_alts[last] { return body_kerbin_pressure_vals[last]. }
    local i is 0.
    until i >= last or body_kerbin_pressure_alts[i + 1] >= kerbin_alt {
        set i to i + 1.
    }
    local span is body_kerbin_pressure_alts[i + 1] - body_kerbin_pressure_alts[i].
    local fraction is 0.
    if span > 1 { set fraction to (kerbin_alt - body_kerbin_pressure_alts[i]) / span. }
    return body_kerbin_pressure_vals[i] + (body_kerbin_pressure_vals[i + 1] - body_kerbin_pressure_vals[i]) * fraction.
}

// Altitude on Kerbin whose static pressure matches the pressure at alt_ here.
// The entry AoA schedule was identified against Kerbin pressure, not height.
function body_kerbin_equivalent_altitude {
    parameter alt_.
    if body_is_kerbin() or not body_has_atmosphere() { return alt_. }
    body_env_init().
    if not (defined body_kerbin_pressure_vals) { return alt_. }
    if body_kerbin_pressure_vals:length < 2 { return alt_. }
    local p is ship:body:atm:altitudepressure(max(0, alt_)).
    if p >= body_kerbin_pressure_vals[0] { return 0. }
    local last is body_kerbin_pressure_vals:length - 1.
    if p <= body_kerbin_pressure_vals[last] { return body_kerbin_pressure_alts[last]. }
    local i is 0.
    until i >= last or body_kerbin_pressure_vals[i + 1] <= p {
        set i to i + 1.
    }
    local p0 is body_kerbin_pressure_vals[i].
    local p1 is body_kerbin_pressure_vals[i + 1].
    local fraction is 0.
    if abs(p0 - p1) > 0.0000001 { set fraction to (p0 - p) / (p0 - p1). }
    return body_kerbin_pressure_alts[i] + fraction * (body_kerbin_pressure_alts[i + 1] - body_kerbin_pressure_alts[i]).
}

// Altitude on the current body where pressure matches Kerbin at kerbin_alt.
function body_pressure_altitude {
    parameter kerbin_alt.
    if body_is_kerbin() or not body_has_atmosphere() { return kerbin_alt. }
    local target_pressure is body_kerbin_pressure_at(kerbin_alt).
    local lo is 0.
    local hi is ship:body:atm:height.
    local n is 0.
    until n >= 14 {
        local mid is (lo + hi) / 2.
        if ship:body:atm:altitudepressure(mid) > target_pressure {
            set lo to mid.
        } else {
            set hi to mid.
        }
        set n to n + 1.
    }
    return (lo + hi) / 2.
}

// Height above the site at which terminal energy management should begin.
// Kerbin returns the vehicle's TEAMAltitude unchanged.
function body_team_agl {
    if not (defined AVES) { return 25000. }
    if body_is_kerbin() or not body_has_atmosphere() { return AVES["TEAMAltitude"]. }
    local matched is body_pressure_altitude(AVES["TEAMAltitude"]).
    return max(3500, min(ship:body:atm:height * 0.55, matched)).
}

// Named altitude gates. Kerbin values are the historical literals.
function body_entry_gate {
    parameter which.
    local kerbin_gate is body_is_kerbin() or not body_has_atmosphere().
    if which = "init" or which = "solver_high" {
        if kerbin_gate { return 75000. }
        return ship:body:atm:height + 5000.
    }
    if which = "solver_status" {
        if kerbin_gate { return 74000. }
        return ship:body:atm:height + 4000.
    }
    if which = "solver_low" {
        if kerbin_gate { return 65000. }
        return ship:body:atm:height - 5000.
    }
    if which = "display" {
        if kerbin_gate { return 70000. }
        return ship:body:atm:height.
    }
    if which = "rcs_aoa" {
        if kerbin_gate { return 55000. }
        return ship:body:atm:height * 55000 / 70000.
    }
    if which = "auto_target" {
        if kerbin_gate { return 72000. }
        return ship:body:atm:height + 2000.
    }
    if which = "team_rcs" {
        if kerbin_gate { return 22000. }
        return max(6000, body_pressure_altitude(22000)).
    }
    if which = "entry_ref" {
        if kerbin_gate { return 60000. }
        return ship:body:atm:height * 60000 / 70000.
    }
    if which = "reset_air" {
        if kerbin_gate { return 50000. }
        return ship:body:atm:height * 50000 / 70000.
    }
    if which = "space" {
        if kerbin_gate { return 70000. }
        return ship:body:atm:height.
    }
    return 70000.
}

// Downrange the atmosphere can realistically be asked to manage, relative
// to the Kerbin 650-1600 km corridor. Crossrange uses radius instead.
function body_aero_range_scale {
    if body_is_kerbin() or not body_has_atmosphere() { return 1. }
    local pressure is max(0.02, ship:body:atm:sealevelpressure).
    return max(0.12, sqrt(pressure) * ship:body:atm:height / 70000).
}

function body_radius_scale {
    if body_is_kerbin() { return 1. }
    return ship:body:radius / 600000.
}

function body_sim_ceiling {
    if body_is_kerbin() or not body_has_atmosphere() { return 70000. }
    return ship:body:atm:height + 2000.
}

function body_local_gravity {
    parameter altitude_asl.
    return ship:body:mu / (ship:body:radius + altitude_asl) ^ 2.
}
