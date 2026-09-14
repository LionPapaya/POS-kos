//**************************************************||
//==================================================||
//==================================================||
//            MANEUVER FUNCTIONS LIBRARY            ||
//==================================================||
//==================================================||
//**************************************************||
// cc. SilverNuke911                                ||
// kOS Script Collection                            ||
// 2024 - 2026                                      ||
//--------------------------------------------------||
//                                                  ||
// A library of kOS functions designed for precise  ||
// maneuver planning and execution in orbital       ||
// mechanics, and other navigation purposes,        ||
// emulating the automation of "Create Maneuver" and||
// "Execute Maneuver" of MechJeb2.0. This includes  ||
// utilities for computing required deltaV, creating||
// various maneuver nodes, and other necessary      ||
// implements, see the rest of the code for stuff   ||
//                                                  ||
// Example use:                                     ||
//     If you want to create a node to circularize  ||
//  at apoapsis and want it to be executed          ||
//  immediately, write:                             ||
//                                                  ||
//  create_node(circularize("at apoapsis"))         ||
//  execute_node()                                  ||
//                                                  ||
//  and that's literally it. Just read the docstring||
//  for each function to know its purpose.          ||
//                                                  ||
//--------------------------------------------------||
//  Last update:  April 2026
//  Update / PATCH Notes:
//  March 28, 2026 - Changed a few of the
//                   functions as per the corrections
//                   in the sub.
//  April 03, 2026 - Updated some functions, the burn
//                   calculation times are now localized
//                 - Thinking of using Rodrigues' formula
//                   for the inclination problem. 
//  April 05, 2026 - Fixed the change eccentricity, it is now working
//                   Fixed change apoapsis and change periapsis
//                   Fixed change inclination using Rodrigues formula
//                   For some fucking reason "time_from_true_anomaly" returns values that are 
//                      0.02 seconds ahead of the actual value (1 physics tick). Added a stopgap solution.
//                   Implemented change LAN
//                   fixed match planes with target.
//                   initialized change_pe_and_ap.
//  April 07, 2026 - Fixed change semi major axis
//                   Fixed change ap and pe
//                   Added orbit inertial position and orbit inertial velocity as helper funcs
//                   Added "change argument of periapsis"
//                   Noted the need to improve "change periapsis" and change eccentricity/smja
//                        They need to accomodate hyperbolic orbits
//  April 09, 2026 - Fixed change_periapsis so it can handle hyperbolic orbits
//                   Fixed change_eccentricity so it can handle hyperbolic orbits
//                   Fixed change_semimajoraxis so it throws errors when given hyperbolic orbit
//                      will try to see later if it can accept negative values for hyperb. orbits.
//                   Fixed change_apoapsis using better mathematical formulation.
//                   Changed the max_acc calculation for execute_node to recalculate every burn loop.
// April 13, 2026 - Added hohmann_maneuver to change circular oribtal radii effectively
//                - Implemented hohmann transfer to target (impressive results).
//--------------------------------------------------||

//==================================================||
// INITIALIZATIONS                                  ||
//**************************************************||
//--------------------------------------------------||
@lazyGlobal off.          //                        ||
global mode_error_message is "[ MODE ERROR ] : Invalid mode given. Mode used is: ".
// set config:ipu to 2000.   //                     ||  
//==================================================||
//**************************************************||


//**************************************************||
//--------------------------------------------------||
//               BURN TIME FUNCTIONS                ||
//--------------------------------------------------||
//**************************************************||

// =================================================||
// Function: ship_isp                               ||
//--------------------------------------------------||
// Purpose:  Computes the effective specific impulse||
//           (ISP) of the vessel, taking into       ||
//           account all active engines and their   ||
//           current thrust and ISP values.         ||
//                                                  ||
// Assumptions:                                     ||
//   - Only considers engines that are currently    ||
//     providing thrust (availablethrust > 0)       ||
//     and have a valid ISP (isp > 0).              ||
//   - The effective ISP is calculated as a         ||
//     thrust-weighted harmonic mean:               ||
//     ISP_eff = Σ(Thrust_i) / Σ(Thrust_i / ISP_i)  ||
//     This accounts correctly for engines with     ||
//     different ISPs and thrusts, reflecting       ||
//     total propellant consumption.                ||
//                                                  ||
// Parameters: None                                 ||
//                                                  ||
// Returns:                                         ||
//   - effective isp : The effective ISP (in s)     ||
//     of all currently firing engines, reflecting  ||
//     their contribution to total thrust and fuel  ||
//     usage.                                       ||
//   - Returns 0 if no engines are active.          ||
// =================================================||

function ship_isp {
    local engineList to list().    // Temporary list to collect engines
    list engines in engineList.    // Populates engineList with all vessel engines

    local total_thrust to 0.       // Sum of engine thrusts
    local totalmdot to 0.          // Overall mass flow 

    for engine in engineList {
        // Only include engines that are firing and have valid ISP
        if engine:availablethrust > 0 and engine:isp > 0 {
            set total_thrust to total_thrust + engine:availablethrust.
            set totalmdot to totalmdot + (engine:availablethrust / engine:isp). 
        }
    }

    if total_thrust > 0 and totalmdot > 0 {
        return total_thrust / totalmdot.   // harmonic-mean Isp
    } else {
        return 0.
    }
}

//==================================================||
//      FUNCTION: calculate_burn_time               ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Helper function to calculate total or half     ||
//   burn time for either engines or rcs            ||
//                                                  ||
// PARAMETERS:                                      ||
//   mnv : A maneuver node with :DELTAV vector      ||
//                                                  ||
// RETURNS:                                         ||
//   Burn time in seconds, or 0 if ISP is 0/null.   ||
//                                                  ||
// METHOD:                                          ||
//   Uses the Tsiolkovsky equation:                 ||
//     ve = ISP × g0                                ||
//     mf = m0 × exp(–Δv / ve)                      ||
//     dm = m0 – mf                                 ||
//     ṁ = Thrust / ve                              ||
//     burn_time = dm / ṁ                           ||
//==================================================||
function calculate_burn_time {
    local parameter delta_v.
    local parameter isp.
    local parameter thrust.
    
    if isp <= 0 or thrust <= 0 { 
        return 0. 
    }
    local ve is isp * constant:g0.
    local mdot is thrust / ve.
    local m0 is ship:mass.
    local mf is m0 * constant:e^(-delta_v / ve).
    local dm is m0 - mf.
    local t is dm / mdot.
    return t.
}

//==================================================||
//      FUNCTION: total_burn_time                   ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Computes the full burn duration needed to      ||
//   achieve a maneuver node's total delta-v.       ||
//                                                  ||
// PARAMETERS:                                      ||
//   mnv : A maneuver node with :DELTAV vector      ||
//                                                  ||
// RETURNS:                                         ||
//   Burn time in seconds, or 0 if ISP is 0/null.   ||
//==================================================||

function total_burn_time {
    local parameter mnv.
    return calculate_burn_time(mnv:deltav:mag, ship_isp(), ship:maxThrust).
}

//==================================================||
//      FUNCTION: half_burn_time                    ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Calculates burn time needed to complete half   ||
//   of a maneuver node's total delta-v.            ||
//                                                  ||
// PARAMETERS:                                      ||
//   mnv : A maneuver node                          ||
//                                                  ||
// RETURNS:                                         ||
//   Half burn time in seconds, or 0 if ISP is 0.   ||
//                                                  ||
// NOTES:                                           ||
//   Uses same method as total_burn_time, but with  ||
//   delta-v halved in the calculation.             ||
//==================================================||

function half_burn_time {
    local parameter mnv.
    return calculate_burn_time(mnv:deltav:mag / 2, ship_isp(), ship:maxThrust).
}

//==================================================||
//      FUNCTION: rcs_isp                           ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Returns the effective ISP (s) of all active    ||
//   RCS thrusters on the vessel.                   ||
//                                                  ||
// PARAMETERS:                                      ||
//   (none)                                         ||
//                                                  ||
// RETURNS:                                         ||
//   A scalar ISP value in seconds.                 ||
//==================================================||

function rcs_isp {
    local rcsList to list().        // Temporary list to collect RCS thrusters
    list rcs in rcsList.            // Populate rcsList with all RCS thrusters

    local total_thrust to 0.        // Sum of RCS thrusts
    local totalmdot to 0.           // Overall mass flow for RCS
    for rcs_ in rcsList {
        // Only include RCS thrusters that are firing, have valid ISP,
        // and are enabled in the fore direction
        if rcs_:availableThrust > 0 
        and rcs_:isp > 0 
        and rcs_:foreenabled {
            set total_thrust to total_thrust + rcs_:availableThrust.
            set totalmdot to totalmdot + (rcs_:availableThrust / rcs_:isp).  // mass flow contribution
        }
    }

    if total_thrust > 0 and totalmdot > 0 {
        return total_thrust / totalmdot.   // harmonic-mean ISP for RCS
    } else {
        return 0.
    }
}

//==================================================||
//      FUNCTION: rcs_total_thrust                  ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Computes the total thrust of all the rcs       ||
//   thrusters (foreward enabled) on the craft      ||
//                                                  ||
// PARAMETERS:                                      ||
//   none                                           ||
//                                                  ||
// RETURNS:                                         ||
//   Total RCS thrust                               ||
//                                                  ||
// METHOD:                                          ||
//   Takes the sum of thrust divided by             ||
//   mass flow rate (thrust/isp)                    ||
//==================================================||

function rcs_total_thrust {
    local rcsList is list().
    list rcs in rcsList.
    local rcs_total_thrust_ is 0.
    for rcs_ in rcsList {
        if rcs_:availableThrust > 0 
            and rcs_:availableThrust > 0 
            and rcs_:foreenabled{
            set rcs_total_thrust_ to 
                rcs_total_thrust_ + rcs_:availableThrust.
        }
    }
    return rcs_total_thrust_.
}
//==================================================||
//      FUNCTION: rcs_burn_time                     ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Computes the full burn time required to        ||
//   complete a maneuver using RCS thrusters.       ||
//                                                  ||
// PARAMETERS:                                      ||
//   mnv : Maneuver node to be executed             ||
//                                                  ||
// RETURNS:                                         ||
//   Total RCS burn time in seconds.                ||
//                                                  ||
// METHOD:                                          ||
//   Applies the Tsiolkovsky rocket equation and    ||
//   standard thrust formula to compute duration.   ||
//==================================================||
function rcs_burn_time {
    local parameter mnv.
    return calculate_burn_time(mnv:deltav:mag, rcs_isp(), rcs_total_thrust()).
}

//==================================================||
//      FUNCTION: rcs_total_deltaV                  ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Calculates the total delta-V available from    ||
//   the vessel's RCS system using monopropellant.  ||
//                                                  ||
// PARAMETERS:                                      ||
//   None                                           ||
//                                                  ||
// RETURNS:                                         ||
//   Total RCS delta-V in meters per second (m/s).  ||
//                                                  ||
// METHOD:                                          ||
//   Applies the Tsiolkovsky rocket equation using  ||
//   the current monopropellant mass, vessel mass,  ||
//   and RCS ISP.                                   ||
//==================================================||

function rcs_total_deltaV {
    local rcs_res is 0.
    for resource in ship:resources {
        if resource:name = "MonoPropellant" {
            set rcs_res to resource.
        }
    }
    local rcs_mass is rcs_res:amount * rcs_res:density.
    local wet_mass is ship:mass.
    local dry_mass is wet_mass - rcs_mass.
    local isp is rcs_isp().
    local ve is isp * constant:g0.
    local dv is ve * ln( wet_mass / dry_mass).
    return dv.
}

//==================================================||
//      FUNCTION: rcs_half_burn_time                ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Computes the time required to burn half of the ||
//   maneuver node's delta-V using RCS thrusters.   ||
//                                                  ||
// PARAMETERS:                                      ||
//   mnv : Maneuver node to be executed             ||
//                                                  ||
// RETURNS:                                         ||
//   Half RCS burn time in seconds.                 ||
//==================================================||

function rcs_half_burn_time {
    local parameter mnv.
    return calculate_burn_time(mnv:deltav:mag / 2, rcs_isp(), rcs_total_thrust()).
}

//**************************************************||
//--------------------------------------------------||
//                   SHIP SYSTEMS                   ||
//--------------------------------------------------||
//**************************************************||

//==================================================||
//      FUNCTION: twr                               ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Computes the vessel's Thrust-to-Weight Ratio   ||
//   (TWR) at its current altitude on the current   ||
//   celestial body.                                ||
//                                                  ||
// RETURNS:                                         ||
//   twr_val : Thrust-to-weight ratio, dimensionless||
//                                                  ||
// NOTES:                                           ||
//   - Uses available thrust, not maximum thrust.   ||
//   - TWR > 1 means upward acceleration possible.  ||
//   - Crucial for launch and landing maneuvers.    ||
//==================================================||

function twr {
    // Compute local gravity at current ship altitude
    local g0 is body:mu / (body:radius + ship:altitude)^2.
    // Compute current ship weight (mass * gravity)
    local ship_weight is ship:mass * g0.
    if ship_weight = 0 { return 0. }
    // Compute thrust-to-weight ratio
    local twr_val is ship:availablethrust / ship_weight.
    return twr_val.
}

//**************************************************||
//--------------------------------------------------||
//               ORBITAL CALCULATIONS               ||
//--------------------------------------------------||
//**************************************************||

//==================================================||
//      FUNCTION: orbital_velocity_circular         ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Computes the circular orbital velocity (m/s)   ||
//   for a given altitude or absolute radius.       ||
//                                                  ||
// PARAMETERS:                                      ||
//   altitude_ : Numeric input, interpreted via mode||
//     - "altitude": altitude above surface (m)     ||
//     - "radius"  : full radius from center (m)    ||
//                                                  ||
//   mode : (optional, string) Defaults to altitude ||
//     - "altitude" -> adds to body:radius          ||
//     - "radius"   -> used as-is                   ||
//                                                  ||
// RETURNS:                                         ||
//   Circular orbital velocity at specified radius  ||
//                                                  ||
// NOTES:                                           ||
//   Formula: v = sqrt(GM / r)                      ||
//   where GM = body:mu, and r is orbital radius.   ||
//                                                  ||
// WARNINGS:                                        ||
//   Prints error if mode is invalid but continues. ||
//==================================================||

function orbital_velocity_circular {
    local parameter altitude_.           
    local parameter mode is "altitude".  
    local r__ is 0.                     
    if mode = "altitude" {
        set r__ to body:radius + altitude_.
    }
    else if mode = "radius" {
        set r__ to altitude_.
    } else {
        print mode_error_message + mode.
    }
    return sqrt(body:mu / r__).
}


//==================================================||
//      FUNCTION: vis_viva_equation                 ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Computes orbital speed (m/s) at a given        ||
//   altitude for an orbit with known semimajor     ||
//   axis using the Vis-Viva equation.              ||
//                                                  ||
// PARAMETERS:                                      ||
//   altitude_ : (numeric) Altitude above surface   ||
//   a_        : (numeric) Semimajor axis of orbit  ||
//                                                  ||
// RETURNS:                                         ||
//   Orbital speed at the given altitude (m/s)      ||
//                                                  ||
// FORMULA:                                         ||
//   v = sqrt( GM * (2/r - 1/a) )                   ||
//     where:                                       ||
//       GM = body:mu (gravitational parameter)     ||
//       r  = body:radius + altitude_               ||
//       a  = semimajor axis of orbit               ||
//==================================================||
function vis_viva_equation {
    local parameter altitude_.  // Altitude above body's surface (m)
    local parameter a_.         // Semimajor axis of the orbit (m)
    local r_ is body:radius + altitude_.
    return sqrt(body:mu * (2 / r_ - 1 / a_)).
}

//==================================================||
//      FUNCTION: calculate_semimajor_axis          ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Computes the semimajor axis of an orbit from   ||
//   its periapsis and apoapsis.                    ||
//                                                  ||
// PARAMETERS:                                      ||
//   periapsis__ : (scalar) Periapsis altitude      ||
//   apoapsis___ : (scalar) Apoapsis altitude       ||
//                                                  ||
// RETURNS:                                         ||
//   Semimajor axis (scalar), measured from the     ||
//   center of the body.                            ||
//==================================================||
function calculate_semimajor_axis {
    local parameter periapsis__.
    local parameter apoapsis___.
    return body:radius + (periapsis__+apoapsis___)/2.
}

