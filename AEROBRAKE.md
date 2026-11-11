# Aerobraking assistant

The Aerobrake program follows the AVES entry AoA schedule by default, with a
bank slider from -120 to +120 degrees. Clear **Use AVES AoA schedule** to use
the fixed AoA slider (0 to 60 degrees). DAP's normal envelope protection still
limits the applied flight commands.

**Cancel - return to POS** stops the assistant loop and disposes its GUI. It
releases steering and throttle locks, clears pending steering restoration, and
stops sending brake, bank and throttle commands. A previously selected CSS mode
is restored with the previous steering mode and current pilot demands; OFF is
restored otherwise, including when the previous selection was AUTO. The POS
menu selector reflects that choice. The launcher services CSS normally and keeps
OFF passive, so terrain protection cannot silently reclaim automatic steering.
The assistant keeps brakes off while active and sends no brake commands after
release.

An ascending atmospheric exit returns to the calling launcher. If actual
apoapsis falls below the atmosphere top first, the assistant releases ownership,
selects AUTO/AoA explicitly, and invokes POS3. Its cached DAP mode remains OFF
until the receiving program attaches its own automatic controls. Cancellation
has priority over that handoff.

## Predicted final apoapsis

The preview uses `current_simstate`, `gravitacc`, `sim_aeroaccel_load` and
`update_simstate_total_accel` from the existing simulation library. Every step
integrates 10 simulated seconds. The signed bank stays fixed throughout a
preview; AoA either stays at the fixed slider value or follows AVES at each
predicted altitude. Above the atmosphere the preview integrates gravity only.
After atmospheric entry and ascending exit, it computes the osculating apoapsis
from orbital energy and angular momentum. Escape and ground impact have explicit
statuses instead of a numeric apoapsis.

A preview starts immediately, then refreshes every 20 real seconds. Bank or
active fixed-AoA changes greater than 10 degrees relative to the previous solve
request trigger a refresh once the inputs remain unchanged for two real seconds.
Changing AoA mode uses the same debounce. Every change affecting a preview
invalidates its displayed result and abandons a running solve; smaller changes
wait for the periodic refresh.

Each control-loop iteration services DAP before performing at most one preview
step. A solve checks a two-second wall-clock deadline before and after each
step, and independently stops at 2,000 steps. It never calls the simulation
library's unbounded trajectory loops, waits inside prediction, or changes the
shared simulation timestep. Timeout and step-limit results remain visible until
the next refresh. Budget enforcement is cooperative between integration steps;
a native FAR query or a stalled game frame cannot be preempted by kOS script.
The wall-clock source is [KUNIVERSE:REALTIME](https://ksp-kos.github.io/KOS/structures/misc/kuniverse.html#KUNIVERSE:REALTIME).

This is a coarse requested-attitude preview. DAP smoothing and envelope limits
can cause the actual trajectory to differ. Long coasts or slow FAR queries can
exhaust the budget without producing an apoapsis.

## Validation

Run `node tests/test_aerobrake.cjs` for 52 assertions executing translated
production helper and orchestration bodies with deterministic clock, GUI and
simulation boundaries. These cover timing thresholds, stale inputs, signed bank,
fixed/scheduled AoA, timeout/step-limit/impact/escape results, the conic apoapsis
calculation, pilot control restoration, normal exit, and explicit POS3 transfer.
They do not emulate Unity scheduling or validate FAR accuracy.

The installed-kOS compiler check now includes the assistant, helper library and
launcher. It requires PowerShell/.NET and the installed KSP assembly; it was not
run in this environment. Existing entry-handoff (9,769 assertions), landing-flare
(five groups) and entry-chart asset (three tests) checks pass. The broader GUI
suite has one unrelated failure: `test_extracted_dialogs_preserve_production_logic`
expects a `gui_dialogs.ks` import in the unchanged `orbital_maneuver.ks`.

In KSP, verify cancel during a preview and while dragging a slider in CSS and
OFF, then exercise pilot throttle, bank and brakes after return. Verify ascending
exit returns to the menu, capture still enters POS3, and repeated runs do not
leave old GUI callbacks. Check prediction responsiveness and agreement with a
completed atmospheric pass, including time warp/lag and a solve that times out.
