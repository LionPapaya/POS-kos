// Run in kOS before flight: runpath("0:/Checks/POS_Atmosphere_Checks.ks").
// Exercises real guidance functions with fixed math inputs. No steering,
// throttle, nodes, warp, FAR forecasts or POS simulator are used.
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/atmosphere.ks").
local failures is 0.
local checks is 0.
function atmo_check {
    parameter passed, description.
    set checks to checks+1.
    if not passed { set failures to failures+1. print "FAIL: "+description. }
}

atmo_check(abs(entry_heading_error(359)+1) < 0.00001,"heading wraps 359 to -1").
atmo_check(abs(entry_heading_error(-721)+1) < 0.00001,"heading handles multiple wraps").
atmo_check(abs(atmospheric_heat_proxy(3200,6)-1) < 0.00001,"heating reference units").
atmo_check(abs(atmospheric_heat_proxy(6400,6)-4) < 0.00001,"heating scales with squared speed at fixed q").
atmo_check(atmospheric_heat_proxy(5000,0) = 0,"no atmospheric heat estimate in vacuum").
atmo_check(abs(entry_command_aoa(60000,2000)-AVES["EGAOA"](60000)) < 0.00001,"ordinary entry AoA retained").
atmo_check(abs(entry_command_aoa(60000,4500)-AVES["Entry"]["high_aoa"]) < 0.00001,"high energy AoA schedule").

local mu is 3.5316e12.
local radius is 600000.
local position is v(700000,0,0).
local velocity is v(0,0,sqrt(mu/700000)).
local circular is atmospheric_metrics(position,velocity,velocity,v(0,0,0),0,mu,radius).
atmo_check(abs(circular["periapsis"]-100000) < 1,"circular periapsis from vectors").
atmo_check(abs(circular["apoapsis"]-100000) < 1,"circular apoapsis from vectors").
local escape is atmospheric_metrics(position,v(0,0,4000),v(0,0,4000),v(0,0,0),0,mu,radius).
atmo_check(escape["energy"] > 0 and escape["eccentricity"] > 1 and escape["apoapsis"] = -1,"escape is not a negative low apoapsis").
local approach_position is v(2000000,0,0).
for radial_speed in list(-500,-1500) {
    local approach_velocity is v(radial_speed,0,1500).
    local correction is aerobrake_periapsis_velocity(approach_position,approach_velocity,642000,mu).
    atmo_check(correction["valid"],"incoming periapsis correction exists").
    if correction["valid"] {
        local orbit_metrics is atmospheric_metrics(approach_position,correction["velocity"],correction["velocity"],v(0,0,0),0,mu,radius).
        atmo_check(abs(orbit_metrics["periapsis"]-42000) < 0.01,"correction solves requested Pe").
        atmo_check(abs(correction["velocity"]:x-radial_speed) < 0.00001,"correction preserves radial speed").
    }
}
atmo_check(not aerobrake_periapsis_velocity(position,velocity,800000,mu)["valid"],"reject correction inside requested Pe").

local nominal is lex("energy",1e6,"energy_rate",-1000,"periapsis",42000,"apoapsis",-1,
    "altitude",70000,"vertical_speed",-50,"speed",3000,"q_kpa",1,"aero_g",1,"heat_proxy",0.2).
local command is aerobrake_command(nominal,45000,false,mu,radius).
atmo_check(not command["exiting"] and command["bank"] >= 0 and command["bank"] <= AVES["Aerobrake"]["max_bank"],"nominal bank stays in envelope").
set command to aerobrake_command(nominal,45000,true,mu,radius).
atmo_check(command["exiting"] and command["bank"] = 0,"exit latch cannot command another dive").
set nominal["heat_proxy"] to 1.1.
set command to aerobrake_command(nominal,45000,false,mu,radius).
atmo_check(command["exiting"] and command["bank"] = 0,"heat estimate forces lift-up exit").
set nominal["heat_proxy"] to 0.2.
set nominal["aero_g"] to 5.
atmo_check(aerobrake_command(nominal,45000,false,mu,radius)["exiting"],"excess aerodynamic load forces exit").
set nominal["aero_g"] to 1.
set nominal["q_kpa"] to 25.
atmo_check(aerobrake_command(nominal,45000,false,mu,radius)["exiting"],"excess dynamic pressure forces exit").
set nominal["q_kpa"] to 1.
set nominal["altitude"] to 40000. set nominal["vertical_speed"] to -300.
atmo_check(aerobrake_command(nominal,45000,false,mu,radius)["exiting"],"descent lead protects altitude reserve").
set nominal["altitude"] to 70000. set nominal["vertical_speed"] to -50.
set nominal["energy"] to -2.5e6. set nominal["energy_rate"] to -10000.
atmo_check(aerobrake_command(nominal,45000,false,mu,radius)["exiting"],"projected continued drag protects exit energy").

local seam_box is list(latlng(-2,178),latlng(-2,-178),latlng(2,-178),latlng(2,178)).
atmo_check(entry_point_in_footprint(latlng(0,179.9),seam_box),"footprint crosses longitude seam").
atmo_check(not entry_point_in_footprint(latlng(0,170),seam_box),"reject point outside seam footprint").
local pole_box is list(latlng(85,-135),latlng(85,-45),latlng(85,45),latlng(85,135)).
atmo_check(entry_point_in_footprint(latlng(89,0),pole_box),"footprint contains pole region").
atmo_check(not entry_point_in_footprint(latlng(75,0),pole_box),"reject point outside polar footprint").
atmo_check(not entry_point_in_footprint(latlng(0,0),list()),"empty footprint is unusable").
atmo_check(not entry_point_in_footprint(latlng(0,0),list(latlng(0,0),latlng(0,0),latlng(0,0))),"degenerate footprint is unusable").
print "Atmospheric math checks: "+checks+" checks; "+failures+" failures.".
if failures = 0 { print "PASS (math only; flight validation still requires KSP/FAR).". }
