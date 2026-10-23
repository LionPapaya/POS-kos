// Pure shared ascent guidance. A plane below the current latitude needs a
// dogleg before a direct launch azimuth exists. Preserve the requested plane;
// never substitute the launch latitude or send a sentinel heading to control.
function ascent_inclination_guidance {
    parameter requested_inclination, launch_site_latitude, northbound is true.
    local command is lex("valid",false,"heading",-1,"mode","invalid",
        "northbound",northbound,"latitude_error",0).
    if requested_inclination < 0 or requested_inclination > 180 or
       abs(launch_site_latitude) > 90 { return command. }
    local latitude_limit is min(requested_inclination,180-requested_inclination).
    local latitude_excess is max(0,abs(launch_site_latitude)-latitude_limit).
    set command["latitude_error"] to latitude_excess.
    local commanded_heading is 90.
    if latitude_excess > 0 {
        set command["mode"] to "dogleg".
        // Retain the equatorward branch after crossing into reachable
        // latitudes. Otherwise the direct solution immediately turns back
        // out of the target plane's latitude band.
        set command["northbound"] to launch_site_latitude < 0.
        local dogleg_turn is min(45,4*latitude_excess).
        if launch_site_latitude < 0 { set dogleg_turn to -dogleg_turn. }
        if requested_inclination <= 90 {
            set commanded_heading to 90+dogleg_turn.
        } else {
            set commanded_heading to 270-dogleg_turn.
        }
    } else {
        set command["mode"] to "direct".
        // At a pole only a polar plane is directly reachable; azimuth has
        // no unique orbital meaning there. Leave along the selected meridian.
        if abs(cos(launch_site_latitude)) < 0.00000001 {
            set commanded_heading to 0.
        } else {
            set commanded_heading to arcsin(max(-1,min(1,
                cos(requested_inclination)/cos(launch_site_latitude)))).
        }
        if not northbound { set commanded_heading to 180-commanded_heading. }
    }
    if commanded_heading < 0 { set commanded_heading to commanded_heading+360. }
    set command["heading"] to commanded_heading.
    set command["valid"] to true.
    return command.
}
