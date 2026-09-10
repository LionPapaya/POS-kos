// Export Poseidon/body/engine/FAR inputs for tools/pos_sim.
// Run in a disposable save with the Poseidon safely in flight or orbit when
// sampling deployable configurations. No cheats, vessel moves, or time warp
// are used. A parked craft still exports body, craft, and engine data.

set CONFIG:IPU to 2000.

function calibration_reset_file {
    parameter path, header.
    if exists(path) { deletepath(path). }
    log header to path.
}

function calibration_engine_curve {
    parameter engine, engine_index, mode_name, pressures, path.
    for pressure in pressures {
        log engine_index + "," + engine:uid + "," + engine:name + "," + mode_name + "," +
            engine:ignition + "," + engine:flameout + "," + pressure + "," +
            engine:possiblethrustat(pressure) + "," + engine:maxthrustat(pressure) + "," +
            engine:availablethrustat(pressure) + "," + engine:ispat(pressure) + "," +
            ship:altitude + "," + ship:airspeed to path.
    }
}

function calibration_set_aero_configuration {
    parameter name.
    if name = "clean" {
        brakes off.
        gear off.
    }
    if name = "airbrake" {
        gear off.
        brakes on.
    }
    if name = "gear" {
        brakes off.
        gear on.
    }
    if name = "landing" {
        gear on.
        brakes on.
    }
    // Give animations and FAR's voxel model time to settle.
    wait 2.
}

clearscreen.
print "POS calibration export".
print "CONFIG:IPU = " + CONFIG:IPU.

local output_root is "0:/POS_calibration".
if not exists(output_root) { createdir(output_root). }
local bodies_path is output_root + "/bodies.csv".
local craft_path is output_root + "/craft.csv".
local engines_path is output_root + "/engines.csv".
local far_path is output_root + "/far.csv".

calibration_reset_file(bodies_path,
    "name,radius_m,mu_m3_s2,rotation_period_s,atmosphere_height_m,sea_level_pressure_atm,has_ocean,has_solid_surface,angular_velocity_raw_x,angular_velocity_raw_y,angular_velocity_raw_z").
local calibration_bodies is list().
list bodies in calibration_bodies.
for calibration_body in calibration_bodies {
    log calibration_body:name + "," + calibration_body:radius + "," + calibration_body:mu + "," +
        calibration_body:rotationperiod + "," + calibration_body:atm:height + "," +
        calibration_body:atm:sealevelpressure + "," + calibration_body:hasocean + "," +
        calibration_body:hassolidsurface + "," + calibration_body:angularvel:x + "," +
        calibration_body:angularvel:y + "," + calibration_body:angularvel:z to bodies_path.
}
print "Exported " + calibration_bodies:length + " bodies.".

// BOUNDS values are in its own vessel-oriented coordinates, not the raw KSP
// world axes. Reading SHIP:BOUNDS once avoids repeatedly forcing a kOS yield.
local vessel_bounds is ship:bounds.
local bounds_min is vessel_bounds:relmin.
local bounds_max is vessel_bounds:relmax.
local bounds_size is bounds_max-bounds_min.
local calibration_parts is list().
list parts in calibration_parts.
calibration_reset_file(craft_path,
    "name,body,status,mass_t,part_count,bounds_min_x,bounds_min_y,bounds_min_z,bounds_max_x,bounds_max_y,bounds_max_z,size_x,size_y,size_z").
log ship:name + "," + ship:body:name + "," + ship:status + "," + ship:mass + "," +
    calibration_parts:length + "," + bounds_min:x + "," + bounds_min:y + "," + bounds_min:z + "," +
    bounds_max:x + "," + bounds_max:y + "," + bounds_max:z + "," +
    bounds_size:x + "," + bounds_size:y + "," + bounds_size:z to craft_path.
print "Exported craft bounds and mass.".

// POSSIBLETHRUSTAT remains useful when an engine is shut down. MAXTHRUSTAT
// and AVAILABLETHRUSTAT are included so enabled/limited behavior is visible.
local pressures is list(0,0.01,0.025,0.05,0.1,0.2,0.4,0.6,0.8,1,1.5,2,3,5).
calibration_reset_file(engines_path,
    "engine_index,uid,name,mode,ignition,flameout,pressure_atm,possible_thrust_kn,max_thrust_kn,available_thrust_kn,isp_s,observed_altitude_m,observed_airspeed_mps").
