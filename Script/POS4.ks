// Direct launcher for a NERV-only landing on an airless body.
set CONFIG:IPU to 2000.
if not(defined(POS_LOGGING_ENABLED)) {
    global POS_LOGGING_ENABLED is false.
}
runpath("0:/Poseidon_SSTO/Poseidon_SSTO_Vacuum_Landing.ks", "ASK", "ASK", -1, 90, "suborbital").