//==================================================||
//      FUNCTION: true_anomaly_to_radius            ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Converts a given true anomaly to the orbital   ||
//   radius (altitude above surface).               ||
//                                                  ||
// PARAMETERS:                                      ||
//   ta : (scalar) True anomaly in degrees          ||
//                                                  ||
// RETURNS:                                         ||
//   Orbital radius (scalar) above the surface.     ||
//==================================================||
function true_anomaly_to_radius {
    local parameter ta.
    local a is ship:obt:semimajoraxis.
    local e is ship:obt:eccentricity.
    local r_ to a * (1 - e^2) / (1 + e * cos(ta)).
    return r_ - body:radius.
}

//==================================================||
//      FUNCTION: radius_to_true_anomaly            ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//  Converts a given orbital radius (or altitude)   ||
//  to the corresponding true anomaly based on the  ||
//  current orbital elements of the active vessel.  ||
//                                                  ||
// PARAMETERS:                                      ||
//      r_ : (scalar) Value to convert.             ||
//           Interpreted as either altitude or      ||
//           radius from the planet center.         ||
//      mode : (string, default "altitude")         ||
//          - "altitude" to treat r_ as above       ||
//            surface altitude (r = r_ + R_body)    ||
//          - "radius" to treat r_ as full radius   ||
//      closest: (bool) returns the closest anomally||
//      which : (integer, 0 or 1)                   ||
//          - 0: returns true anomaly in [0°,180°]  ||
//          - 1: returns true anomaly in [180°,360°]||
//            to account for the 2 places where alt ||
//            is the same                           ||
//                                                  ||
// RETURNS:                                         ||
//      True anomaly in degrees [0°, 360°].         ||
//==================================================||
function radius_to_true_anomaly {
    local parameter r_.
    local parameter mode is "altitude".
    local parameter closest is true. // if true, returns the closest anomaly
    local parameter which is 0. // which overides the closest, 
                          // if 0, returns the [0,180] ta, and if 1, returns the [180,360] ta.

    local r__ is r_.
    if mode = "altitude" {
        set r__ to r__ + body:radius.
    }
    local a is ship:obt:semimajoraxis.
    local e is ship:obt:eccentricity.
    local cos_trueanomaly to (a * (1 - e^2) / r__ - 1) / e.
    local trueanomaly to arccos(cos_trueanomaly).

    if which = 1 {
        return angle_wrap(0 - trueanomaly).
    }
    if not closest {
        return angle_wrap(trueanomaly).
    }
    // Determine closest anomaly
    local alt_trueanomaly to angle_wrap(0 - trueanomaly).
    if time_from_true_anomaly(trueanomaly) > time_from_true_anomaly(alt_trueanomaly) {
        return alt_trueanomaly.
    }
    return angle_wrap(trueanomaly).
}

//==================================================||
// FUNCTION: true_anomaly_to_eccentric_anomaly      ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Converts a true anomaly to the corresponding   ||
//   eccentric anomaly.                             ||
//                                                  ||
// PARAMETERS:                                      ||
//   ta : (scalar) True anomaly in degrees          ||
//                                                  ||
// RETURNS:                                         ||
//   Eccentric anomaly in degrees [0, 360].         ||
//==================================================||
function true_anomaly_to_eccentric_anomaly {
    local parameter ta.
    local e is ship:obt:eccentricity.
    local ea to arctan2(
        sqrt(1 - e^2) * sin(ta), 
        e + cos(ta)
    ).
    return angle_wrap(ea).
}

//==================================================||
// FUNCTION: eccentric_anomaly_to_mean_anomaly      ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Converts an eccentric anomaly to the           ||
//   corresponding mean anomaly.                    ||
//                                                  ||
// PARAMETERS:                                      ||
//   ea : (scalar) Eccentric anomaly in degrees     ||
//                                                  ||
// RETURNS:                                         ||
//   Mean anomaly in degrees [0, 360).              ||
//==================================================||
function eccentric_anomaly_to_mean_anomaly {
    local parameter ea.
    local e is ship:obt:eccentricity.
    local ma to ea - e * sin(ea) * constant:radtodeg.
    return angle_wrap(ma).
}

//==================================================||
// FUNCTION: mean_anomaly_to_eccentric_anomaly      ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Solves Kepler's Equation to compute the        ||
//   Eccentric Anomaly (EA) from a given Mean       ||
//   Anomaly (MA), both in degrees.                 ||
//                                                  ||
// PARAMETERS:                                      ||
//   ma : Mean Anomaly in degrees                   ||
//                                                  ||
// RETURNS:                                         ||
//   Eccentric Anomaly in degrees [0, 360)          ||
//                                                  ||
// METHOD:                                          ||
//   Uses Newton-Raphson iteration on:              ||
//     MA = EA - e * sin(EA)                        ||
//   - Internally uses radians for computation      ||
//   - Eccentricity `e` from ship:obt:eccentricity  ||
//   - Stops when ΔEA < 1e-12                       ||
//                                                  ||
// NOTES:                                           ||
//   - Returned EA is in degrees for compatibility  ||
//     with kOS conventions                         ||
//==================================================||

function mean_anomaly_to_eccentric_anomaly {
    local parameter ma.                         // input mean anomaly
    local parameter tol is 1e-12.               // tolerance
    local parameter max_iter is 1000.           // maximum loop iterations.

    local e is ship:obt:eccentricity.           // orbit eccentricity
    local ma_rad to ma * constant:degtorad.     // convert MA to radians

    local ea_rad to ma_rad.                     // Initial guess EA = MA
    local ea_deg to ea_rad * constant:radtodeg. // Also track EA in degrees
    local diff to 1.

    // Newton-Raphson iteration to solve MA = EA - e * sin(EA)
    from { local i is 0. } until i >= max_iter step { set i to i + 1. } do { // Fixed upper bound
        local new_ea_rad to ea_rad - (
            ea_rad - e * sin(ea_deg) - ma_rad
        ) / (1 - e * cos(ea_deg)).

        set diff to abs(new_ea_rad - ea_rad).
        set ea_rad to new_ea_rad.
        set ea_deg to ea_rad * constant:radtodeg.
        if diff < tol {                           // break when tolerance is met
            return angle_wrap(ea_deg). // Wrap angle to [0, 360)
        }
    }

    print "Did not converge".
    return -1.    // Convergence failure.
}

//==================================================||
//    FUNCTION: eccentric_anomaly_to_true_anomaly   ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Converts eccentric anomaly to true anomaly     ||
//   using the orbital eccentricity.                ||
//                                                  ||
// PARAMETERS:                                      ||
//   ea : (scalar) Eccentric anomaly in degrees     ||
//                                                  ||
// RETURNS:                                         ||
//   True anomaly in degrees [0, 360).              ||
//==================================================||
function eccentric_anomaly_to_true_anomaly {
    local parameter ea.
    local e is ship:obt:eccentricity.
    local ta to arctan2(
        sqrt(1 - e^2) * sin(ea), 
        cos(ea) - e
    ).
    return angle_wrap(ta).
}

//==================================================||
//      FUNCTION: time_from_true_anomaly            ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Computes the time required to reach a given    ||
//   true anomaly from the current orbital state.   ||
//                                                  ||
// PARAMETERS:                                      ||
//   targ_ta : (scalar) Target true anomaly (deg)   ||
//                                                  ||
// RETURNS:                                         ||
//   Time in seconds to reach target true anomaly.  ||
//==================================================||
function time_from_true_anomaly {
    // Input: target true anomaly (targ_ta)
    local parameter targ_ta.
    // Current true anomaly, semi-major axis, 
    // eccentricity, and gravitational parameter
    local curr_ta is ship:obt:trueanomaly.
    local a is ship:obt:semimajoraxis.
    local e is ship:obt:eccentricity.
    local mu is body:mu.
    // Compute the eccentric anomaly for current and target true anomalies
    local ea_curr to arctan2(sqrt(1 - e^2) * sin(curr_ta), e + cos(curr_ta)).
    local ea_targ to arctan2(sqrt(1 - e^2) * sin(targ_ta), e + cos(targ_ta)).
    local ea_rad_curr to ea_curr * constant:degtorad.
    local ea_rad_targ to ea_targ * constant:degtorad.
    // Compute the mean anomaly for current and target eccentric anomalies
    local ma_rad_curr to ea_rad_curr - e * sin(ea_curr).
    local ma_rad_targ to ea_rad_targ - e * sin(ea_targ).
    // Mean motion (n) and time calculation
    local n to sqrt(mu / (a^3)).
    local delta_ma to ma_rad_targ - ma_rad_curr.
    // Ensure positive time (wrap around if necessary)
    if delta_ma < 0 {
        set delta_ma to delta_ma + 2 * constant:pi.
    }
    // Time to reach the target true anomaly
    local t to delta_ma / n.
    return t - 0.02. // For some fucking reason time from true anomaly
                      //returns values which are 0.02 s (1 physics tick) ahead, so this is a temporary fix.
}


//==================================================||
//      FUNCTION: angle_wrap                        ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Ensures angle is within range [0, 360) by wrap ||
//   ping the values outside to be inside the range ||
//                                                  ||
// PARAMETERS:                                      ||
//   value : (scalar) Angle in degrees              ||
//                                                  ||
// RETURNS:                                         ||
//   Angle in degrees within [0, 360).              ||
//==================================================||
function angle_wrap {
    local parameter value.
    local result to mod(value,360).
    if result < 0 {
        set result to result + 360.
    }
    return result.
}

//**************************************************||
//--------------------------------------------------||
//                  MANEUVER NODES                  ||
//--------------------------------------------------||
//**************************************************||

//==================================================||
//      FUNCTION: create_node                       ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Creates and schedules a maneuver node using a  ||
//   maneuver vector input.                         ||
//                                                  ||
// PARAMETERS:                                      ||
//   mnv_node : List of 4 values [eta, dv_r, dv_n,  ||
//              dv_p] where:                        ||
//       eta  : Time from now until burn (s)        ||
//       dv_r : Radial delta-V (m/s)                ||
//       dv_n : Normal delta-V (m/s)                ||
//       dv_p : Prograde delta-V (m/s)              ||
//                                                  ||
// BEHAVIOR:                                        ||
//   - If eta < 0 and all delta-V components are 0, ||
//     a warning is printed.                        ||
//   - Otherwise, the maneuver is scheduled.        ||
//==================================================||

function create_node {
    local parameter mnv_node.

    local uts____ is mnv_node[0].
    local radial_ is mnv_node[1].
    local normal_ is mnv_node[2].
    local prograd is mnv_node[3].

    // Warn if maneuver node is null_mnv()
    if mnv_node[0] < 0 {
        if radial_ = 0 and normal_ = 0 and prograd = 0 {
            print("[ NODE ERROR ] : Unable to make maneuver node").
            return.
        }
    }

    // Construct and add the maneuver node
    local maneuver_node to node(
        uts____,
        radial_,
        normal_,
        prograd
    ).
    add maneuver_node.
}

//==================================================||
//      FUNCTION: raw_node                          ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Constructs a maneuver vector list without      ||
//   applying it immediately.                       ||
//                                                  ||
// PARAMETERS:                                      ||
//   eta____ : Time from now until burn (s)         ||
//   radial_ : Radial delta-V (m/s)                 ||
//   normal_ : Normal delta-V (m/s)                 ||
//   prograd : Prograde delta-V (m/s)               ||
//                                                  ||
// RETURNS:                                         ||
//   A list [eta, dv_r, dv_n, dv_p] suitable for    ||
//   use with create_node()                         ||
//==================================================||

function raw_node {
    local parameter eta____.
    local parameter radial_.
    local parameter normal_.
    local parameter prograd.

    local mnv_nd is list(
        eta____ + time:seconds,
        radial_,
        normal_,
        prograd
    ).

    return mnv_nd.
}

//==================================================||
//      FUNCTION: null_mnv                          ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Returns a dummy maneuver vector that signals   ||
//   no action or an invalid maneuver. Useful for   ||
//   error handling. If given an error message,     ||
//   it prints the error message.                   ||
//                                                  ||
// RETURNS:                                         ||
//   List [-1, 0, 0, 0] representing:               ||
//     - eta     = -1 (invalid timing)              ||
//     - dv_r/n/p = 0 (no delta-V)                  ||
//==================================================||

function null_mnv {
    local parameter errormsg is " ".
    local parameter print_error is true.
    if print_error {
        print(errormsg).
    }
    return list(-1, 0, 0, 0).
}

//==================================================||
//      FUNCTION: rotate_vector                     ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Rotates a given vector along a given axis      ||
//   in space                                       ||
//   Uses right hand rule rotation for positives.   ||
//   Uses Rodrigues' formula for vector rotation    ||
//                                                  ||
// PARAMETERS:                                      ||
//      vector: the vector to be rotated            ||
//      angle : magnitude of rotation [deg]         ||
//              counter clockwise is +              ||
//      axis  : vector, the axis of rotation        ||
// RETURNS:                                         ||
//      A new vector rotated by the specified angle ||
//      along the specified axis                    ||
//==================================================||
function rotate_vector {
    local parameter vector.
    local parameter angle.
    local parameter axis.

    set axis to axis:normalized.
    local rVec to (
        vector * cos(angle) + 
        vCrs(vector,axis) * sin(angle) + 
        axis * vDot(axis,vector)* (1 - cos(angle))
    ).
    return rVec. 
}


//==================================================||
//      FUNCTION: inertial_to_PRN                   ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//      Converts a vector in inertial cartesian     ||
//      reference frame to to a vector              ||
//      in prograde-radial-normal basis relative    ||
//      to the spacecraft, so one can easily convert||
//      dV vectors into maneuver nodes              ||
//                                                  ||
// PARAMETERS:                                      ||
//      vector: the vector to be converted          ||
//      uts   : univesal time of the entire kunivers||
//      with time: return result with uts or not    ||
//   (so it can be pushed to a create node directly)||
//               : default, true.                   ||
// RETURNS:                                         ||
//      A list containing:                          ||
//          uts: universal time [possible to turn off]
//         dv_r: radial component of vector         ||
//         dv_n: normal component of vector         ||
//         dv_p: prograde component of vector       ||
//==================================================||
function inertial_to_PRN {
    local parameter vector.
    local parameter uts.
    local parameter with_time is true.      // return results with ut

    local u_pv is velocityAt(ship,uts):orbit:normalized.                    // prograde unit vector
    local u_nv is vCrs(u_pv,positionAt(ship,uts):normalized):normalized.    // normal unit vector
    local u_rv is vCrs(u_nv,u_pv):normalized.                               // radial unit vector

    local dv_p is vdot(vector, u_pv).               // vector components in upv frame
    local dv_r is vdot(vector, u_rv).               // vector components in urv frame
    local dv_n is vdot(vector, u_nv).               // vector components in unv frame

    if with_time {
        return list(uts, dv_r, dv_n, dv_p).
    } else {
        return list(dv_r, dv_n, dv_p).
    }
}

//==================================================||
//      FUNCTION: true_anomaly_at_ut                ||
//--------------------------------------------------||
// PURPOSE:                                         || 
//      Returns the ship true anomaly after given   ||
//      universal time                              ||
//                                                  ||
// PARAMETERS:                                      ||
//      ut : universal kuniverse time.              ||
// RETURNS:                                         ||
//      nu : the true anomaly [0,360]               ||
//==================================================||
function true_anomaly_at_ut {
    local parameter ut.
    local P_vec is (positionat(ship, eta:periapsis + time:seconds) - body:position):normalized.
    local H_vec is vCrs(velocityAt(ship, eta:periapsis + time:seconds):orbit,P_vec):normalized.
    local Q_vec is vCrs(P_vec, H_vec):normalized.
    local R_vec is positionat(ship,ut) - body:position.
    local nu is vang(R_vec,P_vec).
    if vdot(R_vec,Q_vec) < 0 {
        set nu to 360 - nu.
    }
    return nu.
}

//==================================================||
//      FUNCTION: orbit_inertial_position           ||
//--------------------------------------------------||
// PURPOSE:                                         || 
//      Calculates the position of the ship         ||
//      at a certain true anomaly                   ||
//      relative to inertial reference frame        ||
// PARAMETERS:                                      ||
//      true_anomaly                                ||
//      semimajoraxis (optional)                    ||
//      eccentricity  (optional)                    ||
//      argument of periapsis (optional)            ||                   
// RETURNS:                                         ||
//      the inertial cartesian position of the ship ||
//      at the true anomaly                         ||
//==================================================||
function orbit_inertial_position {
    local parameter true_anomaly.
    local parameter semi_major_axis       is obt:semimajoraxis.
    local parameter eccentricity          is obt:eccentricity.
    local parameter argument_of_periapsis is obt:argumentofperiapsis.

    local rotation is argument_of_periapsis - obt:argumentofperiapsis.
    // Perifocal frame
    local P_vec is (positionat(ship, eta:periapsis + time:seconds) - body:position):normalized.
    local H_vec is vCrs(velocityAt(ship, eta:periapsis + time:seconds):orbit,P_vec):normalized.
    local Q_vec is vCrs(P_vec, H_vec):normalized.

    local rad_Pos is semi_major_axis * (1 - eccentricity^2) / ( 1 + eccentricity * cos(true_anomaly)).
    return rad_Pos * (
        cos(true_anomaly + rotation) * P_vec + 
        sin(true_anomaly + rotation) * Q_vec
    ).
}

