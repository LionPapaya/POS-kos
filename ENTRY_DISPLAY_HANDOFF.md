# Entry chart selection and protection handback

Implemented in this checkout; not copied into the live KSP archive.

## Static entry charts

`tools/build_entry_charts.py` generates 170 PNGs (about 1.4 MB including the
manifest) and `entry_chart_catalog.ks`. All images use the existing 640 by 280
layout and calibrated plot rectangle: x=52..620, y=24..232. Each image contains
its own matching axis labels, grid, historical nominal line and reference band.
The historical reference is clipped at its data coverage; it is never
extrapolated into higher energies.

On the first converged entry plan, `reentry_select_entry_charts` samples the
already-computed trajectory at up to 16 points. It intersects the segments
with the five energy phases, adds range padding, and chooses the smallest
catalog rectangle containing each phase's predicted range. Page 1 also gets
an energy ceiling covering the start of the prediction and the current
vehicle. Page 5 can now extend below 100 km energy height. Pages not covered
by the prediction retain a conservative zero-range window.

Exactly five choices are cached for the entry target. Predictive bank updates
and 2 Hz GUI refreshes do not run selection, generate images, create widgets,
or rescale the charts. A changed entry target explicitly clears the selection
so its next converged prediction can choose another five. The existing 16
prediction markers still update and map through the selected PNG's bounds.
Original backgrounds remain available until a usable plan exists.

Catalog coverage is finite: first-page ceilings reach 1,000 km energy height
and broad fallback range reaches 2,000 km. Selection records `fits=False` and
the GUI labels an exceeded catalog. A later trajectory can still depart from
its initial prediction; this implementation intentionally does not continually
reselect backgrounds. Runtime rendering and instruction cost need KSP checks.

Regenerate assets with `py -3 tools/build_entry_charts.py` (requires Pillow).
Keep the PNGs, JSON manifest and generated kOS catalog together.

## Steering smoothing

The resolved absolute AoA baseline now passes through `changeRate`, using the
same configured pitch-rate schedule as AoA: 4 degrees/second above TEAMAltitude
and 9 degrees/second below it. The smoothed baseline is used in attitude
composition every AoA update. Baseline and handback steps cap elapsed credit
at 0.5 seconds so a slow solve cannot authorize a large catch-up jump.
The terminal route explicitly marks its baseline
as present, including a legitimate zero-degree command. Older callers retain
their existing nonzero-override / zero-means-prograde convention.

While upset or terrain protection owns steering, it records its actual pitch,
heading and bank command. Protection itself retains immediate authority. On
release, the normal AoA smoothing state is rebased on that applied command,
and a final attitude handback stage slews pitch, heading and bank toward live
guidance using the existing rate settings. It handles angle wrap, moving
demands, AoA/aerostr/CSS destinations, and a new protection activation during
capture. The dampener completes when the live demand is reached; it has no
fixed timeout that could reintroduce a jump. OFF/vector transitions clear it.

The baseline and AoA have independent rate limits. Their composed normal pitch
can therefore change by more than either individual rate; the final handback
stage separately limits the applied attitude during recovery capture. This
change does not retune the vertical-speed PID, its integrator, or the existing
upset-release thresholds. The next KSP flight should verify those remaining
controller interactions and the successful runway approach/flare.

## Flight evidence and validation

Flight CSV schema 40 adds requested/smoothed baseline, handback/protection
ownership, and raw/applied handback attitude. These columns use the existing
medium/high sampling cadence. Five `entry_chart_selected` events record image
names and bounds once per selection. `protection_handoff_start` and
`protection_handoff_complete` record the control transitions at all enabled
event logging levels. No logger was added to trajectory simulations.

Validation completed:

- Installed kOS compiler checks, including all changed flight/GUI libraries
  and the generated catalog, with builtin clobbering disabled.
- Three Python tests verify every asset's dimensions and exact manifest/kOS
  bounds, cached selection wiring, and logger/control integration.
- `tests/test_entry_handoff.js` executes translated production helper bodies
  in V8: zero crossings, negative elapsed time, heading/bank wrap, moving
  commands, irregular control intervals, handback completion, protection
  reactivation, AoA/aerostr/CSS return, OFF ownership release, sparse trajectory
  intersections, catalog overflow, one-time selection and explicit reset.
- A geometry replay of 3,024 flight-525 entry samples confirms the catalog can
  contain that entire measured entry. It uses the recorded path as the input
  geometry, not the unavailable original prediction trace, so it is not proof
  that an initial prediction will enclose every subsequent real trajectory.
- All six GUI safety tests pass. Updated two stale assertions to compare
  extracted dialogs at their production home and verify that normal POS
  startup does not enter GUI_TEST. No launcher or dialog implementation changed.
- `git diff --check` passes.

The source-translation tests are restricted helper tests, not a kOS scheduler
or aerodynamic simulation. The `tools/pos_sim/kos_runtime.py`, `tools/test-pos`
and `tools/check-kos-bindings` framework files are absent from this worktree
(and the inspected main checkout), so the project simulation/audit suite could
not run. KSP/FAR and Unity validation remains required; no live flight was run.

With Node installed, run `node tests/test_entry_handoff.js`; optionally pass a
JSON array of recorded `[energy_height_metres, range_metres]` pairs for the
geometry replay. This session executed that same test runner in the tool V8
runtime because Node is not on this machine's PATH. Run the asset checks with
`py -3 -m unittest discover -s tests -p test_entry_chart_assets.py -v`.
