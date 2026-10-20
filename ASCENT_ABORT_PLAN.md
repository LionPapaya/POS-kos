# Ascent abort replacement plan

Date: 2026-10-02. Design for replacing ATI; AED, ATO and EDR are not implemented by this document. The separate implemented change routes `ascent_alignment` to RTLS and adds RTLS evidence. Existing uncommitted work is retained.

## Agreed vehicle assumptions

- Two operating RAPIERs on opposite sides are controllable using their gimbals. Accept this craft-specific assumption; do not require a new torque-certification gate for that configuration.
- Two operating RAPIERs on the same side must not both remain active during ATO. Shut down at least one. Evaluate a permitted single-RAPIER plus healthy-NERV configuration; if unsuitable, isolate both and evaluate late NERV-only ATO. Single-RAPIER capability needs a configured/calibrated policy; it is not established by the opposite-side assumption.
- Late in closed-cycle ascent, 2RO/3RO/4RO can attempt NERV-only ATO after isolating surviving RAPIERs. A strong pitch-up buys altitude/time, but admission must show enough remaining horizontal energy, fuel and burn time for safe insertion. The phase label alone does not establish eligibility.
- Any NERV failure during NERV assist or closed cycle takes priority over a RAPIER-loss ATO allowance. With usable RAPIER propulsion, select AED.
- After nominal RAPIER cutoff, any NERV failure selects EDR. Interpret "RAPIERs are out" here as the intentional end of RAPIER ascent, not an early four-engine failure.
- For one failed NERV, approximately 0.2 of full surviving-NERV thrust is a provisional maximum requiring KSP/FAR calibration. Two failed NERVs means no NERV thrust. Preserve the restriction through every fallback; do not apply it indiscriminately to healthy RAPIER thrust.
- RO/NO count actual failed engine identities. Deliberate isolation/cutoff does not increase the failure count, and isolated healthy engines can be deliberately reused by a subsequent mode.

## Mode names and dispatch

- **AED: Abort to Energy-managed Diversion.** Manage high-speed atmospheric recovery into a reachable runway capture state, then TEAM/landing.
- **ATO: Abort to Orbit.** Supervise nominal continuation or late NERV-only escape and verify a safe orbit.
- **EDR: Emergency Deorbit and Return.** Recover after post-cutoff NERV failure, using a targeted deorbit if necessary or an already-suborbital return, followed by normal-like entry guidance.

| Source phase and failure | Planned selection |
| --- | --- |
| `ascent_alignment`, 1RO/2RO/3RO | RTLS, now implemented |
| `ascent_alignment`, 4RO | Existing contingency |
| `nerv_assist`, any NO, at least one usable RAPIER | AED |
| `nerv_assist`, 1RO and healthy NERVs | Supervised nominal ATO candidate |
| `nerv_assist`, 2RO/3RO and healthy NERVs | AED |
| `nerv_assist`, no usable RAPIER | Contingency, retaining NERV-health restrictions |
| `closed_cycle_climb`, any NO and usable RAPIER | AED |
| `closed_cycle_climb`, 1RO and healthy NERVs | RAPIER-assisted ATO candidate |
| `closed_cycle_climb`, 2RO, opposite-side survivors and healthy NERVs | RAPIER-assisted ATO candidate; assume gimbal control |
| `closed_cycle_climb`, 2RO, same-side survivors and healthy NERVs | Isolate at least one; evaluate permitted single-RAPIER ATO, otherwise late NERV-only ATO |
| `closed_cycle_climb`, 3RO and healthy NERVs | Late NERV-only ATO candidate; otherwise AED if usable RAPIER recovery remains |
| `closed_cycle_climb`, 4RO and healthy NERVs | Late NERV-only ATO candidate before contingency; rejected/early case -> contingency |
| `closed_cycle_climb`, any NO and no usable RAPIER | Emergency-return/contingency branch with restricted surviving NERV thrust |
| `apoapsis_build`, coast or insertion after nominal RAPIER cutoff, any NO | EDR; selectively restart healthy RAPIERs if useful and fuel-supported |
| Active ATO receives a new failure | Reassess once using current ascent phase and newly failed IDs; NO has priority |

