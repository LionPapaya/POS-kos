RUNONCEPATH("0:/Libraries/Poseidon_SSTO_Functions_Main.ks").





set Mun_circ_calc to 0.
set tmicalc to false.
set tmi_done to false.
set Mun_peri_adj_start to false.
set Mun_peri_adj_done to false.
set tmi_adjustment_check to false.


set step to "Launch".
set running to true.
clearScreen.  
set nervs to false.
set rapier_mode to "air".
set rapiers to false.
set circ_done to false.
set Lastest_status to "launching".
set orbitcalc to false.


//min periapsis = 75000 apoapsis > periapsis
//Inclination between 0 and 180
Set TargetApoapsis to 100000.
Set TargetPeriapsis to 100000.
Set TargetInclination to 0.

check_inputs().



reset_sys().

until running = false{
    update_readouts().
    check_abort().
    if step = "Launch"{
         
        if ship:altitude < 85{
             
            rapierson().
            lock throttle to 1.
        }   
        if ship:thrust > 240.{
            brakes off.
                
                
                if ship:airspeed > 120{
                    
                    set step to "rotate".
                    set Lastest_status to "rotating".
                    Set warpmode to "physics".
                    
                }
        }
               
        
    if ship:altitude > 85{
        set Lastest_status to "not in lift off conditon".
        set step to "end".
    }
    }
    if step = "rotate"{
        lock targetPitch to 15.
        if ship:altitude > 90{
            gear off.
            set step to "assent".
            set warp to 0.
        }
    }
    if step = "assent"{
        if ship:airspeed < 440{
            lock targetPitch to  10.
            aeroturn(TargetInclination + 90). 
            
        }


        if airspeed > 440 and ship:altitude < 15000{lock targetPitch to  15. set warp to 1.}
        
        if ship:altitude > 15000 and ship:altitude < 20000 and targetPitch > 0{
            
            set targetPitch to targetPitch - 0.5.
            wait 0.55.
            }
        if ship:altitude > 20000 and ship:altitude < 23000 or targetPitch < 0.5{   
        lock targetPitch to 10.
        set warp to 0.
        nervson().
        set Lastest_status to "nervs on".
        }
        if ship:altitude > 23000 and ship:altitude < 57000{
            if rapier_mode = "air"{
                togglerapiermode().
                set rapier_mode to "closed".
            }   
            set Lastest_status to "rapiers in closed cycle".
            if TargetPitch < 30{
                set targetPitch to targetPitch + 1.
                wait 0.5.
            }   
            set warp to 1.
        }    
        if ship:apoapsis > 57000{
            if rapier_mode = "closed"{
                togglerapiermode().
                set rapier_mode to "air".
            }
        lock targetPitch to 13.
        } 
        if ship:altitude > 70000{
            lock steering to prograde.
            set Lastest_status to "Space".
        }   
        if ship:apoapsis > TargetApoapsis {
            set Step to "circ".
            rapiersoff().
            lock throttle to 0.
        

            
        }
    }
    if step = "circ"{
        if circ_done = false{
            set circ to node( time+eta:apoapsis, 0, 0, 0).
            add circ.
            set circ_done to true.
        }    
        if circ:orbit:periapsis < TargetPeriapsis and orbitcalc = false{
            if  circ:orbit:periapsis + 10000 < TargetPeriapsis{
                set circ:prograde to circ:prograde + 10.
            }
            if circ:orbit:periapsis + 1000 < TargetPeriapsis{
                set circ:prograde to circ:prograde + 1.
            }
            if circ:orbit:periapsis + 100 < TargetPeriapsis{
                set circ:prograde to circ:prograde + 0.1.
            }
        }
        if circ:orbit:periapsis > TargetPeriapsis and orbitcalc = false{
            if  circ:orbit:periapsis - 10000 > TargetPeriapsis{
                set circ:prograde to circ:prograde - 10.
            }
            if circ:orbit:periapsis - 1000 > TargetPeriapsis{
                set circ:prograde to circ:prograde - 1.
            }
            if circ:orbit:periapsis - 100 > TargetPeriapsis{
                set circ:prograde to circ:prograde - 0.1.
            }
        }
        if circ:orbit:periapsis + 500 > TargetPeriapsis and  circ:orbit:periapsis - 500 < TargetPeriapsis and orbitcalc = false{
            set orbitcalc to true.
            set Lastest_status to "manuver calculated succesfully".
            
        }
        if orbitcalc = true{
            nervson().
            rapiersoff().
            set nd to circ.
            execute_node().
            set step to "tmi".
        }
        
        

    }
    if step = "tmi"{
        if tmi_done = false{
            set tmi to node( time+1000, 0, 0, 0).
            add tmi.
            set tmi_done to true.
        }
        
        if tmi:orbit:apoapsis < 12000000 and tmicalc = false{
            if  tmi:orbit:apoapsis + 10000000 < 12000000{
                set tmi:prograde to tmi:prograde + 100.
            }
            if tmi:orbit:apoapsis + 1000000 < 12000000{
                set tmi:prograde to tmi:prograde + 10.
            }
            if tmi:orbit:apoapsis + 100000 < 12000000{
                set tmi:prograde to tmi:prograde + 1.
            }
            if tmi:orbit:apoapsis + 10000 < 12000000{
                set tmi:prograde to tmi:prograde + 0.1.
            }
        
        }
        if tmi:orbit:apoapsis > 12000000 and tmicalc = false{
            if  tmi:orbit:apoapsis - 1000000 > 12000000{
                set tmi:prograde to tmi:prograde - 10.
            }
            if tmi:orbit:apoapsis - 100000 > 12000000{
                set tmi:prograde to tmi:prograde - 1.
            }
            if tmi:orbit:apoapsis - 10000 > 12000000{
                set tmi:prograde to tmi:prograde - 0.1.
            }
        
        }
        if tmi:orbit:apoapsis + 1000000 > 12000000 and  tmi:orbit:apoapsis - 1000000 < 12000000 and tmicalc = false{
            set tmicalc to true.
            set Lastest_status to "tmi calculated succesfully". 
        } 
        if tmi:orbit:transition = "Final" and tmicalc = true{
            set tmi:time to tmi:time + 20.
        }
        if tmi:orbit:transition = "ENCOUNTER" and tmicalc = true{
            set nd to tmi.
            execute_node().
            set step to "tmi-adjustment".
        }
        

    }
    if step = "tmi-adjustment"{
        if tmi_adjustment_check = false{
            set tmi_adj to node( time+200, 0, 0, 0).
            add tmi_adj.
            set tmi_adjustment_check to true.
        }
        
        
        if tmi_adj:orbit:nextpatch:inclination < 160{
            set tmi_adj:radialout to tmi_adj:radialout - 1.
        }
        if tmi_adj:orbit:nextpatch:inclination > 160 and tmi_adj:orbit:nextpatch:periapsis < 15000{
            set tmi_adj:radialout to tmi_adj:radialout - .5.
        }
        if tmi_adj:orbit:nextpatch:inclination > 160 and tmi_adj:orbit:nextpatch:periapsis > 30000{
            set tmi_adj:radialout to tmi_adj:radialout + .5.
        }
        if tmi_adj:orbit:nextpatch:inclination > 160 and tmi_adj:orbit:nextpatch:periapsis < 30000 and tmi_adj:orbit:nextpatch:periapsis > 15000{
            
            set nd to tmi_adj.
            remove tmi_adj.
            add nd. 
            nervson().
            execute_node().
            set step to "Mun_Circ".
        }


        
    }
    if step = "Mun_Circ"{
        
        //    set warpmode to "Rails".
         //   until ship:orbit:body:name = "Mun"{
           //     set warp to 3.
          //  }
           // set warp to 0.
        //}    
        if ship:orbit:body:name = "Mun" and orbit:periapsis < 20000 or orbit:periapsis > 30000 and Mun_peri_adj_done = false{
            if Mun_peri_adj_start = false{
                set peri_adj to node( time+100, 0, 0, 0).
                add peri_adj.
                set Mun_peri_adj_start to true.
            }
            if peri_adj:orbit:periapsis < 20000{
                if  peri_adj:orbit:periapsis + 10000 < TargetPeriapsis{
                    set peri_adj:radialout to peri_adj:radialout + 10.
                }
                if peri_adj:orbit:periapsis + 1000 < TargetPeriapsis{
                    set peri_adj:radialout to peri_adj:radialout + 1.
                }
                if peri_adj:orbit:periapsis + 100 < TargetPeriapsis{
                    set peri_adj:radialout to peri_adj:radialout + 0.1.
                }
            }
            if peri_adj:orbit:periapsis > 30000{
                if  peri_adj:orbit:periapsis - 10000 > 30000{
                    set peri_adj:prograde to peri_adj:prograde - 10.
                }
                if peri_adj:orbit:periapsis - 1000 > 30000{
                    set peri_adj:prograde to peri_adj:prograde - 1.
                }
                if peri_adj:orbit:periapsis - 100 > 30000{
                    set peri_adj:prograde to peri_adj:prograde - 0.1.
                }
            }
            if peri_adj:orbit:periapsis < 30000 and peri_adj:orbit:periapsis > 20000{                
                set nd to peri_adj.
                remove peri_adj.
                add nd. 
                nervson().
                execute_node().
                set Mun_peri_adj_done to true.
            }
        }
        if ship:orbit:body:name = "Mun" and  Mun_peri_adj_done = true and orbit:periapsis < 30000 and orbit:periapsis > 20000{
            set warpmode to "Rails".
            warpto(time+eta:periapsis-1000). 
        }
        if ship:orbit:body:name = "Mun" and  Mun_peri_adj_done = true and orbit:periapsis < 30000 and orbit:periapsis > 20000 and eta:periapsis < 1000{
            if Mun_circ_calc = 0{
                set mun_circ to node( time+100, 0, 0, 0).
                add mun_circ.
                set Mun_circ_calc to 1.
                set Mun_ApoapsisTarget to ship:periapsis.
            }
            
            if mun_circ:orbit:apoapsis < Mun_ApoapsisTarget and Mun_circ_calc = 1{ //if Apoapsis to low
                if  mun_circ:orbit:apoapsis + 10000 < Mun_ApoapsisTarget{
                    set mun_circ:prograde to mun_circ:prograde + 10.
                }
                if mun_circ:orbit:apoapsis + 1000 < Mun_ApoapsisTarget{
                    set mun_circ:prograde to mun_circ:prograde + 1.
                }
                if mun_circ:orbit:apoapsis + 100 < Mun_ApoapsisTarget{
                    set mun_circ:prograde to mun_circ:prograde + 0.1.
                }
            }
            if mun_circ:orbit:apoapsis > Mun_ApoapsisTarget and Mun_circ_calc = 1 { //if Apoapsis to high
                if  mun_circ:orbit:apoapsis - 10000 > Mun_ApoapsisTarget{
                    set mun_circ:prograde to mun_circ:prograde - 10.
                }
                if mun_circ:orbit:apoapsis - 1000 > Mun_ApoapsisTarget{
                    set mun_circ:prograde to mun_circ:prograde - 1.
                }
                if mun_circ:orbit:apoapsis - 100 > Mun_ApoapsisTarget{
                    set mun_circ:prograde to mun_circ:prograde - 0.1.
                }
            }
            if mun_circ:orbit:apoapsis + 999 > Mun_ApoapsisTarget and  mun_circ:orbit:apoapsis - 999 < Mun_ApoapsisTarget and Mun_circ_calc = 1{
                set Mun_circ_calc to 2.
                set Lastest_status to "Mun Circlurisation Manuver calculated succesfully".
            
            }
            if  Mun_circ_calc = 2{
                nervson().
                rapiersoff().
                set nd to mun_circ.
                execute_node().
                set step to "end".
            }
        }
    }
    if step = "runway_abort"{
        set Lastest_status to "Runway abort".
        brakes on.
        lock throttle to 0.
        rapiersoff().
        lock targetPitch to -5.
        if ship:airspeed < 1{
            set Lastest_status to "abort complete".
            set step to "end".
        }    
    }
    if step = "runway_abort_watering"{
        
        
        if  ship:altitude > 150{
            set targetPitch to targetPitch - 1.
            wait 1.
        }
        if  ship:altitude < 80 and ship:airspeed > 100{
            set targetPitch to targetPitch + 1.
            wait 0.5.
        }  
        if ship:airspeed < 150{
            set targetPitch to targetPitch - 1.
            wait 2.
        }
        if ship:airspeed < 70{
            lock throttle to 1.
        }
        if ship:airspeed > 110{
            lock throttle to 0.
        }
        if ship:altitude < 80 and ship:airspeed < 100{
            set targetPitch to 5.
        }
        if ship:altitude < 5{
            set Lastest_status to "watering".
            set step to "end".
        }
        if TargetPitch < -10 or TargetPitch > 15{
            set TargetPitch to 0.
        }
        if  ship:altitude < 40{
            set targetPitch to 15.

        }   
        
    }       
    if step = "end"{
        set running to false.
        set Lastest_status to "ending".
        reset_sys().
        set warp to 0.
        update_readouts().
    }
}