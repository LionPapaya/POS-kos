"""Real-KerboScript tests for shared ascent inclination guidance and logging."""
from pathlib import Path
import math
import re
import unittest

import tools.pos_sim.kos_runtime as kos_runtime_module
from tools.pos_sim.kos_runtime import Runtime


ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "Script/Libraries/Poseidon_SSTO"


def function_source(path, name):
    source = path.read_text(encoding="utf-8-sig")
    match = re.search(r"^function " + re.escape(name) + r"\s*\{", source, re.M)
    if not match:
        raise AssertionError(f"Missing function {name} in {path}")
    following = re.search(r"^function ", source[match.end():], re.M)
    end = match.end() + following.start() if following else len(source)
    return source[match.start():end]


class InclinationGuidanceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        shared = LIB / "inclination_guidance.ks"
        vacuum = LIB / "vacuum_ascent_guidance.ks"
        navigation = ROOT / "Script/Libraries/lib_navigation.ks"
        cls.kos = Runtime(
            shared.read_text(encoding="utf-8-sig")
            + "\n"
            + function_source(navigation, "calculate_heading")
            + "\n"
            + vacuum.read_text(encoding="utf-8-sig")
        )

    def guidance(self, inclination, latitude, northbound=True):
        return self.kos.call(
            "ascent_inclination_guidance", inclination, latitude, northbound
        )

    def test_zero_inclination_doglegs_equatorward_from_both_hemispheres(self):
        expected = {
            (0.01, 90.04, False),
            (-0.01, 89.96, True),
            (20, 135, False),
            (-20, 45, True),
        }
        actual = set()
        for latitude, expected_heading, expected_branch in expected:
            result = self.guidance(0, latitude)
            self.assertTrue(result["valid"])
            self.assertEqual(result["mode"], "dogleg")
            self.assertAlmostEqual(result["heading"], expected_heading, places=8)
            self.assertEqual(result["northbound"], expected_branch)
            self.assertAlmostEqual(result["latitude_error"], abs(latitude), places=8)
            actual.add((latitude, result["heading"], result["northbound"]))
        self.assertEqual(len(actual), len(expected))

    def test_retrograde_180_doglegs_westward_and_equatorward(self):
        for latitude, expected_heading, expected_branch in (
            (0.01, 269.96, False),
            (-0.01, 270.04, True),
            (20, 225, False),
            (-20, 315, True),
        ):
            with self.subTest(latitude=latitude):
                result = self.guidance(180, latitude)
                self.assertTrue(result["valid"])
                self.assertEqual(result["mode"], "dogleg")
                self.assertAlmostEqual(result["heading"], expected_heading, places=8)
                self.assertEqual(result["northbound"], expected_branch)
                self.assertAlmostEqual(result["latitude_error"], abs(latitude), places=8)

    def test_reachable_prograde_and_retrograde_headings_keep_the_requested_branch(self):
        cases = (
            (60, 20, True),
            (60, 20, False),
            (120, 20, True),
            (120, 20, False),
            (60, -20, True),
            (120, -20, False),
        )
        for inclination, latitude, northbound in cases:
            with self.subTest(inclination=inclination, latitude=latitude, northbound=northbound):
                result = self.guidance(inclination, latitude, northbound)
                sine = math.cos(math.radians(inclination)) / math.cos(math.radians(latitude))
                principal = math.degrees(math.asin(sine))
                expected = principal if northbound else 180 - principal
                if expected < 0:
                    expected += 360
                self.assertTrue(result["valid"])
                self.assertEqual(result["mode"], "direct")
                self.assertEqual(result["northbound"], northbound)
                self.assertAlmostEqual(result["heading"], expected, places=8)
                self.assertEqual(result["latitude_error"], 0)

    def test_heading_branch_is_continuous_across_the_equator(self):
        for inclination, northbound in ((60, True), (60, False), (120, True), (120, False)):
            headings = [
                self.guidance(inclination, latitude, northbound)["heading"]
                for latitude in (-20, -10, 0, 10, 20)
            ]
            with self.subTest(inclination=inclination, northbound=northbound):
                self.assertTrue(all(abs(right - left) < 5 for left, right in zip(headings, headings[1:])))

    def test_dogleg_to_direct_transition_preserves_equatorward_branch(self):
        outside = self.guidance(10, 10.1)
        inside = self.guidance(10, 9.9, outside["northbound"])
        self.assertEqual(outside["mode"], "dogleg")
        self.assertFalse(outside["northbound"])
        self.assertEqual(inside["mode"], "direct")
        self.assertFalse(inside["northbound"])
        self.assertLess(abs(inside["heading"] - outside["heading"]), 2)

        south_outside = self.guidance(10, -10.1)
        south_inside = self.guidance(10, -9.9, south_outside["northbound"])
        self.assertTrue(south_outside["northbound"])
        self.assertTrue(south_inside["northbound"])
        self.assertLess(abs(south_inside["heading"] - south_outside["heading"]), 2)

    def test_reachability_boundary_and_polar_cases_are_finite(self):
        for latitude in (-30, 30):
            boundary = self.guidance(30, latitude)
            self.assertTrue(boundary["valid"])
            self.assertEqual(boundary["mode"], "direct")
            self.assertEqual(boundary["latitude_error"], 0)
            self.assertAlmostEqual(boundary["heading"], 90, places=7)

        for latitude, expected_heading, branch in (
            (30.001, 90.004, False),
            (-30.001, 89.996, True),
        ):
            result = self.guidance(30, latitude)
            self.assertEqual(result["mode"], "dogleg")
            self.assertAlmostEqual(result["latitude_error"], 0.001, places=8)
            self.assertAlmostEqual(result["heading"], expected_heading, places=8)
            self.assertEqual(result["northbound"], branch)

        for latitude in (-90, 90):
            for northbound, expected_heading in ((True, 0), (False, 180)):
                result = self.guidance(90, latitude, northbound)
                self.assertEqual(result["mode"], "direct")
                self.assertEqual(result["latitude_error"], 0)
                self.assertEqual(result["northbound"], northbound)
                self.assertTrue(math.isfinite(result["heading"]))
                self.assertAlmostEqual(result["heading"], expected_heading)

            unreachable = self.guidance(60, latitude)
            self.assertEqual(unreachable["mode"], "dogleg")
            self.assertTrue(math.isfinite(unreachable["heading"]))
            self.assertAlmostEqual(unreachable["latitude_error"], 30)

    def test_invalid_inclination_and_latitude_return_invalid_command(self):
        for inclination, latitude in ((-0.001, 0), (180.001, 0), (60, -90.001), (60, 90.001)):
            with self.subTest(inclination=inclination, latitude=latitude):
                result = self.guidance(inclination, latitude)
                self.assertFalse(result["valid"])
                self.assertEqual(result["mode"], "invalid")
                self.assertEqual(result["heading"], -1)
                self.assertEqual(result["latitude_error"], 0)
        self.assertEqual(self.kos.call("calculate_heading", -1, 0), -1)
        self.assertEqual(self.kos.call("vacuum_ascent_launch_heading", 181, 0), -1)

    def test_numeric_wrappers_accept_doglegs_and_optional_persistent_branch(self):
        self.assertAlmostEqual(self.kos.call("calculate_heading", 0, 20), 135)
        self.assertAlmostEqual(self.kos.call("vacuum_ascent_launch_heading", 0, 20), 135)
        northbound = self.kos.call("vacuum_ascent_launch_heading", 120, 20, True)
        southbound = self.kos.call("vacuum_ascent_launch_heading", 120, 20, False)
        self.assertGreater(northbound, 270)
        self.assertGreater(southbound, 180)
        self.assertLess(southbound, 240)
        self.assertAlmostEqual(
            self.kos.call("calculate_heading", 120, 20, False), southbound
        )