An ATO count/layout allowance permits assessment, not an unconditional orbit attempt. Capability rejection selects AED when powered runway recovery is available, or EDR/contingency according to trajectory and propulsion. Immediate terrain/control threats interrupt planning. Known failures do not recreate abort state every tick.

## Common executive and state

Separate three operations currently conflated in `check_abort`/`abort_refresh_state`: observing engine health, latching failure identities, and choosing a recovery mode. Engine health includes expected command, ignition, flameout, usable capacity and delivered thrust with bounded spool/zero-throttle grace. Missing previously installed engine IDs must remain observable even if a part disappears from the current vessel list.

Maintain one persistent recovery context: original failure/source phase, current ascent phase, failed IDs, intended activation/isolation per engine, installed layout, survivor limits, original LF/Ox reserves, mode/subphase, selected runway/interface, attempted/rejected maneuver flags, commitment state and structured outcome. Family-wide `rapiers`/`nervs` booleans are insufficient for deliberately isolating one healthy engine while expecting another to run. Add per-engine desired-command masks.

One executive owns steering and propulsion each tick. Commit a mode transfer atomically; old nominal or recovery blocks must not issue commands afterward. Separate recovery mode from nominal ascent phase so ATO can supervise the ordinary profile without relatching an unchanged failure. Retain source phase after handoff for diagnostics.

Generalize thrust policy so direct node burns, DAP throttle floors, reset/setup, terminal requests and fallback cannot bypass survivor restrictions. Preserve usable engines on pilot handoff and leave throttle initially zero; generic cleanup must not reacquire controls afterward. Read-only kOS suffixes are not script variable names.

## AED procedure and energy guidance

State sequence: `secure -> select_runway -> energy_transit -> capture -> TEAM -> landing -> verify`.

`energy_transit` has intent substates `ascending_coast`, `descending_capture`, `energy_dissipation`, and `powered_extension`, with hysteresis and one continuous controller.

1. **Secure:** cancel warp/dumping, latch failures, take over from ascent, preserve then rate-limit current AoA/bank. Do not demand an immediate dive, reversal or universal throttle cut. Prefer healthy RAPIERs to an asymmetric lone NERV when practical.
2. **Select runway:** evaluate runway directions and upstream capture routes. Screen energy shortage, excessive arrival energy, turn/terrain cost, propulsion reserve and terminal geometry; then prefer feasible candidates ahead. Cache results, reject impossible targets with reasons, bound search time and keep control updates running.
3. **Energy transit:** use an AED-specific AoA/bank profile toward a configurable capture point. Preserve range while thin/high; use drag and route extension only when aerodynamic authority and clearance support them. Throttle supplies an independently budgeted energy deficit; it is not automatically commanded merely because speed is below the former ascent target.
4. **Capture:** require descending capture within position, heading, altitude, speed, sink/control and terminal energy margins for a stable interval; blend commands.
5. **TEAM/landing:** preserve survivor masks, limits, fuel reserves and deliberate go-around capability. Lock target during committed final. Complete after stopped ground contact.

Normal EG cannot be reused unchanged. Its standard TEAM interface is runway elevation +25 km, while NERV assist starts near 20 km and closed-cycle transition can occur near 23 km. Its altitude-crossing predictor can terminate immediately when starting below the normal interface. Use a lower/adaptive AED capture interface, without changing global `TEAMAltitude`. Capture altitude and upstream room must be solved against the terminal intake envelope, not a fixed arbitrary point. About 300-350 m/s is an initial terminal-capture validation target, not an established flight limit.

