# AED, ATO and EDR ascent recovery

Implemented source behavior, 2026-10-11. These modes replace ATI. AED, ATO and EDR each execute directly in their own steps in `Poseidon_SSTO_Orbit_Main.ks`, which defines no functions. Reused lifecycle and engine policy live in the craft library; the two recovery libraries provide prediction, mathematics and return-target services. Orbit Main retains guidance ownership until the deliberate handoff to `Poseidon_SSTO_Reentry.ks`. Atmospheric and asymmetric-engine authority still require Poseidon KSP/FAR flight validation.

The takeoff GUI's V1 estimate is a passive display reference. It does not change the runway-stop/RTLS dispatch described here or the live feasibility decision; see [README](README.md#takeoff-gui-v1-estimate) for its inputs, limits, and telemetry.

## Selection

| Failure phase | Selection |
| --- | --- |
| Launch / rotate / initial heading alignment | Existing runway stop / RTLS, with four RAPIER losses entering contingency |
| Speed build / high-altitude climb | Existing ATR; four RAPIER losses enter contingency |
| NERV assist, one RAPIER loss, healthy NERVs | ATO assessment |
| NERV assist, two or three RAPIER losses, or any NERV loss with usable RAPIERs | AED |
| NERV assist, four RAPIER losses | Contingency |
| Closed cycle, healthy NERVs | ATO assessment, including late four-RAPIER-loss NERV-only candidates |
| Closed cycle, NERV failure | AED with usable RAPIERs; EDR without them |
| After intentional nominal RAPIER cutoff, NERV failure | EDR, including coast and insertion |

Selection permits an assessment, not a guaranteed orbit or landing. Missing installed engine identities, externally shut down commanded engines and persistent flameout/non-delivery are latched as failures. Deliberate shutdown/isolation and reaching a reserve do not increase RO/NO. The original failure phase and engine identities remain attached to every transfer.

## ATO: Abort to Orbit

One failed RAPIER or a confirmed opposite-side pair of survivors can continue with the nominal ascent profile toward a conservative parking orbit. A same-side pair, unknown pair geometry or the uncalibrated single-RAPIER configuration does not qualify for that continuation; surviving RAPIERs are isolated before a late NERV-only escape assessment.

NERV-only admission compares bounded pitch candidates using a finite raise/coast/insertion calculation. It checks horizontal energy, permitted thrust, fuel duration, atmospheric drag allowance, remaining time, and both final apsides. It does not infer eligibility from the phase name or increased apoapsis alone. The atmospheric pull-up and pitch rate are limited. Single-RAPIER ATO remains disabled pending calibration.

Air-breathing continuation changes to closed cycle only above its altitude gate and after acceleration falls below the configured elapsed-time threshold. Insertion is nonblocking and alignment-gated. Every actual flight tick still observes new failures, fuel and apsis growth. Actual bound-orbit periapsis must be above the atmosphere plus 10 km before abort success; initial abort apoapsis target is 100 km. Ordinary zero-loss insertion uses the same monitor while retaining the requested mission apsides. An abort abandons rendezvous/inclination ambitions and preserves a parking-orbit outcome.

Rejection transfers to AED, EDR or contingency with a sticky no-retry flag. New NERV failure takes precedence over continuing ATO. Successful orbit recovery cuts thrust and releases controls at zero initial pilot throttle.

## AED: Abort to Energy-managed Diversion

AED cancels warp and dumping, transitions continuously from the current commands, and preferentially uses healthy RAPIERs. It uses its own energy controller and lower adaptive capture interface; it does not alter the global normal TEAM altitude.

Runway directions are searched in ascending distance from the aircraft to the runway, rather than location-table order. An impossible immediate turn is rejected before integrating its trajectories, so a close runway behind a fast aircraft cannot consume the whole search window. The nearest candidate passing the low-drag and drag forecasts wins. Prediction uses the existing FAR/gravity integrator in bounded slices between live control updates. Selection considers shortage, excess arrival energy, turn room, terrain clearance and a terminal intake point solved against the real glideslope/terminal energy budget.

