set Terminal:width to 81. 
set Terminal:HEIGHT to 30.
if not (defined old_latest_status){
    set old_latest_status to "".
    set old_step to "".
}
if not(defined Step){
    set step to "  ".
}
if not(Lastest_status = old_latest_status){
    clearScreen.
}
if not(step = old_step){
    clearScreen.
}
Print("|==============================================================================|") at(0,0).
Print("|                                                                              |") at(0,1).
Print("|                           POSEIDON OPERATING SYSTEM                          |") at(0,2).
Print("|                                VERSION 1.2.6.2                               |") at(0,3).
Print("|                                                                              |") at(0,4).
Print("|                        VEHICLE : "+ship:shipName+"  ")at(0,5). Print ("|") at(79,5).
Print("|                                                                              |") at(0,6).
if ship:altitude < 70000 and not ( step = "reentry") and not ( step = "TEAM"){
    Print("|==============================================================================|") at(0,7).
    Print("|                                 VEHICLE DATA                                 |") at(0,8).
    Print("|                                                                              |") at(0,9).
    Print("| SURFACE SPEED ="+ round(ship:groundspeed)+ "") at(0,10). Print ("|") at(40,10). print ("VERTICAL SPEED ="+round(ship:verticalSpeed)+"") at(42,10). Print ("|") at(79,10). 
    Print("| AIR SPEED ="+ round(ship:airspeed)+ "") at(0,11). Print ("|") at(40,11). print ("ALTITUDE ="+round(ship:altitude)+"") at(42,11). Print ("|") at(79,11). 
    Print("| STATUS ="+ ship:status+ "  ") at(0,12). Print ("|") at(40,12). print ("MASS ="+round(ship:mass)+"") at(42,12). Print ("|") at(79,12). 
    Print("| STEP ="+ step+ "  ") at(0,13). Print ("|") at(40,13). print ("Throttle ="+throttle+"") at(42,13). Print ("|") at(79,13). 
    Print("|                                                                              |") at(0,14).
}
if ship:altitude < 70000 and step = "reentry"{
    Print("|==============================================================================|") at(0,7).
    Print("|                                 VEHICLE DATA                                 |") at(0,8).
    Print("|                                                                              |") at(0,9).
    Print("| SURFACE SPEED ="+ round(ship:groundspeed)+ "") at(0,10). Print ("|") at(40,10). print ("VERTICAL SPEED ="+round(ship:verticalSpeed)+"") at(42,10). Print ("|") at(79,10). 
    Print("| AIR SPEED ="+ round(ship:airspeed)+ "") at(0,11). Print ("|") at(40,11). print ("ALTITUDE ="+round(ship:altitude)+"") at(42,11). Print ("|") at(79,11). 
    Print("|") at(0,12). Print("h_tt =" +heading_to_target(runway_start)+ "   ") at(3,12). Print ("|") at(40,12). print ("MASS ="+round(ship:mass)+"") at(42,12). Print ("|") at(79,12). 
    Print("|") at(0,13). if defined target_bank {Print ("target bank="+target_bank+ "   ") at(3,13).} Print ("|") at(40,13).  print ("Throttle ="+throttle+"") at(42,13). Print ("|") at(79,13). 
    Print("|                                                                              |") at(0,14).
}  
if ship:altitude < 70000 and step = "TEAM"{
    Print("|==============================================================================|") at(0,7).
    Print("|                                 VEHICLE DATA                                 |") at(0,8).
    Print("|                                                                              |") at(0,9).
    Print("| SURFACE SPEED ="+ round(ship:groundspeed)+ "") at(0,10). Print ("|") at(40,10). print ("VERTICAL SPEED ="+round(ship:verticalSpeed)+"   ") at(42,10). Print ("|") at(79,10). 
    Print("| AIR SPEED ="+ round(ship:airspeed)+ "") at(0,11). Print ("|") at(40,11). print ("ALTITUDE ="+round(ship:altitude)+"") at(42,11). Print ("|") at(79,11). 
    Print("|") at(0,12). Print("steering mode =" +dap["str_mode"]+ "  ")at(3,12). Print ("|") at(40,12). if defined hud_vvdot {Print ("vvdot ="+hud_vvdot+ "   ") at(42,12).} Print ("|") at(79,12). 
    Print("|") at(0,13). if defined Active_HAC {Print ("Active_HAC ="+Active_HAC+ "   ") at(3,13).} Print ("|") at(40,13).  print ("Throttle ="+throttle+"") at(42,13). Print ("|") at(79,13). 
    Print("|                                                                              |") at(0,14).
}  
if ship:altitude > 70000{
    Print("|==============================================================================|") at(0,7).
    Print("|                                 VEHICLE DATA                                 |") at(0,8).
    Print("|                                                                              |") at(0,9).
    Print("| BODY ="+ ship:body+ "") at(0,10). Print ("|") at(40,10). print ("DELTA-V ="+round(ship:Deltav:current)+"") at(42,10). Print ("|") at(79,10). 
    Print("| AIR SPEED ="+ round(ship:airspeed)+ "") at(0,11). Print ("|") at(40,11). print ("ALTITUDE ="+round(ship:altitude)+"") at(42,11). Print ("|") at(79,11). 
    Print("| STATUS ="+ ship:status+ "   ") at(0,12). Print ("|") at(40,12). print ("MASS ="+round(ship:mass)+"") at(42,12). Print ("|") at(79,12). 
    Print("| STEP ="+ step+ "   ") at(0,13). Print ("|") at(40,13). print ("MAX THRUST ="+ship:maxThrust+"") at(42,13). Print ("|") at(79,13). 
    Print("|                                                                              |") at(0,14).
}  
Print("|==============================================================================|") at(0,15).
Print("|                                   ORBIT DATA                                 |") at(0,16).
Print("|                                                                              |") at(0,17).
Print("| APOAPSIS ="+ round(ship:apoapsis)+ "") at(0,18). Print ("|") at(40,18). print ("PERIAPSIS ="+round(ship:periapsis)+"") at(42,18). Print ("|") at(79,18). 
Print("| ETA APOAPSIS ="+ round(ship:obt:eta:apoapsis)+ "") at(0,19). Print ("|") at(40,19). print ("ETA PERIAPSIS ="+round(ship:obt:eta:periapsis)+"") at(42,19). Print ("|") at(79,19). 
Print("| INCLINATION ="+ round(ship:orbit:inclination)+ "") at(0,20). Print ("|") at(40,20). print ("Period ="+round(ship:orbit:period)+"") at(42,20). Print ("|") at(79,20). 
Print("|                                                                              |") at(0,21).
Print("|==============================================================================|") at(0,22).
Print("|                                   Message BOX                                |") at(0,23).
Print("|                                                                              |") at(0,24).
Print("|                                                                              |") at(0,25).
if defined Lastest_status {Print("|  "+lastest_status+"                                             ") at(0,26). Print ("|") at(79,26). }
Print("|                                                                              |") at(0,27).
Print("|                                                                              |") at(0,28).
Print("|==============================================================================|") at(0,29).

set old_latest_status to Lastest_status.
set old_step to step.

