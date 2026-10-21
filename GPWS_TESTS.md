# GPWS_tests: terrain avoidance and departure routing

This branch addresses the flight 380 departure accident: ascent alignment began
about 6 seconds after liftoff at 34 m radar altitude; a roughly 48-degree bank
removed the climb. GPWS activated at 230 m/s, -11 m/s vertical speed, and 47 degrees
of bank. Roll-out and descent arrest took approximately 3 and 4 seconds. The heavy
aircraft could not attain the requested 20-degree AoA. Changing the requested AoA
or delaying every departure turn is not the intended solution.

## Flight behavior

- Before engine spool/brake release, sample candidate departure corridors from
  an early estimated liftoff position. Search runway-relative offsets of 0,
  +/-5, +/-15, +/-30, +/-60 and +/-90 degrees, plus the bounded orbital course.
  Each candidate turns toward its departure course and then toward the orbital
  course after 6 km. Check 18 km, retain 1 km waypoints, and select the clear
  candidate with the smallest orbital-course penalty. Hold takeoff if none of
  these candidates passes, or if runway/takeoff geometry is unavailable.
- Keep the existing 30 m transition into early alignment. Seed its AoA smoother
  from the measured takeoff AoA. Limit the final normal alignment pitch command
  to 20 degrees nose up, including the AoA steering output, and use configured
  AoA rather than feeding measured AoA back into bank compensation. Reduce bank
  continuously when climb weakens and restore full power when climb needs it. Resume
  normal acceleration as soon as the checked dogleg and alignment permit it;
  remaining straight verification waypoints do not impose a speed hold.
- Keep the short 2/4/7-second GPWS probes, and add curved terrain corridors with
  a nominal 35-second range, at least 15 km and at most 45 km. Probe the centre
  and both corridor edges every 250 m. Width starts at 60 m and grows with range.
- Model acceleration, initial-bank roll-out and a 7-second sensing/response
  delay. Limit predicted turn authority to 15 degrees of bank. Credit only
  measured climb, capped at 10 m/s, and reserve sink while turning. Requested
  20-degree AoA does not imply achieved climb authority.
- Check small left/right changes first, then larger offsets up to 60 degrees.
  A candidate must clear the sampled corridor by an additional 50 m before it
  can authorize a turn. Command at most 25 degrees of escape bank. Interleave
  straight-ahead scans with candidate checks, publish results individually,
  recheck the selected side, and reject results older than 4 seconds or from a
  significantly different track. Use the existing wings-level pull-up when no
  current lateral candidate passes. A clear lateral exit can release in level
  flight after the stability dwell.

During ascent alignment, upset pull-up recovery also limits pitch to 20 degrees
and releases only after 2 continuous seconds of forward flight: at least 110 m/s,
0–25 degrees pitch, at most 30 degrees bank, safe AoA and low AoA rate. The initial
zero-AoA unloading stage is unchanged. GPWS terrain escape retains full pull-up
authority; the alignment pitch cap must not suppress terrain avoidance.
Heading guidance, waypoint tracking and the speed-build handoff are unchanged.

All tuning is in `AVES["Ascent"]` and `AVES["Envelope"]["Terrain"]["Navigation"]`.
The shared path math is in `terrain_navigation.ks`. The departure climb gradient
is an explicit conservative assumption (2.5%, reduced above the reference mass),
not a calibrated FAR performance guarantee. Preflight logs label its model as
unvalidated. A finite candidate search can hold a departure even if some other
route exists. Discrete probes can miss terrain between samples; KSP terrain
queries also do not represent buildings or other vessels.

## Telemetry

Schema 28 retains the schema 27 fields and adds `alignment_pitch_limit` alongside
the actual pitch and final steering command, so a flight can distinguish the
configured limit from tracking overshoot or GPWS override. Schema 27 appended long-range margin, time to conflict, threat position/height,
scan age/range, escape mode/course/offset/margin/validity, departure route
progress, and alignment commands. Low mode records plan/waypoint and escape
state events; medium/high retain their existing sample cadence. Planning and
trajectory calculations never call the production flight logger. Model
parameters and preflight waypoint coordinates are recorded separately for later
comparison with a KSP flight.

## Offline evidence and KSP validation

Run `tools/test-pos audit`, then
`python3 -m unittest discover -s tests -p 'test_terrain_navigation.py'`, and
`tools/test-pos all`. The offline framework and older tests are locally ignored
in this repository; the new regression file is included explicitly.

The regressions execute real `.ks` functions in the normal interpreters at
2,000 IPU / 0.02 s. They cover a 5 km mountain wall beyond seven seconds, a clear
small left escape with the right side blocked, an unavoidable near wall,
corridor-edge obstacles, ocean clearance, a mass penalty, waypoint advancement,
climb-preserving turn commands, stale escapes, recovery release, and logger
contracts. A coupled source-loop scenario integrates roll and Cartesian motion
independently with **no positive climb authority** and requires lateral
avoidance to pass. It is a coarse horizontal-avoidance test, not a FAR flight
reconstruction or evidence that the exact flight 380 is now recoverable.

Local evidence is written under `tools/pos_sim/results/` and must not be
committed. In the wall scenario, GPWS detected the threat at about 0.96 s,
selected a -5-degree escape at 2.06 s, and cleared the wall without positive
climb. Inspect `gpws_wall_trace.csv`, `gpws_wall_events.csv` and
`gpws_wall_report.json`. Full-suite and Minmus POS5 evidence use the `gpws_`
prefix in that directory.

The local source-fingerprint suite already expects functions absent from the
unchanged main-branch logger (26 errors and one failed assertion when tested
against that logger). Report that separately; do not hide it by weakening its
assertions or claiming the complete suite is green.

For the first KSP/FAR check, use Area-15 runway 31 with the flight 380 mass and
payload. Verify the selected departure route before/through takeoff, pitch and
climb continuity during the early turn, scan duration/age, actual versus
commanded bank/pitch, clearance through the detour, and the final release back
to nominal ascent. Repeat with left/right terrain constraints and no clear
candidate. Validate heavy-aircraft lift and roll authority in KSP; aerodynamic
moments, control surfaces and other omitted dynamics cannot be certified by
these offline tests.

## Manual recording and rejected-route diagnostics

On the main POS screen, select **Manual Flight Logging** from the program menu.
Recording starts in **OFF**; select **CSS** in the DAP menu for the existing
assisted controls. AUTO is unavailable in this recording mode. Engines, brakes,
gear and throttle remain pilot operated. OFF records without running DAP control
updates; CSS retains its normal envelope/terrain protection. No departure route
approval is required. Select **Stop manual recording** or another program to end
the recording. Files use the normal `/POS_logs/flight_N/` directory and
`program=manual`. None/low logging is temporarily raised to medium (one sample
per second); an existing high setting is retained. The previous logging setting
is restored on exit.

Departure checks now return diagnostic summaries to the caller for every tested
candidate, including rejected ones. `departure_candidate` events contain initial
course/offset, final course, turn distance, pass/fail, worst clearance margin,
distance to the worst sample, predicted bottom altitude, required clearance,
terrain height/position, first conflict time and the maximum climb gradient
needed across the sampled path. A `departure_best_rejected` event identifies the
closest-to-passing rejected candidate. These events are available in low,
medium and high logging modes. Route scoring, assumed climb performance and
acceptance criteria are unchanged; the path routines perform no logging or I/O.