Usable RAPIERs begin an exploratory diversion immediately while those forecasts run. The exploratory choice includes distance and turn arc; it is explicitly provisional, not a certified landing route. Provisional steering aims at the actual runway immediately, rather than its far upstream prediction point. The turn arc remains diagnostic and cannot command wings level merely because the remaining distance shrinks. Bank demand uses a stronger heading gain. Ordinary diversion bank is limited to 70 degrees with sufficient height and speed, or 35 degrees nearer the ground. Up to 120 degrees is available above 7 km clearance and 800 m/s, with at least 2.5 km above the planned intake height, adequate dynamic pressure, and descent no faster than 45 m/s. Existing envelope/terrain/upset protection still has authority. The coordinated-turn predictor retains its separate 35-degree assumption; it never treats an inverted maneuver as a level turn.

Live guidance follows a terminal energy budget that includes circuit room and drag uncertainty. Flight-path feedback limits the requested climb to 10 m/s and descent to 45 m/s, reducing AoA when speed assistance produces excessive climb. Aerodynamic brakes shed excess speed rather than a fixed 20-degree AoA command lofting the aircraft. These commands require KSP/FAR flight validation; source replay is not atmospheric propagation.

A search deadline or a set of rejected unpowered forecasts does not transfer a powered aircraft to contingency or shut down its RAPIERs. `powered_replan` retains usable propulsion and steering; timed-out predictions resume at their existing candidate/family/integration state. Exhausted searches restart with live position, speed and fuel. New candidates receive fresh vessel snapshots, and forecasts over 60 seconds old cannot approve a runway. The 1,200-second deadline logs a strategy change while retaining powered control. Actual unusable RAPIER thrust or fuel transfers to EDR/contingency according to the existing return policy.

The small assist allowance bounds only the thrust credit in the unpowered forecasts; exhausting that allowance does not prohibit using remaining fuel for a diversion. Live limiter-aware thrust, accessible LF/Ox and delta-v govern power availability. Original reserves are preserved initially and released before declaring propulsion unavailable, including during TEAM. AED reactivates surviving engines after reserve release and gives activation one second to settle before declaring loss. Below 10 km and 600 m/s it tries air-breathing RAPIER operation; above 14 km it returns to closed cycle. If jet power remains unavailable after settling and oxidizer remains, it retries closed cycle and inhibits another jet retry for 30 seconds. Failed engine identities remain masked. Fuel use, burn time and delivered delta-v remain logged. The aero prediction is never labelled as a powered trajectory.

A forecast-approved descending capture retains its two-second gate. A provisional powered diversion can instead hand off after 0.5 seconds of stable live TEAM intake conditions: within 20 km of the capture point or 60 km of the runway, 120–350 m/s, 0.7–14.5 km terrain clearance, sink no faster than 45 m/s or climb no faster than 10 m/s, heading toward the runway within 45 degrees, bank at most 35 degrees, and terminal energy margin between -500 and +5,000 m. This live gate does not wait for an unpowered forecast to approve the destination or demand final runway-heading alignment; TEAM builds its own intercept and pattern. Orbit Main then hands off directly to TEAM with the selected capture interface and survivor policy. Remaining guidance, landing and go-around use the reentry script. Actual stopped ground contact establishes landing completion.

During TEAM, powered recovery may dump excess fuel toward the 36-tonne landing reference. Dumping stops at either resource floor: the greater of the original engine reserve, 20 percent of the resource at route initialization, or the configured minimum (1,000 LF / 300 Ox), plus a 100-unit stopping margin. Dumping also stops during descent recovery, go-around and landing handoff. These dump floors retain usable fuel; they do not prevent spending it during a go-around. Draining both resources can leave the aircraft heavier than 36 tonnes. Approach reference speed, brake bands, propulsion speed floor and landing speed gates therefore scale by `sqrt(max(1, mass / 36))`. This is a lift-based heavy-mass allowance, not a calibrated guarantee of heavy landing or runway stopping distance.

An aligned final is still unstable if it is at least 75 m below the profile, sinking faster than 15 m/s and missing the requested vertical speed by at least 10 m/s. TEAM immediately releases brakes and requests at least 70 percent throttle. If that condition persists for three seconds inside 10 km, above the existing 80 m go-around height gate, it commands a go-around. Surviving RAPIERs with fuel permit this vertical escape even when the unpowered reposition energy budget is insufficient. The go-around keeps power on and wings level until a positive climb of at least 2 m/s is established and the existing turn-height gate is met. High-energy final uses its own requested descent for the tracking check. Planned preflare profile deviation alone does not trigger the protection. Final aerostr commands clear inherited ascent pitch/roll trim.

