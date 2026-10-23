"""Tests for pure vacuum-ascent guidance executed from the real .ks source."""
import math
from pathlib import Path
import unittest

from tools.pos_sim.kos_runtime import Runtime


ROOT = Path(__file__).resolve().parents[1]
SHARED_GUIDANCE = ROOT / "Script/Libraries/Poseidon_SSTO/inclination_guidance.ks"
GUIDANCE = ROOT / "Script/Libraries/Poseidon_SSTO/vacuum_ascent_guidance.ks"


class VacuumAscentGuidanceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.kos = Runtime(SHARED_GUIDANCE.read_text() + "\n" + GUIDANCE.read_text())
        cls.config = {
            "pitch_start_clearance": 100,
            "prograde_blend_speed": 450,
            "initial_pitch": 75,
            "terminal_pitch": 10,
            "minimum_vertical_speed": 5,
            "vertical_recovery_pitch": 65,
        }

    def test_launch_heading_covers_equatorial_polar_and_retrograde_cases(self):
        heading = lambda inclination, latitude: self.kos.call(
            "vacuum_ascent_launch_heading", inclination, latitude
        )
        self.assertAlmostEqual(heading(0, 0), 90)
        self.assertAlmostEqual(heading(90, 0), 0)
        self.assertAlmostEqual(heading(180, 0), 270)
        self.assertAlmostEqual(heading(30, 20), math.degrees(math.asin(math.cos(math.radians(30)) / math.cos(math.radians(20)))))

    def test_launch_heading_accepts_best_effort_doglegs_and_polar_orbits(self):
        heading = lambda inclination, latitude, northbound=True: self.kos.call(
            "vacuum_ascent_launch_heading", inclination, latitude, northbound
        )
        self.assertAlmostEqual(heading(0, 20), 135)
        self.assertAlmostEqual(heading(0, -20), 45)
        self.assertAlmostEqual(heading(180, 20), 225)
        self.assertAlmostEqual(heading(180, -20), 315)
        self.assertAlmostEqual(heading(90, 90), 0)
        self.assertAlmostEqual(heading(90, -90), 0)
        self.assertAlmostEqual(heading(90, 90, False), 180)
        self.assertTrue(math.isfinite(heading(60, 90)))

    def test_liftoff_pitch_gate_accepts_twenty_degrees_without_vertical_alignment(self):
        ready = lambda measured, required=20: self.kos.call(
            "vacuum_ascent_liftoff_pitch_ready", measured, required
        )
        self.assertFalse(ready(19.99))
        self.assertTrue(ready(20))
        self.assertTrue(ready(45))
        self.assertTrue(ready(0, 0))

    def test_pitch_schedule_protects_clearance_and_vertical_speed_before_acceleration(self):
        target = lambda clearance, vertical, horizontal, apoapsis: self.kos.call(
            "vacuum_ascent_pitch_target", clearance, vertical, horizontal, apoapsis, 15_000, self.config
        )
        self.assertEqual(target(99, 100, 1_000, 15_000), 90)
        self.assertEqual(target(200, 2, 450, 15_000), 65)
        self.assertAlmostEqual(target(200, 20, 0, 0), 75)
        self.assertAlmostEqual(target(200, 20, 450, 0), 10)
        self.assertAlmostEqual(target(200, 20, 0, 15_000), 10)

    def test_circular_speed_is_physical_and_fail_closed_for_invalid_inputs(self):
        speed = self.kos.call("vacuum_ascent_circular_speed", 215_000, 6.5138398e10)
        self.assertAlmostEqual(speed, math.sqrt(6.5138398e10 / 215_000))
        self.assertEqual(self.kos.call("vacuum_ascent_circular_speed", 0, 6.5138398e10), 0)
        self.assertEqual(self.kos.call("vacuum_ascent_circular_speed", 215_000, 0), 0)


if __name__ == "__main__":
    unittest.main()
