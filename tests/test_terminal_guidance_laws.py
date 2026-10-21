"""Real-KerboScript regression tests for terminal descent safety laws."""
from pathlib import Path
import math
import re
import unittest

from tools.pos_sim.kos_runtime import OpcodeScheduler, Runtime
from tools.pos_sim.math3d import Vec
from tools.pos_sim.terminal_energy_replay import EnergyReplay
from test_glideslope import glideslope_source


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


def terminal_config():
    source = (LIB / "craft_Poseidon_SSTO.ks").read_text(encoding="utf-8-sig")
    start = source.index('Poseidon_SSTO:add("TerminalRoute",lex(')
    start = source.index("lex(", start)
    end = source.index(")).", start) + 1
    return Runtime("function config { return " + source[start:end] + ". }").call("config")


def glideslope_config():
    source = (LIB / "craft_Poseidon_SSTO.ks").read_text(encoding="utf-8-sig")
    start = source.index('Poseidon_SSTO:add("Glideslope",lex(')
    start = source.index("lex(", start)
    end = source.index(")).", start) + 1
    return Runtime("function config { return " + source[start:end] + ". }").call("config")


class TerminalGuidanceLawTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        route = LIB / "terminal_route.ks"
        aero = ROOT / "Script/Libraries/lib_aerostr.ks"
        names = (
            "terminal_mass_speed_scale",
            "terminal_sink_arrest_prediction",
            "terminal_final_profile_command",
            "terminal_pullup_lift_force",
            "terminal_pullup_acceleration",
            "terminal_final_descent_recovery",
            "terminal_vertical_go_around_decision",
            "terminal_descent_rapier_mode",
            "terminal_fuel_dump_decision",
            "terminal_route_surface_clearance",
            "terminal_route_paired_lf_dump_floor",
        )
        cls.kos = Runtime(
            "\n".join(function_source(route, name) for name in names)
            + "\n"
            + glideslope_source()
        )
        cls.config = terminal_config()
        cls.gs = glideslope_config()

    def test_sink_arrest_prediction_retains_mass_and_speed_sensitivity(self):
        light = self.kos.call(
            "terminal_sink_arrest_prediction", -38, -8, 125, 36, 125, self.config
        )
        heavy = self.kos.call(
            "terminal_sink_arrest_prediction", -38, -8, 149, 46.73, 149, self.config
        )
        self.assertGreater(heavy["response_delay"], light["response_delay"])
        self.assertGreater(heavy["arrest_distance"], light["arrest_distance"])
        self.assertAlmostEqual(light["profile_deficit_height"], 360)
        self.assertAlmostEqual(light["absolute_arrest_height"], 536)
        zero_sink = self.kos.call(
            "terminal_sink_arrest_prediction", -38, 0, 125, 36, 125, self.config
        )
        self.assertAlmostEqual(zero_sink["absolute_arrest_height"], 557 + 1 / 3)
        self.assertAlmostEqual(zero_sink["profile_deficit_height"], zero_sink["absolute_arrest_height"])

    def profile_command(self, distance, profile_error, speed, mass, runway_altitude=0):
        profile = self.kos.call("calculate_glideslope_profile", distance,
            runway_altitude, self.gs)
        altitude = profile["altitude"] - profile_error
        return self.kos.call("terminal_final_profile_command", distance, altitude,
            speed, mass, self.config, self.gs, runway_altitude, True)

    def test_flight_407_high_profile_states_command_descent_without_predictive_pitch_floor(self):
        # Recorded flight 407 states: 3.448 km is near profile; at 1.270 km
        # the craft is 163 m above it, and at 57 m it remains about 211 m high.
        near = self.kos.call("terminal_final_profile_command", 3448.22,
            1978.7046, 133.1537, 37.4523, self.config, self.gs, 1183.0, True)
        high = self.kos.call("terminal_final_profile_command", 1270.20,
            1570.8842, 118.3933, 37.4518, self.config, self.gs, 1183.0, True)
        threshold = self.kos.call("terminal_final_profile_command", 56.59,
            1447.0664, 116.4513, 37.4379, self.config, self.gs, 1183.0, True)

        self.assertAlmostEqual(near["profile_error"], 7.8, delta=1.0)
        self.assertLess(near["desired_vs"], -30)
        self.assertLess(high["profile_error"], -150)
        self.assertEqual(high["preview_weight"], 0)
        self.assertLess(high["altitude_correction"], -50)
        self.assertEqual(high["fraction"], 0)
        self.assertEqual(high["desired_vs"], self.config["final_profile_min_vertical_speed"])
        self.assertLess(threshold["profile_error"], -200)
        self.assertEqual(threshold["desired_vs"], self.config["final_profile_min_vertical_speed"])

        high_pitch = self.kos.call("calculate_glideslope_pitch_command", high["desired_vs"],
            -13.8658, 118.3933, self.config["final_pitch_trim_aoa"],
            self.config["final_pitch_vertical_speed_gain"],
            self.config["final_pitch_command_min"], self.config["final_pitch_command_max"])
        feedback = self.kos.call("calculate_preflare_pullup_command", high["region"],
            high["profile_error"], high_pitch["command"],
            self.config["final_preflare_pullup_start_error"],
            self.config["final_preflare_pullup_full_error"],
            self.config["final_preflare_pullup_pitch"])
        self.assertLess(high_pitch["command"], 0)
        self.assertFalse(feedback["active"])
        self.assertLess(feedback["command"], 0)

    def test_near_curve_preview_and_altitude_correction_are_continuous_and_bounded(self):
        preview = {}
        for mass in (37.45, 46.70):
            command = self.profile_command(1000, 0, 125, mass)
            preview[mass] = command
            self.assertGreater(command["lookahead_seconds"], 0)
            self.assertGreater(command["preview_weight"], 0)
            self.assertGreater(command["preview_feedforward_vs"], command["feedforward_vs"])
        self.assertGreater(preview[46.70]["lookahead_seconds"], preview[37.45]["lookahead_seconds"])

        errors = (-200, -50, 0, 50, 200)
        commands = [self.profile_command(1000, error, 125, 46.70) for error in errors]
        corrections = [command["altitude_correction"] for command in commands]
        desired = [command["desired_vs"] for command in commands]
        self.assertTrue(all(a < b for a, b in zip(corrections, corrections[1:])))
        self.assertTrue(all(a <= b for a, b in zip(desired, desired[1:])))
        self.assertTrue(all(self.config["final_profile_min_vertical_speed"] <= value <=
                            self.config["final_profile_max_vertical_speed"] for value in desired))

        for boundary in (self.gs["preflare_start"], self.gs["preflare_end"]):
            left = self.profile_command(boundary - 0.1, 0, 125, 46.70)
            right = self.profile_command(boundary + 0.1, 0, 125, 46.70)
            self.assertLess(abs(left["desired_vs"] - right["desired_vs"]), 0.05)
            self.assertLess(abs(left["preview_feedforward_vs"] -
                                right["preview_feedforward_vs"]), 0.05)

    def test_delayed_independent_response_checks_profile_corridor_and_sink(self):
        # Independent plant: a delayed pitch-to-vertical-acceleration map with
        # finite authority and a mass penalty. It does not use the onboard
        # sink-arrest acceleration or predict its commanded path.
        def integrate(distance, altitude, vertical_speed, airspeed, mass):
            dt = 0.1
            response_delay = 2.0 + max(0, mass - 37.45) / 10.0
            delayed_pitch = [-8.0] * int(round(response_delay / dt))
            at_400 = None
            minimum_altitude = (altitude, distance, vertical_speed)
            while distance > 0:
                profile = self.kos.call("calculate_glideslope_profile", distance, 0, self.gs)
                command = self.kos.call("terminal_final_profile_command", distance,
                    altitude, airspeed, mass, self.config, self.gs, 0, True)
                pitch = self.kos.call("calculate_glideslope_pitch_command",
                    command["desired_vs"], vertical_speed, airspeed,
                    self.config["final_pitch_trim_aoa"],
                    self.config["final_pitch_vertical_speed_gain"],
                    self.config["final_pitch_command_min"],
                    self.config["final_pitch_command_max"])
                pullup = self.kos.call("calculate_preflare_pullup_command",
                    profile["region"], command["profile_error"], pitch["command"],
                    self.config["final_preflare_pullup_start_error"],
                    self.config["final_preflare_pullup_full_error"],
                    self.config["final_preflare_pullup_pitch"])
                delayed_pitch.append(pullup["command"])
                applied_pitch = delayed_pitch.pop(0)
                acceleration = max(-3.0, min(4.0, applied_pitch * 0.15))
                acceleration *= (37.45 / max(37.45, mass)) ** 0.25
                vertical_speed += acceleration * dt
                altitude += vertical_speed * dt
                distance -= airspeed * dt
                if altitude < minimum_altitude[0]:
                    minimum_altitude = (altitude, distance, vertical_speed)
                if at_400 is None and distance <= 400:
                    at_400 = (altitude, vertical_speed, distance)
            return at_400, (altitude, vertical_speed, distance), minimum_altitude

        cases = (
            # Recorded flight 407 at 3.448 km, relative to runway altitude.
            ("407", 3448.22, 1978.7046 - 1183.0, -33.5444, 133.1537, 37.4523),
            # Heavy 46.7 t approach, initially on the steep profile.
            ("heavy", 3800.0,
             self.kos.call("calculate_glideslope_profile", 3800, 0, self.gs)["altitude"],
             -149 * self.gs["angle1"], 149.0, 46.70),
        )
        for label, distance, altitude, vertical_speed, airspeed, mass in cases:
            with self.subTest(case=label):
                at_400, at_threshold, minimum_altitude = integrate(
                    distance, altitude, vertical_speed, airspeed, mass
                )
                for measured_altitude, measured_vs, measured_distance in (at_400, at_threshold):
                    profile_altitude = self.kos.call("calculate_glideslope_profile",
                        max(0, measured_distance), 0, self.gs)["altitude"]
                    self.assertLessEqual(abs(measured_altitude - profile_altitude), 80)
                target_sink = -airspeed * self.gs["angle2"]
                self.assertLessEqual(abs(at_threshold[1] - target_sink), 6)
                clearance_floor = 15
                clearances = (
                    ("400 m", at_400[0]),
                    ("threshold", at_threshold[0]),
                    ("minimum over approach", minimum_altitude[0]),
                )
                violations = [
                    f"{point}={height:.3f} m" for point, height in clearances
                    if height < clearance_floor
                ]
                self.assertEqual(
                    violations, [],
                    f"clearance below {clearance_floor} m: {', '.join(violations)}",
                )

    def test_clearance_arrest_margin_triggers_recovery_before_profile_error_threshold(self):
        recover = self.kos.call(
            "terminal_final_descent_recovery",
            "final", 54, -4, -14, self.config, 100, 250,
        )
        enough_margin = self.kos.call(
            "terminal_final_descent_recovery",
            "final", 54, -4, -14, self.config, 250, 250,
        )
        below_escape_height = self.kos.call(
            "terminal_final_descent_recovery",
            "final", 0, -7, -18, self.config, -20, 70,
        )
        self.assertTrue(recover)
        self.assertFalse(enough_margin)
        self.assertTrue(below_escape_height)
        self.assertFalse(self.kos.call("terminal_final_descent_recovery",
            "final", 0, -7, -18, self.config, -20, 10))
        self.assertTrue(self.kos.call("terminal_final_descent_recovery",
            "final", 0, -7, -18, self.config, -20, 100))

    def test_critical_arrest_margin_goes_around_before_landing_gate_but_never_below_it(self):
        decide = lambda active, distance, elapsed, margin, clearance, contact=False: self.kos.call(
            "terminal_vertical_go_around_decision", active, distance, elapsed,
            margin, clearance, contact, self.config,
        )
        self.assertTrue(decide(True, 900, 0.26, -4, 127))
        self.assertTrue(decide(True, 900, 0.26, 15, 127))
        self.assertTrue(decide(True, 900, 0.26, 125, 250))
        self.assertFalse(decide(True, 900, 0.26, 126, 250))
        self.assertTrue(decide(True, 900, 0.26, -4, 100))
        self.assertTrue(decide(True, 900, 0.26, -50, 70))
        self.assertFalse(decide(True, 900, 0.26, -50, 10))
        self.assertFalse(decide(True, 900, 0.26, -50, 127, True))
        self.assertFalse(decide(True, 900, 0.24, -4, 127))
        self.assertFalse(decide(False, 900, 1, -100, 200))

    def test_lf_dump_is_independent_of_oxidizer_and_respects_reserve_and_owner_guards(self):
        decision = self.kos.call(
            "terminal_fuel_dump_decision",
            "base", 46.73, 1700, 1475, True, True, 600, -20, self.config,
        )
        reserve_stop = self.kos.call(
            "terminal_fuel_dump_decision",
            "base", 46.73, 1490, 1475, False, True, 600, -20, self.config,
        )
        go_around = self.kos.call(
            "terminal_fuel_dump_decision",
            "go_around", 46.73, 1700, 1000, False, True, 500, -20, self.config,
        )
        flare_clearance = self.kos.call(
            "terminal_fuel_dump_decision",
            "final", 46.73, 1700, 1000, False, True, 400, -20, self.config,
        )
        self.assertTrue(decision)
        self.assertFalse(reserve_stop)
        self.assertFalse(go_around)
        self.assertFalse(flare_clearance)

    def test_paired_floor_preserves_a_finite_cc_burn_budget_only_when_usable(self):
        floor = self.kos.call("terminal_route_paired_lf_dump_floor",300,1320,300,2,self.config)
        low_ox_floor = self.kos.call("terminal_route_paired_lf_dump_floor",300,350,300,2,self.config)
        no_engine_floor = self.kos.call("terminal_route_paired_lf_dump_floor",300,1320,300,0,self.config)
        no_ox_floor = self.kos.call("terminal_route_paired_lf_dump_floor",300,250,300,2,self.config)
        self.assertEqual(floor,775)
        self.assertAlmostEqual(low_ox_floor,462.5)
        self.assertEqual(no_engine_floor,300)
        self.assertEqual(no_ox_floor,300)
        self.assertEqual(self.kos.call("terminal_route_surface_clearance",300,25,100),200)

    def test_closed_cycle_requires_thrust_demand_and_paired_reserve_margins(self):
        def mode(step="TEAM", phase="final", throttle=0.3, atmospheric=True, clearance=500,
                 engines=2, lf=5000, ox=1500):
            return self.kos.call(
                "terminal_descent_rapier_mode", step, phase, throttle,
                atmospheric, clearance, engines, lf, ox, 1000, 300, self.config,
            )

        self.assertEqual(mode(), "closed")
        self.assertEqual(mode(throttle=0), "idle")
        self.assertEqual(mode(step="orbit_insert"), "air")
        self.assertEqual(mode(engines=0), "air")
        self.assertEqual(mode(lf=1200), "air")
        self.assertEqual(mode(ox=350), "air")
        self.assertEqual(mode(clearance=100), "air")
        self.assertEqual(mode(clearance=100,phase="go_around"), "closed")
        for phase in ("reposition", "intercept", "hold"):
            self.assertEqual(mode(phase=phase), "closed")
        self.assertEqual(mode(phase="entry"), "air")
        self.assertEqual(mode(atmospheric=False), "air")
        for phase in ("entry", "coast", "landing", "ground"):
            self.assertEqual(mode(phase=phase), "air")
        self.assertEqual(mode(step="landing"), "air")
        self.assertEqual(mode(clearance=100), "air")

    def test_flight385_known_reserve_dump_and_partial_cc_budget(self):
        lf_reserve = 555.997
        ox_floor = 300
        paired_floor = self.kos.call(
            "terminal_route_paired_lf_dump_floor", lf_reserve, 1320, ox_floor, 2, self.config
        )
        self.assertAlmostEqual(paired_floor, 1030.997)
        dump_eligibility = self.kos.call(
            "terminal_fuel_dump_decision", "reposition", 46.73, 1100, paired_floor,
            False, True, 900, -20, self.config,
        )
        self.assertTrue(dump_eligibility)
        self.assertLess(1100,1115)  # prior flight-385 cutoff: 1015 LF floor + 100
        self.assertGreater(paired_floor,lf_reserve)

        def mode(lf, ox):
            return self.kos.call(
                "terminal_descent_rapier_mode", "TEAM", "reposition", 0.3, True,
                900, 2, lf, ox, lf_reserve, ox_floor, self.config,
            )

        self.assertEqual(mode(900,550),"closed")
        self.assertEqual(mode(800,450),"air")
        self.assertEqual(mode(lf_reserve,450),"air")
        self.assertEqual(self.kos.call(
            "terminal_descent_rapier_mode", "TEAM", "reposition", 0.3, True,
            900, 0, 900, 550, lf_reserve, ox_floor, self.config,
        ),"air")
        self.assertEqual(self.kos.call(
            "terminal_descent_rapier_mode", "TEAM", "reposition", 0.3, True,
            900, 2, 900, 250, lf_reserve, ox_floor, self.config,
        ),"air")

    def test_terminal_logger_schema_records_arrest_predictor_and_propulsion_mode(self):
        logger = LIB / "flight_log.ks"
        names = (
            "flight_log_terminal_energy_header",
        )
        column_source = function_source(logger, "flight_log_terminal_energy_columns")
        # The small runtime does not implement kOS's `defined` predicate. Keep
        # the production column-building body intact and disable only its
        # missing-debug fallback for this test invocation.
        column_source = column_source.replace(
            "if not(defined terminal_route_debug) {", "if false {", 1
        )
        self.assertIn("global POS_LOG_SCHEMA_VERSION is 32.", logger.read_text())
        logger_runtime = EnergyReplay()
        row = dict(latitude=0, longitude=-4, runway_start_latitude=0,
                   runway_start_longitude=0, runway_heading=90,
                   runway_altitude=72, altitude=10000, airspeed=200,
                   vertical_speed=-30, thrust=0, ut=0, throttle_actual=0,
                   terminal_airbrake='False', terminal_gear='False',
                   terminal_runway_heading_error=0, roll=0, aoa_actual=10)
        logger_runtime.set_row(row)
        route = logger_runtime.call("terminal_route_init")
        logger_runtime.call("terminal_route_update", route)
        logger_runtime.kos.load_source(
            "\n".join(function_source(logger, name) for name in names)
            + "\n" + column_source,
            "terminal_logger_fields",
        )
        logger_runtime.kos.globals.get_value("terminal_route_debug")["propulsion_mode"] = "closed"
        header = logger_runtime.call("flight_log_terminal_energy_header").split(",")[1:]
        values = logger_runtime.call("flight_log_terminal_energy_columns").split(",")[1:]
        self.assertEqual(len(header), 56)
        self.assertEqual(len(values), len(header))
        self.assertEqual(values[header.index("terminal_propulsion_mode")], "closed")
        logger_runtime.kos.globals.get_value("terminal_route_debug")["preflare_pitch_floor_fraction"] = 0.35
        values = logger_runtime.call("flight_log_terminal_energy_columns").split(",")[1:]
        self.assertEqual(values[header.index("terminal_preflare_pitch_floor_fraction")], "0.35")
        fallback_source = column_source.replace("if false {", "if true {", 1)
        logger_runtime.kos.load_source(fallback_source,"terminal_logger_default_fields")
        fallback_values = logger_runtime.call("flight_log_terminal_energy_columns").split(",")[1:]
        self.assertEqual(len(fallback_values),len(header))
        self.assertIn("terminal_preflare_profile_deficit_height", header)
        self.assertIn("terminal_preflare_absolute_arrest_height", header)
        self.assertIn("terminal_dump_lf_paired_floor", header)
        self.assertIn("terminal_descent_arrest_margin", header)
        self.assertIn("terminal_preflare_pitch_floor_fraction", header)
        self.assertIn("terminal_preflare_preview_seconds", header)
        self.assertIn("terminal_preflare_altitude_correction", header)
        self.assertIn("terminal_pullup_far_valid", header)
        self.assertIn("terminal_pullup_far_accel", header)