// transform a given vector to a true anomaly.
function vector_to_true_anomaly {
    local parameter vector. // relative to body.

    local P_vec is (positionat(ship, eta:periapsis + time:seconds) - body:position):normalized.
    local H_vec is vCrs(velocityAt(ship, eta:periapsis + time:seconds):orbit,P_vec):normalized.
    local Q_vec is vCrs(P_vec, H_vec):normalized.
    set vector to vxcl(H_vec, vector).

    local angle is vang(vector,P_vec).
    if vdot(vector,Q_vec) < 0 {
        return 360 - angle.
    }
    return angle.
}

//==================================================||
//      FUNCTION: orbit_inertial_velocity           ||
//--------------------------------------------------||
// PURPOSE:                                         || 
//      Calculates the velocity of the ship         ||
//      at a certain true anomaly                   ||
//      relative to inertial reference frame        ||
//      Can be used to get velocities of different  ||
//      orbits to calculate node dV                 ||
// PARAMETERS:                                      ||
//      true_anomaly                                ||
//      semimajoraxis (optional)                    ||
//      eccentricity  (optional)                    ||
//      argument of periapsis (optional)            ||                   
// RETURNS:                                         ||
//      the inertial cartesian velocity of the ship ||
//      at the true anomaly                         ||
//==================================================||
function orbit_inertial_velocity {
    local parameter true_anomaly.
    local parameter semi_major_axis       is obt:semimajoraxis.
    local parameter eccentricity          is obt:eccentricity.
    local parameter argument_of_periapsis is obt:argumentofperiapsis.

    local rotation is argument_of_periapsis - obt:argumentofperiapsis.
    local P_vec is (positionat(ship, eta:periapsis + time:seconds) - body:position):normalized.
    local H_vec is vCrs(velocityAt(ship, eta:periapsis + time:seconds):orbit,P_vec):normalized.
    local Q_vec is vCrs(P_vec, H_vec):normalized.
    local semilatus_rectum is  semi_major_axis * (1 - eccentricity^2).

    return sqrt(body:mu / semilatus_rectum) * (
        (- sin(true_anomaly + rotation) - eccentricity * sin(rotation)) * P_vec +
        (  cos(true_anomaly + rotation) + eccentricity * cos(rotation)) * Q_vec
    ).
}
//==================================================||
//      FUNCTION: circularize                       ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Calculates the delta-v vector required to      ||
//   circularize an orbit under various conditions. ||
//                                                  ||
// MODES SUPPORTED:                                 ||
//   - "at periapsis"       : Burn at periapsis     ||
//   - "at apoapsis"        : Burn at apoapsis      ||
//   - "at altitude"        : Burn at given altitude||
//   - "after fixed time"   : Burn after time delay ||
//                                                  ||
// PARAMETERS:                                      ||
//   mode  : (string) Method of circularization     ||
//   value : (optional, numeric) Mode-dependent:    ||
//             "at altitude" -> target altitude (m) ||
//             "after fixed time" -> delay time (s) ||
//                                                  ||
// RETURNS:                                         ||
//   A maneuver node vector [eta, radial, normal,   ||
//   prograde] or null_mnv() if operation fails.    ||
//==================================================||
function circularize {
    local parameter mode.
    local parameter value is 0. // Optional mode-specific value

    // Mode 1: Circularize at Periapsis
    if mode = "at periapsis" {
        local periapsis_dV is 
            orbital_velocity_circular(ship:periapsis) -
            vis_viva_equation(ship:periapsis, ship:orbit:semimajoraxis).
        return list(eta:periapsis + time:seconds, 0, 0, periapsis_dV).
    }

    // Mode 2: Circularize at Apoapsis
    if mode = "at apoapsis" {
        local apoapsis_dV is 
            orbital_velocity_circular(ship:apoapsis) -
            vis_viva_equation(ship:apoapsis, ship:orbit:semimajoraxis).
        return list(eta:apoapsis + time:seconds, 0, 0, apoapsis_dV).
    }

    local function compute_circularization_dv {
        local parameter uts.
 
        // Predict ship's position and velocity at future time
        local pos_vec is positionat(ship, uts) - body:position.
        local vel_vec is velocityat(ship, uts):orbit.

        // Desired circular velocity at the predicted radius
        local circ_vel is orbital_velocity_circular(pos_vec:mag, "radius").

        // Vector exclude the velocity from the position vector to find the planar velocity.
        // Normalize to find unit vector, then multiply by desired circvel.
        local targ_vec is vxcl(pos_vec, vel_vec):normalized * circ_vel.
        local dv_vec is targ_vec - vel_vec.
        return inertial_to_PRN(dv_vec, uts).
    }

    // Mode 3: Circularize at Specified Altitude
    if mode = "at altitude" {
        local target_alt is value.

        // Check if altitude is reachable
        if (target_alt < ship:obt:periapsis) or (target_alt > ship:obt:apoapsis) {
            return null_mnv("[ ALT  ERROR ] : Altitude unreachable").
        }

        // Determine true anomaly and time to reach target altitude
        local target_true_anomaly is radius_to_true_anomaly(target_alt).
        local t_ is time_from_true_anomaly(target_true_anomaly).
        local future_t is time:seconds + t_.
        return compute_circularization_dv(future_t).
    }

    // Mode 4: Circularize After Fixed Time
    if mode = "after fixed time" {
        local t_ is value.
        local future_t is time:seconds + t_.
        return compute_circularization_dv(future_t).
    }

    if mode = "at equatorial AN" {
        local trueanomaly is 360 - obt:argumentofperiapsis.
        local future_t is time_from_true_anomaly(trueanomaly) + time:seconds.
        return compute_circularization_dv(future_t).
    }
    if mode = "at equatorial DN" {
        local trueanomaly is 180 - obt:argumentofperiapsis.
        local future_t is time_from_true_anomaly(trueanomaly) + time:seconds.
        return compute_circularization_dv(future_t).
    }
    return null_mnv(mode_error_message+ mode).
}

//==================================================||
//      FUNCTION: change_eccentricity               ||
//--------------------------------------------------||
// PURPOSE:                                         || 
//   Adjusts the eccentricity of the current orbit  ||
//   by modifying apoapsis or periapsis depending   ||
//   on the specified mode of operation. Works      ||
//   relative to the central body's radius.         ||
//                                                  ||
// PARAMETERS:                                      ||
//   targ_eccentricity : (scalar) Target orbital    ||
//                      eccentricity                ||
//   mode              : (string) Mode for how the  ||
//                      eccentricity should be      ||
//                      changed. Options include:   ||
//                        - "at periapsis"          ||
//                        - "at apoapsis"           ||
//                        - "after fixed time"      ||
//                        - "at altitude"           ||
//   value             : (scalar) Reserved/optional ||
//                      input, default is 0         ||
//                                                  ||
// RETURNS:                                         ||
//   Maneuver node to execute eccentricity change,  ||
//   or null maneuver node if unsupported mode.     ||
//==================================================||
function change_eccentricity {
    local parameter targ_eccentricity.
    local parameter mode.
    local parameter value is 0.

    local r_a is obt:apoapsis + body:radius.
    local r_p is obt:periapsis + body:radius.
    
    if mode = "at periapsis" {
        set r_a to r_p * (1 + targ_eccentricity) / (1 - targ_eccentricity).
        return change_apoapsis(r_a - body:radius, mode).
    }
    if mode = "at apoapsis" {
        set r_p to r_a * (1 - targ_eccentricity) / (1 + targ_eccentricity).
        return change_periapsis(r_p - body:radius, mode).
    }
    
    local function compute_dv {
        local parameter ut.

        // Predict ship's position and velocity at future time
        local p1 is (positionat(ship, ut) - body:position).
        local v1 is velocityat(ship, ut):orbit.
        local rmag is p1:mag.
        local nu is true_anomaly_at_ut(ut).
        
        local e2 is targ_eccentricity.
        if e2 < 0 {
            return null_mnv("[ ORBT ERROR ] : Negative eccentricity not allowed").
        } 
        local a2 is rmag * (1 + e2 * cos(nu)) / ( 1 - e2^2).
        local v2 is orbit_inertial_velocity(nu,a2,e2).
        local dv is v2 - v1.
        return inertial_to_PRN(dv, ut).
    }
    if mode = "at altitude" {
        local target_alt is value.
        local target_true_anomaly is radius_to_true_anomaly(target_alt).
        local t_ is time_from_true_anomaly(target_true_anomaly).
        local future_t is time:seconds + t_.
        return compute_dv(future_t).
    }
    if mode = "after fixed time" {
        local t_ is value.
        local future_t is time:seconds + t_.
        return compute_dv(future_t).
    }
    if mode = "at equatorial AN" {
        local trueanomaly is 360 - obt:argumentofperiapsis.
        local future_t is time_from_true_anomaly(trueanomaly) + time:seconds.
        return compute_dv(future_t).
    }
    if mode = "at equatorial DN" {
        local trueanomaly is 180 - obt:argumentofperiapsis.
        local future_t is time_from_true_anomaly(trueanomaly) + time:seconds.
        return compute_dv(future_t).
    }
    return null_mnv( mode_error_message + mode).
}

//==================================================||
//      FUNCTION: change_apoapsis                   ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Calculates the required delta V                ||
//   to adjust the apoapsis of the current orbit.   ||
//   Can compute the maneuver at periapsis, apoapsis||
//   after a fixed time, or when reaching a target  ||
//   altitude. Handles orbit propagation to predict ||
//   the ship's position and velocity as needed.    ||
//                                                  ||
// PARAMETERS:                                      ||
//   target_apoapsis : (scalar) Target apoapsis in  ||
//                     meters above the central body||
//   mode            : (string) Mode for computing  ||
//                     the maneuver. Options include||
//                       - "at periapsis"           ||
//                       - "at apoapsis"            ||
//                       - "after fixed time"       ||
//                       - "at altitude"            ||
//                       - "at equatorial DN"       ||
//                       - "at equatorial AN"       ||
//   value           : (scalar) Optional parameter, ||
//                     used for time or altitude.   ||
//                                                  ||
// RETURNS:                                         ||
//   List containing the maneuver components.       ||
//   Returns a null maneuver node if the requested  ||
//   mode is unsupported or the target is invalid.  ||
//==================================================||
function change_apoapsis {
    local parameter target_apoapsis.
    local parameter mode.
    local parameter value is 0.
    if mode = "at periapsis" {
        if target_apoapsis < ship:periapsis {
            return null_mnv(
                "[ ALT  ERROR ] : Target apoapsis should be "+
                "bigger than current periapsis"
            ).
        }
        local periapsis_dV is ( 
            vis_viva_equation(
                ship:periapsis, 
                calculate_semimajor_axis(
                    target_apoapsis, 
                    ship:periapsis)
            ) - vis_viva_equation(
                ship:periapsis,
                ship:orbit:semimajoraxis
            )
        ).
        return list(
            eta:periapsis + time:seconds, 
            0,
            0, 
            periapsis_dV
        ).
    }
    if mode = "at apoapsis" {
        if target_apoapsis < ship:apoapsis {
            return null_mnv(
                "[ ALT  ERROR ] : target apoapsis must be "+
                "bigger than current apoapsis"
            ).
        }
        local apoapsis_dV is ( 
            vis_viva_equation(
                ship:apoapsis, 
                calculate_semimajor_axis(
                    target_apoapsis, 
                    ship:apoapsis)
            ) - vis_viva_equation(
                ship:apoapsis,
                ship:orbit:semimajoraxis
            )
        ).
        return list(
            eta:apoapsis + time:seconds, 
            0,
            0, 
            apoapsis_dV
        ).
    }
    local function compute_dv {
        local parameter ut.

        local nu is true_anomaly_at_ut(ut).
        local r1 is positionAt(ship,ut) - body:position.
        local v1 is velocityAt(ship,ut):orbit.
        local rmag is r1:mag.
        local ap2 is target_apoapsis + body:radius.
        local e2 is (ap2 - rmag) / (rmag * cos(nu) + ap2).
        if (e2 < 0) or (e2 >= 1) {
            return null_mnv("[ ORBT ERROR ] : Orbit unachievable under current parameters. Resulting e ="+ e2).
        }
        local a2 is ap2 / (1 + e2).
        local v2 is orbit_inertial_velocity(nu,a2,e2).
        local dV is v2 - v1.
        return inertial_to_PRN(dV,ut).
    }
    if mode = "at altitude" {
        local target_alt is value.
        local trueanomaly is radius_to_true_anomaly(target_alt).
        local future_t is time_from_true_anomaly(trueanomaly) + time:seconds.
        return compute_dv(future_t).
    }
    if mode = "after fixed time" {
        local t_ is value.
        local future_t is t_ + time:seconds.
        return compute_dv(future_t).
    }
    if mode = "at equatorial AN" {
        local trueanomaly is 360 - obt:argumentofperiapsis.
        local future_t is time_from_true_anomaly(trueanomaly) + time:seconds.
        return compute_dv(future_t).
    }
    if mode = "at equatorial DN" {
        local trueanomaly is 180 - obt:argumentofperiapsis.
        local future_t is time_from_true_anomaly(trueanomaly) + time:seconds.
        return compute_dv(future_t).
    }
    return null_mnv(mode_error_message+ mode).
}

//==================================================||
//      FUNCTION: change_periapsis                  ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Calculates the required delta V                ||
//   to adjust the periapsis of the current orbit.  ||
//   Can compute the maneuver at periapsis, apoapsis||
//   after a fixed time, or when reaching a target  ||
//   altitude. Handles orbit propagation to predict ||
//   the ship's position and velocity as needed.    ||
//                                                  ||
// PARAMETERS:                                      ||
//   target_apoapsis : (scalar) Target periapsis in ||
//                     meters above the central body||
//   mode            : (string) Mode for computing  ||
//                     the maneuver. Options include||
//                       - "at periapsis"           ||
//                       - "at apoapsis"            ||
//                       - "after fixed time"       ||
//                       - "at altitude"            ||
//                       - "at equatorial DN"       ||
//                       - "at equatorial AN"       ||
//   value           : (scalar) Optional parameter, ||
//                     used for time or altitude.   ||
//                                                  ||
// RETURNS:                                         ||
//   List containing the maneuver components.       ||
//   Returns a null maneuver node if the requested  ||
//   mode is unsupported or the target is invalid.  ||
//==================================================||
function change_periapsis {
    local parameter target_periapsis.
    local parameter mode.
    local parameter value is 0.
    if mode = "at apoapsis" {
        if target_periapsis > ship:apoapsis {
            return null_mnv(
                "[ ALT  ERROR ] : Target periapsis should be"+
                "smaller than current apoapsis"
            ).
        }
        local apoapsis_dV is ( 
            vis_viva_equation(
                ship:apoapsis, 
                calculate_semimajor_axis(
                    target_periapsis, 
                    ship:apoapsis)
            ) - vis_viva_equation(
                ship:apoapsis,
                ship:orbit:semimajoraxis
            )
        ).
        return list(
            eta:apoapsis + time:seconds,
            0,
            0, 
            apoapsis_dV
        ).
    }
    if mode = "at periapsis" {
        if target_periapsis > ship:periapsis {
            return null_mnv(
                " [ ALT  ERROR ] :"+ 
                "Target periapsis must be smaller"+
                " than current periapsis"
            ).
        }
        local periapsis_dV is (
            vis_viva_equation(
                ship:periapsis,
                calculate_semimajor_axis(
                    ship:periapsis,
                    target_periapsis
                )
            ) -
            vis_viva_equation(
                ship:periapsis,
                ship:orbit:semimajoraxis
            )
        ).
        return list(
            eta:periapsis + time:seconds,
            0,
            0,
            periapsis_dV
        ).
    }
    local function compute_dv {
        local parameter ut.

        local nu is true_anomaly_at_ut(ut).
        local p1 is positionAt(ship,ut) - body:position.
        local rmag is p1:mag.
        local v1 is velocityAt(ship,ut):orbit.
        local e1 is obt:eccentricity.
        local ta is obt:trueanomaly.
        local rp2 is target_periapsis + body:radius.
        if (e1 > 1) and (ta > 0){
            return null_mnv("[ TIME ERROR ] : Ship is past the point of pe adjustment for hyperbolic orbit").
        }
        local e2 is (rp2 - rmag) / (rmag * cos(nu) - rp2).
        if e2 < 0 {
            return null_mnv("[ ORBT ERROR ] : Desired orbit not possible. Resulting e = " + e2).
        }
        local a2 is rp2 / (1 - e2).
        local v2 is orbit_inertial_velocity(nu,a2,e2).
        local dV is v2 - v1.
        return inertial_to_PRN(dV,ut).
    }
    if mode = "at altitude" {
        local target_alt is value.
        local target_true_anomaly is radius_to_true_anomaly(target_alt).
        local future_t is time_from_true_anomaly(target_true_anomaly) + time:seconds.
        return compute_dv(future_t).
    }
    if mode = "after fixed time" {
        local t_ is value.
        local future_t is t_ + time:seconds.
        return compute_dv(future_t).
    }
    if mode = "at equatorial AN" {
        local trueanomaly is 360 - obt:argumentofperiapsis.
        local future_t is time_from_true_anomaly(trueanomaly) + time:seconds.
        return compute_dv(future_t).
    }
    if mode = "at equatorial DN" {
        local trueanomaly is 180 - obt:argumentofperiapsis.
        local future_t is time_from_true_anomaly(trueanomaly) + time:seconds.
        return compute_dv(future_t).
    }
    return null_mnv(mode_error_message+ mode).
}

