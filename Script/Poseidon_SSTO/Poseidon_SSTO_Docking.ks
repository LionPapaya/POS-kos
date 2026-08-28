// Poseidon_SSTO_Docking.ks
// Short-range rendezvous and docking assistant.  The target vessel must first
// be selected in KSP.  Start in space, within 1 km and below 5 m/s relative
// speed.  The program then selects a compatible port on that vessel.
//
// The translation controller deliberately starts at a stand-off point on the
// target port axis.  It will not command final closure until lateral alignment
// and relative speed are both small.

RUNONCEPATH("0:/Libraries/lib_input_terminal.ks").

local docking_running is true.
local docking_paused is false.
local docking_phase is "setup".
local docking_result is "cancelled".
local docking_original_rcs is RCS.
local docking_original_sas is SAS.
local docking_original_control_part is ship:controlpart.
local docking_own_port is 0.
local docking_target_port is 0.
local docking_target_vessel is 0.
local docking_control_gui is 0.
local docking_pause_button is 0.
local docking_target_radius is 0.
local docking_own_radius is 0.
local docking_keepout_radius is 0.
local docking_route_radius is 0.
local docking_route_standoff is 0.
local docking_status_detail is "nominal".

function docking_limit {
    parameter value, limit.
    return max(-limit,min(limit,value)).
}

function docking_zero_translation {
    set ship:control:fore to 0.
    set ship:control:starboard to 0.
    set ship:control:top to 0.
}

function docking_apply_translation {
    parameter velocity_error, gain is 2.2, control_limit is 1.
    set ship:control:fore to docking_limit(
        vdot(velocity_error,ship:facing:forevector) * gain,control_limit
    ).
    set ship:control:starboard to docking_limit(
        vdot(velocity_error,ship:facing:starvector) * gain,control_limit
    ).
    set ship:control:top to docking_limit(
        vdot(velocity_error,ship:facing:topvector) * gain,control_limit
    ).
}

function docking_has_usable_rcs {
    local has_fore is false.
    local has_starboard is false.
    local has_top is false.
    for thruster in ship:rcs {
        if thruster:enabled and not thruster:flameout
            and thruster:availablethrust > 0 {
            if thruster:foreenabled { set has_fore to true. }
            if thruster:starboardenabled { set has_starboard to true. }
            if thruster:topenabled { set has_top to true. }
        }
    }
    return has_fore and has_starboard and has_top.
}

function docking_is_docked {
    parameter port.
    return port:haspartner or port:state:contains("Docked").
}

function docking_vessel_radius {
    parameter vessel.
    // Build the relatively expensive vessel bounds once during setup. The
    // centre offset plus half-diagonal encloses every corner around the CoM.
    local vessel_bounds is vessel:bounds.
    local radius is (vessel_bounds:abscenter - vessel:position):mag
        + vessel_bounds:extents:mag.
    return max(5,radius).
}

// Return a waypoint on a safe shell around the target.  Recalculating this
// every update produces short great-circle segments rather than a chord that
// cuts through the target vessel.
function docking_shell_waypoint {
    parameter center, current_position, goal_position, shell_radius, fallback_up.
    local current_offset is current_position - center.
    local goal_offset is goal_position - center.
    if current_offset:mag < 0.1 {
        set current_offset to fallback_up.
    }
    local current_direction is current_offset:normalized.
    local goal_direction is goal_offset:normalized.

    if current_offset:mag < shell_radius - 2 {
        return center + current_direction * shell_radius.
    }

    local direction_dot is docking_limit(vdot(current_direction,goal_direction),1).
    local direction_angle is arccos(direction_dot).
    if direction_angle < 18 {
        return goal_position.
    }

    local route_normal is vcrs(current_direction,goal_direction).
    if route_normal:mag < 0.01 {
        set route_normal to vcrs(current_direction,fallback_up).
    }
    if route_normal:mag < 0.01 {
        set route_normal to vcrs(current_direction,v(0,1,0)).
    }
    if route_normal:mag < 0.01 {
        set route_normal to vcrs(current_direction,v(1,0,0)).
    }
    if route_normal:mag < 0.01 {
        set route_normal to vcrs(current_direction,v(0,0,1)).
    }
    // All three world axes cannot be parallel to current_direction.  Trying
    // each one prevents NORMALIZED from ever seeing a zero vector when the
    // start and goal happen to be exactly opposite each other.
    local tangent is vcrs(route_normal:normalized,current_direction):normalized.
    local step_angle is 12.
    local waypoint_direction is
        (current_direction * cos(step_angle) + tangent * sin(step_angle)):normalized.
    return center + waypoint_direction * shell_radius.
}

