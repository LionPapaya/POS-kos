// PASSIVE GUI PERFORMANCE BENCHMARK. Run only on a fresh, idle kOS CPU.
// Usage: RUNPATH("0:/GUI_BENCH.ks"). No flight scripts, controls, locks,
// actuators, maneuver nodes, vessel writes, file writes, or IPU changes.
// Measures synthetic ascent GUI updates and a matched lightweight loop.
if defined dap or defined step or defined main_step or defined AVES or defined confirm_in {
    print "GUI_BENCH requires a fresh idle CPU; reboot before running it.".
    until false { wait 1. }
}
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/ascent_gui.ks").

global dap is lex("dap_mode","AUTO").
global step is "gui_bench".
global confirm_in is true.
global Lastest_status is "SYNTHETIC BENCHMARK".
global AVES is lex("Speed",lex("Rotate",100),"Ascent",lex(
    "speed_build_target",400,"closed_cycle_min_altitude",22000,"rapier_cutoff_apoapsis",75000)).
function gui_bench_sample {
    parameter preset.
    local sample is lex().
    set sample["airspeed"] to 0.
    set sample["alignment"] to 0.
    set sample["altitude"] to 0.
    set sample["apoapsis"] to 0.
    set sample["attitude_error"] to 0.
    set sample["burn_seconds"] to 0.
    set sample["burn_window_seconds"] to 0.
    set sample["climb_alt"] to 0.
    set sample["climb_speed"] to 0.
    set sample["command_kind"] to 0.
    set sample["command_valid"] to 0.
    set sample["cutoff_ap"] to 0.
    set sample["dap_mode"] to 0.
    set sample["downrange"] to 0.
    set sample["elapsed"] to 0.
    set sample["eta_apoapsis"] to 0.
    set sample["finished"] to 0.
    set sample["heading"] to 0.
    set sample["heading_command"] to 0.
    set sample["health"] to 0.
    set sample["inclination"] to 0.
    set sample["insertion_altitude_ready"] to 0.
    set sample["insertion_valid"] to 0.
    set sample["nervs"] to 0.
    set sample["orbit_valid"] to 0.
    set sample["outcome"] to 0.
    set sample["page"] to 0.
    set sample["periapsis"] to 0.
    set sample["phase"] to 0.
    set sample["pitch"] to 0.
    set sample["pitch_command"] to 0.
    set sample["rapier_mode"] to 0.
    set sample["rapiers"] to 0.
    set sample["recovery"] to 0.
    set sample["remaining_dv"] to 0.
    set sample["stop_reference_m"] to 0.
    set sample["stop_reference_valid"] to 0.
    set sample["surface_speed"] to 0.
    set sample["target_ap"] to 0.
    set sample["target_inc"] to 0.
    set sample["target_pe"] to 0.
    set sample["throttle"] to 0.
    set sample["ut"] to 0.
    set sample["v1_actual_speed"] to 0.
    set sample["v1_called"] to 0.
    set sample["v1_estimate"] to 0.
    set sample["v1_marker_speed"] to 0.
    set sample["v1_prediction"] to 0.
    set sample["vertical_speed"] to 0.
    set sample["vr_speed"] to 0.
    for flag in list("finished","recovery","v1_called","stop_reference_valid","insertion_valid",
        "insertion_altitude_ready","command_valid","rapiers","nervs") { set sample[flag] to false. }
    set sample["orbit_valid"] to true.
    set sample["page"] to "ASCENT 1 / 2".
    set sample["phase"] to "high_altitude_climb".
    set sample["health"] to "SYNTHETIC - no flight controller".
    set sample["dap_mode"] to "AUTO".
    set sample["rapier_mode"] to "AIR".
    set sample["command_kind"] to "angles".
    set sample["outcome"] to "Display fixture only".
    set sample["altitude"] to 15000.
    set sample["airspeed"] to 900.
    set sample["surface_speed"] to 880.
    set sample["vertical_speed"] to 70.
    set sample["pitch"] to 15.
    set sample["heading"] to 90.
    set sample["climb_alt"] to 20000.
    set sample["climb_speed"] to 1200.
    set sample["target_ap"] to 80000.
    set sample["target_pe"] to 80000.
    set sample["cutoff_ap"] to 85000.
    set sample["apoapsis"] to 60000.
    set sample["periapsis"] to -20000.
    set sample["vr_speed"] to 100.
    set sample["v1_estimate"] to 85.
    set sample["v1_prediction"] to lex("remaining_m",1800,"limited",false,"valid",true,"reason","fixture").
    if preset = "Takeoff" or preset = "V1 unavailable" {
        set sample["page"] to "TAKEOFF". set sample["phase"] to "launch".
        set sample["surface_speed"] to 60. set sample["airspeed"] to 65.
        if preset = "V1 unavailable" { set sample["v1_prediction"]["valid"] to false. }
    }
    if preset = "Ascent 2" {
        set sample["page"] to "ASCENT 2 / 2". set sample["phase"] to "closed_cycle_climb".
    }
    if preset = "Insertion" or preset = "Finished" {
        set sample["page"] to "CIRC". set sample["phase"] to "coast_align".
        set sample["insertion_valid"] to true. set sample["burn_window_seconds"] to 45.
        set sample["remaining_dv"] to 120. set sample["alignment"] to 2.
        set sample["burn_seconds"] to 30. set sample["eta_apoapsis"] to 60.
        if preset = "Finished" { set sample["finished"] to true. set sample["phase"] to "complete". }
    }
    if preset = "Open trajectory" { set sample["orbit_valid"] to false. }
    if preset = "Off chart" { set sample["altitude"] to 40000. set sample["airspeed"] to 2000. }
    return sample.
}
// Construct exactly one real ascent panel before timing. confirm_in bypasses
// the setup wait; constructor reads vessel list for a menu but never writes it.
create_assent_gui().
local bench_count is 12.
local base_start_time is time:seconds.
local base_start_ops is opcodesleft.
local checksum is 0.
for bench_i in range(0,bench_count-1) {
    set checksum to checksum + bench_i * 3 + 1.
}
local base_end_ops is opcodesleft.
local base_end_time is time:seconds.
local baseline_ticks_crossed is base_end_time <> base_start_time.
local baseline_ops is -1.
if not baseline_ticks_crossed { set baseline_ops to base_start_ops-base_end_ops. }

