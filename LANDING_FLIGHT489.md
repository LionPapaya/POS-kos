# Flight 489 landing fix

Source evidence: the latest run in the active KSP installation,
`C:/Users/Leon/Documents/stock_/Ships/Script/POS_logs/flight_489/`.
The companion CSVs were copied unchanged to
`C:/Users/Leon/POS-kos-flight-evidence/flight_489/`.

## Diagnosis

- UT 17890124.679: `unstable_final`. The aircraft reached the threshold about
  6,581 m above the runway at 202 m/s. This pass needed a new approach; a flare
  change cannot make that geometry land safely.
- UT 17890525.259: the next approach entered flare at 34.4 m with measured
  sink -5.15 m/s. The height-based flare requested a progressively shallower
  sink, but the final selection `max(corridor, min(flare, position))` overrode
  it with the touchdown-position request, approximately -6 m/s. The aircraft
  lowered its pitch and increased sink. At UT 17890528.159 clearance protection
  requested a go-around at 16.4 m and -7.73 m/s.
- UT 17890949.539: the third approach entered flare at 34.9 m with only
  -1.87 m/s sink. Position guidance immediately replaced the flare request
  with -7 m/s. At UT 17890954.019 clearance protection requested another
  go-around at 14.9 m and -7.94 m/s. The log subsequently reaches zero liquid
  fuel and ends airborne; there is no completed landing in this recording.

## Change

The selected landing descent now retains the height-based flare request.
Before the threshold, the existing corridor may request a shallower descent
to protect runway clearance. The position request remains telemetry and
cannot demand a steeper descent during flare. Over the runway the flare
continues toward its existing negative touchdown sink target.

The previously unused holding route now receives excess-energy arrivals.
Once speed is at most 350 m/s, clearance is at least 1,500 m, and the direct
final has more than 1,000 m of surplus energy height and 500 m of excess
altitude, TEAM diverts into its holding circuit before reaching the threshold.
The recorded first approach reaches that gate about 10.9 km before the
threshold. Supersonic entry retains its existing descent until terminal turns
are practical. This does not attempt a tight circle at entry speed.

Hold release evaluates direct-final energy independently of the distance in
the remaining hold, so adding a lap cannot immediately authorize its own exit.
The hold exits when the direct margin is at most 250 m and excess profile
height is at most 500 m, or when terrain clearance falls below the holding
floor. Its radius now respects the configured circuit speed and planning bank.
Speed-floor and recovery thrust remain available; a speculative holding lap's
energy deficit alone does not add power while direct-final energy is excessive.
Holding is adaptive, rather than forcing exactly one or two complete laps.

Clearance, stale FAR force, alignment and airspeed escape checks remain active.
`terminal_energy_hold` records holding entry/exit and `terminal_hold_lap`
records completed circuits. Actual turning performance and the number of
circuits needed must be verified in KSP.

The installed game already included the earlier pitch damping, supporting
trim, preflare pull-up scheduling and go-around circuit-rejoin improvements.
Those changes were carried into this checkout to preserve the actual flight
489 baseline. They are prerequisites already present during this flight,
not evidence that this new flare fix has flown successfully.

The logger adds one `landing_flare_command` event per flare at low/medium/high
logging, recording the height-based and final selected requests alongside the
position/corridor requests. Existing medium/high CSV samples already contain
the actual landing request, sink, trim, position/corridor values and clearance
margin. No predictor logs or new per-tick events were added.

## KSP verification

1. Restart the kOS flight program from a fresh CPU boot so RUNONCEPATH loads
   the updated libraries. Reload a save before TEAM/landing, with the original
   fuel state, rather than resuming the exhausted final circuit.
2. Run POS3 normally with high flight logging. A save before the failed flare
   is useful for a focused check; a complete reentry is needed for end-to-end
   fuel and approach validation.
3. On the high arrival, expect `terminal_energy_hold` before the failed
   threshold pass and a holding route instead of a powered go-around. Check
   actual turns, clearance, fuel and the conditions on holding exit.
4. Check that `landing_flare_command.selected_vs` is at least `flare_vs`
   (a less negative value means a shallower descent). During flare,
   `landing_target_vs` should shallow as height decreases instead of dropping
   toward the position request. Confirm actual sink follows it, the wheels
   contact the runway, and rollout ends stopped.
5. Retain both new CSVs. If an escape remains, inspect its reason and the
   clearance/FAR/airspeed samples rather than disabling go-around protection.

Offline scalar checks and recorded-input replay validate command selection;
they do not predict the resulting closed-loop FAR trajectory. Final landing
and runway-distance margins require KSP verification.

Validation: `tests/test_landing_flare_policy.cjs` passes four groups, including
the real height-based flare, both recorded flare windows, unchanged clearance
protection and energy-hold entry/exit policy. The installed `kOS.Safe.dll`
compiler accepts all four changed scripts with safe function-name protection
enabled (`tests/check_installed_kos_compile.ps1`). This compiler check does
not supply KSP binding managers or simulate a flight.

The required `tools/test-pos audit`, `tools/test-pos all` and
`tools/check-kos-bindings` cannot run because `tools/` is absent. Existing
Python tests also have missing simulator imports and two unrelated GUI test
failures against the current baseline. No full-suite pass is claimed.

The locally referenced `pos-roll-archive` skill and its importer were not
available on this Windows installation. Raw companion logs are preserved,
but no standardized roll/stop evidence import or model refit was performed.

The four updated scripts were copied into the active `stock_` KSP script
archive, retaining its high logging setting. Previous files and SHA-256
checksums are in
`C:/Users/Leon/POS-kos-sync-backups/flight489-landing-20261105-212022/`.