function docking_port_label {
    parameter port, index.
    local label is index + ": " + port:title.
    if port:tag <> "" {
        set label to label + " [" + port:tag + "]".
    }
    return label + " | " + port:nodetype + " | " + port:state.
}

function docking_choose_port {
    parameter ports, prompt.
    clearScreen.
    print prompt.
    print "".
    local i is 0.
    for port in ports {
        print docking_port_label(port,i).
        set i to i + 1.
    }
    print "".
    print "Enter port number: ".
    local selected is round(terminal_input_number(19,i + 3,3," 0")).
    if selected < 0 or selected >= ports:length {
        return -1.
    }
    return selected.
}

function docking_select_own_port {
    local ready_ports is list().
    for port in ship:dockingports {
        if port:state = "Ready" or port:state = "PreAttached" {
            ready_ports:add(port).
        }
    }

    if ready_ports:length = 0 {
        print "No ready docking port found on this vessel.".
        print "Open the Mk2 inline docking port and try again.".
        return 0.
    }

    // Poseidon Block 2 has one Mk2 Clamp-O-Tron. Prefer it automatically,
    // while retaining selection support for related craft with several ports.
    local inline_matches is list().
    for port in ready_ports {
        local description is (port:name + " " + port:title + " " + port:tag):lower.
        if description:contains("mk2") or description:contains("inline") {
            inline_matches:add(port).
        }
    }
    if inline_matches:length = 1 {
        return inline_matches[0].
    }
    if ready_ports:length = 1 {
        return ready_ports[0].
    }
    local choice is docking_choose_port(ready_ports,"Select this vessel's docking port").
    if choice < 0 { return 0. }
    return ready_ports[choice].
}

function docking_get_target_vessel {
    parameter selected_target.
    if selected_target = 0 { return 0. }
    if selected_target:istype("DockingPort") or selected_target:istype("Part") {
        return selected_target:ship.
    }
    if selected_target:istype("Vessel") {
        return selected_target.
    }
    return 0.
}

function docking_select_target_port {
    parameter target_vessel, own_port, selected_target.
    if not target_vessel:loaded or not target_vessel:unpacked {
        print "Target vessel is outside full physics range.".
        print "Move within loading range before running docking.".
        return 0.
    }
    local candidates is list().
    for port in target_vessel:dockingports {
        if (port:state = "Ready" or port:state = "PreAttached")
            and port:targetable and port:nodetype = own_port:nodetype {
            candidates:add(port).
        }
    }
    if candidates:length = 0 {
        print "No ready, compatible target docking port found.".
        print "The target must be loaded and its port must be open.".
        return 0.
    }
    // Respect a port explicitly selected in KSP.  Previously the script could
    // silently choose another compatible port (or prompt again), which is
    // particularly confusing at short range.
    if selected_target <> 0 and selected_target:istype("DockingPort") {
        for port in candidates {
            if port = selected_target { return port. }
        }
        print "The selected target port is not ready or is incompatible.".
        return 0.
    }
    if candidates:length = 1 {
        return candidates[0].
    }
    local choice is docking_choose_port(candidates,"Select a port on " + target_vessel:name).
    if choice < 0 { return 0. }
    return candidates[choice].
}

function docking_release_controls {
    docking_zero_translation().
    set ship:control:mainthrottle to 0.
    unlock steering.
    if docking_control_gui <> 0 {
        docking_control_gui:hide().
    }
    docking_original_control_part:controlfrom().
    if docking_original_rcs { RCS ON. } else { RCS OFF. }
    if docking_original_sas { SAS ON. } else { SAS OFF. }
}

function docking_toggle_pause {
    set docking_paused to not docking_paused.
    if docking_pause_button <> 0 {
        set docking_pause_button:text to choose "Resume" if docking_paused else "Pause / hold".
    }
}

function docking_abort {
    set docking_result to "aborted by operator".
    set docking_running to false.
}

function docking_create_control_gui {
    set docking_control_gui to GUI(260,90).
    set docking_control_gui:style:width to 260.
    set docking_control_gui:style:height to 90.
    local title_row is docking_control_gui:addhbox().
    title_row:addlabel("<b>POS Docking Control</b>").
    local button_row is docking_control_gui:addhbox().
    set docking_pause_button to button_row:addbutton("Pause / hold").
    local abort_button is button_row:addbutton("ABORT").
    set docking_pause_button:onclick to docking_toggle_pause@.
    set abort_button:onclick to docking_abort@.
    docking_control_gui:show().
}

