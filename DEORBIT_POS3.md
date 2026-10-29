# POS3 deorbit planning and execution

Run `0:/POS3.ks`, select the location and runway, select a mode, and press **OK**.
Confirmation commits that site's selection for this run. Merely opening the GUI
or changing a popup does not plan or ignite a burn. Forced recovery targets
continue to bypass this confirmation.

- **AUTO** searches for an entry pass, creates one maneuver, executes it with
  the NERVs, then hands the actual flight state to the existing entry, terminal
  route and landing controllers. Resolve existing map nodes before AUTO.
- **Ex** executes the next map node after the site/mode confirmation. It does
  not calculate or replace the node. The GUI shows its delta-v and UT; inspect
  the node in map view before confirming. Entry, delta-v and plane-change gates
  still apply.
- **Man** waits for a pilot-flown deorbit. Entry guidance begins when the actual
  periapsis enters the atmosphere.

DAP **OFF/CSS**, **ABORT**, or closing the window cancels execution. A failed
maneuver is retained for diagnosis. If a propulsion/control failure leaves the
vehicle committed to atmosphere, entry control continues on the actual state;
an explicit pilot cancellation hands control back.

## Lightweight planner

The planner evaluates analytic two-body arcs, one candidate per main-loop tick.
It does not call `calc_entry_traj`, create trial nodes, query Trajectories impacts,
or run an aerodynamic simulation. The old full atmospheric reachability square
has also been removed from orbital coasting. The existing entry solver and its
live bank guidance still run near atmospheric entry. A confirmed AUTO/Ex site
remains selected during solver retries instead of silently choosing another
runway or simulating alternate sites; existing recovery handoffs retain their
previous diversion policy.

The search covers up to six orbital periods, capped at 86,400 seconds. Departure
is at least 600 seconds ahead. It accounts for target rotation through the entire
coast to the descending 60 km interface, including outbound eccentric arcs. A
velocity-aligned retrograde impulse reduces orbital speed. The executor-facing
node measures the actual prograde and radial basis and resolves that impulse
into it, then verifies the resulting delta-v vector. Normal command stays zero.
This incorporates Terra’s eccentric-orbit node projection; Sol supplies the
bounded search, mode flow and guarded executor, and Luna supplies ranked
rejection diagnostics retained across the search. The desired periapsis rises from -10 km for an 80 km departure to +30 km
for departures at/above 1 Mm, keeping high-energy entries shallower.

The historical entry summaries used as a starting point contain many ~2.1 km/s,
4–6 degree descending entries with about 720–965 km remaining at 60 km. They
include incomplete flights. The default preferred range is 850 km, adjusted by
surface-relative entry speed squared and capped at 1,400 km. Admission permits
650–1,600 km downrange and 120 km crossrange. This is a heuristic corridor, not
a newly fitted or certified aerodynamic envelope. Configuration is centralized
in `deorbit_config()`.

The orbit must be closed, without an encounter patch. A latitude gap exceeding
the crossrange allowance is rejected immediately, so an equatorial orbit cannot
target a pole. No plane-change burn is attempted. A bounded search that finds
no pass reports failure rather than growing a burn indefinitely. These runway
coordinates and envelope are Kerbin-specific; AUTO/Ex reject other bodies.

Delta-v is capped at 900 m/s and the usable LF budget after retaining at least
200 LF units or 20% of existing LF, whichever is larger. The executor separately
admits selected-engine thrust, LF, burn duration (maximum 600 seconds), lead
time, and the exact next node. It checks node edits/loss, pilot cancellation,
alignment, actual thrust and delta-v progress throughout the burn. Coast warp
is bounded and allowed only after alignment; every return zeros throttle and
warp. There is no automatic staging. Accessible fuel and FAR/vehicle behavior
still need confirmation in KSP.

## Evidence and validation

The existing logger levels remain intact: low records transitions, medium
records samples at 1 Hz, and high uses the existing fine sampling cadence.
`deorbit_plan_started`, `deorbit_search_finished`, `deorbit_plan_ready`,
`deorbit_execute_start`, `maneuver_phase`, `maneuver_sample`,
`deorbit_execute_return`, `deorbit_execution_result`, `deorbit_partial_entry`, and
`deorbit_rejected` provide proposed and achieved orbit/entry evidence. Deorbit
maneuver samples additionally record actual thrust, LF, and altitude. No logger
runs inside the predictor. Preserve both companion CSV files from the KSP test,
including an incomplete or failed attempt.

The new real-source tests cover analytic invariants and independent numerical
coasts, full rotating-target pass searches at 80 km–2 Mm with prograde/inclined/
retrograde orbits, unreachable sites, mode/ownership guards, executor faults,
and finite NERV burns against the independent physics model. The burn test
stops at maneuver completion; it does not certify atmospheric entry or landing.
Run with the existing local offline framework:

```sh
python3 -m unittest discover -s tests -p 'test_deorbit*.py'
tools/test-pos audit
python3 tools/check-kos-bindings
tools/test-pos all
```

For the one-shot KSP run, use the normal medium logger setting (or high for more
detail). Check the selected runway, planned/achieved periapsis, entry speed and
angle, downrange/crossrange, fuel, and any first failure event. Atmospheric range
and high-energy heating remain KSP validation, as do FAR attitude authority and
landing accuracy.

## Integration validation

The combined implementation requires the targeted real-source deorbit tests,
source audit, protected-binding gate, and full offline suite before handoff.
KSP remains the authority for atmospheric range, heating and landing behavior.