//==================================================||
//      FUNCTION: change_inclination                ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Computes delta-V vector and timing to achieve  ||
//   a desired orbital inclination.                 ||
//                                                  ||
// PARAMETERS:                                      ||
//   target_inclination : Desired inclination (°)   ||
//   mode               : Where to perform the burn:||
//     - "at AN"            : Ascending Node        ||
//     - "at DN"            : Descending Node       ||
//     - "at nearest node"  : Soonest node (AN/DN)  ||
//     - "at cheapest node" : Least delta-V cost    ||
//     - "after fixed time" : (not implemented yet) ||
//                                                  ||
// RETURNS:                                         ||
//   A list containing:                             ||
//     [0] Time until burn (s)                      ||
//     [1] Radial delta-V (m/s)                     ||
//     [2] Normal delta-V (m/s)                     ||
//     [3] Prograde delta-V (m/s)                   ||
//   Or null_mnv() if mode is invalid.              ||
//                                                  ||
// METHOD:                                          ||
//   1. Finds AN/DN times and velocities            ||
//   2. Calculates required inclination correction  ||
//   3. Decomposes delta-V into orbital frame axes  ||
//==================================================||
function change_inclination {
    local parameter target_inclination.
    local parameter mode.

    local current_inclination is obt:inclination.
    local delta_inc is target_inclination - current_inclination.

    local an_ta is 360 - obt:argumentofperiapsis.
    local dn_ta is 180 - obt:argumentofperiapsis.
    local t_an is time_from_true_anomaly(an_ta) + time:seconds.
    local t_dn is time_from_true_anomaly(dn_ta) + time:seconds.
    local vel_vec_an is velocityat(ship,t_an):orbit.
    local vel_vec_dn is velocityat(ship,t_dn):orbit.
    local delta_v_mag_an is 2 * vel_vec_an:mag * sin(abs(delta_inc) / 2).
    local delta_v_mag_dn is 2 * vel_vec_dn:mag * sin(abs(delta_inc) / 2).

    local function compute_dv {
        local parameter isAN.
        local ut is t_an.
        local rad_vector is positionAt(ship,t_an) - body:position.
        local vel_vector is vel_vec_an.
        if not isAN {
            set rad_vector to positionAt(ship,t_dn) - body:position.
            set vel_vector to vel_vec_dn.
            set delta_inc to - delta_inc.
            set ut to t_dn.
        } 
        local rotVector is rotate_vector(vel_vector, delta_inc, rad_vector).
        local deltaV is rotVector - vel_vector.
        return inertial_to_PRN(deltaV, ut).
    }

    if mode = "at AN" {
        return compute_dv(true).
    }
    if mode = "at DN" {
        return compute_dv(false).
    }
    if mode = "at nearest node" {
        if t_an < t_dn {
            return compute_dv(true).
        } else {
            return compute_dv(false).
        }
    }
    if mode = "at cheapest node" {
        if delta_v_mag_an < delta_v_mag_dn {
            return compute_dv(true).
        } else {
            return compute_dv(false).
        }
    }
    if mode = "at altitude" {
        // not yet implemented
        // besides, who the fuck changes inclination in an arbitrary point anyway
        // it acompplishes nothing, it's inneficient and wasteful
        // the only time you do it is when matching inclination with a target
        // but you already have the target to follow at that point.
        // retarded mode. 
    }
    if mode = "after fixed time" {
        // Not implemented yet
        print "after fixed time mode not implemented yet".
    }
    return null_mnv(mode_error_message+ mode).
}


//==================================================||
//      FUNCTION: change_LAN                        ||
//--------------------------------------------------||
//  Calculates delta-V required to change LAN       ||
//  Parameters:                                     ||
//    - target_lan: desired LAN in degrees          ||
//    - mode: where to perform the burn             ||
//      Options: "at periapsis", "at apoapsis",     ||
//      "at nearest apsis", "at cheapest apsis",    ||
//      "at north peak latitude",                   ||
//      "at south peak latitude",                   ||
//      "at nearest peak latitude",                 ||
//      "at cheapest peak latitude"                 ||
//==================================================||
function change_LAN {
    local parameter target_lan.
    local parameter mode.

    local currentLAN is obt:longitudeofascendingnode.
    local ANta is 360 - obt:argumentofperiapsis.
    local northLatTA is ANta + 90.
    local southLatTA is ANta + 270.
    
    local currentTA   is obt:trueanomaly.
    local distToPeri  is min(abs(currentTA - 0), 360 - abs(currentTA - 0)).
    local distToApo   is min(abs(currentTA - 180), 360 - abs(currentTA - 180)).
    local distToNorth is min(abs(currentTA - northLatTA), 360 - abs(currentTA - northLatTA)).
    local distToSouth is min(abs(currentTA - southLatTA), 360 - abs(currentTA - southLatTA)).

    // Helper: Compute delta-V at a given true anomaly
    local function compute_deltaLAN_at_TA {
        local parameter burn_TA.                   // true anomaly where burn occurs
        local parameter is_peak is false.          // true if burn_TA is a peak latitude
        local parameter cartdV_return is false.    // true if we want inertial cartesian dV
        local parameter is_inverse is false.

        // Times for key orbital positions
        local t_AN   is time_from_true_anomaly(ANta) + time:seconds.        // time from ascending node
        local t_NLat is time_from_true_anomaly(northLatTA) + time:seconds.  // time from north peak latitude
        local t_SLat is time_from_true_anomaly(southLatTA) + time:seconds.  // time from south peak latitude
        local t_peri is eta:periapsis + time:seconds.                       // time from periapsis
        local t_apo  is eta:apoapsis  + time:seconds.                       // time from apoapsis
        // Position/velocity vectors at key points
        local ANvec   is positionAt(ship, t_AN)   - body:position.
        local NLatVec is positionAt(ship, t_NLat) - body:position.
        local SLatVec is positionAt(ship, t_SLat) - body:position.
        local periVec is positionAt(ship, t_peri) - body:position.
        local apoVec  is positionAt(ship, t_apo)  - body:position.
        // Basis vectors for the universe, north direction.
        local Zv is (latlng(90,0):position - body:position):normalized.
        // local XV is solarPrimeVector:normalized.
        // Position and velocity at burn location
        local ANvelV is velocityAt(ship, t_AN):orbit.       // velocity at AN
        local hVec is vCrs(ANvelV, ANvec):normalized.       // angular momentum vector

        // Determine the turn axis based on burn location
        local turnAxis is v(0,0,0).
        if is_peak {
            if abs(burn_TA - northLatTA) < 0.1 {
                set turnAxis to NLatVec.
            } else if abs(burn_TA - southLatTA) < 0.1 {
                set turnAxis to SLatVec.
            }
        } else {
            if abs(burn_TA - 0) < 0.1 {
                set turnAxis to periVec.
            } else if abs(burn_TA - 180) < 0.1 {
                set turnAxis to apoVec.
            }
        }
 
        // Calculate required rotation
        local deltaLAN is target_lan - currentLAN.                      // calculate change in lan
        local new_ANvec is rotate_vector(ANvec, deltaLAN, Zv).          // rotate the lan vector to deltalan
        local projNew_ANvec is vxcl(turnAxis, new_ANvec):normalized.    // project that to the plane of the vector of the turn axis
        local projtoH_angle is vang(projNew_ANvec, hvec).               // get the angle from h
        local rotateAngle to projtoH_angle - 90.                        // rotate the vel vector by negative complement
        if is_peak {    
            if is_inverse {                                             // if south, negate.
                set rotateAngle to - rotateAngle.
            }
        } else {    
            if obt:argumentofperiapsis >= 180 {
                set rotateAngle to - rotateAngle.                       // if south, negate.
            }
            if is_inverse {
                set rotateAngle to - rotateAngle.                       // if apoapsis, negate the action on the periapsis
            }
        }
        // Get velocity at burn location and rotate it
        local burnVelVec is velocityAt(ship, time_from_true_anomaly(burn_TA) + time:seconds):orbit.
        local newBurnVelVec is rotate_vector(burnVelVec, rotateAngle, turnAxis).
        // Calculate delta-V
        local deltaV is newBurnVelVec - burnVelVec.
        if cartdV_return {
            return deltaV.
        } else {
            return inertial_to_PRN(deltaV, time_from_true_anomaly(burn_TA) + time:seconds).
        }
    }

    // Helper: Get delta-V magnitude at apsis
    local function get_apsis_deltaV_magnitude {
        local parameter at_periapsis.
        local burnTA is 0.
        if not at_periapsis { set burnTA to 180. }
        local deltaV_vec is compute_deltaLAN_at_TA(burnTA, false, true).
        return deltaV_vec:mag.
    }

    // Helper: Get delta-V magnitude at peak latitude
    local function get_peak_deltaV_magnitude {
        local parameter use_north.
        local burnTA is ANta + 90.
        if not use_north { set burnTA to ANta + 270. }
        local deltaV_vec is compute_deltaLAN_at_TA(burnTA, true, true).
        return deltaV_vec:mag.
    }

    if mode = "at periapsis" {
        return compute_deltaLAN_at_TA(0, false).
    }
    if mode = "at apoapsis" {
        return compute_deltaLAN_at_TA(180, false, false, true).
    }
    if mode = "at nearest apsis" {
        if distToPeri <= distToApo {
            return compute_deltaLAN_at_TA(0, false).
        } else {
            return compute_deltaLAN_at_TA(180, false, false, true).
        }
    }
    if mode = "at cheapest apsis" {
        local deltaV_peri is get_apsis_deltaV_magnitude(true).
        local deltaV_apo  is get_apsis_deltaV_magnitude(false).
        if deltaV_peri < deltaV_apo {
            return compute_deltaLAN_at_TA(0, false).
        } else {
            return compute_deltaLAN_at_TA(180, false).
        }
    }
    if mode = "at north peak latitude" {
        return compute_deltaLAN_at_TA(northLatTA, true).
    }
    if mode = "at south peak latitude" {
        return compute_deltaLAN_at_TA(southLatTA, true, false, true).
    }
    if mode = "at nearest peak latitude" {
        if distToNorth <= distToSouth {
            return compute_deltaLAN_at_TA(northLatTA, true).
        } else {
            return compute_deltaLAN_at_TA(southLatTA, true).
        }
    }
    if mode = "at cheapest peak latitude" {
        local deltaV_north is get_peak_deltaV_magnitude(true).
        local deltaV_south is get_peak_deltaV_magnitude(false).
        if deltaV_north <= deltaV_south {
            return compute_deltaLAN_at_TA(northLatTA, true).
        } else {
            return compute_deltaLAN_at_TA(southLatTA, true, false, true).
        }
    }
    return null_mnv( mode_error_message + mode).
}
//==================================================||
//      FUNCTION: change_pe_and_ap                  ||
//--------------------------------------------------||
//
//--------------------------------------------------||
function change_pe_and_ap {
    local parameter new_pe.
    local parameter new_ap.
    local parameter mode.

    local targ_ap is new_ap + body:radius.
    local targ_pe is new_pe + body:radius.
    local e_targ is (targ_ap - targ_pe) / (targ_ap + targ_pe).
    local a_targ is (new_pe + new_ap) / 2 + body:radius.
    
    local function compute_dv {
        local parameter gtr is false.

        local e1 is obt:eccentricity.
        local a1 is obt:semimajoraxis.
        local e2 is e_targ.
        local a2 is a_targ.
        local p1 is a1 * (1 - e1^2).
        local p2 is a2 * (1 - e2^2).
        local nu is 0.
        if p1 * e2 = p2 * e1 {
            return null_mnv("[ ORBT ERROR ] : Same orbit, no change").
        }
        local cos_nu is ( (p2 - p1) / (p1 * e2 - p2 * e1) ).
        if abs(cos_nu > 1) {
            return null_mnv("[ ORBT ERROR ] : Orbit not possible with current parameters").
        }
        if abs(cos_nu) = 1 {
            // single point intersection
            return null_mnv("[ ORBT ERROR ] : Single point intersection, use change_apoapsis() or change_periapsis() instead").
        }
        if abs(cos_nu) < 1 {
            // nu choosing logic here
            set nu to arcCos(cos_nu).
            if gtr {
                set nu to 360 - nu.
            } 
        }
        local v1 is orbit_inertial_velocity(nu,a1,e1).
        local v2 is orbit_inertial_velocity(nu,a2,e2).
        local dV is v2 - v1.
        return inertial_to_PRN(dV,time_from_true_anomaly(nu)+ time:seconds).

    }
    // not possible to manipulate using time and alts, there are only precisely 
    // 2 or 1 point where two distinct orbits of different pe and ap
    // intersect, and we cannot control it. Best we can do is choose where to do it.
    // no difference in cheapness, dV is the same regardless.
    if mode = "nearest" {
        if obt:trueanomaly > 180 {
            return compute_dv(true).
        } else {
            return compute_dv(false).
        }
      
    }
    if mode = "first half" { // curent orbit true anomally 0 - 180
        return compute_dv(false).
    }
    if mode = "second half" { // current orbit true anomaly 180 - 360 
        return compute_dv(true).
    }
    else {
        return null_mnv(mode_error_message+mode).
    }
}

//==================================================||
//      FUNCTION: return_from_a_moon                ||
//--------------------------------------------------||
//
//--------------------------------------------------||
function return_from_a_moon {
    // local parameter target_periapsis.
    // requires hyperbolic functionalities 
} 

//==================================================||
//      FUNCTION: change_semimajoraxis              ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Changes the semi-major axis of the current     ||
//   orbit to a target value by modifying either    ||
//   the periapsis or apoapsis.                     ||
//                                                  ||
// PARAMETERS:                                      ||
//   target_smja : (scalar) Target semi-major axis  ||
//   mode        : (string) Either "at periapsis",  ||
//                 "at apoapsis", "at altitude",    ||
//                 or "after fixed time"            ||
//                                                  ||
// RETURNS:                                         ||
//   A maneuver node that changes the orbit's       ||
//   semi-major axis to the desired value.          ||
//==================================================||
function change_semimajoraxis {
    local parameter target_smja.
    local parameter mode.
    local parameter value is 0.

    local r_a is obt:apoapsis  + body:radius.
    local r_p is obt:periapsis + body:radius.

    if mode = "at periapsis" {
        set r_a to 2 * target_smja - r_p. 
        set r_a to r_a - body:radius.
        if r_a >= ship:periapsis {
            return change_apoapsis(r_a, mode).
        } else if r_a < ship:periapsis {
            return change_periapsis(r_a, mode).
        }
    }

    if mode = "at apoapsis" {
        set r_p to 2 * target_smja - r_a.
        set r_p to r_p - body:radius.
        if r_p < ship:apoapsis {
            return change_periapsis(r_p, mode).
        } else if r_p >= ship:apoapsis {
            return change_apoapsis(r_p, mode).
        }
        
    }
    local function compute_dv {
        local parameter ut.

        local pos is positionAt(ship,ut) - body:position.
        local v1  is velocityAt(ship,ut):orbit.
        local nu is true_anomaly_at_ut(ut).
        local rmag is pos:mag.
        local discriminant is (rmag * cos(nu))^2 - 4 * target_smja * (rmag - target_smja).
        local e2 is 0.
        if discriminant < 0 {
            return null_mnv("[ ORBT ERROR] : No orbit possible with the given parameters").
        }
        if target_smja >= 0 {
            set e2 to (- rmag * cos(nu) + sqrt(discriminant))/(2*target_smja).
        }
        if target_smja < 0 {
            set e2 to (- rmag * cos(nu) - sqrt(discriminant))/(2*target_smja).
        }
        if (e2 < 0) or (e2 > 1) {
            return null_mnv("[ ORBT ERROR] : No orbit possible with the given parameters").
        }
        local v2 is orbit_inertial_velocity(nu,target_smja,e2).
        local dV is v2 - v1.
        return inertial_to_PRN(dV,ut).
    }
    if mode = "at altitude" {
        local target_alt is value.
        local target_true_anomaly is radius_to_true_anomaly(target_alt).
        local t_ is time_from_true_anomaly(target_true_anomaly).
        return compute_dv(time:seconds + t_).
    }

    if mode = "after fixed time" {
        local t_ is value.
        return compute_dv(time:seconds + t_).
    }
    return null_mnv(mode_error_message+ mode).
}