class InclinationKinematicConvergenceTest(unittest.TestCase):
    """A simple spherical ground-track check, not a vehicle simulation."""

    @classmethod
    def setUpClass(cls):
        source = LIB / "inclination_guidance.ks"
        cls.kos = Runtime(source.read_text(encoding="utf-8-sig"))

    @staticmethod
    def propagate_latitude(latitude, heading, angular_step=0.25):
        phi = math.radians(latitude)
        azimuth = math.radians(heading)
        step = math.radians(angular_step)
        next_sine = math.sin(phi) * math.cos(step) + math.cos(phi) * math.sin(step) * math.cos(azimuth)
        return math.degrees(math.asin(max(-1.0, min(1.0, next_sine))))

    def test_best_effort_dogleg_reduces_latitude_band_residual_kinematically(self):
        target_inclination = 22
        for initial_latitude in (-65, 65):
            latitude = initial_latitude
            command = self.kos.call("ascent_inclination_guidance", target_inclination, latitude)
            residual = max(0, abs(latitude) - target_inclination)
            self.assertEqual(command["mode"], "dogleg")
            steps = 0
            while residual > 0 and steps < 1000:
                latitude = self.propagate_latitude(latitude, command["heading"])
                command = self.kos.call(
                    "ascent_inclination_guidance",
                    target_inclination,
                    latitude,
                    command["northbound"],
                )
                next_residual = max(0, abs(latitude) - target_inclination)
                self.assertLessEqual(next_residual, residual + 1e-9)
                residual = next_residual
                steps += 1
            self.assertLess(steps, 1000)
            self.assertEqual(residual, 0)
            self.assertLessEqual(abs(latitude), target_inclination)


class InclinationFlightLogObserverTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.logger_function = function_source(
            LIB / "flight_log.ks", "flight_log_inclination_observe"
        )

    def make_logger(self, level, seconds=0):
        runtime = Runtime(self.logger_function)
        runtime.globals.update({
            "pos_log_level": level,
            "time": {"seconds": seconds},
            "ship": {"orbit": {"inclination": 72.5}},
        })
        events = []
        runtime.globals["flight_log_event"] = lambda name, detail: events.append((name, detail))
        return runtime, events

    def observe(self, runtime, *args):
        # The compact Runtime lacks kOS's implicit tostring in string joins.
        # Supply that single host-language behavior while executing the real
        # observer function, then restore the operator immediately.
        old_add = kos_runtime_module.OPS["+"]
        kos_runtime_module.OPS["+"] = lambda left, right: (
            str(left) + str(right)
            if isinstance(left, str) or isinstance(right, str)
            else old_add(left, right)
        )
        try:
            return runtime.call("flight_log_inclination_observe", *args)
        finally:
            kos_runtime_module.OPS["+"] = old_add

    def test_level_zero_is_inert(self):
        runtime, events = self.make_logger(0)
        runtime.globals.pop("ship")
        runtime.globals.pop("time")
        runtime.call(
            "flight_log_inclination_observe",
            {"mode": "dogleg", "northbound": False, "heading": 135, "latitude_error": 20},
            0,
            20,
            {"mode": "", "northbound": True, "next_sample": 0},
        )
        self.assertEqual(events, [])

    def test_low_level_logs_state_transitions_without_samples(self):
        runtime, events = self.make_logger(1, 0.25)
        evidence = {"mode": "direct", "northbound": True, "next_sample": 0}
        command = {"mode": "dogleg", "northbound": False, "heading": 135, "latitude_error": 20}
        self.observe(runtime, command, 0, 20, evidence)
        self.assertEqual([event[0] for event in events], ["ascent_inclination_state"])
        self.assertIn("mode=dogleg", events[0][1])
        self.assertIn("inclination_error=72.5", events[0][1])
        self.assertEqual(evidence["mode"], "dogleg")
        self.assertFalse(evidence["northbound"])
        events.clear()
        runtime.globals["time"]["seconds"] = 10
        self.observe(runtime, command, 0, 20, evidence)
        self.assertEqual(events, [])

    def test_medium_and_high_levels_sample_at_one_second_and_point_two_seconds(self):
        for level, period in ((2, 1), (3, 0.2)):
            with self.subTest(level=level):
                runtime, events = self.make_logger(level, 0)
                evidence = {"mode": "dogleg", "northbound": False, "next_sample": 0}
                command = {"mode": "dogleg", "northbound": False, "heading": 135, "latitude_error": 20}
                self.observe(runtime, command, 0, 20, evidence)
                self.assertEqual([event[0] for event in events], ["ascent_inclination_sample"])
                self.assertAlmostEqual(evidence["next_sample"], period)

                events.clear()
                runtime.globals["time"]["seconds"] = period - 0.001
                self.observe(runtime, command, 0, 20, evidence)
                self.assertEqual(events, [])

                runtime.globals["time"]["seconds"] = period
                self.observe(runtime, command, 0, 20, evidence)
                self.assertEqual([event[0] for event in events], ["ascent_inclination_sample"])
                self.assertAlmostEqual(evidence["next_sample"], period * 2)


if __name__ == "__main__":
    unittest.main()
