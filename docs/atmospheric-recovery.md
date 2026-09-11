# Poseidon atmospheric recovery on Kerbin

`POS6.ks` performs one aerobraking/aerocapture pass. `POS3.ks` performs entry and landing. Both are for the existing Poseidon SSTO on Kerbin with the FAR kOS addon.

## Aerobraking

Run `runpath("0:/POS6.ks").` or select **Aerobraking (single pass)** in the POS menu. Start on the inbound **Kerbin** orbit patch, above 170 km, with enough time for the approach correction. A return from a moon or another planet must already be on a Kerbin encounter; this program does not create the interplanetary transfer or moon escape. Existing maneuver nodes must be resolved first.

The program forecasts periapsis candidates from **50 down to 35 km**, in 2.5 km steps, using FAR's onboard aerodynamic force query. Each forecast follows the same bank/exit command law as the live pass. The planner rejects candidates that fail to leave the atmosphere, violate the configured load margins, descend too low, or leave too little exit-orbit height. Among the accepted candidates evaluated within the planning budget, it chooses the lowest predicted exit orbital energy. This is a bounded search, not a proof of the globally lowest possible orbit.

Review the chosen periapsis, predicted exit apoapsis, and correction delta-v in the in-game panel, then click **Execute planned approach and aerobrake**. The approach correction uses the NERVs, with alignment, available-thrust, time, progress, and final-periapsis checks. A cancelled, expired, or unsuccessful correction returns control and reports its reason.

During the pass, engines, landing gear and brakes remain off. Bank regulates descent while preserving positive lift. Pressure, aerodynamic acceleration, the heating estimate, projected altitude, and projected energy loss can latch a lift-up exit. Once latched, the controller does not command another dive. An atmospheric exit is confirmed only after the craft remains above the atmosphere plus a 2 km margin with outward velocity for three seconds.

**There is no post-pass burn, automatic repeat pass, or landing handoff.** The program returns control to coast after exit. Periapsis can remain inside the atmosphere, so the next orbit may enter it again unless you plan another maneuver. A pass that exits while still escaping reports `exited_still_escaping`; exit and capture are separate results.

The selected forecast must retain a nominal 120 km exit-apoapsis floor. This reserve supports the atmospheric exit objective; it is not an apoapsis target that the controller guarantees to hit. If no acceptable pass is predicted within 35–50 km, the program refuses the approach instead of choosing a deeper full entry.

## Limits and model boundaries

Configuration is in `Poseidon_SSTO["Entry"]` and `Poseidon_SSTO["Aerobrake"]` in `Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks`:

| Setting | Initial value |
| --- | ---: |
| Maximum dynamic pressure | 20 kPa |
| Maximum aerodynamic acceleration | 4 g |
| Aerobrake angle of attack | 25 degrees |
| Maximum aerobrake bank | 55 degrees |
| Full high-energy POS3 angle of attack | 28 degrees |
| Maximum POS3 entry bank | 70 degrees |
| Minimum aerobrake altitude reserve | 33 km |
| Pullout lead time | 30 s |
| Forecast acceptance margin on loads | 80% of the configured maxima |
| Heating estimate reference | 3,200 m/s at 6 kPa |