local preset_names is list("Takeoff","Ascent 1","Ascent 2","Insertion").
local update_results is list().
for preset_name in preset_names {
    local fixture is gui_bench_sample(preset_name).
    local start_time is time:seconds.
    local start_ops is opcodesleft.
    for bench_i in range(0,bench_count-1) {
        update_assent_gui(fixture).
    }
    local end_ops is opcodesleft.
    local end_time is time:seconds.
    local crossed is end_time <> start_time.
    local spent is -1.
    if not crossed { set spent to start_ops-end_ops. }
    update_results:add(lex("name",preset_name,"seconds",end_time-start_time,
        "crossed",crossed,"ops",spent)).
}

assent_gui:dispose().
print "POS GUI BENCH / synthetic values / updates per case: "+bench_count.
print "CONFIG:IPU was not read or changed. No explicit wait inside measured loops; kOS may yield at IPU limits.".
print "Baseline loop: UT seconds="+(base_end_time-base_start_time)+
    " | same-tick opcodes="+baseline_ops+" | checksum="+checksum.
for result in update_results {
    local ops_text is "same-tick opcodes="+result["ops"].
    if result["crossed"] { set ops_text to "opcode delta unavailable (physics tick crossed)". }
    print result["name"]+": UT seconds="+result["seconds"]+" | "+ops_text.
}
print "Interpret UT as quantized simulated time, not CPU wall time; zero means below clock resolution.".
print "Baseline is a lightweight reference, not a correction to subtract. GUI updates include formatting and property assignments, not Unity render/frame cost or wall time.".
print "Benchmark ended. Reboot CPU before POS use; benchmark globals remain.".