class TerminalFarCapabilityTest(unittest.TestCase):
    def setUp(self):
        self.host = EnergyReplay()
        self.config = terminal_config()["PreflarePrediction"]
        self.calls = []

        def positive_lift(altitude, velocity):
            self.calls.append((altitude, velocity))
            return Vec(0, 250, 0)

        self.host.far_force = positive_lift
        self.host.set_row(dict(latitude=0, longitude=0, runway_start_latitude=0,
            runway_start_longitude=0, runway_heading=90, runway_altitude=0,
            altitude=10000, airspeed=120, surface_speed=120, vertical_speed=-5,
            thrust=0, ut=1000, throttle_actual=0, mass=30, liquidfuel=0,
            oxidizer=0, terminal_airbrake="False", terminal_gear="False",
            terminal_runway_heading_error=0, roll=0, aoa_actual=16))
        self.route = self.host.call("terminal_route_init")

    def set_state(self, ut, altitude=10000, airspeed=120, brakes=False, gear=False):
        row = dict(self.host.row, ut=ut, altitude=altitude, airspeed=airspeed,
                   terminal_airbrake="True" if brakes else "False",
                   terminal_gear="True" if gear else "False")
        self.host.set_row(row)

    def refresh(self, eligible=True):
        return self.host.call("terminal_route_refresh_pullup_force",
            self.route, self.config, eligible)

    def test_far_projection_is_signed_and_rotation_invariant(self):
        angle = math.radians(16)
        wind = Vec(0, -math.sin(angle), math.cos(angle))
        top = Vec(0, 1, 0)
        lift_axis = top - wind * (top.x * wind.x + top.y * wind.y + top.z * wind.z)
        lift_axis = lift_axis.normalized
        force = lift_axis * 123 + wind * -17
        positive = self.host.call("terminal_pullup_lift_force", force, wind, top)
        negative = self.host.call("terminal_pullup_lift_force", force * -1, wind, top)
        self.assertAlmostEqual(positive, 123, places=6)
        self.assertAlmostEqual(negative, -123, places=6)

        rotate = lambda v: Vec(-v.y, v.x, v.z)
        rotated = self.host.call("terminal_pullup_lift_force", rotate(force),
            rotate(wind), rotate(top))
        self.assertAlmostEqual(rotated, positive, places=6)

    def test_far_acceleration_uses_mass_gamma_bank_gravity_safety_and_cap(self):
        result = self.host.call("terminal_pullup_acceleration", 300, 30, 1,
            100, 60, 60, self.config)
        self.assertAlmostEqual(result["raw"], 3, places=6)
        self.assertAlmostEqual(result["usable"], 1.95, places=6)
        negative = self.host.call("terminal_pullup_acceleration", -300, 30, 1,
            100, 0, 0, self.config)
        self.assertLess(negative["raw"], 0)
        self.assertEqual(negative["usable"], 0)
        capped = self.host.call("terminal_pullup_acceleration", 1000, 20, 1,
            100, 0, 0, self.config)
        self.assertEqual(capped["usable"], self.config["far_maximum_acceleration"])

    def test_far_refresh_cadence_drift_invalidation_missing_addon_and_no_ship_side_effects(self):
        ship_before = dict(self.host.kos.globals.get_value("ship"))
        self.refresh()
        self.assertEqual(self.host.kos.globals.get_value("ship"), ship_before)
        self.assertTrue(self.route["pullup_far_valid"])
        self.assertEqual(len(self.calls), 1)
        sampled_velocity = self.calls[0][1]
        sampled_aoa = math.degrees(math.atan2(-sampled_velocity.y, sampled_velocity.z))
        self.assertAlmostEqual(sampled_aoa, 16, places=6)

        self.set_state(1000.5)
        self.refresh()
        self.assertEqual(len(self.calls), 1)
        self.set_state(1001.1)
        self.refresh()
        self.assertEqual(len(self.calls), 2)
        self.set_state(1001.2, altitude=10101)
        self.refresh()
        self.assertEqual(len(self.calls), 3)

        old_lift = self.route["pullup_far_lift"]
        self.host.kos.globals["addons"] = {"available": lambda name: False, "far": {}}
        self.refresh()
        self.assertFalse(self.route["pullup_far_valid"])
        self.assertEqual(self.route["pullup_far_lift"], old_lift)
        self.assertEqual(len(self.calls), 3)

    def test_far_configuration_change_waits_for_settle_before_refresh(self):
        self.refresh()
        self.assertEqual(len(self.calls), 1)
        self.set_state(1000.1, brakes=True)
        self.refresh()
        self.assertFalse(self.route["pullup_far_valid"])
        self.assertEqual(len(self.calls), 1)
        self.set_state(1001.9, brakes=True)
        self.refresh()
        self.assertFalse(self.route["pullup_far_valid"])
        self.assertEqual(len(self.calls), 1)
        self.set_state(1002.2, brakes=True)
        self.refresh()
        self.assertTrue(self.route["pullup_far_valid"])
        self.assertEqual(len(self.calls), 2)

    def test_ineligible_or_missing_far_suffix_invalidates_cached_sample(self):
        self.refresh()
        self.assertTrue(self.route["pullup_far_valid"])
        self.refresh(eligible=False)
        self.assertFalse(self.route["pullup_far_valid"])
        self.assertEqual(len(self.calls), 1)

        self.set_state(1000.1)
        self.host.kos.globals["addons"] = {"available": lambda name: True,
            "far": {"hassuffix": lambda suffix: False}}
        self.refresh()
        self.assertFalse(self.route["pullup_far_valid"])
        self.assertEqual(len(self.calls), 1)


