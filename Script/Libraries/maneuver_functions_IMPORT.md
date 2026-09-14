# SilverNuke911 maneuver library integration

`lib_orbital_nodes.ks` starts with an **unchanged, byte-for-byte copy** of
[SilverNuke911's maneuver_functions.ks](https://github.com/silvernuke911/KOSscripts/blob/9b5b28f097f2f78edfb955484ac322e8849eceac/lib/maneuver_functions.ks).
The existing POS node helpers follow the `END UNMODIFIED` marker.

- Upstream file commit: `9b5b28f097f2f78edfb955484ac322e8849eceac` (2026-04-27).
- Imported on 2026-09-14; 155,839 bytes.
- SHA-256 of the imported bytes: `f5c4a9f7e6ae23080d136c43fc9f79ef9ecf2527ac720c96e6f0c3bc82312152`.
- Original comments, formatting, function names, parameters, and implementation are preserved, including unfinished functions and upstream defects.

## Flight integration

`Poseidon_SSTO/orbital_maneuver.ks` supplies the command catalog, input dialogs,
validation, node creation, and review. The existing Orbital Maneuvering program
loads it. Select a command, create its node, inspect the displayed/map orbit,
then choose **Execute this node**, **Keep node; do not execute**, or **Delete this
node**. Existing nodes are not overwritten. A node modified since its displayed
review must be reviewed again. Altitudes are meters above the surface; semimajor
axis is meters from the body center; time inputs are seconds from now.

Available commands cover circularization, either/both apses, inclination,
eccentricity, LAN, semimajor axis, resonance, argument of periapsis, target plane
and velocity matching, timed/lowest-delta-v intercepts, closest-approach tuning,
Hohmann transfer, both transfer-window search implementations, and RCS apsis
correction. Target commands use the selected map target and require both objects
to orbit the same central body. The UI supports closed starting orbits. Helpers
and empty/TODO commands remain callable from the library but are not menu actions.
The argument-of-periapsis `cheapest` mode is not offered because upstream compares
`dv1:mag` with itself.

The two-burn Hohmann UI workflow chains the upstream apsis and circularization
planners, reviewing each burn separately. It deliberately does not call the
upstream `hohmann_maneuver` convenience function, which would execute both burns
and an RCS correction without those reviews. Direct RCS correction has its own
explicit start confirmation. Transfer/intercept searches produce a departure
node; including arrival delta-v in search cost does not create an arrival node.
Use **Match target velocity** for that arrival burn.

RSVP and Rendezvous remain separate choices. RSVP reviews each of its generated
nodes. Rendezvous retains its existing automatic two-burn workflow.

`lib_vacstr.ks` now contains `pos_execute_node`, the Poseidon adapter for upstream
`execute_node`. All former callers of the old shared executor use this adapter,
including atmospheric ascent, reentry, and Rendezvous. The dedicated vacuum
PDI/ascent controllers retain their separate execution functions. The adapter
uses manual kOS steering, active engines, and optional warp, rejects missing
thrust or insufficient burn lead time, and restores Poseidon controls afterward.
The upstream function itself remains untouched. Callers stop their workflow if
the adapter does not observe a burn and node removal; this is execution evidence,
not a guarantee that the requested orbit was achieved.

## Logging and validation

The live adapter installs a passive observer around the imported executor.
`events.csv` records planning/review decisions, execution requests, observed
phase transitions, return status, and maneuver samples (remaining delta-v,
ETA, alignment, throttle, mass, thrust, and actual orbital elements). Direct RCS
corrections record start/return events and sampled error/translation command.
Low logs events only, medium samples once per second, and high at most once per
0.02-second tick. No logger is loaded by the node-planning library.

Local regression tests in `tests/test_orbital_maneuver.py` check the import hash,
real KerboScript mathematics through `tools/pos_sim/kos_runtime.py`, actual
planner dispatch, and real GUI callbacks. The executor interface tests use a
stub executor to validate orchestration and cleanup; they do not validate its
closed-loop behavior in KSP. Local hosted-parser support was extended for
scoped parameters/functions, FROM loops, and WHEN observers. The repository
ignores `tests/` and `tools/`, so those validation changes remain local.

The imported library is not certified by these checks. In particular, upstream
closest-approach tuning does not update its best-cost accumulator, the combined
apsis planner contains `abs(cos_nu > 1)`, and the fast transfer search's ASAP mode
scores departure speed rather than departure delta-v. These functions were not
rewritten. Review generated nodes and validate new planning/control behavior in
KSP before relying on it. The GUI workbench is experimental and is not a Unity
renderer or a flight model.
