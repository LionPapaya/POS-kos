# Poseidon SSTO Operating System (POS-kOS)

## Overview
This repository contains scripts for controlling the **Poseidon SSTO**, a custom Single-Stage-to-Orbit spacecraft in **Kerbal Space Program**. The scripts are tailored exclusively for the **Poseidon SSTO** and should not be used with other spacecraft without significant modification.

The system automates the key phases of the mission:
1. **Launch**: Automatic ascent to orbit.
2. **Orbital Maneuvering (OM1)**: Maneuvers such as orbital transfers or rendezvous.
3. **Reentry**: Guided atmospheric descent and runway landing.

---

## Features
### General
- Automated execution of launch, orbital adjustments, and reentry phases.
- Advanced trajectory calculations for precision burns and landings.
- User input prompts for mission-specific configurations (e.g., target orbit, reentry mode).

### Launch
- Smooth takeoff from the runway using RAPIER engines.
- Adaptive pitch control for optimal ascent efficiency.
- Automatic engine mode switching (RAPIER air-breathing to closed-cycle, Nerv activation).
- Circularization maneuver to achieve stable orbits.

### Orbital Maneuvering (OM1)
- Supports transfers to celestial bodies or rendezvous with other vessels.
- Dual maneuver node handling for advanced orbital adjustments.
- Prograde or retrograde orientation settings for orbit insertion or departure.

### Reentry
- Automated deorbit burn calculations based on target location.
- Heading Alignment cone (HAC) pattern for precise runway alignment.
- Dynamic control of RCS, throttle, and brakes for safe landings.
- Telemetry logging for diagnostics and debugging.

---

## Limitations
1. **Exclusive Use**: The scripts are specifically designed for the **Poseidon SSTO**. They rely on its engine configuration, mass, and aerodynamic properties.
2. **Input Dependency**: User inputs such as target apoapsis, inclination, or landing site must be accurate for successful execution.
3. **Kerbal Space Program Dependencies**: Requires active installation of kOS and trajectories.

---

## Usage Instructions
### How to Use


1. **Script Execution**:
   - Select the wanted script in the POS gui. 
   - Follow the on-screen prompts to input mission parameters.

2. **Inputs**:
   - Launch: Target Apoapsis, Periapsis, Inclination.
   - OM1: Target (Body or Vessel), Orbit Type, Nodes, Orientation.
   - Reentry: Target Location, Runway Number, Reentry Mode (Auto, Manual, Experimental).

---

## Phases of Operation
### 1. Launch
Handles automated ascent to orbit:
- Ignites engines, takes off, and performs aerodynamically efficient ascent.
- Automatically switches engines to closed-cycle mode above 23km.
- Creates and executes a circularization maneuver.

### 2. Orbital Maneuvering (OM1)
Executes orbital adjustments:
- Plans and executes maneuver nodes for interplanetary transfers or rendezvous.
- Supports prograde/retrograde orientation and elliptical/circular orbits.

### 3. Reentry
Controls atmospheric descent and landing:
- Plans a deorbit burn and aligns the spacecraft for reentry.
- Uses Heading aligement cone (HAC) patterns for precise runway alignment.
- Guides the SSTO through a safe landing with dynamic throttle and brake control.

---

## Disclaimer
These scripts are **exclusively designed for the Poseidon SSTO**. Using them with other craft may result in failure or unintended behavior.