Managed recovery still preserves deliberate coast and burn-alignment timing outside terminal flight. During TEAM/landing, or an active GPWS terrain escape, it honors the envelope throttle floor. Original engine failure masks and fuel cutoffs remain enforced.

## EDR: Emergency Deorbit and Return

An existing suborbital return coasts without an automatic retrograde burn. A safe orbit requires a fuel-supported, limiter-aware deorbit configuration and a bounded return burn. The initial ballistic footprint/runway screen is geometric, not a solved hypersonic runway-capture promise. If no controlled deorbit or acceptable return target is available, the vehicle remains in orbit and explicitly hands control to the pilot.

Return burns are alignment-gated, tapered, time-bounded and supervised. The controller checks the actual resulting periapsis and recomputes the actual ballistic entry geometry/footprint before handing off. Normal-like entry begins only at a descending atmospheric crossing, skips deorbit setup and retains engine restrictions and reserves. A failed entry/runway assessment falls back without restarting an orbit attempt.

One failed NERV limits the healthy survivor to at most 20 percent per-engine thrust, retaining an existing lower limiter. Two failed NERVs provide no NERV thrust. Healthy RAPIERs retain their own thrust limits. The lone-NERV value is provisional and needs flight calibration.

## Telemetry and validation

Use medium logging for routine flights and high for a specific control failure. Low logs failures, isolation/limit changes, mode/phase transfers, prediction/candidate decisions, handoff and outcomes. Medium samples cached decisions at 1 Hz; high follows the existing control-tick cadence. Logging performs no prediction or trajectory work.

AED events identify nearest-first search starts, each candidate evaluated, provisional diversion choices, deadline/resume reasons, reserve release and extension beyond the forecast credit. Samples record the live propulsion estimate, search index/family/reason, powered-replan state, provisional target status, bank limit/steep-bank state, runway range, desired vertical speed, brakes, terminal energy requirement, live capture validity and engine-mode/restart settling state. Events identify steep-bank entry/exit, engine-mode changes, reserve reactivation and the actual TEAM gate that accepted handoff. The flight-331 geometry regression selects Sandy Island provisionally and exercises search timeout, continued power, reserve release/restart, immediate KSC turnback, 120-degree bank admission/restriction and unsafe capture rejection. Flight-333 regressions exercise the shrinking-range turn, climb feedback, provisional TEAM admission and reserve shutdown with the real engine-command/power functions. This is source/decision evidence, not proof of a completed atmospheric diversion or landing.

Local regression checks execute the real KerboScript functions at 2,000 IPU and 0.02-second physics ticks. Independent vacuum source scenarios additionally use central-gravity physics, fuel consumption and a slew-limited attitude actuator; they do not propagate the onboard predictor as their physics. Reports and traces stay in the ignored `tools/pos_sim/results/` directory.

Flight 338 reached final at about 63 tonnes without dumping fuel, then fell below the profile with sustained 40 m/s sink. GPWS requested full throttle but the old managed-recovery arbiter returned zero. Frozen-state replay of the changed source releases brakes and requests power at approximately 10.1 km, then commands go-around at 9.6 km; the original source never went around. Schema 26 adds cached descent-recovery state/duration/tracking error, recovery throttle floor, mass speed scale and dump floors/status. Transition events identify recovery, go-around reasons and dump activation/stopping. Low/medium/high logging cadence is unchanged, and no logger runs in aerodynamic prediction. This evidence validates source decisions only; KSP/FAR must establish lift/control response, actual drain stopping margin, go-around performance and runway stopping distance.

First KSP tests: 2RO in NERV assist for AED; opposite-side 2RO in closed cycle for ATO; then one NERV shutdown after intentional RAPIER cutoff for EDR. Retain both flight/event logs, the failure altitude/speed/apsides and the actual outcome. Follow with same-side 2RO, early/late 3RO/4RO, a new NERV failure during ATO insertion, low LF/Ox, no feasible runway, and additional failures during TEAM.

The predictors are approximate. KSP/FAR must establish drag/turn capture, thermal/pressure margins, engine torque, gimbal/RCS authority, gear/slope/bounce behavior and impact survival. Passing the browser GUI workbench or vacuum fixtures does not certify those behaviors.
