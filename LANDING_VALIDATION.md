# Entry and landing validation

This branch changes entry prediction, terminal energy management, preflare/flare,
speed support, centreline tracking and go-around recovery. The flight logger records
prediction start/completion, final-descent feasibility, landing handoff/flare,
escape geometry and final runway outcome.

## Current default

The top-level reentry parameter deliberately forces **Sandy-Island runway 22**, as
requested for the current in-game test. Callers can supply a different request;
edit this parameter or set `force` to false to restore interactive selection.
Flight 501 was started for Sandy-Island 22, but its outcome is not verified here.

## In-game evidence

- Flight 494: user confirmed the Island 09 landing went well.
- Flight 495: KSC 27 landed after a flare-clearance escape before contact.
- Flight 496: KSC 09 landed with no commanded go-around. The 15 m success
  cross-track tolerance marked a stop at 17.2 m as off-runway despite pavement
  being visible. This classification tolerance remains a limitation.
- Flight 497: Kola 20 stopped intact after a flare-clearance go-around. The nominal
  runway altitude was a few metres above observed ground contact; final lateral
  placement was not a clean centreline stop.
- Flight 498: guidance/logging ceased near 60 km; the craft later impacted water.
  The initial unbounded-predictor diagnosis was incomplete.
- Flight 499: the kOS traceback confirmed a missing lexicon key in entry guidance.
  Inconsistent encoded versions of the reversal setting were replaced throughout
  the solver, craft configuration and live guidance by `EG_reversal_degrees`.
- Flight 500: full orbital entry and intact KSC 27 pavement stop, with one logged
  go-around for `sink_arrest_margin`. The first recorded contact was about
  123.5 m/s and -3.2 m/s vertical speed, about 335 m past the threshold. It bounced,
  then established contact near 567 m and stopped about 1,038 m past the threshold,
  at -11.9 m cross-track. Remaining liquid fuel at first contact was about 14 units.
  There were 51 prediction starts and 51 completions; at least the first two
  exceeded the shared live prediction budget and were rejected. A successful
  landing does not establish that entry targeting, fuel reserves or every
  prediction is satisfactory.

Raw logs and backups are stored locally outside this repository in
`C:/Users/Leon/POS-kos-flight-evidence` and `C:/Users/Leon/POS-kos-sync-backups`.
They are not committed. The standardized archive importer was unavailable on
this Windows machine; raw-file preservation is not a standardized import.

## Checks

- `node tests/test_landing_flare_policy.cjs`: five regression groups pass.
  These execute selected production scalar helpers through a small translator;
  they do not simulate KSP/FAR dynamics or the entire control state machine.
- `tests/check_installed_kos_compile.ps1 -KspRoot <installed KSP directory>`:
  compiles all six changed KerboScript files with the installed kOS Safe compiler,
  with builtin clobbering disabled. KSP/mod suffix behavior still needs the game.
- `git diff --check`: checked before publication.
- The documented `tools/test-pos` and `tools/check-kos-bindings` framework is absent
  from this checkout, so those checks could not be run.

Further work should prioritize avoiding the first sink-arrest diversion, fuel
reserve management, early prediction budget usage, runway-height calibration,
touchdown bounce and robust runway-width classification. This PR does not claim
these remaining issues are solved.
