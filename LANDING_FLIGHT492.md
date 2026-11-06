# Island 09: runway-aware flare revision

Flight 492's first landing attempt floated over Island 09 without confirmed
wheel contact and then went around. The full flight was not observed to a
terminal outcome: it was reset for the next revision. Raw companion logs are
preserved in `C:/Users/Leon/POS-kos-flight-evidence/flight_492/`. The archive
importer skill remains unavailable; these are raw files, not an imported
roll/stop calibration record.

## Why it floated

The height-only flare progressively requested approximately -0.7 m/s while
still above the runway. Removing the position override fixed the earlier
dangerous steepening, but also exposed this excessive float. Removing the
10 m airborne brake/throttle cutoff preserved airspeed; it did not correct
touchdown position. The envelope remained normal in landing mode throughout
the float. At the runway end the aircraft was still airborne, and heading
guidance toward the runway-end point could then turn back toward a point
behind it. Cross-track drift also grew during the wings-level flare.

## Revised control

- Use runway position, height and closure speed to target contact in the
  early runway (350 m or 30% of runway length, whichever is smaller).
- Limit requested sink to 7 m/s and to a pull-up bound using remaining
  response delay and the lesser of fresh FAR authority and the configured
  2 m/s² tracking acceleration. Retain a nominal 2 m/s terminal sink until
  confirmed contact, rather than a near-level float above contact height.
- Keep the before-threshold clearance floor, existing alignment/FAR/clearance
  checks, the scoped 110 m/s gate and speed support until contact.
- Correct centreline drift with bounded heading and bank commands. Continue
  along the runway heading instead of chasing the runway end after passing it.
- Escape if still airborne beyond the touchdown zone, reserving 500 m for
  rollout. These tuning margins still require in-game verification.

Flare-entry telemetry records the touchdown aim, time remaining and safe-sink
bound. Escape telemetry includes along-track and cross-track position.

## Why the earlier final turned away

In flight 492 the earlier diversion decision occurred near UT 17888323.5.
The aircraft was about 4.58 km above runway altitude, 15.7 km before the
threshold, at 136 m/s and descending about 51 m/s. The following final entry
was near UT 17888532.3, about 4.60 km high, at 121 m/s and climbing about
1 m/s. The extra circuit had not materially improved the height at final entry.

The old gate used excess energy/profile thresholds without checking available
descent distance. Using recorded closure speed and a five-second time reserve,
the approximate average sinks required to reach preflare were 38 and 34 m/s,
both within the normal final controller's 45 m/s descent bound. This supports
the possibility of continuing the earlier approach; it does not prove the
unflown outcome, including lateral capture and subsequent pull-up.

The new gate checks that descent feasibility before ordering another hold.
`terminal_final_descent_plan` records the estimate at final entry, and holding
events record required sink and capture time when a diversion is necessary.

## Current validation state

The changed scripts compiled with the installed kOS compiler. No broad offline
test suite was run for this revision, following the user's preference for KSP
testing. POS TEAM TEST was reloaded with Island 09 forced before loading.
Flight 493 confirms the target and high logging. Its landing outcome is
pending; this document does not claim a successful landing with the revision.
