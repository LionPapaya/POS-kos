// NERV-only PDI landing. Omitted coordinates open the target GUI.
// Every inclination/deorbit node requires an explicit in-game Execute click.
// runpath("0:/Poseidon_SSTO/Poseidon_SSTO_Vacuum_Landing.ks", 8.421, -74.230).
parameter target_latitude is "ASK".
parameter target_longitude is "ASK".
parameter target_altitude_override is -1.
parameter target_landing_heading is 90.
parameter landing_target_mode is "coordinate".

RUNONCEPATH("0:/Libraries/lib_math.ks").
RUNONCEPATH("0:/Libraries/lib_navball.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/control.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/flight_log.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/pdi_navigation.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/pdi_terminal.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/pdi_executive.ks").

pdi_run(target_latitude,target_longitude,target_altitude_override,target_landing_heading,landing_target_mode).
