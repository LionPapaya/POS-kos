// Shared, bounded maneuver-node construction for OM1 and vacuum PDI.
// Planning changes the map's maneuver node only; it never starts an engine.

function pos_node_from_vector {
    parameter burn_ut, delta_velocity.
    local maneuver is node(burn_ut,0,0,0).
    add maneuver.
    // Ask KSP for its own node basis, avoiding a normal-axis sign assumption
    // between Unity's left-handed frame and orbital-mechanics conventions.
    set maneuver:radialout to 1.
    local radial_axis is maneuver:deltav:normalized.
    set maneuver:radialout to 0.
    set maneuver:normal to 1.
    local normal_axis is maneuver:deltav:normalized.
    set maneuver:normal to 0.
    set maneuver:prograde to 1.
    local prograde_axis is maneuver:deltav:normalized.
    set maneuver:prograde to vdot(delta_velocity,prograde_axis).
    set maneuver:radialout to vdot(delta_velocity,radial_axis).
    set maneuver:normal to vdot(delta_velocity,normal_axis).
    return maneuver.
}

function pos_plane_crossing {
    parameter plane_normal, node_type, lead_time.
    local start_ut is time:seconds+lead_time.
    local period is ship:orbit:period.
    local result is lex("valid",false,"ut",0,"ascending",false,"reason","no_plane_crossing").
    if ship:orbit:eccentricity >= 1 or period <= 0 { return result. }
    local left_ut is start_ut.
    local left_side is vdot(positionat(ship,left_ut)-ship:body:position,plane_normal).
    local i is 1.
    until i > 96 {
        local right_ut is start_ut+period*i/96.
        local right_side is vdot(positionat(ship,right_ut)-ship:body:position,plane_normal).
        local ascending is right_side > left_side.
        local selected is node_type = "Nearest" or (node_type = "Ascending" and ascending) or (node_type = "Descending" and not ascending).
        if selected and left_side*right_side <= 0 {
            local iteration is 0.
            until iteration >= 24 or right_ut-left_ut < 0.02 {
                local mid_ut is (left_ut+right_ut)/2.
                local mid_side is vdot(positionat(ship,mid_ut)-ship:body:position,plane_normal).
                if left_side*mid_side <= 0 { set right_ut to mid_ut. }
                else { set left_ut to mid_ut. set left_side to mid_side. }
                set iteration to iteration+1.
            }
            set result["valid"] to true.
            set result["ut"] to (left_ut+right_ut)/2.
            set result["ascending"] to ascending.
            set result["reason"] to "crossing_found".
            return result.
        }
        set left_ut to right_ut.
        set left_side to right_side.
        set i to i+1.
    }
    return result.
}

function pos_plan_inclination {
    parameter target_inclination, node_type is "Nearest", lead_time is 240, target_normal is V(0,0,0).
    local result is lex("valid",false,"reason","invalid_inclination").
    if hasnode { set result["reason"] to "existing_maneuver_nodes". return result. }
    if target_inclination < 0 or target_inclination > 180 { return result. }
    local body_north is (latlng(90,0):position-ship:body:position):normalized.
    local crossing_normal is body_north.
    local target_plane_mode is target_normal:mag > 0.5.
    if target_plane_mode { set crossing_normal to target_normal:normalized. }
    local crossing is pos_plane_crossing(crossing_normal,node_type,lead_time).
    if not crossing["valid"] { set result["reason"] to crossing["reason"]. return result. }
    local burn_ut is crossing["ut"].
    local r is positionat(ship,burn_ut)-ship:body:position.
    local vel is velocityat(ship,burn_ut):orbit.
    local radial_speed is vdot(vel,r:normalized).
    local tangent is vel-r:normalized*radial_speed.
    local target_tangent is V(0,0,0).
    if target_plane_mode {
        set target_tangent to vcrs(target_normal,r):normalized.
        if vdot(target_tangent,tangent) < 0 { set target_tangent to -target_tangent. }
    }else{
        local node_site is ship:body:geopositionof(r+ship:body:position).
        local east is node_site:velocity:orbit:normalized.
        if east:mag < 0.5 { set east to vcrs(body_north,r):normalized. }
        local north_sign is -1.
        if crossing["ascending"] { set north_sign to 1. }
        set target_tangent to east*cos(target_inclination)+body_north*north_sign*sin(target_inclination).
    }
    local target_velocity is r:normalized*radial_speed+target_tangent:normalized*tangent:mag.
    local maneuver is pos_node_from_vector(burn_ut,target_velocity-vel).
    if not target_plane_mode and abs(maneuver:orbit:inclination-target_inclination) > 0.15 {
        remove maneuver.
        set result["reason"] to "inclination_solution_mismatch".
        return result.
    }
    set result["valid"] to true.
    set result["reason"] to "node_ready".
    result:add("node",maneuver).
    result:add("inclination",maneuver:orbit:inclination).
    result:add("dv",maneuver:deltav:mag).
    return result.
}
