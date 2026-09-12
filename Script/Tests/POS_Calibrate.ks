// Export a stationary FAR aerodynamic-force grid for tools/pos_sim.
//
// Run in a disposable save with the Poseidon safely in flight or orbit. This
// script never queries, toggles, or otherwise changes propulsion. It only asks
// FAR to evaluate the present vessel geometry at synthetic relative-wind
// vectors, so keep throttle at zero before starting it.

set CONFIG:IPU to 2000.

function calibration_reset_file {
    parameter path, header.
    if exists(path) { deletepath(path). }
    log header to path.
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
    // Let animations and FAR's voxel model settle before sampling.
    wait 2.
}

function calibration_relative_velocity {
    parameter speed, aoa, bank, vessel_forward, vessel_right.
    // The bank axis rotates the relative-wind/AoA plane around the fixed
    // vessel-forward axis. At zero bank this exactly preserves the previous
    // kOS left-handed Rodrigues construction. The vessel itself is never
    // rotated, avoiding a control input or a change to its flight path.
    local pitch_axis is vcrs(vessel_right,vessel_forward):normalized.
    local bank_axis is pitch_axis*cos(bank)+vessel_right*sin(bank).
    return speed*(vessel_forward*cos(aoa)+bank_axis*sin(aoa)).
}

clearscreen.
print "POS FAR aerodynamic calibration".
print "CONFIG:IPU = " + CONFIG:IPU.

local far_safe is true.
if not ship:body:atm:exists {
    print "FAR grid skipped: current body has no atmosphere.".
    set far_safe to false.
}
if not addons:available("FAR") {
    print "FAR grid skipped: FAR kOS addon is unavailable.".
    set far_safe to false.
}
if addons:available("FAR") and not addons:far:hassuffix("AEROFORCEAT") {
    print "FAR grid skipped: this FAR bridge has no AEROFORCEAT suffix.".
    set far_safe to false.
}
if ship:status = "LANDED" or ship:status = "SPLASHED" or alt:radar < 25 {
    print "FAR grid skipped: deployable sweep needs 25 m terrain clearance.".
    print "Move the craft safely into flight/orbit and rerun this script.".
    set far_safe to false.
}

if far_safe {
    local output_root is "0:/POS_calibration".
    if not exists(output_root) { createdir(output_root). }
    local far_path is output_root + "/far.csv".
    calibration_reset_file(far_path,
        "body,craft_name,configuration,altitude_m,speed_mps,aoa_deg,bank_deg,force_right_kn,force_top_kn,force_forward_kn").

    // Cover the full atmosphere, a subsonic-to-hypersonic speed range, the
    // complete AoA range, and every 15 degrees of relative-wind bank. This
    // produces 458,640 rows across the four deployable configurations.
    local altitude_fractions is list(0,0.025,0.05,0.075,0.1,0.15,0.2,0.3,0.4,0.5,0.65,0.8,0.9,1).
    local speeds is list(0,50,100,200,300,500,750,1000,1250,1500,1750,2000,2500,3000,3500).
    local aoas is list(-180,-150,-120,-90,-60,-45,-30,-20,-15,-12).
    local dense_aoa is -10.
    until dense_aoa > 40 {
        aoas:add(dense_aoa).
        set dense_aoa to dense_aoa+2.
    }
    for sparse_aoa in list(45,60,90,120,150,180) { aoas:add(sparse_aoa). }
    local banks is list(0,15,30,45,60,75,90,105,120,135,150,165,180).
    local configurations is list("clean","airbrake","gear","landing").
    local original_gear is gear.
    local original_brakes is brakes.
    local vessel_forward is ship:facing:forevector:normalized.
    local vessel_top is ship:facing:topvector:normalized.
    // Match lib_aerosim.ks exactly. KSP raw is left-handed; do not replace
    // this with a textbook frame assumption or reverse the VCRS arguments.
    local vessel_right is vcrs(vessel_top,vessel_forward):normalized.

    local sample_count is configurations:length*altitude_fractions:length*speeds:length*aoas:length*banks:length.
    print "Sampling " + sample_count + " FAR force points.".
    for configuration in configurations {
        print "Sampling FAR configuration: " + configuration.
        calibration_set_aero_configuration(configuration).
        for altitude_fraction in altitude_fractions {
            local sample_altitude is ship:body:atm:height*altitude_fraction.
            for sample_speed in speeds {
                for sample_aoa in aoas {
                    for sample_bank in banks {
                        local sample_velocity is V(0,0,0).
                        if sample_speed > 0 {
                            set sample_velocity to calibration_relative_velocity(
                                sample_speed,sample_aoa,sample_bank,vessel_forward,vessel_right).
                        }
                        local raw_force is addons:far:aeroforceat(sample_altitude,sample_velocity).
                        log ship:body:name + "," + ship:name + "," + configuration + "," +
                            sample_altitude + "," + sample_speed + "," + sample_aoa + "," + sample_bank + "," +
                            vdot(vessel_right,raw_force) + "," + vdot(vessel_top,raw_force) + "," +
                            vdot(vessel_forward,raw_force) to far_path.
                    }
                }
                // Yield between speed slices so the long one-off export does
                // not monopolize the kOS CPU or starve FAR/KSP updates.
                wait 0.
            }
            print "  altitude " + round(sample_altitude) + " m complete".
        }
    }
    set gear to original_gear.
    set brakes to original_brakes.
    print "Exported FAR grid to " + far_path.
}

print "FAR calibration complete.".