function docking_read_keys {
    if terminal:input:haschar {
        local key is terminal:input:getchar():tostring():upper.
        if key = "Q" {
            set docking_result to "aborted by operator".
            set docking_running to false.
        }
        if key = "P" {
            docking_toggle_pause().
        }
    }
}

clearScreen.
print "POS Docking".
print "Select the target vessel in KSP before starting this program.".
print "Start in space within 1 km and below 5 m/s relative speed.".
print "Use the docking-control window to pause or abort.".
print "".

set docking_own_port to docking_select_own_port().
local docking_selected_target is 0.
if hastarget { set docking_selected_target to target. }
if docking_own_port <> 0 {
    set docking_target_vessel to docking_get_target_vessel(docking_selected_target).
    if docking_target_vessel = 0 {
        print "No target vessel selected. Docking cancelled.".
    } else if docking_target_vessel = ship {
        print "The target must be another vessel. Docking cancelled.".
    } else {
        set docking_target_port to docking_select_target_port(
            docking_target_vessel,docking_own_port,docking_selected_target
        ).
    }
}

if docking_own_port <> 0 and docking_target_port <> 0 {
    local initial_target_distance is
        (docking_target_vessel:position - ship:position):mag.
    local initial_relative_speed is
        (ship:velocity:orbit - docking_target_vessel:velocity:orbit):mag.
    local docking_in_space is true.
    if ship:body:atm:exists and ship:altitude <= ship:body:atm:height {
        set docking_in_space to false.
    }
    if not docking_in_space {
        set docking_result to "start outside the atmosphere".
        print "Docking cancelled: Poseidon is still inside the atmosphere.".
    } else if initial_target_distance > 1000 {
        set docking_result to "target is farther than 1 km".
        print "Docking cancelled: target is " + round(initial_target_distance) + " m away.".
    } else if initial_relative_speed >= 5 {
        set docking_result to "relative speed is 5 m/s or greater".
        print "Docking cancelled: relative speed is " + round(initial_relative_speed,2) + " m/s.".
    } else {
        set docking_target_radius to docking_vessel_radius(docking_target_vessel).
        set docking_own_radius to docking_vessel_radius(ship).
        set docking_keepout_radius to docking_target_radius + docking_own_radius + 8.
        set docking_route_radius to docking_keepout_radius + max(15,docking_own_radius * 0.5).
        set docking_route_standoff to max(30,docking_own_radius + 15).
        local initial_route_goal is docking_target_port:nodeposition
            + docking_target_port:portfacing:vector:normalized * docking_route_standoff.
        local initial_goal_radius is
            (initial_route_goal - docking_target_vessel:position):mag.
        if initial_goal_radius < docking_route_radius + 5 {
            set docking_route_standoff to docking_route_standoff
                + docking_route_radius + 5 - initial_goal_radius.
        }
        set docking_phase to "velocity match".
        set docking_result to "running".
    }
}

