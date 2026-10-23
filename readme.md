# Poseidon SSTO Operating System (POS-kOS)

POS-kOS is a collection of [kOS](https://github.com/KSP-KOS/KOS) scripts for flying the Poseidon SSTO in Kerbal Space Program. It automates ascent, orbital operations, re-entry, terminal guidance, and landing support.

> **Scope:** POS-kOS is currently built around the Poseidon SSTO. It depends on the craft's engines, mass, aerodynamic configuration, and control tuning, so it is not a general-purpose autopilot.

## What it can do

### Ascent and orbital insertion

- Take off from the active runway.
- Rotate and climb using the Poseidon ascent profile.
- Select a launch heading from the requested orbital inclination.
- Manage RAPIER air-breathing and closed-cycle operation.
- Activate the NERV engines when required for the upper-atmosphere climb.
- Calculate and execute circularization to reach the selected target orbit.
- Display live ascent data, guidance status, and control information in the POS GUI.

Atmospheric and vacuum ascent accept inclinations from 0 to 180 degrees even
when the launch latitude lies outside the requested plane's latitude band.
POS then aims equatorward with a dogleg capped at 45 degrees from east or west,
tapers the turn near the reachable band, and retains that direction when it
joins the direct launch heading. A 0-degree target near KSC therefore remains
0 degrees instead of failing or being replaced by the runway latitude.
This is best-effort ascent guidance: available flight time, fuel, terrain and
steering authority limit convergence, and circularization does not perform an
additional plane change. Validate the remaining inclination error in KSP and
use Orbital Maneuvering if a further correction is needed.

### Orbital operations

The orbital maneuvering menu currently provides:

- RSVP transfers to another celestial body or vessel.
- Execution of an existing maneuver node.
- Apoapsis, periapsis, and inclination changes.
- Circularization of the current orbit.

### Re-entry and landing

- Calculate and execute a de-orbit maneuver.
- Simulate possible entry trajectories before committing to a landing target.
- Select a Kerbin location and runway, or automatically choose a reachable runway.
- Guide the vehicle through atmospheric entry using angle-of-attack and bank control.
- Transition from entry guidance to a terminal route around the selected runway.
- Manage energy, heading alignment, airbrakes, landing gear, and final approach.
- Provide live trajectory, flight-data, and guidance readouts.

### Vacuum landing

- Perform a NERV-only de-orbit and powered descent on a body without an atmosphere.
- Target a supplied latitude/longitude and translate to that surface point after braking.
- Set the tail down at near-zero surface speed, then pitch down onto the landing gear.

### Vacuum ascent

- Select a circular target-orbit altitude and inclination from the POS dialog.
- Use RCS to pitch the landed Poseidon onto its rear support before ignition.
- Use a short full-throttle, closed-cycle RAPIER kick only to lift clear of the tail and gear; the vehicle then retracts the gear and continues on NERVs alone.
- Build apoapsis on the selected heading, create a circularization node, execute it automatically, then return to the POS menu.

## Aborts

Abort modes are selected according to the vehicle's situation and are implemented as separate flight phases. The currently implemented runway-stop and return-to-launch-site modes are documented below.

### `runway_abort`

#### Purpose

`runway_abort` is intended for a takeoff launch failure where the safest response is to stop the vehicle on the runway instead of continuing the ascent.

#### Behavior

When this abort is active, POS-kOS:

1. Sets throttle to zero.
2. Turns off the RAPIER engines.
3. Commands a slight nose-down pitch to keep the vehicle on the runway.
4. Applies the brakes.
5. Continues braking until the vehicle's airspeed is below 1 m/s.
6. Marks the abort complete and ends the current flight program.

### `rtls` (return to launch site)

#### Purpose

`rtls` returns the vehicle to the departure runway after an ascent engine-loss abort when stopping on the runway is no longer feasible. POS also selects it for an engine-loss abort after rotation.

#### Behavior

When this abort is active, POS-kOS:

1. Continues the takeoff until the vehicle is safely airborne when the abort begins before liftoff.
2. Configures the remaining propulsion and, for the applicable multi-RAPIER-loss cases, dumps fuel to the configured recovery mass.
3. Climbs and makes a controlled turn toward the reciprocal runway heading after reaching the minimum turn speed.
4. Stabilizes on the reciprocal heading at the required altitude, then hands the vehicle to the normal re-entry and landing program for the departure runway. The recovery landing permits a go-around.

The abort-mode dispatcher is kept separate from the main flight phases so additional abort modes can be added later without restructuring the mission flow. Additional modes should be documented only after implementation and flight testing.

#### Flight-test status

The maintainer reports successful in-game testing of both `runway_abort` and `rtls`; these modes are considered working on the Poseidon craft. The supplied `flight_145` log set contains one useful abort decision trace (`flight_24/events.csv`): the launch-phase runway-stop check rejected the stop because 472 m remained against 617 m required, then selected `rtls`. This supports the runway-stop feasibility rejection and RTLS selection path, but it does not capture a completed runway stop or the subsequent RTLS return and landing. Treat the maintainer's successful testing as the evidence for those outcomes; the supplied logs do not independently demonstrate them.

## Mission flow

The top-level `POS.ks` script loads shared libraries and chooses a flight program based on the vessel's state:

```text
POS.ks
├── POS1 / Poseidon_SSTO_Orbit_Main.ks   ascent and circularization
├── POS3 / Poseidon_SSTO_Reentry.ks      de-orbit, entry, and landing
├── POS4 / Poseidon_SSTO_Vacuum_Landing.ks  targeted NERV-only landing on an airless body
├── POS5 / Poseidon_SSTO_Vacuum_Landing.ks  convenient-site NERV-only landing
├── POS6 / Poseidon_SSTO_Vacuum_Ascent.ks   NERV ascent from an airless-body landing
├── OM1 / Poseidon_SSTO_OM1.ks            orbital maneuvering
└── POS2 / Poseidon_SSTO_Docking.ks       docking workflow
```

Shared libraries contain the vehicle definition, control loops, GUI, navigation helpers, aerodynamic simulation, entry guidance, runway constants, and terminal-area routing.

## Repository layout

The GitHub distribution contains the flight scripts, GUI image assets, example craft, and this README. Tests, calibration scripts, Python tools, logs, and development documents are kept locally.

| Path | Purpose |
| --- | --- |
| `Script/POS.ks` | Main launcher and flight-mode selector |
| `Script/POS1.ks` | Shortcut for the ascent program |
| `Script/POS3.ks` | Shortcut for the re-entry program |
| `Script/POS4.ks` | Shortcut for the targeted vacuum-landing program |
| `Script/POS5.ks` | Shortcut for a vacuum landing at the predicted convenient site |
| `Script/POS6.ks` | Shortcut for an airless-body NERV ascent |
| `Script/Poseidon_SSTO/` | Main Poseidon mission scripts |
| `Script/Libraries/Poseidon_SSTO/` | Poseidon-specific vehicle, GUI, control, guidance, and routing code |
| `Script/Libraries/rsvp/` | Orbital transfer and maneuver calculations |
| `Script/Libraries/` | Shared navigation, aerodynamics, math, and input helpers |
| `Poseidon SSTO Block 2.craft` | Example Poseidon craft file |

## Requirements

- Kerbal Space Program 1.12.5
- kOS
- The kOS Ferram Aerospace Research integration/add-on used by the scripts
- Giulio Dondi's Ferram fork
- The Poseidon SSTO craft, or a suitably modified vehicle matching the script assumptions

The scripts use aerodynamic data from the Ferram integration, so re-entry and terminal guidance will not work correctly without the required add-on.

## Installation

1. Install the required KSP version and mods.
2. Copy the contents of this repository's `Script` directory into the kOS script directory used by your KSP installation.
3. Place `Poseidon SSTO Block 2.craft` in the appropriate `Ships/SPH` folder.
4. Load the Poseidon SSTO in KSP and run `0:/POS.ks` from a kOS terminal.

The script paths use kOS's `0:/` volume. If your kOS volume is configured differently, update the paths consistently before running the scripts.

## Basic use

Run `POS.ks` while controlling the Poseidon. POS-kOS inspects the vessel's altitude and atmospheric state, then opens the appropriate operating screen. From there you can:

- start an ascent and choose target apoapsis, periapsis, and inclination;
- open the orbital maneuvering selector;
- start re-entry and select a landing location and runway; or
- choose **Vacuum Landing** for a coordinate target, or **Vacuum Landing (Convenient)** to select a nearby planned site with minimal cross-range correction; or
- use the docking workflow when applicable.

During flight, the GUI shows the active phase, guidance mode, vehicle data, and trajectory information.

The ascent manager starts with a **Takeoff** surface-speed bar and V1/VR ticks.
It remains visible through rotation and changes to the altitude/airspeed chart
only after the rotate phase ends. The V1 marker estimates the accelerate-stop
limit from runway remaining, current surface speed and mass, using logged
takeoff acceleration and the supplied takeoff-weight braking measurements.
When the live runway-feasibility check actually calls V1, the marker latches that
measured surface speed. VR comes from the configured rotation
airspeed, translated to the current surface-speed frame for its tick. Coincident
thresholds share one tick. The displayed V1 tick is always capped at VR in the
bar's surface-speed frame, including after a callout. The numeric callout and log
retain the true measured speed even when the tick is capped. Numeric labels
distinguish estimated/called V1 and VR.

The takeoff stopping-distance reference reuses the existing conservative fit
`0.055 * max(1, mass / 69.5) * surface_speed^2 + 30` metres over its
calibrated 13-113.6 m/s interval.
It covers all 12 supplied stopping measurements and is unavailable outside that
interval. Both the speed marker and this readout are passive display references;
the actual runway-stop and rotation decisions continue to use their live inputs.

After takeoff the manager automatically uses two guidance pages: **Ascent 1** covers
alignment through NERV assist with a fixed altitude/airspeed chart, and **Ascent 2**
covers closed-cycle climb and apoapsis build with the cutoff target and orbit
readouts. Its large apoapsis/cutoff panel includes remaining altitude and a
progress bar; closed-cycle climb shows the RAPIER cutoff before switching to
the NERV ascent cutoff. Circularization has a separate page with a large
estimated countdown to the insertion burn window, remaining delta-v, alignment,
burn-duration estimate, and actual/requested orbit. The countdown uses the live
controller's timing gate; ignition still requires its altitude and alignment
conditions. Missing or stale insertion estimates display as unavailable rather
than counting down old data. The climb chart's
cross is a planning aimpoint, not a predicted flight path; reaching the altitude
trigger starts NERV assist even if the speed aimpoint has not been reached.

The status line distinguishes tracking, insufficient observed progress, manual
control, protection activity, and recovery. Tracking means steering is within a
5-degree display threshold and progress has been observed over a two-second
window; it is advisory and does not change the flight law or abort criteria.
The display refreshes at 2 Hz and shows its sample UT so a frozen readout is
recognizable. Final insertion readouts remain available until the window is
closed. `ascent_display_state` events record page/phase/status changes at low
logging level; medium adds 1 Hz display samples and high records each fresh
display snapshot. Normal flight telemetry retains its existing rates.

`ascent_inclination_state` records dogleg/direct and northbound/southbound
changes at low logging level. Medium adds 1 Hz `ascent_inclination_sample`
events and high adds 5 Hz samples, including the requested and actual
inclination, remaining latitude excess, and commanded heading. Atmospheric
ascent records `ascent_inclination_result` on exit; vacuum ascent includes the
target and residual error in `vacuum_ascent_complete`.

The chart uses one background PNG and two small marker images. Placement is
based on kOS layout offsets and still needs in-game KSP/Unity verification;
the experimental offline GUI workbench cannot establish final image alignment.

### Targeted vacuum landing

Use the **Vacuum Landing** item from the main menu, or run `0:/POS4.ks`. It operates only on bodies without an atmosphere. It keeps the R.A.P.I.E.R.s disabled and uses the LV-N engines for both the de-orbit node and powered descent.

POS4 opens a latitude/longitude dialog when coordinates are omitted. Pass the first two parameters to skip that dialog; leave the altitude override negative to use terrain height at the selected point:

```ks
runpath("0:/Poseidon_SSTO/Poseidon_SSTO_Vacuum_Landing.ks", 8.421, -74.230).
```

For the no-coordinate option, choose **Vacuum Landing (Convenient)** or run `0:/POS5.ks`. It derives a nearby landing site from the planned de-orbit path, so it does not spend fuel steering across the body to a user-selected point. Both modes place every required inclination and de-orbit node on the map, then wait for an explicit **Execute this node** click. The review window also offers replan and cancel actions.

The fourth optional parameter is the preferred heading used while the craft pitches from its tail contact down onto the gear; pass `"convenient"` as the fifth parameter to select the convenient-site mode from a terminal. Start from a stable orbit with sufficient LV-N thrust-to-weight ratio; the program refuses to begin if the enabled NERVs cannot provide the braking reserve.

### Flight logging

File logging is disabled by default. Before launching POS, set the logging mode in the kOS terminal:

```ks
global POS_LOGGING_MODE is "medium".
runpath("0:/POS.ks").
```

The available modes are:

| Mode | Records | Cost |
| --- | --- | --- |
| `none` | Nothing: no folder and no files are created. | One early return in the real-flight hook. |
| `low` | Flight start, phase/subphase and DAP-mode transitions, runway/target choices, solver outcomes, aborts, terminal-phase changes, and status/validation events. | State-string comparisons only. |
| `medium` | Everything in `low`, plus one complete vehicle/control/guidance sample per second. | The detailed vehicle values are read only once per second. |
| `high` | Everything in `medium`, sampled on every real control tick. | Intended for diagnosing a specific failure, not routine flights. |

Each run creates the next unused directory under `0:/POS_logs/`, for example:

```text
0:/POS_logs/flight_1/flight.csv
0:/POS_logs/flight_1/events.csv
```

The files are never appended to or reused. `flight.csv` contains the replayable position, velocity, acceleration, attitude, DAP command, control-envelope, GPWS terrain-protection readouts, target/runway, terminal-guidance values, and the craft's current celestial body. Entry samples also record the planned and commanded predictive bank, active authority, both candidate banks, their signed range residuals and TEAM-box miss distances, the measured sensitivity, validity, calculation time, and next update time. Vacuum-landing samples additionally record the target coordinates, target distance, lowest-bounds clearance, speed, requested vertical speed, NERV throttle, braking distance, available acceleration, tail-contact state, pitch-down target, PDI solution error, predicted clearance, thrust saturation, node approval, and pitch-over readiness. Same-body rendezvous samples record target distance, relative speed, plane error, phase, and whether the docking handoff gate is satisfied. GPWS samples include its state, worst predicted clearance, required clearance, clearance margin, recovery timer, next scan time, and whether its pull-up control is active. `events.csv` records the decisions that explain state changes, including the flight's starting body, SOI/body transitions, vacuum target, node review and decision, de-orbit plan, braking start, translation start, engine-cutoff pitch-over, gear touchdown, GPWS state transitions, entry display-page transitions, and rendezvous planning/burn/handoff transitions. The entry-trajectory solver and the simulation routines it calls do not perform any logging, so their calculations have no logging branches.

If you find an issue, please report it in the [GitHub issue tracker](https://github.com/LionPapaya/POS-kos/issues) and include the matching `flight.csv` and `events.csv` logs. Together, the flight samples and state-transition events make the problem reproducible and diagnosable.

For compatibility, setting the old `POS_LOGGING_ENABLED` flag to `true` before launch selects the new `high` mode. Use `POS_LOGGING_MODE` for new launches.

For a same-body orbital rendezvous, choose **Rendezvous** in Orbital Maneuvering and select the other vessel. The routine plans and executes a two-burn Lambert intercept, matches the target velocity, and retains that vessel as the KSP target. It reports success only inside the docking gate (within 1 km and below 5 m/s), at which point start Docking to select ports and perform the close-range approach. In Ascent, selecting a vessel in the **RENDEZVOUS** menu first waits for its predicted launch corridor, inserts into that vessel's orbit, then runs the same final rendezvous routine. The docking-control window provides Pause/Resume and Abort buttons.

Reentry started below 72 km automatically chooses an initial runway from the Trajectories impact prediction, or from the current position if no impact prediction is available. If the entry solver fails, basic guidance continues updating while other runway candidates are tried. Coarse predictions rank actual TEAM targets without rejecting candidates; failed alternatives do not displace the best available approach unless their entry plan converges. If none converges, the craft continues toward that approach until the normal TEAM handoff gates allow terminal guidance. The TEAM lateral offset has a **100 km maximum**.

Recovery telemetry records candidate searches and rejections, solver durations, retry times, and the age of the last basic guidance update. Live DAP steering and protection continue during lengthy calculations; trajectory predictors remain independent of the logger.

## Takeoff performance estimate

To attempt takeoff even when the preflight departure check refuses it, change
`"override_preflight_refusals",false,` to `"override_preflight_refusals",true,`
under `Poseidon_SSTO:add("Takeoff",lex(` in
`Script/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks`, then restart the kOS
program with the updated file loaded (reboot the CPU if the craft library was
already loaded). The default is `false`. All checks still run and retain their
actual results. An overridden refusal prints a warning and attempts departure
using the orbital course when no checked terrain route is available. Engine
failure aborts and in-flight terrain protection remain active. The runway-length
estimate is already advisory and does not itself refuse takeoff.

The flight logger records `takeoff_preflight_policy` and, for a failed check,
either `departure_takeoff_held` or `departure_takeoff_overridden`, together with
the existing runway prediction and terrain-plan diagnostics. These events use
the existing low/medium/high logging modes; no trajectory prediction logs.

Ascent prints an advisory runway assessment before launch and records it again at brake release. It uses the selected departure direction and the craft's position along the runway, rejecting off-runway or misaligned positions. `required_runway_m` and `runway_margin_m` now refer only to liftoff with the 15% distance allowance. `required_departure_m` separately estimates distance to 35 m height; the aircraft may climb beyond the pavement end, so `screen_fits` is diagnostic and does not veto a takeoff.

`departure_status` distinguishes `estimated_feasible`, `demonstrated_departure`, and `unknown`. A negative generic runway margin means the conservative estimate does not confirm pavement margin; it does not prove the takeoff impossible. For Nye-Island runway 15, flights 20/22 plus the maintainer's confirmation support `demonstrated_departure` at 68.72565–68.82 tonnes, with the normal profile and a start within 5 m of the threshold. That evidence permits `sufficient` even when the conservative distance model does not fit the mapped pavement. It adds no invented pavement or terrain clearance and does not extend the demonstrated mass limit to heavier loads or the reciprocal direction. Other runways, including Sandy-Island, Hazard-Shallows and Island, receive no such evidence override. Lighter loads may be estimated feasible while remaining unvalidated extrapolations.

The pure Poseidon model and assessment are in `Script/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks`; generic runway projection is in `Script/Libraries/lib_navigation.ks`. Tune the craft-specific values under `AVES["Takeoff"]`:

```kerboscript
local estimate is takeoff_performance(ship:mass,2500,AVES["Speed"]["Rotate"],AVES["Ascent"]["rotate_pitch"]).
```

It returns rotation and liftoff distances, liftoff speed, initial climb distance, required distance, runway margin, and validity/result flags. The current profile rotates at **110 m/s** and commands 20 degrees. The model includes acceleration between rotation and actual liftoff, a minimum pitch-response time, and the measured slow initial climb. The live wrapper `assess_takeoff_runway(selected_runway)` calculates remaining runway from the current position.

Calibration uses 26 confirmed liftoffs and 24 completed initial climbs in the supplied `flight_145` collection. Supported initial mass is 68.72565–70.04567 tonnes, with nominal Poseidon propulsion, the current rotation profile, and Kerbin launch altitudes of 70–325 m. Weight, density, and thrust scaling outside that envelope is explicitly heuristic: numeric estimates are returned, but `model_valid` and `sufficient` remain false. Changes to wing geometry, payload balance, engines, FAR settings, runway slope, or obstacles require new flight validation even inside the mass range. The 15% allowance is an engineering margin, not a statistical confidence interval.

At 69.5 tonnes the conservative estimate is about 1,893 m to liftoff, 2,177 m with the runway margin, and 3,591 m to reach 35 m including the departure margin. This is deliberately above the recorded distances. The 12 supplied stopping runs were confirmed at takeoff weight and bound the braking curve used by the GUI V1 estimate. Their exact mass was not recorded; 69.5 tonnes is the logged takeoff reference, and mass scaling remains an assumption. The GUI estimate does not replace the existing live V1/abort model. The assessment does not block takeoff or change the ascent commands.

`events.csv` records takeoff predictions, brake release, rotation, confirmed liftoff, and reaching the screen height. Low logging records transitions; medium adds 1 Hz takeoff samples; high samples each physics tick. Predictions remain independent of logging.

Calibration tools and generated reports are maintained locally and are not included in this flight distribution. KSP/FAR remains the final validation of takeoff and climb behavior.

## Known limitations

- Tuning is specific to the Poseidon SSTO and may fail on other craft.
- Interplanetary or very high-altitude re-entry is not yet reliable.
- Vacuum landing begins from a stable orbit and needs LV-N thrust-to-weight greater than 1.10; terrain with a steep slope at the requested coordinates is not screened.
- Runway and trajectory selection depends on the data in `lib_location_constants.ks`.
- `runway_abort` and `rtls` have been successfully exercised in maintainer flight testing on Poseidon. The supplied `flight_145` logs capture a runway-stop rejection and RTLS selection, but do not provide complete flight traces for a successful runway stop, RTLS turnback, runway handoff, or go-around. Keep those broader failure-condition claims limited to separately recorded flight evidence.
- The Ferram integration must be available for the aerodynamic calculations used by guidance.

## Development notes

When adding an abort mode, keep its behavior behind the abort-mode dispatcher and give it a dedicated flight-phase state. Add user-facing documentation only after the mode is implemented and tested with the Poseidon craft. For flight-guidance or control changes, review the flight logger in the same change and retain representative `flight.csv` and `events.csv` traces for each claimed behavior. This keeps the abort section easy to extend and its test claims traceable.

`TRAJ 1 V/SIT` through `TRAJ 5 V/SIT` are successively zoomed views of one fixed energy-height/range reference corridor generated from successful `reentry_low` flight logs. Their energy bands are 260–290, 210–260, 170–210, 140–170, and 100–140 km. Their corresponding RNG windows are 600–1,100, 450–800, 150–600, 50–300, and 0–180 km. The median remaining range at each energy height remains the centreline. A smoothstep width taper runs from about ±120 km at the far-range end to ±30 km near the target. These bands are visual references and do not define aerodynamic or reachability limits.

During predictive entry, the V/SIT dotted path is interpolated from the existing lower-bank and upper-bank guidance predictions. The traces are matched at shared energy heights, and their remaining ranges are blended using the selected commanded-bank fraction. Sixteen reusable dots stay anchored to the prediction's source state until the next normal guidance update; basic, frozen, invalid, and reset states hide the path. This display adds no trajectory searches. Regenerate the KerboScript profile and backgrounds together using the locally maintained development tools and a representative set of flight logs.

The active page follows energy height and clamps only beyond the complete 100–290 km display span. TEAM then uses the wide `L/SIT 1` and the close-in `L/SIT 2`. Recheck the live shuttle, path placement, axes, and offsets in KSP. Validate regenerated displays and page transitions in KSP; the offline GUI workbench approximates kOS layout but is not a Unity renderer.

## Credits

- The kOS community libraries and frameworks used for input, navball, and location constants.
- Giulio Dondi for the Ferram add-on and aerodynamic-force helpers.

Four-RAPIER-loss contingency recovery now attempts a monitored NERV orbit insertion when the NERVs were already active. If insertion is infeasible, it retains healthy NERVs for runway entry and recovery, then selects ocean corridors or sampled flat land when needed. On Kerbin, failed searches, unsafe finals, and timeouts continue into automatic emergency recovery, using reserve fuel when needed. Contingency finishes after stopped ground contact, splashdown, or preservation of a stable orbit. This behavior still requires in-game flight validation.

Water recovery captures a wings-level approach at 400 m hull clearance, or earlier for a fast descent, preserving the existing GPWS lift command. It arrests sink before braking away excess speed, then holds about 3 m hull clearance unpowered until lift runs out and the aircraft settles. Crossing the normal approach-speed boundary no longer lowers the water AoA command. A land-target emergency crossing the coast uses the same early water gate. Low aborts that are still climbing retain terrain protection; sink-rate trend feedback restores lift before a fading climb becomes a steep descent and releases airbrakes when sink is worsening. Atmospheric contingency recovery enables fuel dumping to a fixed 10% LF floor; that remaining LF is available to healthy NERVs. Orbit rescue keeps dumping disabled. Contact events preserve the last airborne speed, sink and mass before water drag or part loss can hide a hard impact. These approach, stall and drain margins require KSP/FAR validation.

### Late-ascent aborts: AED, ATO and EDR

ATI has been replaced by AED (energy-managed runway diversion), ATO (supervised orbit recovery), and EDR (emergency deorbit/return). Their guidance remains in Orbit Main until the reentry/TEAM handoff. Engine failures, deliberate isolation, per-engine survivor limits, original fuel reserves and rejected-attempt history persist across transfers. These modes have source/offline validation and still require KSP/FAR flight calibration.

### Takeoff GUI V1 estimate

The takeoff speed bar estimates V1 from the runway available at brake release,
less the distance already rolled, current surface speed and vessel mass. It solves
`remaining = k * (V1² - current_speed²) + b * V1² + 30 m`, with
`k = 0.107 * mass / 69.5` from logged takeoff acceleration and
`b = 0.055 * max(1, mass / 69.5)` from the twelve supplied takeoff-weight abort
stops. The 30 m allowance and braking coefficient cover all supplied stops.
Linear mass scaling assumes fixed braking force; lighter craft receive no
braking-distance credit. Masses outside the logged 68.73–70.05 t range are marked
as extrapolations. Landing logs near 35.7 t are not treated as takeoff-weight
braking calibration.

`V1 >=` means the runway permits stopping at the displayed limit (VR or the
highest measured abort speed, 113.6 m/s); it does not claim an exact V1 beyond
that limit. An unknown or misaligned runway hides the estimate. The actual V1
callout continues to use the executive's runway-abort feasibility decision and
retains its measured surface speed. Display telemetry records the runway budget,
mass, coefficients, validity and limiting status at the existing low/medium/high
cadence. This remains a passive display estimate: it does not change runway-stop,
RTLS, or contingency dispatch. Validate stopping and GUI behavior in KSP; the
offline GUI is experimental.
