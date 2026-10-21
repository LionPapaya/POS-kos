"""Standalone regressions for the kOS built-in binding audit."""

from pathlib import Path
import tempfile
import unittest

from tools.pos_sim.source_audit import (
    BUILTIN_BOUND_VARIABLES,
    BUILTIN_FUNCTIONS,
    audit_file,
)


ROOT = Path(__file__).resolve().parents[1]
SCRIPT_ROOT = ROOT / "Script"


def findings_for(source):
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "bindings.ks"
        path.write_text(source, encoding="utf-8")
        return audit_file(path, Path(directory))


def collision_findings(findings):
    return [finding for finding in findings if "clobbers" in finding.message]


class BuiltinClobberingAuditTests(unittest.TestCase):
    def test_catalog_covers_the_regression_names(self):
        for name in ("PATH", "WAYPOINT", "CHAR", "TRANSFER"):
            with self.subTest(name=name):
                self.assertIn(name, BUILTIN_FUNCTIONS)
        self.assertIn("VESSEL", BUILTIN_FUNCTIONS | BUILTIN_BOUND_VARIABLES)

    def test_finds_builtin_collisions_across_binding_positions(self):
        source = """function path { }
function collision_positions {
    parameter first_value, char, last_value.
    parameter first_parameter, transfer, last_parameter.
    for vessel in all_vessels { print vessel:name. }
    local first_local is 1, waypoint is 2, last_local is 3.
    global first_global to 1, path to 2.
    declare local first_declared is 1, transfer is 2.
    set keep_value to 1, path to 2.
    lock char to 1.
}
"""
        findings = collision_findings(findings_for(source))
        actual = [(finding.line, finding.message) for finding in findings]
        self.assertEqual(actual, [
            (1, "variable name 'path' clobbers kOS built-in function 'PATH'"),
            (3, "variable name 'char' clobbers kOS built-in function 'CHAR'"),
            (4, "variable name 'transfer' clobbers kOS built-in function 'TRANSFER'"),
            (5, "variable name 'vessel' clobbers kOS built-in function 'VESSEL'"),
            (6, "variable name 'waypoint' clobbers kOS built-in function 'WAYPOINT'"),
            (7, "variable name 'path' clobbers kOS built-in function 'PATH'"),
            (8, "variable name 'transfer' clobbers kOS built-in function 'TRANSFER'"),
            (9, "variable name 'path' clobbers kOS built-in function 'PATH'"),
            (10, "variable name 'char' clobbers kOS built-in function 'CHAR'"),
        ])

    def test_allows_supported_set_and_lock_bindings(self):
        source = """set target to vessel("Target").
set shipname to "test craft".
lock throttle to 0.5.
lock steering to heading(90, 0).
lock wheelthrottle to 0.
"""
        self.assertEqual(collision_findings(findings_for(source)), [])

    def test_ignores_comments_strings_member_suffixes_and_noncolliding_names(self):
        source = '''// local path is should not be treated as a binding.
function safe_names {
    local path_label is "PATH".
    local waypoint_text is "WAYPOINT and CHAR".
    local vessel_status is ship:vessel.
    local transfer_count is 1.
    print char("x").
    print ship:velocity + ship:altitude.
}
'''
        self.assertEqual(collision_findings(findings_for(source)), [])

    def test_current_production_renames_have_no_builtin_bindings(self):
        changed_sources = {
            "Libraries/Poseidon_SSTO/ascent_recovery_gui.ks": "handoff_state",
            "Libraries/Poseidon_SSTO/gui.ks": "listed_vessel",
            "Libraries/lib_math.ks": "input_character",
            "Poseidon_SSTO/Poseidon_SSTO_Docking.ks": "bounded_vessel",
            "Poseidon_SSTO/Poseidon_SSTO_Orbit_Main.ks": "aed_target_site",
        }
        for relative_path, renamed_identifier in changed_sources.items():
            path = SCRIPT_ROOT / relative_path
            with self.subTest(path=relative_path):
                source = path.read_text(encoding="utf-8-sig")
                self.assertIn(renamed_identifier, source)
                findings = audit_file(path, SCRIPT_ROOT)
                self.assertEqual(collision_findings(findings), [], path)


if __name__ == "__main__":
    unittest.main()
