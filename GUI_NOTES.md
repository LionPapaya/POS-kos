# POS GUI notes

## Earlier live observations (retained; not verified this session)

`Script/GUI_TEST.ks` is called first by POS.ks (the existing temporary entry is preserved). The selector now has an Exit button. A new idle loop immediately after the call prevents Exit from falling through into flight initialization. To restore normal startup, remove the temporary comment, RUNPATH call and following idle loop together, then reboot. The KSP archive at `Ships/Script` is separate from this worktree; no live files were copied or overwritten in this work. Never reload the quicksave for this workflow.

The ascent constructor blocks until confirmation or `step = "end"`. Its callbacks expect a `dap` lexicon even when the display is tested separately. The selector supplies dummy state and explicit synthetic samples; it never calls the live collector. Ascent setup lets you inspect validation and confirm into the synthetic ascent-1 layout. Other ascent presets bypass setup confirmation.

On a 1920 x 1080 display, the ascent setup opened centered. Confirming expanded the window down beyond the bottom edge, hiding lower contents. The DAP popup stayed open across the transition and uses the stock popup appearance. These observations need retesting after GUI changes.

## Code conventions and performance

- GUI callbacks can mutate shared flight state. A test harness must stub or isolate that state and avoid invoking flight scripts or control setup.
- Existing ascent and return displays use dark background images, restrained pale labels, small muted captions, and common `ascent_display_label_style` typography. Their chart backgrounds and markers use calibrated pixel positions; verify at actual game resolution before changing dimensions.
- `RUNONCEPATH` caches library execution within a session; a CPU reboot is needed to exercise updated library code reliably. Constructors may block waiting for user input, so arrange test cases around their actual lifecycle.
- GUI updates consume the same limited kOS instruction budget as guidance. Avoid rebuilding widgets or assigning identical text and styles every tick; cache changes and rate-limit display-only work without slowing control loops. Measure with flight logs under representative conditions before claiming an improvement.
- Unity layout collapses adjacent vertical margins using the maximum; the ascent marker positioning code compensates for negative margins. Do not simplify it without checking chart overlays in KSP.

Retest: with the shared style and initial Y=40, the expanded ascent panel fits vertically at 1920 x 1080. The harness leaves its flight values empty, so chart data and other pages remain unverified. The GUI can be dragged; default placement remains relevant when it first expands.


## 2026-11-04 Sol review and display-only selector

All work in this session was performed by Sol without agents, KSP UI, deployment, save loading, or archive writes. Earlier observations above are historical, not new validation. All existing style edits and the temporary POS entry were retained.

### Changes reviewed / made