//==================================================||
//      FUNCTION: change_resonant_orbit             ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Sets a resonant orbit by changing the          ||
//   semi-major axis such that the orbital period   ||
//   becomes a rational multiple of a reference     ||
//   time (e.g., the body's rotation period).       ||
//                                                  ||
// PARAMETERS:                                      ||
//   target_resonance : (scalar) Desired resonance  ||
//                      (e.g 1/2 means 2 orbits per ||
//                      base_time) or change your   ||
//                      orbital period to 1/2 of    || 
//                      your current one            ||
//   mode             : (string) Burn mode —        ||
//                      "at periapsis",             ||
//                      "at apoapsis",              ||
//                      "after fixed time",         ||
//                      or "at altitude"            ||
//   base_time        : (scalar) Reference time     ||
//                      (defaults to orbiting object||
//                      orbital period )            ||
//   value            : (optional scalar) Only used ||
//                      in modes that require a     ||
//                      reference altitude or time. ||
//                                                  ||
// RETURNS:                                         ||
//   A maneuver node that sets the orbit into the   ||
//   desired resonance.                             ||
//==================================================||
function change_resonant_orbit {
    local parameter target_resonance. 
    local parameter mode. 
    local parameter base_time is obt:period. 
    local parameter value is 0. 

    local T_orbit is base_time * target_resonance.
    local a_resonant is (body:mu * T_orbit^2 / (4 * constant:pi^2))^(1/3).
    
    if mode = "at periapsis" {
        return change_semimajoraxis(a_resonant, mode).
    }

    if mode = "at apoapsis" {
        return change_semimajoraxis(a_resonant, mode).
    }

    if mode = "after fixed time" {
        return change_semimajoraxis(a_resonant, mode, value).
    }

    if mode = "at altitude" {
        return change_semimajoraxis(a_resonant, mode, value).
    }

    return null_mnv(mode_error_message+ mode).
}
//==================================================||
//   FUNCTION: change_argument_of_periapsis         ||
//--------------------------------------------------||
//
//--------------------------------------------------||
function change_argument_of_periapsis {
    local parameter target_w.
    local parameter mode.

    local current_w is obt:argumentofperiapsis.
    local delta_w is target_w - current_w.

    local nu1 is delta_w/2.
    if nu1 < 0 {
        set nu1 to nu1 + 180.
    }
    local nu2 is nu1 + 180.

    local v11 is orbit_inertial_velocity(nu1,obt:semimajoraxis,obt:eccentricity).
    local v21 is orbit_inertial_velocity((nu1 - delta_w),obt:semimajoraxis,obt:eccentricity,target_w).
    local dv1 is v21 - v11.
    local v12 is orbit_inertial_velocity(nu2,obt:semimajoraxis,obt:eccentricity).
    local v22 is orbit_inertial_velocity((nu2 - delta_w),obt:semimajoraxis,obt:eccentricity,target_w).
    local dv2 is v22 - v12.
    local t_nu1 is time_from_true_anomaly(nu1) + time:seconds.
    local t_nu2 is time_from_true_anomaly(nu2) + time:seconds.
  
    if mode = "first half" {
        return inertial_to_PRN(dv1,t_nu1).
    }
    if mode = "second half" {
        return inertial_to_PRN(dv2,t_nu2).
    }
    if mode = "nearest" {
        if t_nu1 < t_nu2 {
            return inertial_to_PRN(dv1,t_nu1).
        } else {
            return inertial_to_PRN(dv2,t_nu2).
        }
    }
    if mode = "cheapest" {
        if dv1:mag < dv1:mag {
            return inertial_to_PRN(dv1,t_nu1).
        } else {
            return inertial_to_PRN(dv2,t_nu2).
        }
    }

}

//==================================================||
//   FUNCTION: change_surface_longitude_of_apsis    ||
//--------------------------------------------------||
//
//--------------------------------------------------||
function change_surface_longitude_of_apsis {
    // local parameter apsis.
    // local parameter targ_longitude.
    // local parameter mode.
    // if mode = "at periapsis" {

    // }
    // if mode = "at apoapsis" {

    // }
    // if mode = "at longitudinal antipode" {

    // }
    // if mode = "after fixed time" {

    // }
    // return null_mnv(mode_error_message+ mode).
}

//**************************************************||
//--------------------------------------------------||
//                 RCS CORRECTIONS                  ||
//--------------------------------------------------||
//**************************************************||
//==================================================||
//      FUNCTION: rcs_corrector                     ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Uses RCS to adjust orbital elements (apoapsis, ||
//   periapsis) to a target value by throttling     ||
//   RCS fore/aft translation until a given         ||
//   tolerance is achieved.                         ||
//                                                  ||
// PARAMETERS:                                      ||
//   mode        : "apoapsis", "periapsis",         ||
//                 or "closest approach" (TODO)     ||
//   tgt_value   : Target value (in meters) to      ||
//                 correct the orbital element to.  ||
//   has_sas     : Manual check if the craft has sas 
//                 capabilities or not
//   tolerance   : (optional) Acceptable error in   ||
//                 meters. Default is 10.           ||
//                                                  ||
// NOTES:                                           ||
// - Will automatically orient to PROGRADE.         ||
// - Will not engage if ISP is 0 or if RCS is       ||
//   disabled.                                      ||
//==================================================||
// DEBUG THIS PIECE OF SHIT.
// WILL FIX THIS
function rcs_corrector {
    local parameter mode.
    local parameter tgt_value.
    local parameter tolerance is 10.
    local parameter has_sas is true.
    
    if has_sas {
        sas on.
        set sasmode to "PROGRADE".
    } else {
        sas off.
        lock steering to ship:prograde.
    }
    rcs off.
    wait until vang(ship:facing:vector, ship:velocity:orbit) < 0.25.
    rcs on.
    if mode = "apoapsis" {
        lock error to ship:obt:apoapsis - tgt_value.
        print(error).
        lock errorsign to error/abs(error).
        lock errorMag to abs(error).
        lock rcs_t to max(0.1,min(1, (errorMag)/tgt_value)).
        until errorMag <= tolerance {
            set ship:control:fore to -errorsign*rcs_t.
            print(-errorsign*rcs_t).
            wait 0.
        }
        shut_down().
    }
    if mode = "periapsis" {
        lock error to ship:obt:periapsis - tgt_value.
        lock errorsign to error/abs(error).
        lock errorMag to abs(error).

        lock rcs_t to max(0.1,min(1,(errorMag)/tgt_value)).
        until errorMag <= tolerance {
            set ship:control:fore to -errorsign*rcs_t.
            wait 0.
        }
        shut_down().
    }
    if mode = "closest approach" {
        // not yet implemented.
    }
    else {
        return.
    }
    local function shut_down {
        set ship:control:fore to 0.
        set ship:control:neutralize to true.
        rcs off.
        return.
    }
}

//**************************************************||
//--------------------------------------------------||
//                   EXECUTE NODE                   ||
//--------------------------------------------------||
//**************************************************||

//==================================================||
//      FUNCTION: execute_node                      ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Executes the current maneuver node using       ||
//   main engine or RCS. Handles warping, pointing, ||
//   and throttle control to ensure precise burn.   ||
//                                                  ||
// PARAMETERS:                                      ||
//   has_sas     : (optional) If true, enables SAS  ||
//                 to lock to MANEUVER              ||
//                 Make FALSE if the craft has no   ||
//                 SAS capabilities or targeting    ||
//                 capabilities                     ||
//                 (i.e. small probes)              ||
//   warp_to_node: (optional) If true, warps to     ||
//                 burn start. Default: ON          ||
//   thruster    : (optional) "engine" (default) or ||
//                 "rcs", depending on which        ||
//                 mode of thrust is preferred      ||
//   has_reac_wheels : manual setting if vehicle    ||
//                  has reaction wheels or not      ||
//                                                  ||
// RETURNS:                                         ||
//   none                                           ||
//                                                  ||
// Method  :                                        ||
//   1. If no thrust is available and using engine, ||
//      it stages.                                  ||
//   2. Aligns the ship toward the maneuver node    ||
//      via SAS or manual steering.                 ||
//   3. Computes the half-burn time for accurate    ||
//      warp and burn alignment.                    ||
//   4. Warps close to the maneuver node and begins ||
//      the burn at the proper time.                ||
//   5. Adjusts throttles until the delta-V is      ||
//      nearly depleted.                            ||
//   6. Cleans up the maneuver node and resets SAS  ||
//      orientation.                                ||
//                                                  ||
// NOTES:                                           ||
// - Auto-stages if main engine thrust = 0.         ||
// - Uses burn time estimation for half-offset burn ||
// - Deletes node after execution.                  ||
// - If RCS selected, assumes constant low thrust.  ||
// - Resets steering/SAS after burn completes.      ||
//==================================================||

function execute_node {
    // Define optional parameters with defaults
    local parameter has_sas is true.
    local parameter warp_to_node is true.
    local parameter thruster is "engine".
    local parameter has_reac_wheels is true.

    local mnv_node is node(0,0,0,0).

    // Store the next maneuver node
    if hasnode {
        set mnv_node to nextNode.
    } else { 
        print("[ NODE ERROR ] : No maneuver node"). 
        return.
    }

    rcs off.
    // If ship has no thrust and thruster is engine-based, stage to activate engines
    if ship:availableThrust = 0 and thruster = "engine" {
        stage.
    }

    // Handle orientation: Use SAS or manual steering
    if has_sas {
        unlock steering.
        sas on.
        wait 0.1. // yield a bit. otherwise it does not align to maneuver.
        set sasMode to "MANEUVER". // Use maneuver alignment mode
    } else {
        sas off.
        lock steering to mnv_node:deltav:vec. // Manually aim using delta-V vector
    }

    // Store initial delta-V for later dot product check
    local init_dv to mnv_node:deltav.

    // Initialize throttle control
    local tset to 0.
    lock throttle to tset.
    local max_acc to 0.
    // Calculate half-burn time based on thruster type
    local half_time is 0.
    if thruster = "engine" {
        set half_time to half_burn_time(mnv_node).
        set max_acc to ship:maxthrust / ship:mass.
    }
    if thruster = "rcs" {
        set half_time to rcs_half_burn_time(mnv_node).
        set max_acc to rcs_total_thrust() / ship:mass.
    }

    // if burn is too close, cancel it.
    if mnv_node:eta < (half_time + 5) {
        print("[ BURN ERROR ] : TIMING MARGIN TOO CLOSE. CANCELLING BURN.").
        wait 5.
        remove nextNode.
        return.
    }
    // Burn state and control flow variables
    local burn_done to false.
    local current_state is "turning to mnv". // Initial state: turn toward maneuver
    // local handlers is lexicon().
    // // BURN CONTROL LOOP
    // handlers:add( // Phase 1: Rotate to maneuver node direction
    //     "turning to mnv",
    //     {
    //         if not has_reac_wheels {
    //             rcs on.
    //         }
    //         if vang(ship:facing:vector, mnv_node:deltav:vec) <= 0.5 {
    //             return "coasting to node". // Ready to warp once aligned
    //         }
    //         return "turning to mnv".
    //     }
    // ).
    // handlers:add( // Phase 2: Warp to just before burn if enabled
    //     "coasting to node",
    //     {
    //         if warp_to_node {
    //             c_warpto(mnv_node:eta - half_time - 10).
    //             return "waiting for node".
    //         }
    //         else {
    //             return "waiting for node".
    //         }
    //     }
    // ).
    // handlers:add ( // Phase 3: Wait until burn start point
    //     "waiting for node",
    //     {
    //         if mnv_node:eta <= half_time {
    //             if thruster = "rcs" {
    //                 rcs on.
    //             }
    //             set current_state to "execute burn".
    //         }
    //         return "waiting for node".
    //     }
    // ).
    // handlers:add (  // Phase 4: Execute the maneuver burn
    //     "execute burn",
    //     {
    //         until burn_done {
    //             // calculate max_acc
    //             if thruster = "engine" {
    //                 set max_acc to ship:maxthrust / ship:mass.
    //             } else if thruster = "rcs" {
    //                 set max_acc to rcs_total_thrust() / ship:mass.
    //             }
    //             // Estimate appropriate throttle based on remaining delta-V
    //             set tset to min(mnv_node:deltav:mag / max_acc, 1).

    //             // Abort burn if the dot product goes negative (overshot)
    //             if vDot(init_dv, mnv_node:deltav) < 0 {
    //                 lock throttle to 0.
    //                 break.
    //             }

    //             // Stop burn when remaining delta-V is small
    //             if mnv_node:deltav:mag < 0.1 {
    //                 wait until vDot(init_dv, mnv_node:deltav) < 0.5.
    //                 lock throttle to 0.
    //                 set burn_done to true.
    //             }
    //             wait 0.
    //         }
    //         return "post burn".
    //     }
    // ).
    // handlers:add ( // Phase 5: Restore SAS and controls after burn
    //     "post burn",
    //     {
    //         rcs off.
    //         if has_sas {
    //             set sasMode to "STABILITYASSIST".
    //         } else {
    //             lock throttle to 0.
    //             unlock steering.
    //             sas on.
    //             set sasMode to "STABILITYASSIST".
    //         }
    //         return "remove mnv". // Final phase
    //     }
    // ).
    // handlers:add ( // Phase 6: Remove the maneuver node
    //     "remove mnv",
    //     {
    //         remove mnv_node.
    //         set current_state to "burn done".
    //     }
    // ).
    // // Main control loop for handling node execution phases
    // until current_state = "burn done" {
    //     local handler is handlers[current_state].
    //     set current_state to handler().
    //     wait 0.
    // }
    until current_state = "burn done" {
        // Phase 1: Rotate to maneuver node direction
        if current_state = "turning to mnv" {
            if not has_reac_wheels {
                rcs on.
            }
            if vang(ship:facing:vector, mnv_node:deltav:vec) <= 0.5 {
                set current_state to "coasting". // Ready to warp once aligned
            }
        }

        // Phase 2: Warp to just before burn if enabled
        if current_state = "coasting" {
            if warp_to_node {
                c_warpto(mnv_node:eta - half_time - 10).
                set current_state to "waiting for node".
            }
            else {
                set current_state to "waiting for node".
            }
        }

        // Phase 3: Wait until burn start point
        if current_state = "waiting for node" {
            if mnv_node:eta <= half_time {
                if thruster = "rcs" {
                    rcs on.
                }
                set current_state to "execute burn".
            }
        }

        // Phase 4: Execute the maneuver burn
        if current_state = "execute burn" {
            until burn_done {
                // calculate max_acc
                if thruster = "engine" {
                    set max_acc to ship:maxthrust / ship:mass.
                } else if thruster = "rcs" {
                    set max_acc to rcs_total_thrust() / ship:mass.
                }
                // Estimate appropriate throttle based on remaining delta-V
                set tset to min(mnv_node:deltav:mag / max_acc, 1).

                // Abort burn if the dot product goes negative (overshot)
                if vDot(init_dv, mnv_node:deltav) < 0 {
                    lock throttle to 0.
                    break.
                }

                // Stop burn when remaining delta-V is small
                if mnv_node:deltav:mag < 0.1 {
                    wait until vDot(init_dv, mnv_node:deltav) < 0.5.
                    lock throttle to 0.
                    set burn_done to true.
                }
                wait 0.
            }
            set current_state to "post burn". // Proceed to cleanup
        }

        // Phase 5: Restore SAS and controls after burn
        if current_state = "post burn" {
            rcs off.
            if has_sas {
                set sasMode to "STABILITYASSIST".
            } else {
                lock throttle to 0.
                unlock steering.
                sas on.
                set sasMode to "STABILITYASSIST".
            }
            set current_state to "remove mnv". // Final phase
        }

        // Phase 6: Remove the maneuver node
        if current_state = "remove mnv" {
            remove mnv_node.
            set current_state to "burn done".
        }

        wait 0.
    }
    return. 
}