local calibration_engines is list().
list engines in calibration_engines.
local engine_index is 0.
for calibration_engine in calibration_engines {
    local engine_mode is "single".
    if calibration_engine:multimode { set engine_mode to calibration_engine:mode. }
    calibration_engine_curve(calibration_engine,engine_index,engine_mode,pressures,engines_path).
    if calibration_engine:multimode {
        calibration_engine:togglemode().
        wait 1.
        calibration_engine_curve(calibration_engine,engine_index,calibration_engine:mode,pressures,engines_path).
        calibration_engine:togglemode().
        wait 1.
    }
    set engine_index to engine_index+1.
}
print "Exported " + calibration_engines:length + " engine curves.".

local far_safe is true.
if not ship:body:atm:exists {
    print "FAR grid skipped: current body has no atmosphere.".
    set far_safe to false.
}
if not addons:available("FAR") {
    print "FAR grid skipped: FAR kOS addon is unavailable.".
    set far_safe to false.
}
if ship:status = "LANDED" or ship:status = "SPLASHED" or alt:radar < 25 {
    print "FAR grid skipped: deployable sweep needs 25 m terrain clearance.".
    print "Move the craft safely into flight/orbit and rerun this script.".
    set far_safe to false.
}

if far_safe {
    local original_gear is gear.
    local original_brakes is brakes.
    calibration_reset_file(far_path,
        "configuration,altitude_m,speed_mps,aoa_deg,force_right_kn,force_top_kn,force_forward_kn").

    local altitude_fractions is list(0,0.025,0.05,0.075,0.1,0.15,0.2,0.3,0.4,0.5,0.65,0.8,0.9,1).
    local speeds is list(0,50,100,200,300,500,750,1000,1250,1500,1750,2000,2500,3000,3500).
    local aoas is list(-180,-150,-120,-90,-60,-45,-30,-20,-15,-12).
    local dense_aoa is -10.
    until dense_aoa > 40 {
        aoas:add(dense_aoa).
        set dense_aoa to dense_aoa+2.
    }
    for sparse_aoa in list(45,60,90,120,150,180) { aoas:add(sparse_aoa). }
    local configurations is list("clean","airbrake","gear","landing").
    local vessel_forward is ship:facing:forevector:normalized.
    local vessel_top is ship:facing:topvector:normalized.
    // Match lib_aerosim.ks exactly. KSP raw is left-handed; do not replace
    // this with a textbook frame assumption or reverse the VCRS arguments.
    local vessel_right is vcrs(vessel_top,vessel_forward):normalized.

    for configuration in configurations {
        print "Sampling FAR configuration: " + configuration.
        calibration_set_aero_configuration(configuration).
        for altitude_fraction in altitude_fractions {
            local sample_altitude is ship:body:atm:height*altitude_fraction.
            for sample_speed in speeds {
                for sample_aoa in aoas {
                    local sample_velocity is V(0,0,0).
                    if sample_speed > 0 {
                        // Same left-handed kOS Rodrigues convention used by
                        // POS's aeroforce_ld and sim_aeroaccel_load.
                        set sample_velocity to sample_speed*(
                            vessel_forward*cos(sample_aoa) +
                            vcrs(vessel_right,vessel_forward)*sin(sample_aoa) +
                            vessel_right*vdot(vessel_right,vessel_forward)*(1-cos(sample_aoa))).
                    }
                    local raw_force is addons:far:aeroforceat(sample_altitude,sample_velocity).
                    log configuration + "," + sample_altitude + "," + sample_speed + "," + sample_aoa + "," +
                        vdot(vessel_right,raw_force) + "," + vdot(vessel_top,raw_force) + "," +
                        vdot(vessel_forward,raw_force) to far_path.
                }
            }
            print "  altitude " + round(sample_altitude) + " m complete".
            wait 0.
        }
    }
    set gear to original_gear.
    set brakes to original_brakes.
    print "Exported FAR grid to " + far_path.
}

print "Calibration export complete: " + output_root.
