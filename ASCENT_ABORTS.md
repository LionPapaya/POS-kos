# AED, ATO and EDR ascent recovery

Implemented source behavior, 2026-10-11. These modes replace ATI. Their flight executives remain in `Poseidon_SSTO_Orbit_Main.ks` until a deliberate handoff to `Poseidon_SSTO_Reentry.ks`; libraries provide engine policy, prediction and mathematics. Atmospheric and asymmetric-engine authority still require Poseidon KSP/FAR flight validation.

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

Runway directions are screened against unpowered low-drag and drag families using the existing FAR/gravity integrator. Prediction proceeds in bounded slices between live control updates. Selection considers shortage, excess arrival energy, turn room, terrain clearance and a terminal intake point solved against the real glideslope/terminal energy budget. Prediction failure has a bounded fallback rather than freezing controls.

Any powered extension is accounted separately with original fuel reserves and explicit time, fuel and delta-v limits. The aero prediction is never labelled as a powered trajectory. Target refresh uses rejection reasons and hysteresis.

A descending capture must remain stable for two seconds within the configured position, altitude, speed (at most 350 m/s), heading, bank, sink, clearance and terminal-energy gates. Orbit Main then hands off directly to TEAM with the selected capture interface and survivor policy. Remaining guidance, landing and go-around use the reentry script. Actual stopped ground contact establishes landing completion.

## EDR: Emergency Deorbit and Return

An existing suborbital return coasts without an automatic retrograde burn. A safe orbit requires a fuel-supported, limiter-aware deorbit configuration and a bounded return burn. The initial ballistic footprint/runway screen is geometric, not a solved hypersonic runway-capture promise. If no controlled deorbit or acceptable return target is available, the vehicle remains in orbit and explicitly hands control to the pilot.

Return burns are alignment-gated, tapered, time-bounded and supervised. The controller checks the actual resulting periapsis and recomputes the actual ballistic entry geometry/footprint before handing off. Normal-like entry begins only at a descending atmospheric crossing, skips deorbit setup and retains engine restrictions and reserves. A failed entry/runway assessment falls back without restarting an orbit attempt.

One failed NERV limits the healthy survivor to at most 20 percent per-engine thrust, retaining an existing lower limiter. Two failed NERVs provide no NERV thrust. Healthy RAPIERs retain their own thrust limits. The lone-NERV value is provisional and needs flight calibration.

## Telemetry and validation

Use medium logging for routine flights and high for a specific control failure. Low logs failures, isolation/limit changes, mode/phase transfers, prediction/candidate decisions, handoff and outcomes. Medium samples cached decisions at 1 Hz; high follows the existing control-tick cadence. Logging performs no prediction or trajectory work.

Local regression checks execute the real KerboScript functions at 2,000 IPU and 0.02-second physics ticks. Independent vacuum source scenarios additionally use central-gravity physics, fuel consumption and a slew-limited attitude actuator; they do not propagate the onboard predictor as their physics. Reports and traces stay in the ignored `tools/pos_sim/results/` directory.

First KSP tests: 2RO in NERV assist for AED; opposite-side 2RO in closed cycle for ATO; then one NERV shutdown after intentional RAPIER cutoff for EDR. Retain both flight/event logs, the failure altitude/speed/apsides and the actual outcome. Follow with same-side 2RO, early/late 3RO/4RO, a new NERV failure during ATO insertion, low LF/Ox, no feasible runway, and additional failures during TEAM.

The predictors are approximate. KSP/FAR must establish drag/turn capture, thermal/pressure margins, engine torque, gimbal/RCS authority, gear/slope/bounce behavior and impact survival. Passing the browser GUI workbench or vacuum fixtures does not certify those behaviors.
