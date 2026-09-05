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

## Aborts

Abort modes are selected according to the vehicle's situation and are implemented as separate flight phases. Only the currently implemented abort mode is documented below.

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

The abort-mode dispatcher is kept separate from the main flight phases so additional abort modes can be added later without restructuring the mission flow. They are not documented here until implemented and tested.

## Mission flow

The top-level `POS.ks` script loads shared libraries and chooses a flight program based on the vessel's state:

```text
POS.ks
├── POS1 / Poseidon_SSTO_Orbit_Main.ks   ascent and circularization
├── POS3 / Poseidon_SSTO_Reentry.ks      de-orbit, entry, and landing
├── OM1 / Poseidon_SSTO_OM1.ks            orbital maneuvering
└── POS2 / Poseidon_SSTO_Docking.ks       docking workflow
```

Shared libraries contain the vehicle definition, control loops, GUI, navigation helpers, aerodynamic simulation, entry guidance, runway constants, and terminal-area routing.

## Repository layout

| Path | Purpose |
| --- | --- |
| `Script/POS.ks` | Main launcher and flight-mode selector |
| `Script/POS1.ks` | Shortcut for the ascent program |
| `Script/POS3.ks` | Shortcut for the re-entry program |
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
- use the docking workflow when applicable.

During flight, the GUI shows the active phase, guidance mode, vehicle data, and trajectory information.

### Flight logging and replay

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

The files are never appended to or reused. `flight.csv` contains the replayable position, velocity, acceleration, attitude, DAP command, control-envelope, GPWS terrain-protection readouts, target/runway, and terminal-guidance values. GPWS samples include its state, worst predicted clearance, required clearance, clearance margin, recovery timer, next scan time, and whether its pull-up control is active. `events.csv` records the decisions that explain state changes, including GPWS state transitions. The entry-trajectory solver and the simulation routines it calls do not perform any logging, so their calculations have no logging branches.

To replay a `medium` or `high` flight, open the local, gitignored [replay tool](tools/flight-replay/index.html) in a browser. Load the matching `flight.csv`, optionally load `events.csv`, then use the timeline and the 3-D view. The inspector shows every recorded column at the selected frame; the scene shows the recorded flight path, vehicle, runway, and entry target without rerunning guidance.

For compatibility, setting the old `POS_LOGGING_ENABLED` flag to `true` before launch selects the new `high` mode. Use `POS_LOGGING_MODE` for new launches.

For docking, first select the other vessel (or one of its docking ports) as the KSP target. Start outside the atmosphere, within 1 km of the target vessel, and below 5 m/s relative velocity. POS prefers Poseidon's open Mk2 inline port, honors a port explicitly targeted in KSP, and lets you choose among multiple compatible ports when the vessel itself is targeted. It matches the measured motion of the two port faces (including vessel rotation), moves out to a target-sized keep-out shell only when it is not already in a safe approach corridor, routes around the vessel when necessary, and performs stand-off, alignment, and final approach. Recoverable final-corridor drift returns to the approach gate, magnetic contact releases autopilot inputs for capture, and a progress watchdog retries one stalled approach before stopping with a diagnostic. The docking-control window provides Pause/Resume and Abort buttons. It does not perform orbital phasing or a distant rendezvous.

## Known limitations

- Tuning is specific to the Poseidon SSTO and may fail on other craft.
- Interplanetary or very high-altitude re-entry is not yet reliable.
- Runway and trajectory selection depends on the data in `lib_location_constants.ks`.
- Abort handling is under active development; only `runway_abort` should currently be treated as documented functionality.
- The Ferram integration must be available for the aerodynamic calculations used by guidance.

## Development notes

When adding an abort mode, keep its behavior behind the abort-mode dispatcher and give it a dedicated flight-phase state. Add user-facing documentation only after the mode is implemented and tested with the Poseidon craft. This keeps the abort section easy to extend without documenting work-in-progress behavior.

## Credits

- The kOS community libraries and frameworks used for input, navball, and location constants.
- Giulio Dondi for the Ferram add-on and aerodynamic-force helpers.
