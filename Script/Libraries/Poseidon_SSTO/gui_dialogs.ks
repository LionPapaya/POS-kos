// Passive inputs only: no node creation, logging or control calls.
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/gui_style.ks").

function pos_om_catalog {
    local commands is list().
    commands:add(lex("label","Circularize","key","circularize","modes",list("at apoapsis","at periapsis","after fixed time","at altitude","at equatorial AN","at equatorial DN"),"fields",list(list("Mode value: delay (s) or altitude (m)",240,0,1000000000000.0)),"target",false,"note","")).
    commands:add(lex("label","Change apoapsis","key","apoapsis","modes",list("at periapsis","at apoapsis","after fixed time","at altitude","at equatorial AN","at equatorial DN"),"fields",list(list("Target altitude (m)",100000,1,1000000000000.0),list("Mode value: delay (s) or altitude (m)",240,0,1000000000000.0)),"target",false,"note","")).
    commands:add(lex("label","Change periapsis","key","periapsis","modes",list("at apoapsis","at periapsis","after fixed time","at altitude","at equatorial AN","at equatorial DN"),"fields",list(list("Target altitude (m)",100000,1,1000000000000.0),list("Mode value: delay (s) or altitude (m)",240,0,1000000000000.0)),"target",false,"note","")).
    commands:add(lex("label","Change inclination","key","inclination","modes",list("at nearest node","at cheapest node","at AN","at DN"),"fields",list(list("Target inclination (deg)",0,0,180)),"target",false,"note","")).
    commands:add(lex("label","Change eccentricity","key","eccentricity","modes",list("at apoapsis","at periapsis","after fixed time","at altitude","at equatorial AN","at equatorial DN"),"fields",list(list("Target eccentricity",0.1,0,0.999999),list("Mode value: delay (s) or altitude (m)",240,0,1000000000000.0)),"target",false,"note","")).
    commands:add(lex("label","Change LAN","key","lan","modes",list("at nearest apsis","at cheapest apsis","at periapsis","at apoapsis","at nearest peak latitude","at cheapest peak latitude","at north peak latitude","at south peak latitude"),"fields",list(list("Target angle (deg)",0,0,360)),"target",false,"note","")).
    commands:add(lex("label","Change periapsis and apoapsis","key","both_apses","modes",list("nearest","first half","second half"),"fields",list(list("Target periapsis (m)",100000,1,1000000000000.0),list("Target apoapsis (m)",200000,1,1000000000000.0)),"target",false,"note","")).
    commands:add(lex("label","Change semimajor axis","key","semimajoraxis","modes",list("at apoapsis","at periapsis","after fixed time","at altitude"),"fields",list(list("Semimajor axis from body center (m)",800000,1,1000000000000.0),list("Mode value: delay (s) or altitude (m)",240,0,1000000000000.0)),"target",false,"note","")).
    commands:add(lex("label","Resonant orbit","key","resonance","modes",list("at apoapsis","at periapsis","after fixed time","at altitude"),"fields",list(list("Period ratio",1.5,0.001,1000),list("Base period (s); 0 = current orbit",0,0,1000000000000.0),list("Mode value: delay (s) or altitude (m)",240,0,1000000000000.0)),"target",false,"note","")).
    commands:add(lex("label","Change argument of periapsis","key","argument","modes",list("nearest","first half","second half"),"fields",list(list("Target angle (deg)",0,0,360)),"target",false,"note","")).
    commands:add(lex("label","Return from current moon","key","return_from_moon","modes",list("at periapsis"),"fields",list(list("Target parent periapsis altitude (m)",80000,0,1000000000000.0)),"target",false,"note","Plans an escape burn at the current orbit's next periapsis. Review the parent-body trajectory before executing.")).
    commands:add(lex("label","Capture at current body","key","capture_at_body","modes",list("at periapsis"),"fields",list(),"target",false,"note","For an incoming hyperbolic trajectory: circularizes at the current body's next periapsis.")).
    commands:add(lex("label","Match target plane","key","match_planes","modes",list("at nearest node","at cheapest node","at AN","at DN"),"fields",list(),"target",true,"note","")).
    commands:add(lex("label","Match target velocity","key","match_velocity","modes",list("at closest approach","after fixed time"),"fields",list(list("Mode value: delay (s) or altitude (m)",240,0,1000000000000.0)),"target",true,"note","")).
    commands:add(lex("label","Intercept at chosen time","key","intercept_time","modes",list("chosen time"),"fields",list(list("Departure delay (s)",240,30,1000000000000.0),list("Flight time after departure (s)",3600,1,1000000000000.0)),"target",true,"note","")).
    commands:add(lex("label","Fine tune closest approach","key","fine_tune","modes",list("closest approach"),"fields",list(list("Target distance (m)",100,1,1000000000000.0),list("Departure delay (s)",240,30,1000000000000.0),list("Search samples (integer)",60,2,200)),"target",true,"note","")).
    commands:add(lex("label","Hohmann transfer to target","key","hohmann_target","modes",list("transfer"),"fields",list(),"target",true,"note","Creates the departure node. Use Match target velocity for arrival.")).
    commands:add(lex("label","Lowest delta-v intercept","key","intercept","modes",list("lowest dv"),"fields",list(),"target",true,"note","Search cost includes arrival braking; only the departure node is created.")).
    commands:add(lex("label","Transfer window search 1","key","porkchop1","modes",list("lowest dv","as soon as possible"),"fields",list(list("Departure window start (s from now)",240,120,1000000000000.0),list("Departure window end (s from now)",3600,121,1000000000000.0),list("Minimum flight time (s)",600,1,1000000000000.0),list("Maximum flight time (s)",7200,2,1000000000000.0),list("Include arrival cost: 0 or 1",1,0,1),list("Samples per axis (integer)",25,2,100)),"target",true,"note","Search may take time at 2000 IPU. Creates departure only; arrival cost is optional.")).
    commands:add(lex("label","Transfer window search 2","key","porkchop2","modes",list("lowest dv","as soon as possible"),"fields",list(list("Departure window start (s from now)",240,120,1000000000000.0),list("Departure window end (s from now)",3600,121,1000000000000.0),list("Minimum flight time (s)",600,1,1000000000000.0),list("Maximum flight time (s)",7200,2,1000000000000.0),list("Include arrival cost: 0 or 1",1,0,1),list("Samples per axis (integer)",25,2,100)),"target",true,"note","Search may take time at 2000 IPU. Creates departure only; arrival cost is optional.")).
    commands:add(lex("label","Hohmann orbit change (two burns)","key","hohmann_orbit","modes",list("after fixed time"),"fields",list(list("Target altitude (m)",100000,1,1000000000000.0),list("Departure delay (s)",240,30,1000000000000.0)),"target",false,"note","Each burn is created and reviewed separately. Requires a nearly circular starting orbit.")).
    commands:add(lex("label","RCS apsis correction","key","rcs","modes",list("apoapsis","periapsis"),"fields",list(list("Target altitude (m)",100000,1,1000000000000.0),list("Tolerance (m)",10,0.1,10000)),"target",false,"note","Direct RCS correction: review the target before starting. No maneuver node is created.")).
    return commands.
}