The heating estimate is `sqrt(q / q_reference) * (speed / speed_reference)^2`, a normalized convective-load proxy derived from the density/speed dependence. It is **not a part-temperature reading or a calibrated temperature limit**. The standard [kOS Part interface](https://ksp-kos.github.io/KOS/structures/vessels/part.html) does not expose general skin/internal-temperature suffixes; the [kOS source](https://github.com/KSP-KOS/KOS/blob/develop/src/kOS/Suffixed/Part/PartValue.cs) defines the supported part suffixes. Monitor actual part temperatures in KSP when validating these initial limits. FAR force forecasts also do not establish achievable attitude response, aerodynamic moments, thermal soak, or structural margins.

Dynamic pressure from `SHIP:Q` is converted from atmospheres to kPa using `CONSTANT:ATMTOKPA`, as specified by the [kOS vessel interface](https://ksp-kos.github.io/KOS/structures/vessels/vessel.html#vessel-dynamicpressure). Forecast pressure uses the body's pressure, temperature and molecular mass; live protection uses measured vessel pressure and FAR force.

## POS3 entry recovery

POS3 checks boundness before using apoapsis, accepts atmospheric inbound hyperbolic trajectories with a later outgoing orbit patch, and establishes entry attitude before the atmosphere or on a late start. Its high-energy AoA schedule is shared with the onboard entry forecast. Orbit states, forecast positions and planned ground tracks carry a time origin so planet rotation is accounted for during long forecasts.

The entry solver has a real-time deadline and a predicted-flight duration bound. Skips, invalid endpoints, incomplete plans, excessive iterations and timeouts return explicit failures. `calc_entry_traj()` returns `entry_pos_square` as an ordered list of geographic vertices whenever reachability construction succeeds. The footprint can be a triangle or a quadrilateral; an empty list means there is no usable footprint. Failed iterative solves can also retain `best_state` and `best_error`.

Only a converged plan with at least two chronological samples may drive the reference controller. POS3 invalidates expired or substantially divergent plans, retains basic bank/AoA guidance, and spaces out further solver attempts. It does not index `converged_sim` on a failed result or endlessly repeat the old alternate search every control tick.

If a target cannot be solved, automatic alternate selection:

1. Tests catalog runway **TEAM interface points** against the returned footprint and prefers a reachable catalog runway near the original destination.
2. If no catalog runway qualifies, samples interior interface points and looks ahead for a land strip. It screens a 3 km strip, including points 50 m either side, rejecting water, excessive grade and terrain variation. The resulting TEAM interface must still lie inside the footprint.
3. Rebuilds runway position, end, heading, altitude, TEAM target, Trajectories target, plan state and terminal-route state together. It records attempted targets to avoid oscillation and permits at most two automatic target changes per run.

A screened off-field site is a coarse terrain candidate, not a surveyed runway. The existing terminal landing stability gates and terrain protection still apply. If no nearby terminal area is reachable when entry ends, POS3 reports `no_reachable_terminal_area` and returns control rather than starting a remote runway approach. A real atmospheric skip reports `entry_skipped_to_space`, without reporting a landing success.

## Validation and telemetry

The atmospheric behavior requires validation in KSP/FAR. Source auditing and syntax parsing performed during development do not establish flight performance. Development tools and the standalone math-check script are maintained locally and are not included in this repository.

Flight logger schema **9** adds `atmosphere_*` columns for energy and energy rate, eccentricity, apsides, pressure in kPa, aerodynamic g, heating proxy, planned periapsis, exit latch/confirmation, reason, plan validity/age and retarget count. Low mode records transition events; medium retains one-second sampling; high retains per-control-tick sampling. Existing bank, AoA, throttle, RCS, envelope and terrain fields remain available. No logger runs inside the onboard trajectory integrators.

Relevant events are `aerobrake_candidate`, `aerobrake_plan`, `aerobrake_correction`, `atmosphere_state`, `aerobrake_complete`, `entry_solver`, `entry_plan_invalid`, `entry_retarget`, `entry_alternate_unavailable`, and `entry_skip_exit`. Solver events include footprint vertices and best endpoint error when available.

KSP/FAR validation cases:

- Moon return and a faster hyperbolic return: compare predicted/actual exit, minimum altitude, peak pressure, g and heating proxy, actual part temperatures, bank tracking and exit apoapsis.
- Deliberately infeasible high-energy return: verify that the planner declines every unsafe candidate and does not command a full entry.
- Cancelled or late approach approval, missing NERV thrust, poor alignment and a stalled burn: verify cutoff, node cleanup and a failure result.
- POS3 with an unreachable runway: verify alternate interface containment, complete runway metadata changes and successful replanning or continued basic guidance.
- POS3 deadline/nonconvergence, late start, longitude-seam footprint and atmospheric skip: verify no missing-key exceptions, retry throttling, correct plan validity and the appropriate handoff.
- Repeat POS3/POS6 from the menu on the same processor: verify no stale target, terminal route, entry plan or throttle state survives.