//**************************************************||
//--------------------------------------------------||
//                    NAVIGATION                    ||
//--------------------------------------------------||
//**************************************************||
//==================================================||
//      FUNCTION: compass_hdg                       ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Computes the compass heading of the ship's     ||
//   current facing direction relative to the       ||
//   planetary surface (0° = North, 90° = East).    ||
//                                                  ||
// PARAMETERS:                                      ||
//   (none)                                         ||
//                                                  ||
// RETURNS:                                         ||
//   A scalar angle in degrees [0, 360) representing||
//   the compass heading.                           ||
//                                                  ||
// METHOD:                                          ||
//   Projects the ship's forward vector onto the    ||
//   horizontal plane and calculates the angle      ||
//   relative to north.                             ||
//==================================================||

function compass_hdg {
    local up_vector is ship:up:vector.
    local north_vector is ship:north:vector.
    local east_vector is vcrs(up_vector, north_vector).      
    local facing_vector is ship:facing:forevector.
    local projV is vxcl(up_vector, facing_vector). 
    local angle is vang(north_vector, projV).
    if vdot(projV, east_vector) < 0 {
        set angle to 360 - angle.
    }
    return angle.
}
//==================================================||
//      FUNCTION: vectorHeading                     ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Calculates the compass heading (angle from     ||
//   true north) of a vector in the ship's surface  ||
//   reference frame.                               ||
//                                                  ||
// PARAMETERS:                                      ||
//   V__ : (vector) Direction vector to analyze     ||
//                                                  ||
// RETURNS:                                         ||
//   Scalar angle in degrees [0, 360) representing  ||
//   the heading of the vector.                     ||
//                                                  ||
// METHOD:                                          ||
//   Projects the vector onto the horizontal plane  ||
//   and computes its angle from true north.        ||
//==================================================||
function vectorHeading{
    local parameter V__.
    set V__ to V__:normalized.
    local north_v is ship:north:vector:normalized.
    local up_v is ship:up:vector.
    local east_v is vcrs(up_v, north_v).
    local hdg is vang(north_v, V__).
    local projhdg is vxcl(up_v,V__).
    if vdot(projhdg,east_v)<0 {
        set hdg to 360 - hdg.
    }
    return hdg.
}

//**************************************************||
//--------------------------------------------------||
//                  FLIGHT VECTORS                  ||
//--------------------------------------------------||
//**************************************************||
function orbital_basis_vectors {
    local z is (latlng(90,0):position - body:position):normalized.
    local x is solarPrimeVector:vec:normalized.
    local y is vCrs(x,z):normalized.
    return list(x,y,z).
}

//**************************************************||
//--------------------------------------------------||
//                   CUSTOM WAIT                    ||
//--------------------------------------------------||
//**************************************************||
// wait function that does not pause the 
// guidance loop, and activates after a certain time 
// is done.
//
// I guess... this can just be done with timers 
// inside the loop?
// Like: 
// timer is 0
// until false {
//     if runmode = 1{
        
//         set runmode to 2.
//     }
//     if runode = 2 {
//         timer = timer + 0.02. // or whatever the time tick is
//         if timer = 5 {
//             // do thing
//         }
//     }
// }
// but idk.
// When then statements, perhaps?
// until false {
//     if runmode = 1{
//      timer = time:seconds + 10
//         set runmode to 2.
//     }
//     if runode = 2 {
//         when time:seconds > timer then {
//             // sum shit
//         set runmode to 3?
//         }
//     }
// }

//**************************************************||
//--------------------------------------------------||
//                   CUSTOM WARP                    ||
//--------------------------------------------------||
//**************************************************||
// 
//==================================================||
//      FUNCTION: c_warpto                          ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Provides a custom time warp function to safely ||
//   and smoothly warp to a future universal time.  ||
//   This arose because of the inherent problems    ||
//   and bugs that are associated with KOS's inbuilt||
//   warpto function when it calls KSP's warping in ||
//   the API. It's a bit buggy, it changes the      ||
//   position of the apsides, and quite often, it   ||
//   overshoots since it's going too damn fast, henc||
//   i made a custom warper which slows a staggered ||
//   way to not spoil the warping effect.           ||
//                                                  ||
// PARAMETERS:                                      ||
//   eta__ : (scalar) Seconds from now to time to   ||
//                    warp to.                      ||
//                                                  ||
// RETURNS:                                         ||
//   None.                                          ||
//                                                  ||
// METHOD:                                          ||
//   Determines remaining time to the target and    ||
//   adjusts warp speed in tiers based on thresholds||
//   to ensure a smooth slowdown approaching the    ||
//   destination time. Starts at low warp rates for ||
//   short durations and gradually increases for    ||
//   longer waits. Warp changes are smoothed to     ||
//   avoid jarring transitions.                     ||
//                                                  ||
//   Once the target time is reached, warp is reset ||
//   to real-time (0).                              ||
//==================================================||
function c_warpto {
    local parameter eta__.
    
    local eta_time is time:seconds + eta__.
    local current_warp is 0.
    // pointless to timewarp to a time that close.
    if eta__ < 20 {
        return.
    }
    set warp to 1. // staggered timewarp increase.
    wait 1.        // less buggy.
    set warp to 2.
    wait 1.
    until time:seconds >= eta_time {
        local time_remaining is eta_time - time:seconds.
        // Determine the target warp based on time remaining
        if time_remaining < 7.5 {
            set current_warp to 0.          // Real time
        } else if time_remaining < 30 {
            set current_warp to 1.          // 5x      // 30 s
        } else if time_remaining < 60 {
            set current_warp to 2.          // 10x     // 1  min
        } else if time_remaining < 300 {
            set current_warp to 3.          // 50x     // 5  min
        } else if time_remaining < 1800 { 
            set current_warp to 4.          // 100x    // 30 min
        } else if time_remaining < 10800 {
            set current_warp to 5.          // 1000x   // 3  hrs
        } else if time_remaining < 108000 {
            set current_warp to 6.          // 10,000x // 5  days
        } else if time_remaining > 108000 {
            set current_warp to 7.          // 100000x 
        }
        // else {
        //     // Gradually increase warp up to max (7)
        //     // Technicall max could be higher but ts is safer
        //     if warp < 7 {
        //         set warp to warp + 1.
        //         wait 0.5.
        //     }
        // }

        // Update warp only if different from current
        if warp <> current_warp {
            set warp to current_warp.
        }
        wait 0. // Yield control for smooth behavior
    }
    // Stop warp once target time is reached
    set warp to 0.
}


//**************************************************||
//--------------------------------------------------||
//                INCLINATION ASCENT                ||
//--------------------------------------------------||
//**************************************************||

//==================================================||
//      FUNCTION: inclination_heading               ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Calculates the azimuthal launch heading needed ||
//   to achieve a target orbital inclination.       ||
//   If desired inclination is lower than the       ||
//   current latitude, defaults to the current lat  ||
//                                                  ||
//   Applies a correction based on deviation from   ||
//   the current orbit's inclination, and also      ||
//   dynamically updates in flight. lock ship       || 
//   heading to this function at flight time        ||
//                                                  ||
// PARAMETERS:                                      ||
//   target_inclination : Desired inclination (°)   ||
//   mode               : "northbound" (default)    ||
//                        "southbound" launch       ||
//   current_latitude   : (optional) Launch site    ||
//                        latitude; defaults to     ||
//                        ship:latitude             ||
//                                                  ||
// RETURNS:                                         ||
//   Launch heading in degrees                      ||
// Example use: In ascent guidance loop:            ||
// lock heading to inclination_heading(30,"northbound).
//==================================================||

function inclination_heading {
    local parameter target_inclination.
    local parameter mode is "northbound".
    local parameter current_latitude is ship:latitude. // Default to current latitude

    // Ensure inclination is physically achievable at the current latitude
    if current_latitude > target_inclination {
        print("[ INCL ERROR ] : Current latitude higher than target inclination. Adjusting").
        set target_inclination to current_latitude.
    }

    // Define coordinate basis vectors
    local N is (latlng(90,0):position - body:position):normalized. // "Up" vector toward north pole
    local P is (ship:position - body:position):normalized.         // Position vector from body center to ship
    local U is vxcl(P, N):normalized. // Unit vector pointing eastward (horizontal direction)
    local T is vcrs(P, N):normalized. // Unit vector pointing northward

    // Shorthand
    local i is target_inclination.
    local lat is current_latitude.

    // Calculate angle between launch vector and orbital plane
    local alpha is arcCos(cos(i)/cos(lat)).

    // Calculate two candidate burn directions (east of north or west of north)
    local B1 is U * cos(alpha) - T * sin(alpha).
    local B2 is U * cos(alpha) + T * sin(alpha).

    // Get deviation from target inclination (positive or negative)
    local ang_deviation is (ship:obt:inclination - target_inclination).

    // Determine the sign of deviation
    local cor_sgn is abs(ang_deviation) / (ang_deviation). // +1 or -1

    // Compute a correction term to nudge heading for better inclination convergence
    // This is to counteract the initial velocity given by 
    // planet spin. I'm too lazy to calculate how to counteract it
    // and it's bullshit anw, this makes the same results.

    local correction_term is cor_sgn * 3 * ln(3 * abs(ang_deviation) - 1).

    // Choose launch direction and compute heading
    if mode = "northbound" {
        local V1 is vcrs(P, B1):normalized.         // Velocity direction for northbound launch
        local heading1 is vectorHeading(V1).        // Convert to compass heading
        return heading1 + correction_term.
    }

    if mode = "southbound" {
        local V2 is vcrs(P, B2):normalized.         // Velocity direction for southbound launch
        local heading2 is vectorHeading(V2).        // Convert to compass heading
        return heading2 - correction_term.
    }
}

//**************************************************||
//--------------------------------------------------||
//             INTERPLANETARY TRANSFERS             ||
//--------------------------------------------------||
//**************************************************||

//==================================================||
//      FUNCTION: lambert_solver                    ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Solves Lambert’s problem using the universal   ||
//   variable formulation to compute the initial    ||
//   and final velocity vectors for a transfer      ||
//   orbit between two position vectors in a given  ||
//   time of flight.                                ||
//                                                  ||
// METHOD:                                          ||
//   Uses the universal variables method to solve   ||
//   the time of flight equation iteratively via    ||
//   bisection on the universal anomaly squared     ||
//   (psi), adjusting c2 and c3 functions based on  ||
//   the sign of psi.                               ||
//                                                  ||
// PARAMETERS:                                      ||
//   r1  : (vector) Initial position vector         ||
//   r2  : (vector) Final position vector           ||
//   tof : (scalar) Time of flight for the          ||
//         transfer [seconds]                       ||
//   mu  : (scalar) Gravitational parameter         ||
//         [m^3/s^2]                                ||
//   t_m : (scalar) Transfer direction (+1 = short  ||
//         way, -1 = long way)                      ||
//                                                  ||
// RETURNS:                                         ||
//   A list containing:                             ||
//     - v1 : (vector) Velocity at r1 to start the  ||
//            transfer                              ||
//     - v2 : (vector) Velocity at r2 upon arrival  ||
//                                                  ||
//   All vectors are in SOI-RAW                     ||
//   If the solver fails to converge, returns two   ||
//   zero vectors                                   ||
//==================================================||
function lambert_solver {
    
    // A lambert solver utilizing universal variable formulation
    // The algorithm was adapted from this paper: 
    // https://www.researchgate.net/publication/236012521_Lambert_Universal_Variable_Algorithm
    // I wont even bother commenting and explaing what this shit does
    // I don't understand it either, I just adapted the algorithm from the paper

    // radius vectors are measured relative to center body, 
    // i.e., sun (if interplanetary) or kerbin (if interlunar) is [0,0,0].

    local parameter r1.   // ship position when launching
    local parameter r2.   // target position at arrival
    local parameter tof.  // time of flight
    local parameter mu.   // just body:mu
    local parameter t_m.  // transfer direction. +1 for shortway, -1 for longway

    local parameter N is 0.          // for multiple orbit passes
    local parameter max_iter is 500. // maximum iterations for bisection search convergence
    local parameter tol is 1e-6.     // time tolerance
    
    local null_vector is v(0,0,0).
    // stumpff function c2
    local function c_2{
        local parameter z.

        local function cosh {
            local parameter x.
            return (constant:e^(x) + constant:e^ (-x)) / 2.
        }
        if z > 0 {
            return (1.0 - cos(constant:radtodeg * sqrt(z))) / z.
        }
        if z < 0 {
            return (1.0 - cosh(sqrt(-z))) / z.
        }
        else {
            return 1/2 .
        }
    }

    // stumpff function c3
    local function c_3 {
        local parameter z.
        local function sinh{
            local parameter x.
            return (constant:e^(x) - constant:e^ (-x)) / 2.
        }
        if z > 0 {
            local sqrtz is sqrt(z).
            return (sqrtz - sin(constant:radtodeg * sqrtz)) / (z)^1.5.
        }
        if z < 0 {
            local sqrtmz is sqrtmz.
            return (sinh(sqrtmz) - sqrtmz) / (-z)^1.5.
        }
        else {
            return 1/6 .
        }
    }

    local mag_r1 to r1:mag.
    local mag_r2 to r2:mag.

    // local gamma to vdot(r1,r2) / (mag_r1 * mag_r2).
    local gamma to cos(vang(r1, r2)).
    // cross product for transfer angle determination
    local cross_r1r2 is vcrs(r1,r2).
    // Determine A based on transfer type.
    local A to t_m * sqrt(mag_r1 * mag_r2 * (1  + gamma)).
    if t_m = 0 {
        set A to sqrt(mag_r1 * mag_r2 * (1  + gamma)).
        if vdot(cross_r1r2, (latlng(90,0):position - body:position)) < 0 {
            set A to - A.
        } 
    }

    if A = 0 {
        print "Orbit cannot exist".
        return list(null_vector, null_vector).
    }

    local psi   is 0. // initial guess for psi
    local psi_u is 0. // psi upper
    local psi_l is 0. // psi lower
    if N = 0 { // 1 revolution
        set psi   to   0.    
        set psi_u to   4 * constant:pi^2. 
        set psi_l to - 4 * constant:pi^2.
    } else { // N revolution case
        set psi_u to (2 * (N + 1) * constant:pi)^2. 
        set psi_l to (2 * N * constant:pi)^2. 
        set psi   to (psi_l + psi_u) / 2. 
    }

    local B to 0.
    local chi3 to 0.
    local tof_ to 0.
    local c2 to 0.5.
    local c3 to 1/6.

    local solved to false.

    from { local i is 0.} until i >= max_iter step { set i to i + 1.} do {
        set c2 to c_2(psi).
        set c3 to c_3(psi).
        set B to mag_r1 + mag_r2 + A * (psi * c3 - 1) / sqrt(c2). // Compute B.

       if B < 0 {
            // B negative - adjust bounds only
            set psi_l to psi.
            set psi to (psi_u + psi_l)/2.
        } else {
            // B is positive, safe to compute chi3 and tof
            set chi3 to (B / c2)^(1.5).
            set tof_ to (chi3 * c3 + A * sqrt(B)) / sqrt(mu).
            
            // Check convergence
            if abs(tof - tof_) < tol {
                set solved to true.
                break.
            }
            
            // Update bounds using bisection
            if tof_ < tof {
                set psi_l to psi.
            } else {
                set psi_u to psi.
            }
            set psi to (psi_u + psi_l)/2.
        }
    }

    if not solved {
        print "[ ERROR ] Did not converge".
        return list(null_vector, null_vector).
    }
    // compute fuinal velocities
    local f to 1 - B / mag_r1.
    local g to A * sqrt( B / mu).
    local g_dot to 1 - B / mag_r2.
    // avoid division by zero.
    if abs(g) < 1e-12 {
        print "[ ERROR ] Near zero [g] division".
        return list(v(3.8e38,3.8e38,3.8e38),v(3.8e38,3.8e38,3.8e38)).
    }
    local f_dot to (f * g_dot - 1) / g.
    local v1 to (r2 - f * r1) / g.
    local v2 to f_dot * r1 + g_dot * v1.
    return list(v1,v2).
}
// make a function for porkchop plotting, 
// targeting planets so and so
// translation of the porchop plot into an actual maneuver
// then one that returns a meneuver node


