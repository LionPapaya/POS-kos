// NERV ascent from a completed airless-body landing.  The live executive
// presents a target-orbit dialog, performs the brief closed-cycle RAPIER
// liftoff kick, and automatically executes its circularization node.
set CONFIG:IPU to 2000.

RUNONCEPATH("0:/Libraries/lib_math.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/control.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/flight_log.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/vacuum_ascent_guidance.ks").
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/vacuum_ascent.ks").

vacuum_ascent_run().