if docking_result = "running" {
    docking_own_port:controlfrom().
    set target to docking_target_port.
    SAS OFF.
    RCS ON.
    wait 0.
    if not docking_has_usable_rcs() {
        set docking_result to "no enabled, fueled translation RCS is available".
        set docking_running to false.
    }
    docking_create_control_gui().

    local previous_port_delta is
        docking_target_port:nodeposition - docking_own_port:nodeposition.
    local previous_sample_time is time:seconds.
    local port_relative_velocity is
        ship:velocity:orbit - docking_target_vessel:velocity:orbit.
    local observed_phase is docking_phase.
    local best_progress_error is 999999.
    local last_progress_time is time:seconds.
    local stall_recoveries is 0.
    local capture_started is 0.

    until not docking_running {
        docking_read_keys().
        if not docking_running { break. }

        if docking_is_docked(docking_target_port) or docking_is_docked(docking_own_port) {
            set docking_result to "docked".
            set docking_running to false.
        }
        if not docking_running { break. }

        if docking_target_vessel:isdead or not docking_target_vessel:loaded
            or not docking_target_vessel:unpacked {
            set docking_result to "target vessel left full physics range".
            set docking_running to false.
        } else if docking_own_port:state <> "Ready"
            and docking_own_port:state <> "PreAttached" {
            set docking_result to "own docking port became " + docking_own_port:state.
            set docking_running to false.
        } else if docking_target_port:state <> "Ready"
            and docking_target_port:state <> "PreAttached" {
            set docking_result to "target docking port became " + docking_target_port:state.
            set docking_running to false.
        }
        if not docking_running { break. }

        local target_axis is docking_target_port:portfacing:vector:normalized.
        local target_top is docking_target_port:portfacing:topvector:normalized.
        // NODEPOSITION is the actual mating face; POSITION is only the part's
        // centre and is notably wrong for the inline Mk2 docking-port part.
        local port_delta is docking_target_port:nodeposition - docking_own_port:nodeposition.
        // Positive axial distance means Poseidon is in front of the target
        // port (the target port's facing vector points toward Poseidon).
        local axial_distance is -vdot(port_delta,target_axis).
        local lateral_error is (port_delta + target_axis * axial_distance):mag.
        local alignment_error is
            vang(docking_own_port:portfacing:vector,-target_axis).
        local sample_time is time:seconds.
        local sample_dt is sample_time - previous_sample_time.
        if sample_dt > 0.001 and sample_dt < 1 {
            // Differentiating the actual node-to-node vector includes target
            // rotation, own-vessel rotation, and translation. COM velocities
            // alone omit both ports' tangential motion.
            local measured_port_velocity is -(port_delta - previous_port_delta) / sample_dt.
            set port_relative_velocity to
                port_relative_velocity * 0.65 + measured_port_velocity * 0.35.
        }
        set previous_port_delta to port_delta.
        set previous_sample_time to sample_time.
        local relative_speed is port_relative_velocity:mag.
        local closing_speed is -vdot(port_relative_velocity,target_axis).

        // Magnetic capture is a KSP-controlled transition. Fighting it with
        // translation inputs is a common cause of bounce-offs.
        local capture_active is docking_own_port:state = "PreAttached"
            or docking_target_port:state = "PreAttached".
        if capture_active and capture_started = 0 {
            set capture_started to time:seconds.
            set docking_phase to "magnetic capture".
        }
        if not capture_active and docking_phase = "magnetic capture" {
            set capture_started to 0.
            set docking_phase to "approach gate".
            set docking_status_detail to "capture released; retrying gently".
        }
        if capture_active and time:seconds - capture_started > 20 {
            set docking_result to "magnetic capture did not complete within 20 seconds".
            set docking_running to false.
        }
        if not docking_running { break. }

        // A drift out of the final corridor is recoverable. Backing out to the
        // gate is safer and much more useful than dropping all control at once.
        if docking_phase = "final" and not capture_active
            and (axial_distance < 0.15 or lateral_error > 0.75
                or alignment_error > 4 or closing_speed > 0.35) {
            set docking_phase to "approach gate".
            set docking_status_detail to "final corridor lost; returning to gate".
        }

        // Both docking-port faces must oppose each other. CONTROLFROM makes
        // the ship axes and RCS translation axes relative to Poseidon's port.
        // Once the magnets engage, release cooked steering as well as
        // translation so KSP's capture torque can settle the two vessels.
        if capture_active {
            unlock steering.
        } else {
            lock steering to lookdirup(-target_axis,target_top).
        }

        local target_center is docking_target_vessel:position.
        local own_position is docking_own_port:nodeposition.
        local center_offset is own_position - target_center.
        local center_distance is center_offset:mag.
        local route_goal is
            docking_target_port:nodeposition + target_axis * docking_route_standoff.
        local aim_point is own_position.
        local max_closure is 0.8.
        local position_gain is 0.08.
        local progress_error is 0.

        if docking_phase = "magnetic capture" {
            set aim_point to own_position.
            set max_closure to 0.
            set progress_error to port_delta:mag.
        } else if docking_phase = "velocity match" {
            // First remove the inherited relative velocity. Holding the current
            // position here avoids adding a large translation demand while RCS
            // is still cancelling as much as 5 m/s.
            set aim_point to own_position.
            set max_closure to 1.25.
            set progress_error to relative_speed.
            if relative_speed < 0.3 {
                // Do not send an already aligned vessel on a hazardous and
                // unnecessary trip around the keep-out shell.
                if axial_distance > 2
                    and lateral_error < 4 {
                    set docking_phase to choose "approach gate"
                        if axial_distance < 12 and lateral_error < 1 and alignment_error < 3
                        else "stand-off".
                } else {
                    set docking_phase to choose "clear target"
                        if center_distance < docking_route_radius - 2
                        else "route around".
                }
            }
        } else if docking_phase = "clear target" {
            // Move radially away before going around; this prevents a route
            // chord from passing through the target or clipping its appendages.
            local escape_direction is center_offset.
            if escape_direction:mag < 0.1 { set escape_direction to target_top. }
            set aim_point to target_center + escape_direction:normalized * docking_route_radius.
            set max_closure to 0.8.
            set progress_error to max(0,docking_route_radius - center_distance).
            if center_distance >= docking_route_radius - 2 and relative_speed < 0.5 {
                set docking_phase to "route around".
            }
        } else if docking_phase = "route around" {
            set aim_point to docking_shell_waypoint(
                target_center,own_position,route_goal,docking_route_radius,target_top
            ).
            set max_closure to 1.2.
            set progress_error to (own_position - route_goal):mag.
            if (own_position - route_goal):mag < 4 and relative_speed < 0.5 {
                set docking_phase to "stand-off".
            }
        } else if docking_phase = "stand-off" {
            set aim_point to docking_target_port:nodeposition + target_axis * 25.
            set max_closure to 0.8.
            set position_gain to 0.1.
            set progress_error to (aim_point - own_position):mag.
            if lateral_error < 1.5 and abs(axial_distance - 25) < 2
                and relative_speed < 0.5 and alignment_error < 3 {
                set docking_phase to "approach gate".
            }
        } else if docking_phase = "approach gate" {
            set aim_point to docking_target_port:nodeposition + target_axis * 7.
            set max_closure to 0.3.
            set position_gain to 0.12.
            set progress_error to (aim_point - own_position):mag.
            if lateral_error < 0.35 and abs(axial_distance - 7) < 0.8
                and relative_speed < 0.25 and alignment_error < 1 {
                set docking_phase to "final".
            }
        } else {
            set aim_point to docking_target_port:nodeposition.
            set max_closure to min(0.12,max(0.04,axial_distance * 0.035)).
            set position_gain to 0.14.
            set progress_error to port_delta:mag.
        }

        if docking_phase <> observed_phase {
            set observed_phase to docking_phase.
            set best_progress_error to 999999.
            set last_progress_time to time:seconds.
        } else if progress_error < best_progress_error - 0.2 {
            set best_progress_error to progress_error.
            set last_progress_time to time:seconds.
        }
        if docking_paused { set last_progress_time to time:seconds. }

        if capture_active {
            docking_zero_translation().
        } else if docking_paused {
            docking_apply_translation(-port_relative_velocity,2,0.35).
        } else {
            local position_error is aim_point - docking_own_port:nodeposition.
            local desired_port_velocity is position_error * position_gain.

            // Limit commanded speed independently of controller gain.
            if desired_port_velocity:mag > max_closure {
                set desired_port_velocity to desired_port_velocity:normalized * max_closure.
            }
            docking_apply_translation(desired_port_velocity - port_relative_velocity).
        }

        // One automatic reset handles transient oscillation or a bad initial
        // velocity estimate. A second 45-second stall indicates unavailable
        // translation authority or geometry the autopilot cannot safely solve.
        if not docking_paused and not capture_active
            and time:seconds - last_progress_time > 45 {
            if stall_recoveries = 0 {
                set stall_recoveries to 1.
                set docking_phase to choose "approach gate"
                    if axial_distance > 0.15 and lateral_error < 2
                    else "velocity match".
                set observed_phase to "reset pending".
                set docking_status_detail to "progress stalled; resetting approach".
            } else {
                set docking_result to "no docking progress; check RCS authority and obstructions".
                set docking_running to false.
            }
        }

        local pause_text is choose " (PAUSED)" if docking_paused else "          ".
        print ("Phase: " + docking_phase + pause_text):padright(52) at(0,7).
        print ("Port distance: " + round(port_delta:mag,2) + " m"):padright(52) at(0,8).
        print ("Axial / lateral: " + round(axial_distance,2) + " / " + round(lateral_error,2) + " m"):padright(52) at(0,9).
        print ("Relative speed: " + round(relative_speed,3) + " m/s"):padright(52) at(0,10).
        print ("Target clearance: " + round(center_distance - docking_keepout_radius,1) + " m"):padright(52) at(0,11).
        print ("Port alignment error: " + round(alignment_error,2) + " deg"):padright(52) at(0,12).
        print ("Status: " + docking_status_detail):padright(60) at(0,13).
        print "Use docking-control window | terminal P/Q also work" at(0,14).

        if port_delta:mag > 2000 {
            set docking_result to "target moved outside safe physics range".
            set docking_running to false.
        }
        wait 0.
    }
}

docking_release_controls().
print ("Docking program ended: " + docking_result):padright(70) at(0,15).