Use specific energy/energy height relative to capture: `H = h_relative + (V^2 - V_capture^2)/(2g)` for screening, with consistent SI quantities. Actual route prediction includes gravity, aerodynamic work, propulsion work and fuel consumption where modeled. At 1,500 m/s the kinetic term is approximately 115 km of energy height; proximity alone cannot establish a safe landing route. Evaluate both a low-drag reachability envelope and a drag/path-length dissipation envelope. Reject a close ahead runway if there is insufficient room to slow; do not default to tight TEAM holding turns at ascent speed.

Use the existing gravity/aero integrator with explicit AED profiles for unpowered trajectory families. It currently does not model thrust or propellant consumption. Powered extension therefore needs either a separately bounded assist budget with live reassessment, or an explicit predictor extension; never label an unpowered prediction as validation of powered flight. Normal terminal clean-loss learning is limited to 350 m/s and cannot be extrapolated to ascent speed.

Bank controls lateral path as well as lift/energy; AoA controls lift and drag subject to pressure, thermal, stall and attitude limits. Excess energy requests zero thrust and safe drag/dogleg options; low energy first removes drag, then allows bounded propulsion or a closer runway. Preserve yields and bound candidate/solver work. No convergence -> degraded recovery/fallback, not frozen controls.

Fallback: loss of usable RAPIER or runway feasibility transfers once to EDR if ballistic return planning is needed, otherwise contingency entry/glide/site-search. Use explicit target hysteresis and final commitment.

## ATO procedure

State sequence: `assess -> nominal_continue` or `nerv_only_escape`, then `apoapsis_build -> coast_align -> insert -> verify_orbit -> orbital_hold`.

1. **Assess:** no NO allowance; confirm usable thrust, LF/Ox, control health and insertion timing. Opposite-side surviving RAPIERs are allowed by the user assumption. Same-side pair requires at least one isolated. Track failures independently from deliberate isolation.
2. **Nominal continuation:** preserve nominal ascent targets initially when margins allow. Use speed/climb progress per elapsed second, not per-loop `speed_trend`. If original mission targets become unaffordable, reduce to a configured minimum safe parking orbit; abandon inclination/rendezvous ambitions before spending recovery reserves.
3. **Late NERV-only escape:** isolate remaining RAPIERs as selected. Require healthy NERVs and a finite-burn prediction of full escape-plus-insertion. Compare bounded strong pitch-up candidates using current altitude, horizontal/radial velocity, pressure, fuel and time to atmospheric descent. Inside the atmosphere enforce AoA, rate, pressure/thermal and attitude limits. A higher apoapsis alone is not proof: preserve enough horizontal energy for periapsis raise.
4. **Coast/insertion:** estimate actual burn duration from permitted surviving thrust. Weak thrust may require early/blended insertion rather than a mandatory long coast. Monitor new failures, alignment, fuel reserve and actual apsis growth throughout a yieldable burn.
5. **Verify:** bound trajectory and actual periapsis above atmospheric height plus configured clearance. Maneuver executor return does not establish success. Orbital hold ends thrust and preserves reserves with a structured ATO outcome.

Current `execute_node` blocks the ascent monitor while running and can return early. Either add a supervisor/cancellation interface respected during warp/coast/burn or use a common recovery insertion executive. Do not leave the current unconditional ascent-complete assignment after node execution.

Reject on insufficient fuel/time/progress/control or new NO. Carry no-retry flags into the next mode so contingency does not attempt the same rejected insertion again.

Engine-side identification is feasible using engine UID, craft tags/positions and documented symmetry relations. Use known craft layout to classify operating sides. Different authored symmetry sets or unknown topology require resolution/fallback. Part position/facing is not exact nozzle/gimballed-force geometry, but the accepted opposite-side policy does not need an exact torque model.

## EDR procedure

State sequence: `secure -> assess_return -> configure_propulsion -> plan_return -> align -> return_burn_or_coast -> verify_entry_trajectory -> entry -> TEAM -> landing -> outcome`.