class TerminalDescentRepositionIntegrationTest(unittest.TestCase):
    def test_descending_team_reposition_uses_bounded_closed_cycle_command(self):
        host = EnergyReplay()
        host.kos.load_source(glideslope_source(), "real-glideslope-controllers")
        g = host.kos.globals
        commands = []
        g.update({
            "step": "TEAM",
            "dap": {"aoa": {}, "aerostr": {"turn_pitch": 0}},
            "terminal_route_target_arrow_enabled": False,
            "terminal_route_target_arrow_active": False,
            "rapierson": lambda: commands.append("rapiers"),
            "togglerapiermode": lambda mode: commands.append(mode),
            "recovery_engines": {"r": {"kind": "rapier", "present": True,
                "failed": False, "isolated": False,
                "part": {"thrustlimit": 1, "flameout": False}}},
        })
        row = dict(
            latitude=0, longitude=-8000/600000*180/math.pi,
            runway_start_latitude=0, runway_start_longitude=0,
            runway_heading=90, runway_altitude=25, altitude=9000,
            airspeed=125, surface_speed=125, vertical_speed=-20,
            thrust=0, ut=0, throttle_actual=0, mass=46.73,
            liquidfuel=5000, oxidizer=1320, terminal_airbrake="False",
            terminal_gear="False", terminal_runway_heading_error=0,
            roll=0, aoa_actual=13,
        )
        host.set_row(row)
        route = host.call("terminal_route_init")
        route["phase"] = "reposition"
        host.kos.scheduler = OpcodeScheduler(ipu=2000, tick_seconds=0.02)
        host.call("terminal_route_update", route)
        self.assertEqual(route["phase"], "reposition")
        self.assertEqual(route["propulsion_mode"], "closed")
        self.assertEqual(route["propulsion_throttle"], 0.35)
        host.call("terminal_route_fly", route)
        self.assertEqual(g.get_value("dapthrottle"), 0.35)
        self.assertEqual(commands, ["rapiers", "closed"])


if __name__ == "__main__":
    unittest.main()
