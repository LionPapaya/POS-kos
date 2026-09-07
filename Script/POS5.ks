// Direct launcher for a NERV-only landing at a nearby planned site.
if not(defined(POS_LOGGING_ENABLED)) {
    global POS_LOGGING_ENABLED is false.
}
runpath("0:/Poseidon_SSTO/Poseidon_SSTO_Vacuum_Landing.ks", 0, 0, -1, 90, "convenient").