function pos_om_inputs {
    parameter command.
    local panel is gui(550,500).
    pos_gui_window_style(panel,550).
    panel:addlabel(command["label"]).
    if command["note"] <> "" {
        local maneuver_note is panel:addlabel(command["note"]).
        set maneuver_note:style:width to 520.
        set maneuver_note:style:wordwrap to true.
    }
    local mode_menu is panel:addpopupmenu().
    for mode_name in command["modes"] { mode_menu:addoption(mode_name). }
    local fields is list().
    for spec in command["fields"] {
        local row is panel:addhlayout().
        local field_label is row:addlabel(spec[0]).
        set field_label:style:width to 360.
        local field_input is row:addtextfield(""+spec[1]).
        set field_input:style:width to 140.
        fields:add(field_input).
    }
    if command["target"] {
        if hastarget { panel:addlabel("Selected map target: "+target:name). }
        else { panel:addlabel("Select a target in map view before creating the node."). }
    }
    local message is panel:addlabel("").
    set message:style:wordwrap to true.
    set message:style:width to 520.
    local result is lex("accepted",false,"mode","","numbers",list()).
    local done is false.
    local buttons is panel:addhlayout().
    local plan_button is buttons:addbutton("Create maneuver").
    if command["key"] = "rcs" { set plan_button:text to "Review correction". }
    local cancel_button is buttons:addbutton("Cancel").
    set cancel_button:onclick to { set done to true. }.
    set plan_button:onclick to {
        local numbers is list().
        local valid is true.
        local index is 0.
        for field in fields {
            local number is field:text:tonumber(-1e30).
            local spec is command["fields"][index].
            if number < spec[2] or number > spec[3] {
                set valid to false.
                set message:text to spec[0]+": enter a number from "+spec[2]+" to "+spec[3].
            }
            numbers:add(number).
            set index to index+1.
        }
        if valid {
            set result["numbers"] to numbers.
            set result["mode"] to mode_menu:value.
            set result["accepted"] to true.
            set done to true.
        }
    }.
    panel:show().
    until done { wait 0.1. }
    panel:dispose().
    return result.
}

function vacuum_target_input {
    parameter target_lat, target_lng.
    local result is lex("valid",false,"lat",0,"lng",0).
    local dialog is GUI(430,210).
    pos_gui_window_style(dialog,430).
    dialog:addlabel("Poseidon PDI landing coordinates").
    dialog:addlabel("Latitude (-90..90)").
    local lat_field is dialog:addtextfield("").
    dialog:addlabel("Longitude (-180..180)").
    local lng_field is dialog:addtextfield("").
    if target_lat <> "ASK" { set lat_field:text to target_lat:tostring. }
    if target_lng <> "ASK" { set lng_field:text to target_lng:tostring. }
    local message is dialog:addlabel("").
    local done is false.
    local accept is dialog:addbutton("Use landing site").
    set accept:onclick to {
        local lat_value is lat_field:text:tonumber(-9999).
        local lng_value is lng_field:text:tonumber(-9999).
        if abs(lat_value) <= 90 and abs(lng_value) <= 180 {
            set result["lat"] to lat_value.
            set result["lng"] to lng_value.
            set result["valid"] to true.
            set done to true.
        }else{ set message:text to "Enter valid numeric latitude and longitude.". }
    }.
    local cancel is dialog:addbutton("Cancel").
    set cancel:onclick to { set done to true. }.
    dialog:show().
    until done { wait 0.1. }
    dialog:hide().
    return result.
}
