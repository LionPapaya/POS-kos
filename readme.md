# Poseidon SSTO Operating System (POS-kOS)

POS-kOS is a [kOS](https://github.com/KSP-KOS/KOS) flight-control system for the Poseidon SSTO in Kerbal Space Program. It provides automated ascent, orbital maneuvers, rendezvous and docking, atmospheric return, runway landing, and powered flight on airless bodies, with an in-game graphical interface.

The guidance is built around the Poseidon's engines, mass, aerodynamics, and control configuration. The included `Poseidon SSTO Block 2.craft` is the reference vehicle.

## Ascent and orbital insertion

The launch program accepts target apoapsis, periapsis, and inclination. It identifies the departure runway, assesses the departure, holds the brakes while the RAPIER engines spool up, and manages the takeoff roll, rotation, and climb.

Guidance switches the RAPIERs between air-breathing and closed-cycle operation and brings in the NERV engines for the upper-atmosphere ascent. It builds the requested apoapsis and executes a circularization maneuver. Inclinations from 0 to 180 degrees are accepted; when the launch latitude lies outside the requested orbital plane, guidance uses a bounded equatorward dogleg. Fuel, terrain, and steering authority determine the final achievable orbit.

The ascent GUI follows the flight through takeoff, atmospheric climb, closed-cycle ascent, and circularization. It shows a takeoff speed bar with V1 and rotation markers, estimated stopping distance, altitude and airspeed, engine and guidance status, cutoff targets, and the insertion-burn countdown.

Selecting a vessel as the ascent rendezvous target adds a launch-window wait, insertion into the target orbit, and a subsequent orbital rendezvous.

## Orbital maneuvers, rendezvous, and docking

The Orbital Maneuvering program offers:

- Transfers to another celestial body or vessel using the RSVP library.
- Execution of an existing maneuver node.
- Apoapsis, periapsis, and inclination changes.
- Circularization of the current orbit.
- Same-body rendezvous with a selected vessel.

Same-body rendezvous plans and executes a two-burn intercept and matches the target's velocity. It retains the vessel as the KSP target and reports docking readiness within 1 km and below 5 m/s relative speed.

The Docking program handles the close-range approach. It selects compatible docking ports, approaches a stand-off point on the target port's axis, aligns the craft, and uses RCS translation for final closure. The docking window provides Pause/Resume and Abort controls.

## Atmospheric return and runway landing

The return program plans and executes a deorbit maneuver, predicts entry trajectories, and guides the Poseidon toward a selected Kerbin location and runway. It can also select a reachable runway automatically.

Entry guidance controls angle of attack and bank to manage energy and range. It transitions into terminal-area energy management (TEAM), builds a route to the runway, aligns the approach, and manages airbrakes, landing gear, flare, and rollout. Terrain protection monitors the projected flight path and can command a recovery pull-up.

The return GUI combines flight data, guidance status, energy-versus-range charts, predicted trajectory markers, and terminal-area approach displays. The chart pages change with the entry and approach phase.

## Aerobraking

The Aerobraking program controls one atmospheric pass with either the AVES angle-of-attack schedule or a fixed angle of attack, together with a pilot-selected bank. Its GUI predicts the final apoapsis for the selected settings and updates the prediction as the flight progresses.

Cancel returns to the POS launcher and restores CSS if it was previously selected; otherwise control returns to OFF. A completed atmospheric exit returns to the launcher. If apoapsis falls below the top of the atmosphere, the program hands control to the atmospheric return program.

## Flight recovery

POS selects recovery behavior according to flight phase, available propulsion, runway distance, and the vehicle's energy:

- **Runway abort:** cuts thrust and brakes to a stop when sufficient runway remains.
- **Return to launch site (RTLS):** continues to a safe airborne state, turns back, and hands the vehicle to landing guidance for the departure runway.
- **Energy-managed diversion (AED):** seeks a runway recovery during later ascent.
- **Abort to orbit (ATO):** supervises an orbit-recovery attempt with the remaining propulsion.
- **Emergency deorbit/return (EDR):** manages a return when continued orbital ascent is unsuitable.

Contingency guidance carries engine-failure and fuel-reserve information between recovery phases. It can use remaining NERV propulsion for orbit recovery or atmospheric return and select water or land recovery corridors when a runway approach is unavailable.

## Flight on airless bodies

### Powered landing

Vacuum landing uses NERV propulsion for deorbit and powered descent, keeping the RAPIERs disabled. It brakes toward the surface target, translates to that location, settles onto the rear support, and pitches down onto the landing gear.

**Vacuum Landing (Suborbital)** accepts a latitude and longitude. **Vacuum Landing (Convenient)** derives a nearby site from the planned deorbit path. Required inclination and deorbit nodes are shown for review, with execute, replan, and cancel controls.

Begin from a stable orbit with sufficient NERV thrust and fuel. The program requires a thrust-to-weight ratio above 1.10 for its braking reserve. The coordinate target does not include steep-slope screening.

### Ascent

Vacuum ascent accepts a circular-orbit altitude and inclination. RCS pitches the landed craft onto its rear support. A short closed-cycle RAPIER boost lifts it clear of the tail and landing gear, after which it retracts the gear and climbs on NERV propulsion. Guidance builds apoapsis and executes circularization before returning to the POS menu.

## Installation and operation

The scripts are intended for Kerbal Space Program 1.12.5 with kOS, Giulio Dondi's Ferram fork, and the kOS Ferram integration that exposes the aerodynamic-force queries used by guidance.

1. Copy the contents of `Script/` into your KSP installation's kOS script archive, preserving the directory structure and GUI images.
2. Place `Poseidon SSTO Block 2.craft` in the save's `Ships/SPH/` directory.
3. Load the craft and run the launcher from its kOS terminal:

```ks
runpath("0:/POS.ks").
```

The launcher chooses its initial program from the vessel's altitude and atmospheric state. Its program selector provides access to Launch, Landing, Aerobraking, Orbital Maneuvering, Docking, vacuum landing, vacuum ascent, and manual flight recording. The control selector offers automatic guidance, control-stick steering (CSS), and OFF.

The scripts use the `0:/` archive path. Keep the libraries and images at the corresponding paths when copying the files.

### Direct launchers

| Script | Program |
| --- | --- |
| `Script/POS.ks` | Main launcher and program selector |
| `Script/POS1.ks` | Ascent and orbital insertion |
| `Script/POS3.ks` | Atmospheric return and runway landing |
| `Script/POS4.ks` | Vacuum landing at supplied coordinates |
| `Script/POS5.ks` | Vacuum landing at a convenient site |
| `Script/POS6.ks` | Vacuum ascent |
| `Script/POS7.ks` | Aerobraking |

Orbital Maneuvering and Docking are available through the main launcher.

## Flight recording

File logging is off by default. To enable it before starting POS:

```ks
global POS_LOGGING_MODE is "medium".
runpath("0:/POS.ks").
```

The modes are `none`, `low` for events and state changes, `medium` for events plus one flight-data sample per second, and `high` for events plus samples on every real control tick. Each session writes `flight.csv` and `events.csv` into a new directory under `0:/POS_logs/`.

Manual Flight Logging records a pilot-flown session from the main menu, with OFF for manual control or CSS for assisted steering. Stopping the recording returns to the program selector.

## Code and assets

| Path | Contents |
| --- | --- |
| `Script/Boot/` | kOS boot launcher |
| `Script/Poseidon_SSTO/` | Main mission programs and flight-data HUD |
| `Script/Libraries/Poseidon_SSTO/` | Vehicle configuration, control, guidance, recovery, and GUI code |
| `Script/Libraries/rsvp/` | Orbital transfer and maneuver calculations |
| `Script/Libraries/gui_images/` | GUI backgrounds, charts, markers, and controls |
| `Script/Libraries/lib_*.ks` | Shared navigation, aerodynamics, math, and input helpers |
| `Poseidon SSTO Block 2.craft` | Poseidon reference craft |

## Credits

- The kOS community libraries and frameworks used for input, navball, and location constants.
- Giulio Dondi for the Ferram add-on and aerodynamic-force helpers.