- Trigger after nominal RAPIER cutoff for any NO, including coast/insertion. Stop the superseded insertion node and warp under the same executive; keep failure IDs and original reserves.
- Distinguish a safe orbit requiring deorbit from an already-suborbital trajectory. For the latter, preserve a viable return and apply only a justified footprint/entry correction. Do not automatically burn retrograde and steepen an existing return.
- Evaluate usable LF and oxidizer together for healthy closed-cycle RAPIERs. Include actual remaining engine layout. One surviving NERV is restricted to the provisional authority cap or shut down; no NERV availability for 2NO. A combination can be useful, but do not double-count LF in separate delta-v estimates.
- Select a viable entry footprint and runway/region; compare limited NERV return, RAPIER return and passive coast. Account for capped thrust and long burn duration. A runway is a preferred outcome only when reachable under the entry envelope. In a safe orbit with no controllable deorbit propulsion, preserve orbital hold and report deorbit unavailable; do not assume a landing trajectory exists.
- Make burns alignment-gated, finite-duration and monitored. Verify actual periapsis/return geometry before handing over to normal-like EG. Already atmospheric high-energy cases can use AED capture; do not repeat deorbit setup or restore blocked propulsion.
- Preserve the survivor restriction across normal entry, TEAM, contingency and pilot handoff. The tentative 0.2 value is not a certified control limit. Per-engine limiting or exclusive activation must let RAPIERs operate at their own permitted power rather than indiscriminately capping all engines.

kOS documents per-engine `THRUSTLIMIT` as writable percent: the provisional 0.2 limit corresponds to `THRUSTLIMIT = 20`. Keep a preexisting lower limiter, and budget burn timing using limiter-aware `AVAILABLETHRUST` (or `POSSIBLETHRUST` when evaluating an inactive candidate). Preserve the limit through direct throttle locks, DAP floors and pilot handoff; restore it only on deliberate release. This protects the NERV restriction without imposing a global 20% cap on RAPIERs. Actual authority still needs flight calibration. Coupled LF/Ox consumption and accessibility must be taken from engine/resource data, not separate delta-v estimates that spend the same LF twice.

## Contingency overlap and required changes

| Existing behavior | Conflict | Planned resolution |
| --- | --- | --- |
| `abort_refresh_state` unconditionally promotes >=4RO | Overrides late 4RO ATO on the next refresh | Refresh health only; central selector evaluates NO priority and late NERV-only ATO before contingency |
| Contingency already has orbit raise/coast/insert | Duplicate controllers could disagree/retry | Share pure math/progress/insertion services; one owner, one attempt history |
| Contingency orbit-first can remain eligible during EDR | Reattempts ascent after emergency-return commitment | Explicitly suppress orbit-first in EDR and its fallback context |
| Orbit eligibility captures `nervs_were_active` | Later recovery activation can confuse origin capability | Retain origin activation separately from current desired commands and physical health |
| Contingency always shuts RAPIERs off | Can discard EDR's usable return propulsion | Preserve mode-specific engine policy; only an explicit transition isolates RAPIERs |
| Healthy NERV recovery can request full thrust with one survivor | Violates lone-NERV authority restriction | Shared per-engine restrictions survive every service/fallback |
| Contingency `powered_entry` uses coarse energy/geometric screening | Cannot establish AED high-speed capture/dissipation | Retain as degraded fallback; add dedicated AED prediction/profile |
| Each initialization establishes its own reserve/attempt flags | Fallback can spend reserve or retry rejected ATO | Transfer original reserve, spent-fuel budget and no-retry history |
| Reentry receives `context` but does not consume preservation flags | Setup/TEAM/reset overwrite survivor policy | Parse and honor explicit context through setup, handoff and cleanup |
| Generic cleanup bypass is specific to contingency mode | AED/ATO/EDR pilot handoff may be overwritten | Outcome/control-ownership based cleanup for all recovery modes |
| Existing count/ignition flags ignore deliberate per-engine selection | Same-side engine isolation can become a false failure | Maintain per-UID health and desired-command masks |
| Generic node executor stages when available thrust is zero | Unrequested configuration change during recovery | Recovery executor prohibits automatic staging and uses explicit no-thrust outcomes |

