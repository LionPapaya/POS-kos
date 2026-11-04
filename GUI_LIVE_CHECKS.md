# Live GUI inspection log

2026-11-04, KSP 1920x1080, synthetic display-only harness. No quicksave reload or maneuver.

- Main menu: opens, selector returns. DAP caption wraps DA/P and long vacuum landing option wraps in popup. Fix delegated.
- Takeoff: opens with synthetic V1 and VR markers and values. Footer renders literal `\n` between downrange and elapsed time. Fix delegated.
- V1 unavailable: opens and shows unavailable text with no V1 tick. Same footer issue.
- Ascent 1: opens, vehicle and target markers appear at approximately 900 m/s / 15 km and 1200 m/s / 20 km, matching fixture. Same footer issue. No flight controller used.

All remain to be rechecked after pending GUI edits; these observations are not exhaustive input or performance verification.
- Ascent 2: synthetic 60 / 75 km cutoff and 15 km remaining displayed; same footer issue. Recheck after layout edits.
- Insertion: synthetic 45-second burn window and orbit targets visible; same footer issue. Recheck after edits.
- Entry 1: synthetic chart and central marker render. Preview initially covered selector Back; moved test selector aside for further inspection. Flight rows were intentionally unpopulated.
- Entry 2: midpoint marker and chart render; selector remains usable with side placement. Flight data and predictions are not populated by this fixture.
- Retest after Sol layout changes: main menu DAP and both long vacuum landing entries fit on one line. Takeoff overview has the correct line break and is shorter; Readouts button displays the flight rows. The footer was not visible on the Readouts page in this synthetic test and needs investigation. Overview/Readouts selected-state contrast also needs checking.
- Follow-up: the Readouts footer appeared after the interface settled, with both lines visible. Initial missing footer may be asynchronous layout/event delay rather than persistent clipping; retest rapid switching.
- Entry 3, 4 and 5: synthetic midpoint markers and page-specific axes/backgrounds render without visible clipping. Planning/waiting only; live prediction and data remain untested.
- Entry fallback: basic fallback heading and explanation visible on page 3 chart. Predictive/frozen/converged modes remain untested.
- Revised takeoff: Overview and Readouts both show two-line footer in the same position; bracket/highlight identifies selected page. Synthetic values only; needs remaining ascent states and repeated switching.
- RSVP inputs: opened Body and Vessel target modes, switched orbit type to elliptical and accepted; harness returned without dispatch. Target list had at least one vessel; empty-list behavior not exercised. Dialog has no Cancel control.
- OM mode: opens and accepts Circularize in harness. Fixed 300px height leaves large empty area and long option labels wrap; no cancel. Other selections not yet exercised.
- Revised RSVP: Cancel button rendered and returned to selector without dispatch in harness. Production early return was source-reviewed, not executed.
- Revised OM mode: compact 500x190 panel opens; visible long options fit without wrapping and Circularize selection returns in harness. Scrolled bottom options still need checking.
- Baseline benchmark, IPU 2000 boot setting: 12 synthetic updates took 0.22 s UT (takeoff), 0.20 s (ascent 1), 0.18 s (ascent 2), 0.20 s (insertion); each crossed physics ticks so opcode delta unavailable. These are quantized simulated durations under this session, not wall-clock CPU or Unity render times. Baseline loop: 205 same-tick opcodes. Compare only under same conditions.

- Ascent hidden-readouts optimization, same passive benchmark / 12 updates: Takeoff 0.22 s UT, Ascent 1 0.18 s, Ascent 2 0.16 s, Insertion 0.18 s; prior 0.22 / 0.20 / 0.18 / 0.20 s. These are quantized simulation times, not wall-clock or Unity rendering measurements; all crossed physics ticks. No error observed.

- Updated synthetic Ascent 1 preview: after switching Overview to Readouts, placeholders appeared briefly and then values populated on a subsequent refresh; no terminal error. The 1 m synthetic increments are rounded in the displayed km value, so a quick visual check does not establish the precise update interval or changing value. Other one-shot ascent fixtures still leave Readouts blank in the harness after switching.

- Legacy Periapsis input: 400x300 window contains substantial unused space and only OK, with no Cancel. The current repository search found only the test harness calling this helper. Blank input returned to the harness; no production operation was run.

- Revised rendezvous target: live passive fixture displayed both buttons; clicking Select a vessel first with None left the dialog open; Cancel returned to the selector without dispatch. Production caller and actual vessel selection were not exercised.

- TEAM AoA, CSS and aero: synthetic panels rendered with respective pitch values 12, 5 and 7 degrees; CSS/aero show AoA, bank and pitch bias as n/a. Envelope/terrain text wraps onto a second line. Preview returned through selector. This fixture samples once, not a live update or control test.