//**************************************************||
//--------------------------------------------------||
//              RENDEZVOUS AND DOCKING              ||
//--------------------------------------------------||
//**************************************************||
//  TO BE DONE
function fine_tune_closest_approach_to_target {
    local parameter target_distance is 100.
    local parameter at_certain_time is 90.
    local parameter tof_resol is 60.
    if not hasTarget {
        return null_mnv("[ TRGT ERROR ] : No target selected").
    }
    local t0 is time:seconds + at_certain_time.
    local ut_nearest is time_of_closest_approach().
    local dst_nearest is target_distance_at_ut(ut_nearest).
    local tof_min is 0.8 * (ut_nearest - t0).
    local tof_max is 1.2 * (ut_nearest - t0).
    if dst_nearest < target_distance {
        return null_mnv("[ MNVR ERROR ] : Closest approach already within parameters.").
    }
    local tof_list is linspace(tof_min,tof_max,tof_resol).
    local r1 is positionAt(ship, time:seconds + at_certain_time) - body:position.
    local vshp is velocityAt(ship,t0):orbit.
    local best_v1 is v(0,0,0).
    local best_dV is 3e38.
    from { local j is 0. } until j >= tof_resol step { set j to j + 1. } do {
        local r2 is positionAt(target,t0 + tof_list[j]) - body:position.
        local transfer_vectors is lambert_solver(r1, r2, tof_list[j], body:mu, +1).
        local v1 is transfer_vectors[0].
        local v2 is transfer_vectors[1].
        local vtgt is velocityAt(target,t0 + tof_list[j]):orbit.
        if vdot(v1,vshp) < 0 {
            set transfer_vectors to lambert_solver(r1, r2,tof_list[j],body:mu,-1).
            set v1 to transfer_vectors[0].
            set v2 to transfer_vectors[1].
        }
        local total_dV is ((v1-vshp):mag + (v2 - vtgt):mag).
        if total_dV < best_dV {
            set best_v1 to v1.
        }
    }
    return inertial_to_PRN(best_v1 - velocityAt(ship, t0):orbit, t0).
}

function intercept_target_at_chosen_time {
    local parameter after_time.         // how many seconds from NOW to execute the mode. 
    local parameter time_after_burn.    // time after burn to intercept target
    if not hasTarget {
        return null_mnv("[ TRGT ERROR ] : No target selected").
    }
    local after_time_ut is after_time + time:seconds.
    local r1 is positionAt(ship, after_time_ut) - body:position.
    local r2 is positionAt(target, after_time_ut + time_after_burn) - body:position.
    
    // Try both transfer types
    local sol1 is lambert_solver(r1, r2, time_after_burn, body:mu, +1).
    local sol2 is lambert_solver(r1, r2, time_after_burn, body:mu, -1).
    
    local v1_1 is sol1[0].
    local v1_2 is sol2[0]. 
    
    local vshp is velocityAt(ship, after_time_ut):orbit.

    local dV1 is (v1_1 - vshp):mag.
    local dV2 is (v1_2 - vshp):mag.
    
    // Choose the better transfer type
    local v1 is v1_1.
    if dV2 < dV1 { 
        set v1 to v1_2. 
    }
    local dV_vec is v1 - vshp.
    return inertial_to_PRN(dV_vec, after_time_ut).
}

function hohmann_transfer_to_target {
    // vessel eccentricity must be < 0.005 
    // target eccentricity must be < 0.005
    if not hasTarget {
        return null_mnv("[ TRGT ERROR ] : No target selected").
    }
    local ship_h is vcrs(ship:velocity:orbit,ship:position-body:position).
    local trgt_h is vcrs(target:velocity:orbit,target:position - body:position).
    if vang(ship_h,trgt_h) > 0.1 {
        return null_mnv("[ TRGT ERROR] : Ship not on the same plane as target. delta inc > 0.1").
    }
    if obt:eccentricity > 0.01 {
        return null_mnv("[ ORBT ERROR ] : Current orbit e > 0.01").
    }
    if target:obt:eccentricity > 0.01 {
        return null_mnv("[ TRGT ERROR ] : Target orbit e > 0.01").
    }

    local ship_a is obt:semimajoraxis.
    local trgt_a is target:obt:semimajoraxis.
    local transfer_a is (ship_a  + trgt_a) / 2. // conservative estimate with minimal error.
    local transfer_t is constant:pi * sqrt(transfer_a^3 / body:mu).
    local ship_omega is sqrt(body:mu / ship_a^3)*constant:radtodeg.
    local trgt_omega is sqrt(body:mu / trgt_a^3)*constant:radtodeg.
    local delta_omega is 0.
    local target_phase is 0.
    local current_phase is 0.
    if trgt_a > ship_a {
        set delta_omega to (ship_omega - trgt_omega).
        set target_phase to 180 - trgt_omega * transfer_t.
        set current_phase to vector_to_true_anomaly(target:position - body:position) - obt:trueanomaly.
    } else {
        set delta_omega to (trgt_omega - ship_omega).
        set target_phase to 180 + trgt_omega * transfer_t.
        set current_phase to obt:trueanomaly - vector_to_true_anomaly(target:position - body:position).
    }
    if current_phase < 0 {
        set current_phase to current_phase + 360.
    }
    local phase_error to current_phase - target_phase.
    if phase_error < 0 {
        set phase_error to phase_error + 360.
    }
    local wait_time is phase_error / delta_omega.
    local burn_t is wait_time + time:seconds.
    local transfer_apoapsis is (positionAt(target,burn_t) - body:position):mag - body:radius.
    local transfer_periapsis is (positionAt(ship,burn_t) - body:position):mag - body:radius.
    set transfer_a to (transfer_apoapsis + transfer_periapsis)/2 + body:radius.
    local transfer_v is vis_viva_equation(transfer_periapsis,transfer_a).
    local ship_burn_v is velocityAt(ship,burn_t):orbit.
    local ship_pos_v is positionAt(ship,burn_t) - body:position.
    local burn_vector is vxcl(ship_pos_v,ship_burn_v):normalized * transfer_v.
    return inertial_to_PRN(burn_vector - ship_burn_v,burn_t).
}

function intercept_target {
    local parameter mode is "lowest dv".
    local parameter value is 0.
    local parameter include_2nd_burn is True.
    local safe_time is 60.

    // we're gonna lambert solver this shit.
    if mode = "lowest dv" {
        local ref1_time is min(obt:period,target:obt:period).
        local ref2_time is max(obt:period,target:obt:period).
        local t0 is time:seconds + safe_time.
        local tf is time:seconds + ref1_time.
        local tof0 is ref2_time * 0.2.
        local toff is ref2_time * 0.8.
        return porkchop_evaluation2(t0, tf, tof0, toff, mode, include_2nd_burn).
    }
    if mode = "at certain time" {
        // initiate orbit after specified time.
    }
    if mode = "as soon as possible" {
            // lowest possible delta v 30 s from now.
    }
}

function dock_to_target {
    // local parameter target_part.
    // local parameter approach_speed.

}

function target_distance_at_ut {
        local parameter ut.
        local ship_posv is positionat(ship, ut).
        local trgt_posv is positionat(target,ut).
        local diff_v is trgt_posv - ship_posv.
        return diff_v:mag.
}

function time_of_closest_approach {
    local parameter t0 is time:seconds.
    local parameter tf is time:seconds + obt:period.
    local parameter n is 51.
    local parameter max_iter is 1000.
    local parameter tol is 1e-4.

    if not hastarget {
        return null_mnv("[ TRGT ERROR ] : No target detected. Please set target").
    }
    local t_list is list().
    local f_list is list().
    for i in range(n) {
        local t_value is t0 + (i / (n - 1)) * (tf - t0).
        t_list:add(t_value).
        f_list:add(target_distance_at_ut(t_value)).
    }
    local minima_idx is list().
    if f_list[0] <= f_list[1] {
        minima_idx:add(0).
    }
    if f_list[n-1] <= f_list[n-2] {
        minima_idx:add(n-1).
    }
    for i in range(1,n - 1) {
        if f_list[i] <= f_list[i-1] and f_list[i] <= f_list[i+1] {
            minima_idx:add(i).
        }
    }
    local function golden_section_search{
        local parameter a.
        local parameter b.
        local gr is (sqrt(5) - 1) / 2.
        local c is b - gr * (b - a).
        local d is a + gr * (b - a).
        local fc is target_distance_at_ut(c).
        local fd is target_distance_at_ut(d).
        for i in range(max_iter){
            if (abs(b - a) < tol){
                break.
            }
            if fc < fd {
                set b to d.
                set d to c.
                set fd to fc.
                set c to b - gr * (b - a).
                set fc to target_distance_at_ut(c).
            } else {
                set a to c.
                set c to d.
                set fc to fd.
                set d to a + gr * (b - a).
                set fd to target_distance_at_ut(d).
            }
            if (i = (max_iter - 1)) {
                print "[ CONVERGENCE ERROR ] : Golden search probably did not converge".
            }
        }
        return (a + b) / 2.
    }

    local best_t is -1.
    local best_f is 3.4e38.
    local t_candidate is -1.
    local f_candidate is 3.4e38.
    for midx in minima_idx {
        if (midx = 0) {
            set t_candidate to t_list[0].
        } else if (midx = n - 1) {
            set t_candidate to t_list[n - 1].
        } else {
            local a is t_list[midx - 1].
            local b is t_list[midx + 1].
            set t_candidate to golden_section_search(a,b).
        }
        set f_candidate to target_distance_at_ut(t_candidate).
        if f_candidate < best_f {
            set best_f to f_candidate.
            set best_t to t_candidate. 
        }
    }
    if ((abs(best_t - t0) < 2 * tol) or (abs(best_t - tf) < 2 * tol)) {
        print("[ CAUTION ] : Minimum might lie outside given bounds").
    }
    return best_t.
}   

//==================================================||
//      FUNCTION: match_planes_with_target          ||
//--------------------------------------------------||
// PURPOSE:                                         ||
//   Computes the maneuver required to match the    ||
//   orbital plane of the active vessel with that   ||
//   of the currently targeted vessel.              ||
//                                                  ||
// PARAMETERS:                                      ||
//   mode : A string determining where the plane    ||
//          change is executed. Supported modes:    ||
//                                                  ||
//          - "at AN" : Perform burn at relative    ||
//                      ascending node.             ||
//          - "at DN" : Perform burn at relative    ||
//                      descending node.            ||
//          - "at nearest node" : Chooses the       ||
//                      closest of relative AN or DN||
//          - "at cheapest node" : Chooses the node ||
//                      requiring less delta-V.     ||
//                                                  ||
// RETURNS:                                         ||
//   A manueuver node                               ||
//                                                  ||
//   If no target is set or mode is unsupported,    ||
//   returns a null maneuver                        ||
//                                                  ||
// METHOD:                                          ||
//   Computes orbit normals, finds AN and DN,       ||
//   computes required inclination change, and      ||
//   estimates delta-V using vector geometry and    ||
//   the cosine law for inclination changes.        ||
//==================================================||
function match_planes_with_target {
    local parameter mode.
    
    if not hastarget {
        return null_mnv("[ TRGT ERROR ] : No target detected. Please set target").
    }

    local p0 is body:position.
    local r1 is ship:position - p0.         // radius vector
    local v1 is ship:velocity:orbit.        // velocity vector
    local h1 is vcrs(v1,r1).                // angular momentum vector
    local e1 is (vcrs(h1,v1)/body:mu - r1:normalized). // eccentricity vector, points to periapsis.

    local r2 is target:position - p0.       // target radius
    local v2 is target:velocity:orbit.      // target vel
    local h2 is vcrs(v2,r2).                // target angular momentum

    local an_vec is vcrs(h1,h2).            // vector that points to the relative ascending node.
    local AN_ta is vang(e1,an_vec).         // true anomaly of relative ascending node
    if vdot(an_vec,vcrs(e1,h1)) < 0 {
        set AN_ta to 360-AN_ta.
    }
    local DN_ta is angle_wrap(AN_ta - 180). // true anomaly of relative descending node
    local delta_inc is - vang(h1,h2).         // difference of inclination
    // reuse change_inclination code.
    local t_an is time_from_true_anomaly(AN_ta) + time:seconds.
    local t_dn is time_from_true_anomaly(DN_ta) + time:seconds.
    // Compute velocity vectors at each node
    local vel_vec_an is velocityat(ship, t_an):orbit.
    local vel_vec_dn is velocityat(ship, t_dn):orbit.
    // Compute required delta-v magnitude at each node
    local delta_v_mag_an is 2 * vel_vec_an:mag * sin(abs(delta_inc) / 2).
    local delta_v_mag_dn is 2 * vel_vec_dn:mag * sin(abs(delta_inc) / 2).
    // helper function to calculate delta V.
    local function compute_dv {
        local parameter isAN.
        local ut is t_an.
        local rad_vector is positionAt(ship,t_an) - body:position.
        local vel_vector is vel_vec_an.
        if not isAN {
            set rad_vector to positionAt(ship,t_dn) - body:position.
            set vel_vector to vel_vec_dn.
            set delta_inc to - delta_inc.
            set ut to t_dn.
        } 
        local rotVector is rotate_vector(vel_vector, delta_inc, rad_vector).
        local deltaV is rotVector - vel_vector.
        return inertial_to_PRN(deltaV, ut).
    }
    // Decision logic by mode
    if mode = "at AN" {
        return compute_dv(true).
    }
    if mode = "at DN" {
        return compute_dv(false).
    }
    if mode = "at nearest node" {
        if t_an < t_dn {
            return compute_dv(true).
        } else {
            return compute_dv(false).
        }
    }
    if mode = "at cheapest node" {
        if delta_v_mag_an < delta_v_mag_dn {
            return compute_dv(true).
        } else {
            return compute_dv(false).
        }
    }
    return null_mnv(mode_error_message+ mode).
}

function match_velocities_with_target {
    local parameter mode is "at closest approach".
    local parameter value is 0.
    if mode = "at closest approach" {
        local closest_t is time_of_closest_approach().
        local trgt_v is velocityAt(target, closest_t):orbit.
        local ship_v is velocityAt(ship, closest_t):orbit.
        local dV is trgt_v - ship_v.
        return inertial_to_PRN(dV,closest_t).
    }
    if mode = "after fixed time" {
        local fixed_t is value + time:seconds.
        local trgt_v is velocityAt(target, fixed_t):orbit.
        local ship_v is velocityAt(ship, fixed_t):orbit.
        local dV is trgt_v - ship_v.
        return inertial_to_PRN(dV,fixed_t).
    }
    return null_mnv().
}

// PLANNED STUFF
//**************************************************||
//--------------------------------------------------||
//                LANDING FUNCTIONS                 ||
//--------------------------------------------------||
//**************************************************||

//**************************************************||
//--------------------------------------------------||
//                  LINEAR DESCENT                  ||
//--------------------------------------------------||
//**************************************************||

//**************************************************||
//--------------------------------------------------||
//                    HOVER PIDS                    ||
//--------------------------------------------------||
//**************************************************||

//**************************************************||
//--------------------------------------------------||
//               BALLISTIC TARGETING                ||
//--------------------------------------------------||
//**************************************************||
// for ballistic missiles and stuff
// after launching missile, directs the guidance
// system to go to a certain location
// in the planetary surface
// and adjusts shit dynamically

//**************************************************||
//--------------------------------------------------||
//                WAYPOINT GUIDANCE                 ||
//--------------------------------------------------||
//**************************************************||
// waypoint guide stuff

//**************************************************||
//--------------------------------------------------||
//                 PLANE AUTOPILOT                  ||
//--------------------------------------------------||
//**************************************************||
// set altitude
// set vertical speed
// set roll
// set target speed


//**************************************************||
//--------------------------------------------------||
//                 EXPERIMENTAL                     ||
//--------------------------------------------------||
//**************************************************||
function free_return_trajectory {
    // for entering a free return trajectory on mun/minmus ONLY.
    // specify that orbit ecc must not be greater than 0.01
    // and difference in inclination not greater than 0.5 degrees.
    // will work for various starting circular parking orbit radii
    // idk how this one will work in general, maybe something similar to porkchop plots, maybe

}

function hohmann_maneuver {
    local parameter tgt_altitude.
    local parameter mode.
    local parameter value is 0.
    
    if obt:eccentricity > 0.01 {
        print("[ ORBT ERROR ] : Eccentricity greater than 0.01").
        return.
    }
    create_node(change_apoapsis(tgt_altitude,mode,value)).
    execute_node().
    rcs_corrector("apoapsis",tgt_altitude).
    create_node(circularize("at apoapsis")).
    execute_node().
    return.
}
//**************************************************||
//--------------------------------------------------||
//                 SPECIAL POINTS                   ||
//--------------------------------------------------||
//**************************************************||

function subsolar_point {
    // Returns the coordinates on the surface of the current body that is directly under the sun.
    local sun_ll is body:geoPositionof(body("Sun"):position).
    local sun_lat is sun_ll:lat.
    local sun_long is sun_ll:lng.
    return list(sun_lat,sun_long).
}

