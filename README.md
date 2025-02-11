# Poseidon SSTO Operating System (POS-kOS)

## Overview
This repository contains scripts for controlling the **Poseidon SSTO**, a Single-Stage-to-Orbit spacecraft in **Kerbal Space Program**. The scripts are tailored exclusively for the **Poseidon SSTO** and should not be used with other spacecraft without significant modification.

The system automates the key phases of the mission:
1. **Launch**: Automatic ascent to orbit.
2. **Orbital Maneuvering **: Maneuvers such as orbital transfers or orbital adjustmants.
3. **Reentry**: Guided atmospheric descent and runway landing.

---

## Features

### Launch
- Takeoff from the runway.
- Adaptive pitch control for optimal ascent efficiency.
- Automatic engine mode switching (RAPIER air-breathing to closed-cycle, Nerv activation).
- Circularization maneuver to achieve stable orbits.

### Orbital Maneuvering
- Supports transfers to celestial bodies or rendezvous with other vessels.
- Inclination, Apoapsis or periapsis changes.

### Reentry
- Closed loop reentry alg
- auto deorbit calculation and execution
- runway landing on all Kerbinside runways

---

## Limitations
1. **Exclusive Use**: The scripts are specifically designed for the **Poseidon SSTO**. They rely on its engine configuration, mass, and aerodynamic properties.
2. The reentry doesn't work properly from interplaetary alt, yet.

---

## Usage Instructions
### How to Use
 1. install the latest version of KSP (1.12.5)
 2. install the kos mod and the ferram kos addon
 3. install giulio dondis ferram fork
 4. place the scripts in the ships folder
 5. place the craft in the ships/sph folder
---

## Disclaimer
These scripts are **exclusively designed for the Poseidon SSTO**. Using them with other craft may result in failure or unintended behavior.
Please report any issues in the issues page of the github


## Credits 
The KS lib for some functions in the input_lib and the navball_lib and the framework for the location constants
Giulio dondi for the ferram addon and some aero force functions