Contingency remains the lower-capability emergency recovery service: entry coast, corridor/site search, glide, final, ground stop and ditch. Share those services rather than run its whole independent executive concurrently. In `ocean_ditch`, committed protection ownership remains intact; a new runway search or generic throttle floor must not interrupt it.

Combined 4RO+NO cannot qualify for the all-NERVs-healthy ATO and has no powered RAPIER AED route. Use EDR/contingency return with the surviving-NERV restriction and an explicit passive/pilot outcome where no automatic option exists.

## Implementation sequence and acceptance evidence

1. Central recovery context, per-engine health/command masks, engine-side classification, dispatch priority, outcome cleanup and logger contract. Preserve current runway/RTLS behavior.
2. ATO supervision for 1RO and accepted opposite-side 2RO; monitored insertion and truthful orbit completion. Add finite-burn admission/strong-pitch-up branch for late 2RO/3RO/4RO with healthy NERVs.
3. AED candidate selection and unpowered energy profiles, then bounded powered extension and adaptive TEAM handoff. Wire explicit preservation context instead of normal setup resets.
4. EDR finite-burn return planning, limited lone-NERV/RAPIER configurations, passive suborbital return, then normal-like entry handoff.
5. Extract shared contingency fallback services and validate every cross-mode escalation, no-retry flag, reserve and pilot-control outcome.

Each guidance/control change reviews `flight_log.ks`. Low logs failure/mode/phase transitions, decisions and rejection/final reasons. Medium samples cached state at 1 Hz; high uses the established tick cadence. Include per-engine failed/isolated IDs and limits, available/delivered thrust, LF/Ox/reserves, geometry, predicted/actual energy and apsides, insertion/return timing, AoA/bank/alignment, runway gate and outcome. Logging performs no terrain/FAR/prediction work and is a passive observer in simulation.

Run real `.ks` math/selector/state tests with `tools/pos_sim/kos_runtime.py`; test combined failures, ignored existing IDs, missing parts, intentional shutdown, opposite/same-side survivor configurations, reserve transfer, cap/floor/direct-executor interactions, candidate shortage/excess, adaptive interface, search deadlines, stable handoff and actual outcomes. Keep independent dynamics separate from onboard prediction. Use 2,000 IPU and 0.02-second physics ticks, retain yields and save trace/events under ignored `tools/pos_sim/results/`.

Full scenarios: early/late 1RO, opposite-side 2RO, same-side pair reduced to one/all off, early rejected and late eligible NERV-only 2RO/3RO/4RO, NO during ATO, 1NO/2NO before/after closed cycle and cutoff, LF/Ox shortage, no reachable runway, failed predictor, new failure during TEAM, rejected ATO entering contingency without retry, and pilot handoff without control reacquisition.

Run `tools/test-pos audit` after each KerboScript edit, relevant focused tests while iterating, and `tools/test-pos all` before completed-change handoff. KSP/FAR flight logs must establish strong-pitch-up, drag/turn capture, lone-NERV and single-RAPIER authority. The offline model omits aerodynamic moments, gimbal, flex, RCS authority, slopes, suspension, bounce, wheel friction and water-impact behavior.

## References

- Current source: `Script/Libraries/Poseidon_SSTO/{craft_Poseidon_SSTO,control,entry_guid,terminal_route,contingency,flight_log}.ks`, `Script/Poseidon_SSTO/{Poseidon_SSTO_Orbit_Main,Poseidon_SSTO_Reentry}.ks`, `Script/Libraries/{lib_navigation,lib_aerosim,lib_orbital_nodes}.ks`.
- kOS [Part geometry/symmetry](https://ksp-kos.github.io/KOS/structures/vessels/part.html#part-symmetrypartner) and [Engine thrust-limit API](https://ksp-kos.github.io/KOS/structures/vessels/engine.html#engine-thrustlimit).
- Local subagent designs: `tools/pos_sim/results/aed_design.md`, `ato_design.md`, and `edr_design.md` (ignored analysis artifacts).