- Shared window skin is applied before widgets are created. The skin and state suffixes in `gui_style.ks` are documented kOS APIs. Added the toggle skin and hover/active/focused ON states so minimize controls and selected menu items receive the palette consistently. Reference: [Skin](https://ksp-kos.github.io/KOS_DOC/structures/gui_widgets/skin.html), [Style](https://ksp-kos.github.io/KOS/structures/gui_widgets/style.html).
- Fixed `deorbit_help` width from 780 to 640 inside the 680px return window. Preserved ascent Y=40, the main-menu width/title changes, shared styles on the mission dialogs, and the existing TEAM/route 0.5-second display throttles. No measured performance claim is made; throttle time is simulation UT, not wall time.
- Moved the existing `pos_om_catalog`, `pos_om_inputs`, and `vacuum_target_input` definitions into `gui_dialogs.ks`. Their production callers import it; the harness imports the same definitions. Offline checks compare their logic against HEAD (allowing the pre-existing style call). No planner or flight implementation was copied into the harness.
- The harness imports `gui.ks` and `gui_dialogs.ks` only. Transitive imports are `gui_style.ks`, `ascent_gui.ks`, `return_gui.ks`, `ascent_recovery_gui.ks`, and `entry_nominal_profile.ks`. These files have passive top-level definitions/data. `gui.ks` also defines live helpers; the harness does not invoke those helpers. This is an audited call boundary, not a general-purpose kOS security sandbox.
- Main-menu program changes only change dummy `main_step`; there is no dispatcher. Its DAP callback is replaced before yielding to UI events with a dummy lexicon update. Ascent DAP updates also write only to the dummy lexicon. The real DAP/control libraries are never imported.
- All accepted input results are discarded. Even buttons whose original labels say Create maneuver / Plan and execute only complete the input dialog here. No node is created, edited, removed or executed. No locks, actuator commands, logging, file writes, IPU changes, or maneuver solvers are issued by the harness.

### Exact selectable coverage: 50 entries

| Entries | Real functions / coverage | Dependencies and limits |
| --- | --- | --- |
| Main menu (1) | `create_main_gui`; program list, DAP popup, hidden logging-stop control | Dummy state; DAP callback substituted. No program or logging dispatch. |
| Ascent setup (1) | `create_assent_gui`; orbit inputs, same-body target list, validation, minimize/X, confirmation | Reads current atmosphere height and vessel list. Confirmation shows a synthetic ascent-1 sample. X skips sample rendering. |
| Takeoff; V1 unavailable; Ascent 1; Ascent 2; Insertion; Finished; Open trajectory; Off chart (8) | `create_assent_gui` + `update_assent_gui(sample)` and hero/takeoff renderers | Explicit fixture AVES and sample lexicons; no `ascent_display_collect`, initialization, guidance, or live data polling. Covers all four nominal pages and selected warning/visibility branches, not every numeric boundary. Recovery widgets are constructed but remain hidden. |
| Return structure (1) | `create_reentry_gui` in a separately owned styled parent | Structural empty return panel, not live setup. No runway selector, DAP/mode setup, or automatic target selection. |
| Entry 1..5; Entry fallback (6) | `return_entry_page` + `return_render_entry`; fallback uses page 3 | Midpoint energy/range synthetic vehicle marker; no prediction path supplied. Covers all five chart backgrounds and basic fallback text. No predictive candidates, frozen/converged state, or sampled path coverage. |
| RSVP inputs; OM mode; Rendezvous target; Periapsis; Circularisation; Apoapsis; Inclination (7) | `get_inputs_rsvp`, `get_om_mode`, `get_rendezvous_target`, `get_inputs_Periapsis`, `get_inputs_circliurisation`, `get_inputs_Apoapsis`, `get_inputs_Inclination` | Reads bodies/vessels for target menus; local `remove_spaces` formatter; catalog supplies OM mode options. Original spelling and button labels retained. No target is assigned to the vessel. |
| PDI coordinates (1) | `vacuum_target_input("ASK","ASK")` | Numeric coordinate validation, valid acceptance, Cancel and invalid-message paths are available for manual inspection. No site planning or PDI executive load. |
| TEAM AoA; TEAM CSS; TEAM aero (3) | `update_team_dap_gui` | Synthetic DAP command/envelope/throttle values exercise all three command-output sources. Timer reset per opening; one display update only. |
| OM command forms (22) | `pos_om_inputs(command)` for each catalog entry below | Actual catalog-driven modes, fields, notes, numeric validation, acceptance/Cancel. Target text reads current map target if any, otherwise absence message. Mode choices remain selectable within each form. No planner invocation. |

The 22 catalog entries are: Circularize; Change apoapsis; Change periapsis; Change inclination; Change eccentricity; Change LAN; Change periapsis and apoapsis; Change semimajor axis; Resonant orbit; Change argument of periapsis; Return from current moon; Capture at current body; Match target plane; Match target velocity; Intercept at chosen time; Fine tune closest approach; Hohmann transfer to target; Lowest delta-v intercept; Transfer window search 1; Transfer window search 2; Hohmann orbit change (two burns); RCS apsis correction. The catalog populates the selector dynamically so new forms appear automatically; update the count/checks and review safety when changing it.

### Explicit exclusions / remaining risks

- `create_reentry_display` and `update_reentry_gui` are deliberately bypassed: live telemetry, automatic runway selection, Trajectories and navigation dependencies. Full return setup therefore has source review only, including the width fix.
- Return TEAM / final / rollout renderers need runway geometry, navigation functions and/or live stopping observations. Their final/rollout assets exist but these pages are not selectable here.
- Recovery decision/map/table/handoff states are not rendered; only their hidden widgets are constructed by ascent. No recovery collector or handoff tick is called.
- Terminal-route debug panel needs route/runway helpers and live route state; excluded. TEAM output panel is covered separately.
- `pos_om_review_node`, `pos_om_rcs_review`, and `vacuum_approve_node` are excluded. RCS review contains actual execution after confirmation; node reviews read/modify live node state or use fingerprints/logging. Do not test these by loading their live libraries.
- `vacuum_ascent_target_input` remains in a mixed control-support module, with launch-heading/navigation dependencies; excluded. Docking control, aerobrake, vacuum-ascent status and PDI status panels are embedded in flight entry scripts; their style edits were source-reviewed only. Do not run those scripts for screenshots.
- Fresh idle CPU required: the harness refuses existing `dap`, `main_step` or `AVES`, then idles without changing controls. This guard cannot detect unrelated programs or other CPUs. It does not stop or release controls held elsewhere. Do not use it alongside flight software. Test globals remain after Exit; reboot before any normal POS session or harness restart. RUNONCEPATH caches definitions.
- Selector buttons are disabled during modal calls. Finish those with their own OK/Cancel/X; the selector Back button is available for persistent previews. Invalid ascent inputs may need adjustment above the current body's atmosphere. Target lists reflect the current scene and may be empty. RemoteTech signal delay can affect UI events.
- Owned persistent previews and the selector are disposed. Legacy modal dialogs (including PDI) hide their windows internally and expose no handle; repeated openings can retain hidden widgets until CPU reboot. No blanket CLEARGUIS is used, to avoid deleting unrelated windows.
- Ascent/return chart geometry, expanded height, popup behavior, text clipping, small-screen placement, font readability, event timing and GUI suffix compatibility with the installed kOS version still need runtime inspection. No KSP renderer or kOS compiler was run here; synthetic page availability is implemented coverage, not proof of visual correctness.

### Run instructions and verification

1. Use this checkout as the source. No live game file has been modified. Any later deployment should go to a separate disposable test archive after checking local differences; this task does not deploy files.
2. With the `Script` tree mounted as archive volume `0:` on an idle fresh CPU, run `RUNPATH("0:/GUI_TEST.ks").` Existing POS startup also enters it and stays safely idle after Exit. Do not run normal flight scripts concurrently.
3. Choose an entry, Open, inspect controls and synthetic values. Close persistent previews with the selector's Back button. Finish modal dialogs using their own controls. Reboot to clear all cached definitions and dummy globals after finishing.
4. To restore normal POS startup, remove the temporary three-line entry comment/call/idle guard at the beginning of `POS.ks`, then reboot. Do not remove only the idle guard while leaving the harness call in place.

Offline validation: `py -3 -m unittest discover -s tests -p test_gui_harness.py -v` passes six source-level checks: import/top-level safety boundary, absence of harness control/file commands, unchanged extracted dialog logic, fixture key completeness, catalog/assets, and POS non-fallthrough. `git diff --check` passes. These checks do not execute KerboScript callbacks or Unity layout. Existing `test_deorbit_flow.py` could not import `tools.pos_sim.kos_runtime` (`ModuleNotFoundError: No module named 'tools'`); that runtime is absent from this checkout. No unrelated flight test success is claimed.

Live kOS compiler check: STATUS is a built-in read-only name; even a local variable with that name fails with CLOBBERBUILTINS disabled. Use a unique name for GUI labels.