//LAUNCH PAD
//RUNWAYS
//we can probably just reuse kslib.
// but, hey, make your own.


// TODO 
// custom warp                                  <done>
// rcs total deltaV                             <done>
// lambert solver                               <done>
// match planes with target                     <done>
// subsolar point                               <done>  
// chage eccentricity                           <done>
// change apoapsis / periapsis                  <done>
// change semimajor axis                        <done>
// change LAN                                   <done>
// change Arg peri                              <done>
//

// plane guidance - set altitude
// plane guidance - set vertical speed
// plane guidance - set roll
// plane guidance - set target speed
// hover script
// landing script
// communication of vessels
// porkchop plotting    
// inflight emergency guidance les
// docking
// custom wait
// ballistic targeting
// target intercept functions
// at altitude and at certain time modes
// make at altitude the nearest altitude.
// return from a moon


// SATURN V LAUNCH
// saturn v abort modes.
// free return trajectory
// transposition and docking
// LM descent 
// rendezvouz and docking.
// 
//**************************************************||
//--------------------------------------------------||
//                DEBUG FUNCTIONS                   ||
//--------------------------------------------------||
//**************************************************||

function vector_display {
    local parameter vector.
    local parameter nround is 3.
    local x is round(vector:x,nround).
    local y is round(vector:y,nround).
    local z is round(vector:z,nround).
    return x + " " + y + " " + z.
}

function vector_debug { 
    // common debugging vectors
    // the concept here is just draw them once for comparison, then do a clearvecdraws after some time.
    // universe basis vectors
    local zv is (latlng(90,0):position - body:position):normalized.
    local xv is solarPrimeVector:vec:normalized.
    local yv is vCrs(xv,zv):normalized.
    vecDraw(body:position, zv*1e6, rgb(1,0,0),"Z",1,true,0.2,true,false). // Z basis
    vecDraw(body:position, xv*1e6, rgb(1,0,0),"X",1,true,0.2,true,false). // X basis
    vecDraw(body:position, yv*1e6, rgb(1,0,0),"Y",1,true,0.2,true,false). // Y basis

    // orbit perifocal vectors
    local pv is (positionat(ship, eta:periapsis + time:seconds) - body:position):normalized.
    local hv is vCrs(velocityAt(ship, eta:periapsis + time:seconds):orbit,pv):normalized.
    local qv is vCrs(pv, hv):normalized.
    vecDraw(body:position, pv*1e6, rgb(0,0,1),"Z",1,true,0.2,true,false). // p basis
    vecDraw(body:position, hv*1e6, rgb(0,0,1),"X",1,true,0.2,true,false). // h basis
    vecDraw(body:position, qv*1e6, rgb(0,0,1),"Y",1,true,0.2,true,false). // q basis

    // orbit inclination vector 
    local iv is vCrs(hv,zv):normalized.
    vecDraw(body:position, iv*1e6, rgb(0,1,0),"Y",1,true,0.2,true,false). // i basis
}
// function number_format {
//      for number formating in printing.
//      like python's f-strings.
//     // FIX THIS SHIT FIX THIS SHIT
//     local parameter float.
//     local parameter nround.
    
//     local sign is float / abs(float).

// }

function linspace {
    local parameter x0.
    local parameter xf.
    local parameter n.
    if n < 2 {
        return list().
    }
    local output is list().
    for i in range(n) {
        output:add(x0 + (i/(n - 1)) * (xf - x0)).
    }
    return output.
}

function arange {
    local parameter x0.
    local parameter xf.
    local parameter dx.
    local n is floor((xf - x0) / dx).
    local output is list().
    for i in range(n) {
        output:add( x0 + i * dx).
    }
    return output.
}
// test lambert solver first!
function porkchop_evaluation1 {
    // search space.
    local parameter ut0.  // universal time start evaluation, use time:seconds
    local parameter utf.  // universal time end evaluation. Preferably ut0 + orbital period of lower body.
    local parameter tof0. // time of flight initial value. Preferably 0.2 of the orbit of the higher body.
    local parameter toff. // time of flight final value. Preferably 1 orbit period of lower body/
    local parameter mode is "lowest dv". // mode is get the lowest dv
    local parameter include_2nd_burn is true. // include the approach dv in the evaluation.
    local parameter safe_time is ut0 + 60. // safe time for when mode= "ASAP"
    local parameter t_resol is 100. // resolution of exit time evaluation.
    local parameter tof_resol is 100. // resolution of tof evaluation/
  
    if not hastarget {
        return null_mnv("[ TRGT ERROR ] : No target detected. Please set target").
    }
    local maxval is 3.8e38.
    local null_vector is v(1e38,1e38,1e38).
    local deltaV_array is list().
    local vector_array is list().
    from { local i is 0. } until i >= t_resol step { set i to i + 1. } do {  
        local tof_list is list().
        local vec_list is list().
        from { local j is 0. } until j >= tof_resol step { set j to j + 1. } do {
            tof_list:add(maxval).
            vec_list:add(null_vector).
        }
        deltaV_array:add(tof_list).
        vector_array:add(vec_list).
    }
    local t_list is linspace(ut0,utf,t_resol).
    local tof_list is linspace(tof0,toff,tof_resol).
    for i in range(t_resol) {
        for j in range(tof_resol) { 
            local r1 is positionAt(ship,t_list[i]) - body:position.
            local r2 is positionAt(target,t_list[i] + tof_list[j]) - body:position.
            local transfer_vectors is lambert_solver(r1, r2,tof_list[j],body:mu,+1).
            local v1 is transfer_vectors[0].
            local v2 is transfer_vectors[1].
            local vshp is velocityAt(ship,t_list[i]):orbit.
            local vtgt is velocityAt(target, t_list[i] + tof_list[j]):orbit.
            if vdot(v1,vshp) < 0 {
                set transfer_vectors to lambert_solver(r1, r2,tof_list[j],body:mu,-1).
                set v1 to transfer_vectors[0].
                set v2 to transfer_vectors[1].
            }
            if not include_2nd_burn {
                set deltaV_array[i][j] to (v1 - vshp):mag.
            } else {
                set deltaV_array[i][j] to ((v1 - vshp):mag + (v2 - vtgt):mag).
            }
            set vector_array[i][j] to v1.            
        }
    }
    if mode = "lowest dv" {
        // determine lowest valued index 
        local minidx_i is 0.
        local minidx_j is 0.
        local mindV is deltaV_array[minidx_i][minidx_j].
        for i in range(t_resol) {
            for j in range(tof_resol){
                local test_dV is deltaV_array[i][j].
                if test_dV < mindV {
                    set minidx_i to i.
                    set minidx_j to j.
                    set mindV to test_dV.
                }
            }
        }
        local ut is t_list[minidx_i].
        local v1 is vector_array[minidx_i][minidx_j].
        local vshp is velocityAt(ship,ut):orbit.
        local dV is v1 - vshp.
        return inertial_to_PRN(dV,ut).
    }
    if (mode = "ASAP") or (mode = "as soon as possible") {
        // Find the index closest to safe_time
        local safe_idx is 0.
        local min_time_diff is abs(t_list[0] - safe_time).
        for i in range(t_resol) {
            local time_diff is abs(t_list[i] - safe_time).
            if time_diff < min_time_diff {
                set min_time_diff to time_diff.
                set safe_idx to i.
            }
        }
        
        // Evaluate only at safe_idx, across all tof values
        local minidx_j is 0.
        local mindV is deltaV_array[safe_idx][minidx_j].
        for j in range(tof_resol) {
            local test_dV is deltaV_array[safe_idx][j].
            if test_dV < mindV {
                set minidx_j to j.
                set mindV to test_dV.
            }
        }  
        local ut is t_list[safe_idx].
        local v1 is vector_array[safe_idx][minidx_j].
        local vshp is velocityAt(ship,ut):orbit.
        local dV is v1 - vshp.
        return inertial_to_PRN(dV,ut).
    }
}

// better version with safer space handling. 

function porkchop_evaluation2 {
    local parameter ut0.  // universal time start evaluation, use time:seconds
    local parameter utf.  // universal time end evaluation. Preferably ut0 + orbital period of lower body.
    local parameter tof0. // time of flight initial value. Preferably 0.2 of the orbit of the higher body.
    local parameter toff. // time of flight final value. Preferably 1 orbit period of lower body/
    local parameter mode is "lowest dv". // mode is get the lowest dv
    local parameter include_2nd_burn is true. // include the approach dv in the evaluation.
    local parameter value is 0. // parameter value for specific time.
    local parameter safe_time is ut0 + 120. // safe time for when mode= "ASAP"
    local parameter t_resol is 25. // resolution of exit time evaluation.
    local parameter tof_resol is 25. // resolution of tof evaluation/
  
    if not hastarget {
        return null_mnv("[ TRGT ERROR ] : No target detected. Please set target").
    }
    local t_list is linspace(ut0, utf, t_resol).
    local tof_list is linspace(tof0, toff, tof_resol).
    
    if mode = "lowest dv" {
        local best_dV is 1e38.
        local best_ut is 0.
        local best_v1 is v(0,0,0).
        print("Checking search space...").
        local counter to 0.
        from { local i is 0. } until i >= t_resol step { set i to i + 1. } do { 
            local r1 is positionAt(ship, t_list[i]) - body:position.
            local vshp is velocityAt(ship, t_list[i]):orbit.
            from { local j is 0. } until j >= tof_resol step { set j to j + 1. } do {
                local r2 is positionAt(target, t_list[i] + tof_list[j]) - body:position.
                local transfer_vectors is lambert_solver(r1, r2, tof_list[j], body:mu, +1).
                local v1 is transfer_vectors[0].
                local v2 is transfer_vectors[1].
                local vtgt is velocityAt(target, t_list[i] + tof_list[j]):orbit.
                if vdot(v1,vshp) < 0 {
                    set transfer_vectors to lambert_solver(r1, r2,tof_list[j],body:mu,-1).
                    set v1 to transfer_vectors[0].
                    set v2 to transfer_vectors[1].
                }
                local dv1mag is (v1-vshp):mag.
                local dv2mag is (v2 - vtgt):mag.
                local total_dV is choose (dv1mag + dv2mag) if include_2nd_burn else (dv1mag).
                if total_dV < best_dV {
                    set best_dV to total_dV.
                    set best_ut to t_list[i].
                    set best_v1 to v1.
                }
                set counter to counter + 1.
                print counter.
            }
        }
        // local dV_vec is best_v1 - velocityAt(ship, best_ut):orbit.
        return inertial_to_PRN(best_v1 - velocityAt(ship, best_ut):orbit, best_ut).
    }
    
    if (mode = "ASAP") or (mode = "as soon as possible") {
        // Fix t0 at safe_time, only evaluate tof space
        local best_dV is 1e38.
        local best_v1 is v(0,0,0).
        local r1 is positionAt(ship, safe_time) - body:position.
        local vshp is velocityAt(ship, safe_time):orbit.
        from { local j is 0. } until j >= tof_resol step { set j to j + 1. } do {
            local r2 is positionAt(target, safe_time + tof_list[j]) - body:position.
            local transfer_vectors is lambert_solver(r1, r2, tof_list[j], body:mu, +1).
            local v1 is transfer_vectors[0].
            local v2 is transfer_vectors[1].
            
            local vtgt is velocityAt(target, safe_time + tof_list[j]):orbit.
            if vdot(v1,vshp) < 0 {
                set transfer_vectors to lambert_solver(r1, r2,tof_list[j],body:mu,-1).
                set v1 to transfer_vectors[0].
                set v2 to transfer_vectors[1].
            }
            
            local total_dV is v1:mag.
            if include_2nd_burn { 
                set total_dV to total_dV + (v2 - vtgt):mag. 
            }
            if total_dV < best_dV {
                set best_dV to total_dV.
                set best_v1 to v1.
            }
        }
        return inertial_to_PRN(best_v1 - velocityAt(ship, safe_time):orbit, safe_time).
    }
    if "at certain time" {
        // Fix t0 at safe_time, only evaluate tof space
        local t0_value is value.
        local best_dV is 1e38.
        local best_v1 is v(0,0,0).
        local r1 is positionAt(ship, t0_value) - body:position.
        local vshp is velocityAt(ship, t0_value):orbit.
        from { local j is 0. } until j >= tof_resol step { set j to j + 1. } do {
            local r2 is positionAt(target, t0_value + tof_list[j]) - body:position.
            local transfer_vectors is lambert_solver(r1, r2, tof_list[j], body:mu, +1).
            local v1 is transfer_vectors[0].
            local v2 is transfer_vectors[1].
            local vtgt is velocityAt(target, t0_value + tof_list[j]):orbit.

            if vdot(v1,vshp) < 0 {
                set transfer_vectors to lambert_solver(r1, r2,tof_list[j],body:mu,-1).
                set v1 to transfer_vectors[0].
                set v2 to transfer_vectors[1].
            }
            
            local total_dV is v1:mag.
            if include_2nd_burn { 
                set total_dV to total_dV + (v2 - vtgt):mag. 
            }
            if total_dV < best_dV {
                set best_dV to total_dV.
                set best_v1 to v1.
            }
        }

        return inertial_to_PRN(best_v1 - velocityAt(ship, t0_value):orbit, t0_value).
    }
}

    // local function find_minidx {
    //     local parameter tmin_list.
    //     local minidx is -1.
    //     local mindist is 3.8e38.
    //     for k in range(5) {
    //         if target_distance_at_ut(tmin_list[k]) < mindist {
    //             set minidx to k.
    //             set mindist to target_distance_at_ut(tmin_list[minidx]).
    //         }
    //     }
    //     return minidx.
    // }
    // local function five_point_seach {
    //     local parameter a.
    //     local parameter b.
    //     local min_list is list().
    //     for i in range(5) {
    //         local t_value is a + (i / (4)) * (b - a).
    //         min_list:add(t_value).
    //     }
    //     local min_t is 3.4e38.
    //     local p0 is -1.
    //     local p1 is -1.
    //     local p2 is -1.
    //     local p3 is -1.
    //     local p4 is -1.
    //     for j in range(max_iter) {
    //         local minidx is find_minidx(min_list).
    //         if minidx = 0 {
    //             set p0 to min_list[0].
    //             set p2 to min_list[1].
    //             set p4 to min_list[2].
    //         } else if minidx = 4 {
    //             set p0 to min_list[2].
    //             set p2 to min_list[3].
    //             set p4 to min_list[4].
    //         } else {
    //             set p0 to min_list[minidx-1].
    //             set p2 to min_list[minidx].
    //             set p4 to min_list[minidx+1].
    //         }   
    //         if j = max_iter - 1{
    //             set min_t to p2.
    //         }
    //         set p1 to (p0 + p2)/2.
    //         set p3 to (p2 + p4)/2.  
    //         if (abs(p2-p4)<tol) and (abs(p0-p2)<tol) {
    //             set min_t to p2. 
    //             break.
    //         } else {
    //             set min_list to list(p0,p1,p2,p3,p4).
    //         }
    //     }
    //     return min_t.
    // }

// END UNMODIFIED SILVERNUKE911 MANEUVER FUNCTIONS LIBRARY

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
    local orbit_period is ship:orbit:period.
    local result is lex("valid",false,"ut",0,"ascending",false,"reason","no_plane_crossing").
    if ship:orbit:eccentricity >= 1 or orbit_period <= 0 { return result. }
    local left_ut is start_ut.
    local left_side is vdot(positionat(ship,left_ut)-ship:body:position,plane_normal).
    local i is 1.
    until i > 96 {
        local right_ut is start_ut+orbit_period*i/96.
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
    local node_position is positionat(ship,burn_ut)-ship:body:position.
    local vel is velocityat(ship,burn_ut):orbit.
    local radial_speed is vdot(vel,node_position:normalized).
    local tangent is vel-node_position:normalized*radial_speed.
    local target_tangent is V(0,0,0).
    if target_plane_mode {
        set target_tangent to vcrs(target_normal,node_position):normalized.
        if vdot(target_tangent,tangent) < 0 { set target_tangent to -target_tangent. }
    }else{
        local node_site is ship:body:geopositionof(node_position+ship:body:position).
        local east is node_site:velocity:orbit:normalized.
        if east:mag < 0.5 { set east to vcrs(body_north,node_position):normalized. }
        local north_sign is -1.
        if crossing["ascending"] { set north_sign to 1. }
        set target_tangent to east*cos(target_inclination)+body_north*north_sign*sin(target_inclination).
    }
    local target_velocity is node_position:normalized*radial_speed+target_tangent:normalized*tangent:mag.
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
