"""Real-KerboScript regression tests for terminal descent safety laws."""
from pathlib import Path
import json
import math
import re
import unittest

from tools.pos_sim.kos_runtime import OpcodeScheduler, Runtime
from tools.pos_sim.aero import AnalyticAero
from tools.pos_sim.bodies import stock_body
from tools.pos_sim.craft import parse_craft
from tools.pos_sim.math3d import Vec, cross, dot
from tools.pos_sim.physics import FlightCommand, PhysicsSimulator, VehicleModel, VehicleState
from tools.pos_sim.terrain import latitude_longitude
from tools.pos_sim.terminal_energy_replay import EnergyReplay, destination
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


def source_block(source, marker):
    """Return one balanced production block for a narrow source replay."""
    start = source.index(marker)
    opening = source.index("{", start)
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start:index + 1]
    raise AssertionError(f"Unclosed block beginning at {marker!r}")


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


def historical_glideslope_config():
    # Frozen approach recordings before the 3.6 km to 1 km profile change.
    return Runtime(
        'function config { return lex('
        '"angle1",0.268,"angle2",0.0524077793,"target1",450,'
        '"preflare_start",1500,"preflare_end",400,"shallow_aimpoint",875). }'
    ).call("config")


def landing_config():
    source = (LIB / "craft_Poseidon_SSTO.ks").read_text(encoding="utf-8-sig")
    start = source.index('Poseidon_SSTO:add("Landing",lex(')
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
        # Replay those measurements against their recorded pre-change curve.
        old_gs = historical_glideslope_config()
        near = self.kos.call("terminal_final_profile_command", 3448.22,
            1978.7046, 133.1537, 37.4523, self.config, old_gs, 1183.0, True)
        high = self.kos.call("terminal_final_profile_command", 1270.20,
            1570.8842, 118.3933, 37.4518, self.config, old_gs, 1183.0, True)
        threshold = self.kos.call("terminal_final_profile_command", 56.59,
            1447.0664, 116.4513, 37.4379, self.config, old_gs, 1183.0, True)

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
            command = self.profile_command(2500, 0, 125, mass)
            preview[mass] = command
            self.assertGreater(command["lookahead_seconds"], 0)
            self.assertGreater(command["preview_weight"], 0)
            self.assertGreater(command["preview_feedforward_vs"], command["feedforward_vs"])
        self.assertGreater(preview[46.70]["lookahead_seconds"], preview[37.45]["lookahead_seconds"])

        errors = (-200, -50, 0, 50, 200)
        commands = [self.profile_command(2500, error, 125, 46.70) for error in errors]
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

    def test_extended_preflare_joins_both_glides_and_preserves_threshold_reference(self):
        # Execute calculate_glideslope_profile from lib_aerostr.ks against the
        # live craft configuration, rather than duplicating its Hermite math.
        self.assertAlmostEqual(self.gs["angle1"], 0.268)
        self.assertAlmostEqual(self.gs["angle2"], 0.0524077793)
        self.assertEqual(self.gs["preflare_start"], 3600)
        self.assertEqual(self.gs["preflare_end"], 1000)
        self.assertEqual(self.gs["shallow_aimpoint"], 875)
        expected_intercept = 3600 - (
            (1000 + 875) * self.gs["angle2"]
            + 2600 * (self.gs["angle1"] + self.gs["angle2"]) / 2
        ) / self.gs["angle1"]
        self.assertAlmostEqual(self.gs["target1"], expected_intercept, places=8)
        self.assertAlmostEqual(self.gs["target1"], 1679.1242564, places=6)

        def profile(distance):
            return self.kos.call("calculate_glideslope_profile", distance, 0, self.gs)

        shallow = profile(1000)
        start = profile(3600)
        threshold = profile(0)
        self.assertEqual(shallow["region"], "shallow")
        self.assertEqual(start["region"], "steep")
        self.assertAlmostEqual(shallow["altitude"], 98.264584, places=5)
        self.assertAlmostEqual(shallow["gradient"], self.gs["angle2"], places=9)
        self.assertAlmostEqual(start["altitude"], 514.795, places=2)
        self.assertAlmostEqual(start["gradient"], self.gs["angle1"], places=9)
        self.assertAlmostEqual(threshold["altitude"], 45.8568, places=3)
        self.assertAlmostEqual(threshold["gradient"], self.gs["angle2"], places=9)

        for boundary, expected_altitude, expected_gradient in (
            (1000, shallow["altitude"], self.gs["angle2"]),
            (3600, start["altitude"], self.gs["angle1"]),
        ):
            left = profile(boundary - 0.01)
            right = profile(boundary + 0.01)
            self.assertAlmostEqual(left["altitude"], expected_altitude, delta=0.01)
            self.assertAlmostEqual(right["altitude"], expected_altitude, delta=0.01)
            self.assertAlmostEqual(left["gradient"], expected_gradient, delta=2e-6)
            self.assertAlmostEqual(right["gradient"], expected_gradient, delta=2e-6)

    def test_extended_preflare_curvature_is_monotone_and_bounds_sink_arrest_acceleration(self):
        gradients = [
            self.kos.call("calculate_glideslope_profile", distance, 0, self.gs)["gradient"]
            for distance in range(1000, 3601, 100)
        ]
        self.assertTrue(all(left < right for left, right in zip(gradients, gradients[1:])))

        # Vertical speed is -V*gradient while the aircraft closes at V, so
        # required upward acceleration is V^2 times profile curvature.
        curvatures = []
        for distance in range(1100, 3501, 100):
            before = self.kos.call(
                "calculate_glideslope_profile", distance - 1, 0, self.gs
            )["gradient"]
            after = self.kos.call(
                "calculate_glideslope_profile", distance + 1, 0, self.gs
            )["gradient"]
            curvatures.append((after - before) / 2)
        expected_curvature = (self.gs["angle1"] - self.gs["angle2"]) / 2600
        self.assertTrue(all(curvature > 0 for curvature in curvatures))
        for curvature in curvatures:
            self.assertAlmostEqual(curvature, expected_curvature, delta=2e-8)
        self.assertAlmostEqual(130 ** 2 * expected_curvature, 1.40, delta=0.02)
        self.assertAlmostEqual(150 ** 2 * expected_curvature, 1.87, delta=0.02)

    def test_extended_preflare_profile_is_inside_gear_and_commit_height_windows(self):
        route = terminal_config()
        gear_gate = route["PreflareCommit"]
        before_preflare = self.kos.call(
            "calculate_glideslope_profile", gear_gate["gear_distance"] - 1, 0, self.gs
        )
        commit_start = self.kos.call(
            "calculate_glideslope_profile", gear_gate["distance"], 0, self.gs
        )
        self.assertEqual(gear_gate["gear_distance"], 4200)
        self.assertEqual(gear_gate["gear_height"], 850)
        self.assertLess(before_preflare["altitude"], gear_gate["gear_height"])
        self.assertEqual(gear_gate["distance"], 3600)
        self.assertEqual(gear_gate["minimum_height"], 75)
        self.assertEqual(gear_gate["maximum_height"], 650)
        self.assertGreater(commit_start["altitude"], gear_gate["minimum_height"])
        self.assertLess(commit_start["altitude"], gear_gate["maximum_height"])

    def _trimmed_analytic_aoa(self, body, aero, altitude, speed, vertical_speed, mass):
        flight_path = math.asin(vertical_speed / speed)
        velocity = Vec(math.cos(flight_path), math.sin(flight_path), 0) * speed
        normal = Vec(-math.sin(flight_path), math.cos(flight_path), 0)
        gravity = body.mu / (body.radius + altitude) ** 2

        def normal_acceleration(aoa_deg):
            pitch = flight_path + math.radians(aoa_deg)
            forward = Vec(math.cos(pitch), math.sin(pitch), 0)
            top = Vec(-math.sin(pitch), math.cos(pitch), 0)
            force = aero.evaluate(body, altitude, velocity, forward, top).force
            return dot(force, normal) / mass - gravity * math.cos(flight_path)

        low, high = 0.0, 25.0
        self.assertLess(normal_acceleration(low), 0)
        self.assertGreater(normal_acceleration(high), 0)
        for _ in range(60):
            middle = (low + high) / 2
            if normal_acceleration(middle) > 0:
                high = middle
            else:
                low = middle
        trim_aoa = (low + high) / 2
        self.assertAlmostEqual(normal_acceleration(trim_aoa), 0, delta=0.05)
        self.assertLess(normal_acceleration(trim_aoa - 1), 0)
        self.assertGreater(normal_acceleration(trim_aoa + 1), 0)
        self.assertLess(math.degrees(flight_path) + trim_aoa, 0)
        return trim_aoa

    def _steady_glide_trim(self, body, aero, altitude, speed, mass):
        gravity = body.mu / (body.radius + altitude) ** 2

        def equilibrium(aoa_deg):
            aoa = math.radians(aoa_deg)
            forward_level = Vec(math.cos(aoa), math.sin(aoa), 0)
            top_level = Vec(-math.sin(aoa), math.cos(aoa), 0)
            level_force = aero.evaluate(
                body, altitude, Vec(speed, 0, 0), forward_level, top_level
            ).force
            drag = -dot(level_force, Vec(1, 0, 0))
            flight_path = -math.asin(max(-1, min(1, drag / (mass * gravity))))
            velocity = Vec(math.cos(flight_path), math.sin(flight_path), 0) * speed
            pitch = flight_path + aoa
            forward = Vec(math.cos(pitch), math.sin(pitch), 0)
            top = Vec(-math.sin(pitch), math.cos(pitch), 0)
            force = aero.evaluate(body, altitude, velocity, forward, top).force
            tangent = Vec(math.cos(flight_path), math.sin(flight_path), 0)
            normal = Vec(-math.sin(flight_path), math.cos(flight_path), 0)
            tangent_acceleration = dot(force, tangent) / mass - gravity * math.sin(flight_path)
            normal_acceleration = dot(force, normal) / mass - gravity * math.cos(flight_path)
            return flight_path, tangent_acceleration, normal_acceleration

        low, high = 0.0, 25.0
        self.assertLess(equilibrium(low)[2], 0)
        self.assertGreater(equilibrium(high)[2], 0)
        for _ in range(60):
            middle = (low + high) / 2
            if equilibrium(middle)[2] > 0:
                high = middle
            else:
                low = middle
        trim_aoa = (low + high) / 2
        flight_path, tangent_accel, normal_accel = equilibrium(trim_aoa)
        return {
            "aoa_deg": trim_aoa,
            "flight_path_deg": math.degrees(flight_path),
            "pitch_deg": math.degrees(flight_path) + trim_aoa,
            "tangent_acceleration": tangent_accel,
            "normal_acceleration": normal_accel,
        }

    def _run_independent_terminal_case(self, label, distance, clearance, vertical_speed,
                                      airspeed, mass, runway_altitude,
                                      initial_pitch_override=None,
                                      maximum_turn_rate_deg_s=None,
                                      maximum_steps=900, source_ut=0.0):
        # Plant inputs are fixed independently of guidance: stock Kerbin,
        # default 70 m^2 AnalyticAero, stock craft RAPIER closed-cycle data,
        # and the standard 0.02 s translational/attitude simulator.
        body = stock_body("kerbin")
        aero = AnalyticAero()
        self.assertEqual(aero.reference_area, 70.0)
        flight_path = math.asin(vertical_speed / airspeed)
        altitude_asl = runway_altitude + clearance
        trim_aoa = self._trimmed_analytic_aoa(
            body, aero, altitude_asl, airspeed, vertical_speed, mass
        )
        trimmed_pitch = math.degrees(flight_path) + trim_aoa
        initial_pitch = (trimmed_pitch if initial_pitch_override is None
                         else initial_pitch_override)
        craft = parse_craft(ROOT / "Poseidon SSTO Block 2.craft")
        rapier_count, rapier_thrust, rapier_isp = craft.vacuum_propulsion("rapier")
        self.assertEqual(rapier_count, 4)

        fuel_units = 2000.0
        oxidizer_units = 1320.0
        fuel_mass = fuel_units * 0.005
        vehicle = VehicleModel(
            dry_mass_t=mass - fuel_mass,
            thrust_kn=0,
            isp_s=rapier_isp,
            maximum_turn_rate_deg_s=12.0 if maximum_turn_rate_deg_s is None
            else maximum_turn_rate_deg_s,
        )

        class FlatRunway:
            def elevation(self, latitude, longitude):
                return runway_altitude

        simulator = PhysicsSimulator(
            body, vehicle, aero=aero, terrain=FlatRunway(), dt=0.02
        )
        start_longitude = -math.degrees(distance / body.radius)
        longitude_radians = math.radians(start_longitude)
        up = Vec(math.cos(longitude_radians), math.sin(longitude_radians), 0)
        east = Vec(-math.sin(longitude_radians), math.cos(longitude_radians), 0)
        position = up * (body.radius + altitude_asl)
        air_velocity = (
            east * math.cos(flight_path) + up * math.sin(flight_path)
        ) * airspeed
        forward = east * math.cos(math.radians(initial_pitch)) + up * math.sin(math.radians(initial_pitch))
        top = up * math.cos(math.radians(initial_pitch)) - east * math.sin(math.radians(initial_pitch))
        state = VehicleState(
            position,
            air_velocity + cross(body.angular_velocity, position),
            mass,
            forward,
            top,
            liquid_fuel_t=fuel_mass,
            oxidizer_t=oxidizer_units * 0.005,
        )

        host = EnergyReplay()
        host.kos.globals.get_value("aves")["Landing"] = landing_config()
        host.kos.load_source(
            (ROOT / "Script/Libraries/lib_aerostr.ks").read_text(encoding="utf-8-sig"),
            "terminal-approach-aerostr",
        )
        host.kos.load_source(
            function_source(ROOT / "Script/Libraries/lib_navigation.ks", "navigation_longitude_delta")
            + function_source(ROOT / "Script/Libraries/lib_navigation.ks", "calcdistance_m"),
            "production_navigation_distance",
        )
        globals_ = host.kos.globals
        engine_mode = {"value": "air"}
        healthy_rapiers = {
            f"part_{index}": {
                "kind": "rapier", "present": True, "failed": False, "isolated": False,
                "part": {"thrustlimit": 100, "flameout": False},
            }
            for index in range(rapier_count)
        }
        globals_.update({
            "step": "TEAM",
            "gear": False,
            "brakes": False,
            "dap": {
                "aoa": {"target_aoa": 0, "target_bank": 0, "base_pitch": 0},
                "aerostr": {"turn_pitch": 0, "turn_roll": 0, "distance_pitch": 0,
                            "turn_heading": 90, "aerostr_Roll": 0},
            },
            "recovery_engines": healthy_rapiers,
            "terminal_route_target_arrow_enabled": False,
            "terminal_route_target_arrow_active": False,
            "rapierson": lambda: None,
            "togglerapiermode": lambda mode: engine_mode.update(value=mode),
            "nervson": lambda: None,
            "abort_set_fuel_dump": lambda enabled: None,
            "roll_for": lambda: 0,
        })

        last_pitch = initial_pitch
        last_throttle = 0.0
        minimum_clearance = clearance
        go_around = None
        crossed_400 = None
        crossed_threshold = None
        initial_control = None
        impact = None

        def row_from_state():
            latitude, longitude = latitude_longitude(
                state.position, body.angular_speed * state.time
            )
            altitude = state.position.mag - body.radius
            surface_velocity = state.velocity - cross(body.angular_velocity, state.position)
            radial = state.position.normalized
            vertical = dot(surface_velocity, radial)
            return {
                "latitude": latitude, "longitude": longitude,
                "runway_start_latitude": 0, "runway_start_longitude": 0,
                "runway_heading": 90, "runway_altitude": runway_altitude,
                "altitude": altitude, "airspeed": surface_velocity.mag,
                "surface_speed": surface_velocity.mag, "vertical_speed": vertical,
                "thrust": state.throttle * simulator.vehicle.thrust_kn,
                "ut": source_ut + state.time, "throttle_actual": state.throttle,
                "mass": state.mass_t,
                "liquidfuel": (state.liquid_fuel_t or 0) / 0.005,
                "oxidizer": state.oxidizer_t / 0.005,
                "terminal_airbrake": "True" if globals_.get_value("brakes") else "False",
                "terminal_gear": "True" if globals_.get_value("gear") else "False",
                "terminal_runway_heading_error": 0, "roll": 0,
                "aoa_actual": aero.evaluate(
                    body, altitude, surface_velocity, state.forward, state.top
                ).aoa_deg,
                "terrain_height": runway_altitude,
                "step": globals_.get_value("step"),
                "status": "LANDED" if state.landed else ("CRASHED" if state.crashed else "FLYING"),
            }

        def sync_host():
            host.set_row(row_from_state())
            ship = globals_.get_value("ship")
            ship["partstitledpattern"] = lambda pattern: []
            ship["facing"] = {"forevector": state.forward, "topvector": state.top}
            ship["groundspeed"] = row_from_state()["surface_speed"]

        def physics_tick(_duration):
            nonlocal minimum_clearance, impact
            sync_host()
            simulator.vehicle = VehicleModel(
                dry_mass_t=vehicle.dry_mass_t,
                thrust_kn=rapier_thrust if engine_mode["value"] == "closed" else 0,
                isp_s=rapier_isp,
                reaction_wheel_torque_knm=vehicle.reaction_wheel_torque_knm,
                inertia_t_m2=vehicle.inertia_t_m2,
                throttle_time_constant_s=vehicle.throttle_time_constant_s,
                maximum_turn_rate_deg_s=vehicle.maximum_turn_rate_deg_s,
                maximum_dynamic_pressure_kpa=vehicle.maximum_dynamic_pressure_kpa,
                crash_vertical_speed_m_s=vehicle.crash_vertical_speed_m_s,
            )
            longitude = math.atan2(state.position.y, state.position.x)
            up_now = state.position.normalized
            east_now = Vec(-math.sin(longitude), math.cos(longitude), 0)
            target_pitch = (
                east_now * math.cos(math.radians(last_pitch))
                + up_now * math.sin(math.radians(last_pitch))
            )
            before_contact = row_from_state()
            aero_configuration = "clean"
            if globals_.get_value("gear") and globals_.get_value("brakes"):
                aero_configuration = "landing"
            elif globals_.get_value("gear"):
                aero_configuration = "gear"
            elif globals_.get_value("brakes"):
                aero_configuration = "airbrake"
            step_result = simulator.step(
                state,
                FlightCommand(throttle=last_throttle, target_direction=target_pitch,
                              aero_configuration=aero_configuration),
            )
            if state.crashed and impact is None:
                impact = {
                    "time": state.time,
                    "altitude_asl": before_contact["altitude"],
                    "clearance": before_contact["altitude"] - runway_altitude,
                    "vertical_speed": before_contact["vertical_speed"],
                    "airspeed": before_contact["airspeed"],
                    "contact_clearance": step_result.clearance_m,
                }
            minimum_clearance = min(minimum_clearance, state.minimum_clearance_m)
            sync_host()

        sync_host()
        route = host.call("terminal_route_init")
        route["phase"] = "final"
        route["last_phase_change_time"] = source_ut

        # Execute the actual source handoff and landing owner. FAR's force
        # query is served by the independent AnalyticAero plant below; the
        # source arrest predictor remains the checked-in KerboScript.
        reentry_source = (ROOT / "Script/Poseidon_SSTO/Poseidon_SSTO_Reentry.ks").read_text(
            encoding="utf-8-sig"
        )
        team_gear = source_block(reentry_source, 'if terminal_route["gear"]{')
        team_brakes = source_block(reentry_source, 'if terminal_route["airbrake"]{')
        handoff = source_block(reentry_source, 'if terminal_route["landing_ready"]{')
        landing = source_block(reentry_source, 'if step = "landing"{')
        contact_monitor = source_block(reentry_source, "if landing_committed_once and ")
        ground_complete = source_block(reentry_source, "function reentry_ground_complete {")
        host.kos.load_source(
            "function replay_production_team_controls {\n" + team_gear + "\n" + team_brakes + "\n}\n"
            + "function replay_production_landing_handoff {\n" + handoff + "\n}\n"
            + "function replay_production_landing_step {\n" + landing + "\n}\n"
            + "function replay_production_landing_contact_monitor {\n" + contact_monitor + "\n}\n"
            + ground_complete,
            "production_reentry_landing_blocks",
        )

        def apply_control_action(control, action):
            if control == "gear":
                globals_["gear"] = bool(action)
            elif control == "brakes":
                globals_["brakes"] = bool(action)

        host.action = apply_control_action
        globals_.update({
            "step": "TEAM",
            "terminal_route": route,
            "time": {"seconds": source_ut},
            "gear": False,
            "brakes": False,
            "dap": {
                "dap_mode": "auto",
                "str_mode": "aoa",
                "envelope": {"terrain_state": "clear"},
                "aoa": {"target_aoa": 0, "target_bank": 0, "base_pitch": 0},
                "aerostr": {"turn_pitch": 0, "turn_roll": 0, "distance_pitch": 0,
                            "turn_heading": 90, "aerostr_Roll": 0},
            },
            "landing_preflare_active": False,
            "landing_preflare_escape_since": -1,
            "landing_ground_contact_seen": False,
            "landing_committed_once": False,
            "landing_preflare_brakes": False,
            "landing_flare_started": False,
            "reentry_preserve_propulsion": False,
            "recovery_result": {"complete": False, "success": False, "reason": "running"},
            "runway_start": {"lat": 0, "lng": 0},
            "runway_end": {"lat": 0, "lng": 0},
            "update_team_dap_gui": lambda: None,
            "update_terminal_route_gui": lambda: None,
            "log_status": lambda _message: None,
            "Lastest_status": "",
        })

        def analytic_far_force(sample_altitude, sample_velocity):
            host.far_calls += 1
            host.far_samples.append((sample_altitude, sample_velocity))
            configuration = "landing" if globals_.get_value("gear") and globals_.get_value("brakes") else "clean"
            return aero.evaluate(
                body, sample_altitude, sample_velocity, state.forward, state.top,
                configuration=configuration,
            ).force

        host.far_force = analytic_far_force
        crossed_3600 = None
        landing_handoff = None
        flare_command = None
        scheduler = OpcodeScheduler(ipu=2000, tick_seconds=0.02, on_tick=physics_tick)
        host.kos.scheduler = scheduler
        try:
            for _ in range(maximum_steps):
                sync_host()
                globals_["terminal_route"] = route
                host.call("replay_production_landing_contact_monitor")
                if globals_.get_value("step") == "TEAM":
                    host.call("terminal_route_update", route)
                    host.call("terminal_route_fly", route)
                    host.call("replay_production_team_controls")
                    host.call("replay_production_landing_handoff")
                debug = globals_.get_value("terminal_route_debug")
                last_pitch = (globals_.get_value("dap")["aerostr"]["turn_pitch"]
                              + globals_.get_value("dap")["aerostr"]["distance_pitch"])
                last_throttle = globals_.get_value("dapthrottle")
                direct_distance = host.call("terminal_route_geometry")["distance"]
                measured = row_from_state()
                if initial_control is None:
                    initial_control = {
                        "phase": route["phase"], "distance": direct_distance,
                        "altitude_asl": measured["altitude"],
                        "vertical_speed": measured["vertical_speed"],
                        "desired_vertical_speed": debug["desired_vertical_speed"],
                        "profile_error": debug["profile_error"],
                        "pitch_command": last_pitch,
                        "throttle_command": last_throttle,
                        "propulsion_mode": route["propulsion_mode"],
                    }
                if crossed_3600 is None and direct_distance <= 3600:
                    profile_3600 = self.kos.call(
                        "calculate_glideslope_profile", max(0, direct_distance),
                        runway_altitude, self.gs,
                    )
                    crossed_3600 = {
                        "distance": direct_distance,
                        "altitude_asl": measured["altitude"],
                        "clearance": measured["altitude"] - runway_altitude,
                        "vertical_speed": measured["vertical_speed"],
                        "airspeed": measured["airspeed"],
                        "profile_error": profile_3600["altitude"] - measured["altitude"],
                        "phase": route["phase"],
                        "high_energy_final_active": route["high_energy_final_active"],
                        "pitch_command": last_pitch,
                        "throttle_command": last_throttle,
                    }
                if landing_handoff is None and globals_.get_value("landing_committed_once"):
                    landing_handoff = {
                        "distance": direct_distance,
                        "clearance": measured["altitude"] - runway_altitude,
                        "kind": route["landing_handoff_kind"],
                        "step_owner": globals_.get_value("step"),
                        "profile_error": debug["profile_error"],
                        "far_valid": route["pullup_far_valid"],
                        "far_age": route["pullup_far_age"],
                        "exit_margin": debug["preflare_commit_margin"],
                    }
                if globals_.get_value("step") == "landing":
                    host.call("replay_production_landing_step")
                    last_pitch = (globals_.get_value("dap")["aerostr"]["turn_pitch"]
                                  + globals_.get_value("dap")["aerostr"]["distance_pitch"])
                    last_throttle = globals_.get_value("dapthrottle")
                    if flare_command is None and globals_.get_value("landing_flare_started"):
                        flare_command = {
                            "clearance": row_from_state()["altitude"] - runway_altitude,
                            "desired_vertical_speed": debug["landing_desired_vs"],
                            "flare_fraction": debug["landing_flare_fraction"],
                            "pitch_command": last_pitch,
                            "step_owner": globals_.get_value("step"),
                        }
                profile = self.kos.call(
                    "calculate_glideslope_profile", max(0, direct_distance),
                    runway_altitude, self.gs,
                )
                profile_error = profile["altitude"] - measured["altitude"]
                if crossed_400 is None and direct_distance <= 400 and route["phase"] == "final":
                    crossed_400 = (
                        measured["altitude"], measured["vertical_speed"],
                        measured["airspeed"], profile_error,
                    )
                if crossed_threshold is None and direct_distance <= 0 and route["phase"] == "final":
                    crossed_threshold = (
                        measured["altitude"], measured["vertical_speed"],
                        measured["airspeed"], profile_error,
                    )
                if route["phase"] == "go_around" and go_around is None:
                    event_detail = next(
                        (detail for name, detail in reversed(host.events)
                         if name == "terminal_go_around"),
                        "",
                    )
                    go_around = {
                        "time": state.time, "distance": direct_distance,
                        "clearance": measured["altitude"] - runway_altitude,
                        "vertical_speed": measured["vertical_speed"],
                        "pitch_command": last_pitch, "throttle_command": last_throttle,
                        "detail": event_detail,
                    }
                scheduler.wait(0)
                measured = row_from_state()
                if state.crashed or state.landed or (go_around and measured["vertical_speed"] >= 0):
                    break
        finally:
            host.kos.scheduler = None

        return {
            "label": label, "trim_aoa_deg": trim_aoa,
            "trim_pitch_deg": initial_pitch,
            "crashed": state.crashed, "landed": state.landed,
            "minimum_clearance_m": minimum_clearance,
            "go_around": go_around, "crossed_400": crossed_400,
            "crossed_threshold": crossed_threshold,
            "crossed_3600": crossed_3600,
            "initial_control": initial_control,
            "landing_handoff": landing_handoff,
            "flare_command": flare_command,
            "impact": impact,
            "terminal_phase": route["phase"], "final_time_s": state.time,
            "final_step_owner": globals_.get_value("step"),
            "final_landing_preflare_active": globals_.get_value("landing_preflare_active"),
            "final_vertical_speed_mps": row_from_state()["vertical_speed"],
            "final_altitude_asl_m": row_from_state()["altitude"],
            "initial_pitch_deg": initial_pitch,
            "trimmed_pitch_deg": trimmed_pitch,
            "maximum_turn_rate_deg_s": simulator.vehicle.maximum_turn_rate_deg_s,
            "opcodes": scheduler.profile().total_opcodes,
            "physics_updates": scheduler.profile().physics_updates,
            "elapsed_physics_s": scheduler.profile().elapsed_time,
            "max_opcodes_per_update": scheduler.profile().max_opcodes_in_update,
            "events": list(host.events),
            "far_query_count": host.far_calls,
            "far_last_query": ({
                "altitude": host.far_samples[-1][0],
                "velocity": [host.far_samples[-1][1].x,
                             host.far_samples[-1][1].y,
                             host.far_samples[-1][1].z],
            } if host.far_samples else None),
            "aero": aero.__class__.__name__, "reference_area_m2": aero.reference_area,
            "body": body.name, "physics_dt_s": simulator.dt,
            "rapier_count": rapier_count, "closed_cycle_thrust_kn": rapier_thrust,
            "closed_cycle_isp_s": rapier_isp,
            "air_mode_thrust_model": "zero; no independent air-breathing calibration available",
        }

    def test_physical_approach_runs_source_handoff_and_records_plant_diagnostics(self):
        heavy_profile = self.kos.call("calculate_glideslope_profile", 3800, 0, self.gs)
        preflare_profile = self.kos.call("calculate_glideslope_profile", 3600, 0, self.gs)
        steady_trim = self._steady_glide_trim(
            stock_body("kerbin"), AnalyticAero(),
            heavy_profile["altitude"], 149.0, 46.70,
        )
        self.assertAlmostEqual(steady_trim["tangent_acceleration"], 0, delta=0.05)
        self.assertAlmostEqual(steady_trim["normal_acceleration"], 0, delta=0.05)
        self.assertLess(steady_trim["pitch_deg"], 0)
        cases = (
            # Recorded flight 407 high-profile state, converted from ASL to
            # runway-relative clearance without altering its speed or mass.
            ("407_high_profile_miss", 1270.20, 1570.8842 - 1183.0,
             -13.8658, 118.3933, 37.4518, 1183.0, None, None),
            # 46.7 t approach on the source glideslope, with the recorded
            # 149 m/s speed and mass-dependent steep-profile sink rate.
            ("heavy_steep_profile", 3800.0, heavy_profile["altitude"],
             -149 * self.gs["angle1"], 149.0, 46.70, 0.0, None, None),
            # Flight 415 measured 827 m runway clearance at 3.584 km, 133.2
            # m/s, -33.96 m/s, 37.45 t, and -4.6 deg actual pitch. Its pitch
            # rose only 6.6 deg in 4.5 s after a 25 deg command; cap this plant
            # at the observed 1.5 deg/s to test the new lower reference.
            ("415_measured_entry", 3584.0, 827.3, -33.96, 133.2, 37.45, 0.0,
             -4.6, 1.5),
            # Sweep both ends of the 130-150 m/s band for nominal and heavy
            # masses, with the same conservative measured pitch response.
            ("curve_130_light", 3600.0, preflare_profile["altitude"],
             -130 * self.gs["angle1"], 130.0, 37.5, 0.0, None, 1.5),
            ("curve_150_light", 3600.0, preflare_profile["altitude"],
             -150 * self.gs["angle1"], 150.0, 37.5, 0.0, None, 1.5),
            ("curve_130_heavy", 3600.0, preflare_profile["altitude"],
             -130 * self.gs["angle1"], 130.0, 46.7, 0.0, None, 1.5),
            ("curve_150_heavy", 3600.0, preflare_profile["altitude"],
             -150 * self.gs["angle1"], 150.0, 46.7, 0.0, None, 1.5),
        )
        diagnostics = []
        for (label, distance, clearance, vertical_speed, airspeed, mass, runway_altitude,
             initial_pitch, maximum_turn_rate) in cases:
            with self.subTest(case=label):
                result = self._run_independent_terminal_case(
                    label, distance, clearance, vertical_speed,
                    airspeed, mass, runway_altitude,
                    initial_pitch_override=initial_pitch,
                    maximum_turn_rate_deg_s=maximum_turn_rate,
                )
                self.assertEqual(result["physics_dt_s"], 0.02)
                self.assertEqual(result["aero"], "AnalyticAero")
                self.assertLessEqual(result["max_opcodes_per_update"], 2000)
                self.assertIsNotNone(result["initial_control"])
                self.assertGreater(result["far_query_count"], 0)
                if result["landing_handoff"] is not None:
                    self.assertEqual(result["landing_handoff"]["kind"], "preflare")
                    self.assertEqual(result["landing_handoff"]["step_owner"], "landing")
                    self.assertTrue(any(name == "landing_handoff" for name, _ in result["events"]))
                    self.assertTrue(result["landing_handoff"]["far_valid"])
                    self.assertLessEqual(
                        result["landing_handoff"]["far_age"],
                        self.config["PreflareCommit"]["maximum_far_age"],
                    )
                    self.assertGreaterEqual(
                        result["landing_handoff"]["exit_margin"],
                        self.config["PreflareCommit"]["minimum_exit_margin"],
                    )
                if result["go_around"] is not None:
                    # Validate source ownership and requested power only. This
                    # plant has no calibrated air-breathing thrust, so its
                    # subsequent clearance is diagnostic, not a flight contract.
                    self.assertEqual(result["final_step_owner"], "TEAM")
                    self.assertGreater(result["go_around"]["throttle_command"], 0)
                    self.assertIn("terminal_go_around", [name for name, _ in result["events"]])
                if result["flare_command"] is not None:
                    landing = landing_config()
                    self.assertEqual(result["flare_command"]["step_owner"], "landing")
                    self.assertAlmostEqual(result["flare_command"]["clearance"], 35, delta=1)
                    self.assertGreaterEqual(result["flare_command"]["flare_fraction"], 0)
                    self.assertLessEqual(result["flare_command"]["flare_fraction"], 1)
                    self.assertGreaterEqual(
                        result["flare_command"]["pitch_command"], landing["minimum_turn_pitch"]
                    )
                    self.assertLessEqual(
                        result["flare_command"]["pitch_command"], landing["maximum_turn_pitch"]
                    )
                diagnostics.append(result)

        self.assertTrue(
            any(result["flare_command"] is not None for result in diagnostics),
            "the integrated source replay must exercise the production 35 m flare",
        )

        # Flight 415's first final sample starts on the recorded source path,
        # before the old-curve 3.584 km snapshot. The planar plant holds the
        # ground track aligned and preserves the recorded pitch response limit;
        # it does not assume whether the new reference is captured.
        result_415 = self._run_independent_terminal_case(
            "415_final_entry_counterfactual",
            16544.59, 5096.67, -49.557, 138.89375, 37.45, 1188.0,
            initial_pitch_override=-7.8607,
            maximum_turn_rate_deg_s=1.5,
            maximum_steps=6000,
            source_ut=309975.396,
        )
        self.assertIsNotNone(result_415["initial_control"])
        self.assertGreater(result_415["far_query_count"], 0)
        diagnostics.append(result_415)

        result_path = ROOT / "tools/pos_sim/results/terminal_guidance_physics_diagnostics.json"
        result_path.parent.mkdir(parents=True, exist_ok=True)
        capture = result_415["crossed_3600"]
        capture_by_3600 = capture is not None and abs(capture["profile_error"]) <= 500
        result_path.write_text(json.dumps({
            "contract": (
                "Source command, FAR-gate, and landing-owner checks use production .ks blocks. "
                "AnalyticAero is an approximate independent plant and FAR query service; "
                "air-mode thrust is zero. Clearance, impact, and capture outcomes after a "
                "powered go-around are diagnostics, not powered-flight assertions."
            ),
            "flight_415_counterfactual": {
                "captures_new_reference_by_3600m": capture_by_3600,
                "finding": None if capture_by_3600 else (
                    "The source path remained more than 500 m above the new reference at 3.6 km."
                    if capture is not None else
                    "The source path did not reach 3.6 km before its terminal event."
                ),
                "evidence_at_3600m": capture,
                "initial_control": result_415["initial_control"],
                "impact": result_415["impact"],
                "limitation": "Aligned-track AnalyticAero plant with zero air-mode thrust; a source-path diagnostic, not KSP/FAR validation.",
            },
            "cases": diagnostics,
        }, indent=2) + "\n", encoding="utf-8")

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
        steering_source = function_source(logger, "flight_log_landing_steering_columns")
        default_steering_source = steering_source.replace(
            "if not(defined steeringmanager) {", "if true {", 1
        )
        self.assertIn("global POS_LOG_SCHEMA_VERSION is 36.", logger.read_text())
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
            + "\n" + default_steering_source + "\n" + column_source,
            "terminal_logger_fields",
        )
        logger_runtime.kos.globals.get_value("terminal_route_debug")["propulsion_mode"] = "closed"
        header = logger_runtime.call("flight_log_terminal_energy_header").split(",")[1:]
        values = logger_runtime.call("flight_log_terminal_energy_columns").split(",")[1:]
        self.assertEqual(len(header), 66)
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
        self.assertIn("terminal_landing_handoff_kind", header)
        self.assertIn("terminal_preflare_commit_stable", header)
        self.assertIn("terminal_preflare_commit_margin", header)
        self.assertIn("terminal_landing_preflare_active", header)
        self.assertIn("terminal_landing_pullup_active", header)
        self.assertIn("terminal_landing_pullup_margin", header)
        self.assertIn("terminal_landing_pullup_response_delay", header)
        self.assertIn("steering_manager_enabled", header)
        self.assertIn("steering_manager_target_pitch", header)
        self.assertIn("steering_manager_pitch_error", header)
        self.assertEqual(values[header.index("steering_manager_enabled")], "False")
        self.assertEqual(values[header.index("steering_manager_target_pitch")], "0")
        self.assertEqual(values[header.index("steering_manager_pitch_error")], "0")
        self.assertEqual(values[header.index("terminal_landing_pullup_active")], "False")
        self.assertEqual(values[header.index("terminal_landing_pullup_margin")], "0")
        self.assertEqual(values[header.index("terminal_landing_pullup_response_delay")], "0")
        live_steering_source = steering_source.replace(
            "if not(defined steeringmanager) {", "if false {", 1
        )
        # The compact simulator models suffix presence with lexicon:haskey.
        live_steering_source = live_steering_source.replace(":hassuffix(", ":haskey(")
        logger_runtime.kos.load_source(
            'global dap is lex("aerostr",lex("turn_pitch",-30)).\n'
            'global steeringmanager is lex("enabled",true,"target",lex("pitch",42),"pitcherror",3).\n'
            'function pitch_for { parameter vessel,target. return target["pitch"]. }\n'
            + live_steering_source + "\n" + column_source,
            "terminal_logger_live_fields",
        )
        live_debug = logger_runtime.kos.globals.get_value("terminal_route_debug")
        live_debug["landing_pullup_active"] = True
        live_debug["landing_pullup_margin"] = -6.9
        live_debug["landing_pullup_response_delay"] = 0.64
        live_values = logger_runtime.call("flight_log_terminal_energy_columns").split(",")[1:]
        self.assertEqual(live_values[header.index("terminal_landing_pullup_active")], "True")
        self.assertEqual(live_values[header.index("terminal_landing_pullup_margin")], "-6.9")
        self.assertEqual(live_values[header.index("terminal_landing_pullup_response_delay")], "0.64")
        self.assertEqual(live_values[header.index("steering_manager_enabled")], "True")
        self.assertEqual(live_values[header.index("steering_manager_target_pitch")], "42")
        self.assertEqual(live_values[header.index("steering_manager_pitch_error")], "3")


class TerminalLandingBrakeConfigTest(unittest.TestCase):
    def test_committed_configuration_releases_at_speed_boundary_and_stays_latched(self):
        helper = Runtime(function_source(LIB / "terminal_route.ks", "terminal_landing_config_brake"))
        config = terminal_config()
        scale = 1.0
        threshold = (config["LandingCommit"]["minimum_speed"] +
                     config["PreflareCommit"]["brake_release_speed_margin"]) * scale

        self.assertTrue(helper.call("terminal_landing_config_brake", True,
                                    threshold + 0.01, scale, config))
        self.assertFalse(helper.call("terminal_landing_config_brake", True,
                                     threshold, scale, config))
        self.assertFalse(helper.call("terminal_landing_config_brake", True,
                                     threshold - 0.01, scale, config))
        # Once the owner clears its stored latch, speed recovery cannot re-arm it.
        self.assertFalse(helper.call("terminal_landing_config_brake", False,
                                     threshold + 20, scale, config))

        heavy_scale = 1.12
        heavy_threshold = threshold * heavy_scale
        self.assertTrue(helper.call("terminal_landing_config_brake", True,
                                    heavy_threshold + 0.01, heavy_scale, config))
        self.assertFalse(helper.call("terminal_landing_config_brake", True,
                                     heavy_threshold, heavy_scale, config))


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
        # Capability is sampled only once the source reaches an eligible final.
        self.assertEqual(len(self.calls), 0)

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

    def test_far_configuration_change_refreshes_immediately_then_bounds_settling_cadence(self):
        self.refresh()
        self.assertEqual(len(self.calls), 1)
        previous_lift = self.route["pullup_far_lift"]

        def optimistic_lift(altitude, velocity):
            self.calls.append((altitude, velocity))
            return Vec(0, 500, 0)

        self.host.far_force = optimistic_lift
        self.set_state(1000.1, brakes=True)
        self.refresh()
        self.assertTrue(self.route["pullup_far_valid"])
        self.assertEqual(len(self.calls), 2)
        self.assertAlmostEqual(self.route["pullup_far_lift"], previous_lift)

        self.set_state(1000.2, brakes=True)
        self.refresh()
        self.assertEqual(len(self.calls), 2)
        self.set_state(1000.4, brakes=True)
        self.refresh()
        self.assertEqual(len(self.calls), 3)
        self.assertAlmostEqual(self.route["pullup_far_lift"], previous_lift)

        self.set_state(1001.9, brakes=True)
        self.refresh()
        self.assertTrue(self.route["pullup_far_valid"])
        self.assertEqual(len(self.calls), 4)
        self.set_state(1002.2, brakes=True)
        self.refresh()
        self.assertTrue(self.route["pullup_far_valid"])
        self.assertEqual(len(self.calls), 4)
        self.set_state(1003.0, brakes=True)
        self.refresh()
        self.assertEqual(len(self.calls), 5)
        self.assertGreater(self.route["pullup_far_lift"], previous_lift)

    def test_ineligible_or_missing_far_suffix_invalidates_cached_sample(self):
        self.refresh()
        self.assertTrue(self.route["pullup_far_valid"])
        self.assertEqual(len(self.calls), 1)
        self.refresh(eligible=False)
        self.assertFalse(self.route["pullup_far_valid"])
        self.assertEqual(len(self.calls), 1)

        self.set_state(1000.1)
        self.host.kos.globals["addons"] = {"available": lambda name: True,
            "far": {"hassuffix": lambda suffix: False}}
        self.refresh()
        self.assertFalse(self.route["pullup_far_valid"])
        self.assertEqual(len(self.calls), 1)


class TerminalPreflareCommitSourceReplayTest(unittest.TestCase):
    """Replay frozen approach samples with their recorded profile configuration."""

    def setUp(self):
        self.host = EnergyReplay()
        globals_ = self.host.kos.globals
        self.config = terminal_config()
        globals_.get_value("aves")["Landing"] = landing_config()
        self.samples = (
            {
                "ut": 310070.903261203, "latitude": -6.05469463184998,
                "longitude": 99.7636393238406, "altitude": 1469.32063921622,
                "radar_altitude": 288.720336914063,
                "airspeed": 131.664339286806, "surface_speed": 131.664339286805,
                "vertical_speed": -34.1044303997754, "mass": 37.5175666809082,
                "runway_start_latitude": -6.02376054801774,
                "runway_start_longitude": 99.6216145281208,
                "runway_heading": 282.284017498376, "runway_altitude": 1188,
                "roll": -0.0247484282116475, "aoa_actual": 9.65818979805836,
                "terminal_pullup_far_lift": 697.480326815725,
                "terminal_runway_heading_error": -0.117128822424945,
            },
            {
                "ut": 310071.223261203, "latitude": -6.05386292457728,
                "longitude": 99.7598352657984, "altitude": 1458.4713871089,
                "radar_altitude": 277.878173828125,
                "airspeed": 131.440630967101, "surface_speed": 131.440630967101,
                "vertical_speed": -33.9984563087382, "mass": 37.5175666809082,
                "runway_start_latitude": -6.02376054801774,
                "runway_start_longitude": 99.6216145281208,
                "runway_heading": 282.284017498376, "runway_altitude": 1188,
                "roll": -0.0415588190455143, "aoa_actual": 9.85193621022492,
                "terminal_pullup_far_lift": 697.480326815725,
                "terminal_runway_heading_error": -0.115907591865835,
            },
            {
                "ut": 310071.523261203, "latitude": -6.05308435099959,
                "longitude": 99.7562737170747, "altitude": 1448.33999012003,
                "radar_altitude": 267.720275878906,
                "airspeed": 131.268570859463, "surface_speed": 131.268570859463,
                "vertical_speed": -33.8482178735264, "mass": 37.5175666809082,
                "runway_start_latitude": -6.02376054801774,
                "runway_start_longitude": 99.6216145281208,
                "runway_heading": 282.284017498376, "runway_altitude": 1188,
                "roll": -0.0644526744855002, "aoa_actual": 10.0132728167649,
                "terminal_pullup_far_lift": 697.480326815725,
                "terminal_runway_heading_error": -0.114227389306052,
            },
        )
        self.far_lift = 0.0

        def recorded_far_force(_altitude, velocity):
            # The CSV stores the source's signed FAR lift projection (kN),
            # not the force vector. Reconstruct only its vector direction in
            # the sampled body basis; preserve the recorded magnitude and the
            # live query speed instead of inventing an 800 kN force.
            top = Vec(0, 1, 0)
            wind = velocity.normalized
            lift_axis = top - wind * dot(top, wind)
            self.assertAlmostEqual(velocity.mag, self.query_speed, delta=0.001)
            return lift_axis.normalized * self.far_lift

        self.query_speed = 0.0
        self.host.far_force = recorded_far_force
        self.host.kos.load_source(glideslope_source(), "real-glideslope-controllers")
        reentry_source = (ROOT / "Script/Poseidon_SSTO/Poseidon_SSTO_Reentry.ks").read_text(encoding="utf-8-sig")
        handoff = source_block(reentry_source, 'if terminal_route["landing_ready"]{')
        landing = source_block(reentry_source, 'if step = "landing"{')
        contact_monitor = source_block(reentry_source,
            'if landing_committed_once and ')
        self.host.kos.load_source(
            "function replay_production_landing_handoff {\n" + handoff + "\n}\n"
            + "function replay_production_landing_step {\n" + landing + "\n}\n"
            + "function replay_production_landing_contact_monitor {\n" + contact_monitor + "\n}\n"
            + source_block(reentry_source, "function reentry_ground_complete {"),
            "production_reentry_landing_blocks",
        )
        globals_ = self.host.kos.globals

        def apply_control_action(control, action):
            if control == "gear":
                globals_["gear"] = bool(action)
            elif control == "brakes":
                globals_["brakes"] = bool(action)

        self.host.action = apply_control_action
        globals_.update({
            "dap": {"envelope": {"terrain_state": "inhibited"}, "str_mode": "aoa",
                    "aoa": {"target_aoa": 0, "target_bank": 0, "base_pitch": 0},
                    "aerostr": {"turn_pitch": 0, "distance_pitch": 0,
                                 "turn_roll": 0, "turn_heading": 0}},
            "update_team_dap_gui": lambda: None,
            "rapierson": lambda: None,
            "togglerapiermode": lambda _mode: None,
            "nervson": lambda: None,
            "terminal_route_target_arrow_enabled": False,
            "terminal_route_target_arrow_active": False,
            "Lastest_status": "",
            "landing_preflare_active": False,
            "landing_preflare_escape_since": -1,
            "landing_ground_contact_seen": False,
            "landing_committed_once": False,
            "landing_preflare_brakes": False,
            "landing_flare_started": False,
            "runway_end": {"lat": 0, "lng": 0},
            "step": "TEAM",
        })

    def use_historical_approach_configuration(self):
        # Flights 409 and 413 used the prior 1.5 km to 400 m Hermite curve.
        # Keep those frozen samples on their recorded profile so they continue
        # to test ownership and FAR timing without claiming they joined the
        # newly lowered 3.6 km to 1 km reference.
        old_glideslope = historical_glideslope_config()
        old_route = terminal_config()
        old_route["PreflareCommit"]["distance"] = 1500
        old_route["PreflareCommit"]["maximum_height"] = 350
        old_route["PreflareCommit"]["gear_distance"] = 2200
        old_route["PreflareCommit"]["gear_height"] = 500
        aves = self.host.kos.globals.get_value("aves")
        aves["glideslope"] = old_glideslope
        aves["TerminalRoute"] = old_route
        self.config = old_route

    def _set_row(self, sample, gear, brakes, step="TEAM", overrides=None):
        row = dict(
            latitude=sample["latitude"], longitude=sample["longitude"],
            altitude=sample["altitude"], airspeed=sample["airspeed"],
            surface_speed=sample["surface_speed"], vertical_speed=sample["vertical_speed"],
            thrust=0, ut=sample["ut"], throttle_actual=0, mass=sample["mass"],
            liquidfuel=0, oxidizer=0,
            terminal_airbrake="True" if brakes else "False",
            terminal_gear="True" if gear else "False",
            terminal_runway_heading_error=sample["terminal_runway_heading_error"],
            roll=sample["roll"], aoa_actual=sample["aoa_actual"],
            runway_start_latitude=sample["runway_start_latitude"],
            runway_start_longitude=sample["runway_start_longitude"],
            runway_heading=sample["runway_heading"], runway_altitude=sample["runway_altitude"],
            terrain_height=sample["altitude"] - sample["radar_altitude"],
            status="FLYING", step=step,
        )
        if overrides:
            row.update(overrides)
        self.far_lift = sample["terminal_pullup_far_lift"]
        self.query_speed = row["airspeed"]
        self.host.set_row(row)
        ship = self.host.kos.globals.get_value("ship")
        ship["partstitledpattern"] = lambda _pattern: []
        ship["groundspeed"] = row["airspeed"]
        return row

    def test_reentry_landing_owner_releases_brakes_at_boundary_and_never_rearms(self):
        g = self.host.kos.globals
        self._set_row(self.samples[-1], True, True, step="landing")
        route = self.host.call("terminal_route_init")
        route["phase"] = "final"
        route["landing_handoff_kind"] = "preflare"
        g.update({
            "terminal_route": route,
            "step": "landing",
            "landing_preflare_active": True,
            "landing_preflare_escape_since": -1,
            "landing_ground_contact_seen": False,
            "landing_flare_started": False,
            "landing_preflare_brakes": True,
            "dapthrottle": 0,
            "brakes": True,
        })
        scale = self.host.call("terminal_mass_speed_scale", self.samples[-1]["mass"],
                               self.config)
        release_speed = (self.config["LandingCommit"]["minimum_speed"] +
                         self.config["PreflareCommit"]["brake_release_speed_margin"]) * scale

        def run_at_speed(speed, ut):
            sample = dict(self.samples[-1], ut=ut, altitude=1300,
                          radar_altitude=112, airspeed=speed,
                          surface_speed=speed, vertical_speed=-12)
            self._set_row(sample, True, True, step="landing")
            g["terminal_route"] = route
            g["step"] = "landing"
            self.host.call("replay_production_landing_step")
            return sample

        run_at_speed(release_speed + 1, self.samples[-1]["ut"] + 0.02)
        self.assertTrue(g.get_value("brakes"))
        self.assertTrue(g.get_value("landing_preflare_brakes"))
        hold_events = [detail for name, detail in self.host.events
                       if name == "approach_brake" and "landing_config_hold" in detail]
        self.assertTrue(hold_events)

        run_at_speed(release_speed, self.samples[-1]["ut"] + 0.04)
        self.assertFalse(g.get_value("brakes"))
        self.assertFalse(g.get_value("landing_preflare_brakes"))

        run_at_speed(release_speed + 20, self.samples[-1]["ut"] + 0.06)
        self.assertFalse(g.get_value("brakes"))
        self.assertFalse(g.get_value("landing_preflare_brakes"))

    def test_route_init_logs_the_live_final_profile_geometry(self):
        self._set_row(self.samples[-1], False, False)
        self.host.call("terminal_route_init")
        profile_events = [detail for name, detail in self.host.events
                          if name == "terminal_profile_config"]
        self.assertEqual(len(profile_events), 1)
        for expected in (
            "steep_gradient=0.268",
            "shallow_gradient=0.0524077793",
            "preflare_start=3600",
            "preflare_end=1000",
            "shallow_aimpoint=875",
        ):
            self.assertIn(expected, profile_events[0])
        self.assertIn("steep_intercept=1679.12", profile_events[0])

    def test_contact_during_go_around_reclaims_landing_before_dap_and_latches_bounce(self):
        reentry_source = (ROOT / "Script/Poseidon_SSTO/Poseidon_SSTO_Reentry.ks").read_text(
            encoding="utf-8-sig"
        )
        contact_start = reentry_source.index(
            'if landing_committed_once and '
        )
        dap_update = reentry_source.index("dap:update()", contact_start)
        self.assertLess(contact_start, dap_update)

        g = self.host.kos.globals
        g.update({
            "dap": {"dap_mode": "auto"},
            "landing_committed_once": True,
            "landing_ground_contact_seen": False,
            "landing_preflare_active": True,
            "landing_preflare_brakes": False,
            "landing_preflare_escape_since": 310100,
            "step": "TEAM",
            "dapthrottle": 0.6,
            "brakes": False,
            "terminal_route_debug": {
                "landing_preflare_active": True,
                "landing_pullup_active": True,
            },
        })
        self._set_row(self.samples[-1], True, False, step="TEAM",
                      overrides={"status": "LANDED"})
        self.host.call("replay_production_landing_contact_monitor")
        self.assertEqual(g.get_value("step"), "landing")
        self.assertTrue(g.get_value("landing_ground_contact_seen"))
        self.assertFalse(g.get_value("landing_preflare_active"))
        self.assertFalse(g.get_value("terminal_route_debug")["landing_preflare_active"])
        self.assertFalse(g.get_value("terminal_route_debug")["landing_pullup_active"])
        self.assertEqual(g.get_value("dapthrottle"), 0)
        self.assertTrue(g.get_value("brakes"))
        contact_events = [detail for name, detail in self.host.events
                          if name == "landing_contact_after_escape"]
        self.assertEqual(len(contact_events), 1)
        self.assertIn("from=TEAM", contact_events[0])

        # A later airborne sample is the bounce case. The latched contact
        # keeps this controller in rollout with power cut and brakes applied.
        self._set_row(self.samples[-1], True, False, step="TEAM",
                      overrides={"status": "FLYING", "vertical_speed": 4})
        g["step"] = "landing"
        g["dapthrottle"] = 0.5
        g["brakes"] = False
        self.host.call("replay_production_landing_contact_monitor")
        self.assertEqual(g.get_value("step"), "landing")
        self.assertTrue(g.get_value("landing_ground_contact_seen"))
        self.assertEqual(g.get_value("dapthrottle"), 0)
        self.assertTrue(g.get_value("brakes"))
        self.assertEqual(len([name for name, _ in self.host.events
                              if name == "landing_contact_after_escape"]), 1)

        # Once the pilot selects manual DAP, contact must not reclaim landing
        # control or alter their throttle and brake commands.
        g.update({
            "dap": {"dap_mode": "manual"},
            "landing_ground_contact_seen": False,
            "landing_preflare_active": True,
            "terminal_route_debug": {
                "landing_preflare_active": True,
                "landing_pullup_active": True,
            },
            "step": "TEAM",
            "dapthrottle": 0.6,
            "brakes": False,
        })
        self._set_row(self.samples[-1], True, False, step="TEAM",
                      overrides={"status": "LANDED"})
        self.host.call("replay_production_landing_contact_monitor")
        self.assertEqual(g.get_value("step"), "TEAM")
        self.assertFalse(g.get_value("landing_ground_contact_seen"))
        self.assertEqual(g.get_value("dapthrottle"), 0.6)
        self.assertFalse(g.get_value("brakes"))
        self.assertEqual(len([name for name, _ in self.host.events
                              if name == "landing_contact_after_escape"]), 1)

    def test_flight_409_source_update_and_reentry_handoff_precede_old_sink_escape(self):
        self.use_historical_approach_configuration()
        route = None
        commanded_gear = False
        commanded_brakes = False
        for sample in self.samples:
            self._set_row(sample, commanded_gear, commanded_brakes)
            if route is None:
                route = self.host.call("terminal_route_init")
                # This frozen trace begins after the recorded route has
                # already joined final; retain that observed state.
                route["phase"] = "final"
                route["last_phase_change_time"] = sample["ut"]
            self.host.call("terminal_route_update", route)
            commanded_gear = route["gear"]
            commanded_brakes = route["airbrake"]

        self.assertTrue(route["landing_ready"])
        self.assertEqual(route["landing_handoff_kind"], "preflare")
        self.assertTrue(route["pullup_far_valid"])
        self.assertLessEqual(self.samples[-1]["ut"] - route["pullup_far_time"], 1.5)
        self.assertGreaterEqual(self.host.kos.globals.get_value("terminal_route_debug")["preflare_commit_margin"], 15)
        self.assertLess(route["geometry"]["distance"], 1500)
        self.assertGreater(route["geometry"]["altitude"], 75)
        self.assertLess(route["geometry"]["altitude"], 350)
        self.assertEqual(route["profile_region"], "preflare")
        self.assertGreaterEqual(route["preflare_stable_since"], self.samples[-2]["ut"])

        g = self.host.kos.globals
        g["terminal_route"] = route
        g["step"] = "TEAM"
        # Reentry calls route.update, then route.fly, then checks the handoff
        # in this same tick. Keep the production guidance command in between.
        self.host.call("terminal_route_fly", route)
        route_pitch = g.get_value("terminal_route_debug")["pitch_bias"]
        route_target_vs = g.get_value("terminal_route_debug")["desired_vertical_speed"]
        self.assertLess(route_target_vs, -25)
        self.host.call("replay_production_landing_handoff")
        self.assertEqual(g.get_value("step"), "landing")
        self.assertTrue(g.get_value("landing_preflare_active"))
        handoff_events = [detail for name, detail in self.host.events if name == "landing_handoff"]
        self.assertTrue(handoff_events)
        self.assertIn("kind=preflare", handoff_events[-1])
        self.assertIn("target_vertical_speed=-", handoff_events[-1])

        # Run the exact landing-owner block from Reentry. Its pitch command
        # must pull harder than the existing gentle terminal tracking law,
        # while its sink target remains on the curved approach reference.
        sample = self.samples[-1]
        self._set_row(sample, True, commanded_brakes, step="landing")
        g["terminal_route"] = route
        g["step"] = "landing"
        self.host.call("replay_production_landing_step")
        landing_debug = g.get_value("terminal_route_debug")
        landing_pitch = g.get_value("dap")["aerostr"]["turn_pitch"]
        self.assertGreater(landing_pitch, route_pitch)
        self.assertGreater(landing_debug["landing_desired_vs"], -35)
        self.assertLess(landing_debug["landing_desired_vs"], -10)
        self.assertTrue(g.get_value("landing_preflare_active"))
        self.assertEqual(g.get_value("dap")["aerostr"]["distance_pitch"], 0)

        # Follow the actual shallow segment before reaching the existing 35 m
        # flare. Position is placed on the recorded runway centreline so the
        # production geometry and profile both enter the shallow region.
        runway = {"lat": sample["runway_start_latitude"],
                  "lng": sample["runway_start_longitude"]}
        shallow_position = destination(runway, sample["runway_heading"] + 180, 200)
        shallow_candidate = dict(
            sample, ut=sample["ut"] + 0.02,
            latitude=shallow_position["lat"], longitude=shallow_position["lng"],
            vertical_speed=-6.8,
        )
        self._set_row(shallow_candidate, True, False, step="landing")
        g["terminal_route"] = route
        shallow_geometry = self.host.call("terminal_route_geometry")
        shallow_profile = self.host.call(
            "calculate_glideslope_profile", shallow_geometry["distance"], sample["runway_altitude"],
            g.get_value("aves")["glideslope"],
        )
        shallow_height = shallow_profile["altitude"] - sample["runway_altitude"]
        shallow_sample = dict(
            shallow_candidate,
            altitude=shallow_profile["altitude"], radar_altitude=shallow_height,
        )
        self._set_row(shallow_sample, True, False, step="landing")
        g["terminal_route"] = route
        g["step"] = "landing"
        self.host.call("replay_production_landing_step")
        measured_shallow_profile = self.host.call(
            "calculate_glideslope_profile", shallow_geometry["distance"],
            sample["runway_altitude"], g.get_value("aves")["glideslope"],
        )
        shallow_command = self.host.call("terminal_final_profile_command",
            shallow_geometry["distance"], shallow_sample["altitude"],
            math.sqrt(max(0, shallow_sample["surface_speed"] ** 2
                          - shallow_sample["vertical_speed"] ** 2))
            * max(0, math.cos(math.radians(shallow_geometry["heading_error"]))),
            shallow_sample["mass"],
            self.config, g.get_value("aves")["glideslope"],
            sample["runway_altitude"], True)
        shallow_debug = g.get_value("terminal_route_debug")
        self.assertEqual(measured_shallow_profile["region"], "shallow")
        self.assertTrue(g.get_value("landing_preflare_active"))
        self.assertAlmostEqual(shallow_debug["landing_desired_vs"],
                               shallow_command["desired_vs"], places=6)
        self.assertLess(shallow_debug["landing_desired_vs"], -5)
        self.assertGreater(shallow_debug["landing_desired_vs"], -8)

        # The same production block switches to the existing 35 m flare law.
        flare_sample = dict(shallow_sample, ut=shallow_sample["ut"] + 0.02,
                            altitude=1220, radar_altitude=32, vertical_speed=-8)
        self._set_row(flare_sample, True, False, step="landing")
        g["terminal_route"] = route
        g["step"] = "landing"
        self.host.call("replay_production_landing_step")
        flare_debug = g.get_value("terminal_route_debug")
        self.assertFalse(g.get_value("landing_preflare_active"))
        self.assertGreaterEqual(flare_debug["landing_desired_vs"], -7)
        self.assertLessEqual(flare_debug["landing_desired_vs"], -0.7)
        self.assertTrue(g.get_value("landing_flare_started"))

        # Contact latches out preflare even if the vessel later bounces airborne.
        contact_sample = dict(flare_sample, ut=flare_sample["ut"] + 0.02,
                              altitude=1230, vertical_speed=-3)
        self._set_row(contact_sample, True, False, step="landing",
                      overrides={"status": "LANDED"})
        ship = g.get_value("ship")
        ship["groundspeed"] = 2
        g["terminal_route"] = route
        g["step"] = "landing"
        self.host.call("replay_production_landing_step")
        self.assertTrue(g.get_value("landing_ground_contact_seen"))
        self.assertFalse(g.get_value("landing_preflare_active"))
        bounce_sample = dict(contact_sample, ut=contact_sample["ut"] + 0.02,
                             altitude=1230, vertical_speed=-3)
        self._set_row(bounce_sample, True, False, step="landing")
        g["terminal_route"] = route
        g["step"] = "landing"
        self.host.call("replay_production_landing_step")
        self.assertFalse(g.get_value("landing_preflare_active"))
        self.assertEqual(g.get_value("dapthrottle"), 0)

    def test_flight_413_measured_far_pullup_credit_prevents_old_escape_then_keeps_escape_protection(self):
        self.use_historical_approach_configuration()
        # These are frozen flight-413 measurements. `terminal_pullup_far_lift`
        # is the logger's measured signed FAR lift projection (kN); _set_row
        # reconstructs only its vector direction for the source query, without
        # inventing a force magnitude or simulating touchdown.
        samples = (
            {
                "ut": 310060.099130421, "latitude": -6.04500295251084,
                "longitude": 99.7204197873211, "altitude": 1357.46652466699,
                "radar_altitude": 176.980804443359, "airspeed": 130.361121602673,
                "surface_speed": 130.370555432328, "vertical_speed": -26.4774542575662,
                "mass": 37.4979858398438, "runway_start_latitude": -6.02376054801774,
                "runway_start_longitude": 99.6216145281208, "runway_heading": 282.284017498376,
                "runway_altitude": 1188, "roll": 0.0232062312048883,
                "aoa_actual": 11.217536781756, "terminal_pullup_far_lift": 661.628535394248,
                "terminal_runway_heading_error": 0.225925700105449,
            },
            {
                "ut": 310060.619130421, "latitude": -6.04362744226416,
                "longitude": 99.7139654108969, "altitude": 1343.40086047305,
                "radar_altitude": 162.929946899414, "airspeed": 130.119494506201,
                "surface_speed": 130.128767302561, "vertical_speed": -25.8363620408329,
                "mass": 37.4979858398438, "runway_start_latitude": -6.02376054801774,
                "runway_start_longitude": 99.6216145281208, "runway_heading": 282.284017498376,
                "runway_altitude": 1188, "roll": 0.0137501842508427,
                "aoa_actual": 11.1961278764819, "terminal_pullup_far_lift": 660.333279686667,
                "terminal_runway_heading_error": 0.225925700105449,
            },
            {
                # The go-around event was logged between flight samples. This
                # row preserves its recorded 135.6 m runway clearance and
                # -24.4 m/s sink while interpolating position between adjacent
                # measured samples. FAR lift is the nearest preceding sample.
                "ut": 310061.459130422, "latitude": -6.041540502373305,
                "longitude": 99.70417731690595, "altitude": 1323.6,
                "radar_altitude": 142.6, "airspeed": 129.62, "surface_speed": 129.62,
                "vertical_speed": -24.4, "mass": 37.4979820251465,
                "runway_start_latitude": -6.02376054801774,
                "runway_start_longitude": 99.6216145281208,
                "runway_heading": 282.284017498376, "runway_altitude": 1188,
                "roll": 0.0087, "aoa_actual": 12.15,
                "terminal_pullup_far_lift": 656.212098626414,
                "terminal_runway_heading_error": 0.225925700105449,
            },
        )
        route = None
        guidance = []
        for index, sample in enumerate(samples):
            self._set_row(sample, True, False, step="landing")
            if route is None:
                route = self.host.call("terminal_route_init")
                route["phase"] = "final"
                route["landing_handoff_kind"] = "preflare"
                self.host.kos.globals["terminal_route"] = route
            guidance.append(self.host.call("terminal_landing_preflare_guidance", route))

            debug = self.host.kos.globals.get_value("terminal_route_debug")
            self.assertTrue(debug["landing_pullup_active"])
            self.assertLessEqual(debug["landing_pullup_response_delay"],
                                 self.config["PreflarePrediction"]["response_delay_seconds"] + 0.1)
            if index == 0:
                self.assertLess(guidance[-1]["exit_margin"],
                                self.config["PreflareCommit"]["minimum_exit_margin"])
                self.assertGreaterEqual(route["landing_pullup_since"], 0)
                self.assertAlmostEqual(route["landing_pullup_since"], sample["ut"])
                check = self.host.call("terminal_route_preflare_commit_check", route)
                self.assertGreaterEqual(guidance[-1]["desired_vs"], check["target_vertical_speed"])
                self.assertGreater(guidance[-1]["desired_vs"], sample["vertical_speed"] + 15)
                pitch = self.host.call("terminal_landing_pitch_command",
                    guidance[-1]["desired_vs"], sample["vertical_speed"], landing_config())
                self.assertEqual(pitch, landing_config()["maximum_turn_pitch"])
            elif index == 1:
                self.assertLess(debug["landing_pullup_response_delay"],
                                self.config["PreflarePrediction"]["response_delay_seconds"])

        # At the historical 310061.459 go-around location the full two-second
        # predictor is still negative, but the staged response-time allowance
        # leaves margin and does not repeatedly escape from an aligned path.
        old_escape = guidance[-1]
        debug = self.host.kos.globals.get_value("terminal_route_debug")
        self.assertAlmostEqual(old_escape["profile_error"], -5.0, delta=1)
        self.assertLess(old_escape["exit_margin"], 0)
        self.assertGreater(old_escape["pullup_margin"], 0)
        self.assertLess(old_escape["response_delay"], 0.8)
        self.assertFalse(old_escape["unsafe"])
        self.assertGreater(debug["landing_pullup_margin"], 0)
        starts = [detail for name, detail in self.host.events if name == "landing_pullup_start"]
        self.assertEqual(len(starts), 1)
        self.assertIn("full_delay_margin=", starts[0])
        self.assertFalse(any(name == "terminal_go_around" for name, _ in self.host.events))

        # Alignment remains an independent escape guard during committed
        # pull-up, even while the credited clearance margin is positive.
        alignment_sample = dict(samples[-1], ut=samples[-1]["ut"] + 0.02,
                                terminal_runway_heading_error=16)
        self._set_row(alignment_sample, True, False, step="landing")
        alignment = self.host.call("terminal_landing_preflare_guidance", route)
        self.assertTrue(alignment["unsafe"])
        self.assertEqual(alignment["escape_reason"], "alignment")

        # A severe sink deterioration with the same measured FAR capability
        # still starts the persistence timer and hands off to the powered
        # go-around owner. This is a source stress case, not a flight replay.
        severe_sink = dict(samples[-1], ut=alignment_sample["ut"] + 0.18,
                           vertical_speed=-40, roll=samples[-1]["roll"])
        self._set_row(severe_sink, True, False, step="landing")
        g = self.host.kos.globals
        g.update({
            "terminal_route": route,
            "step": "landing",
            "landing_preflare_active": True,
            "landing_preflare_escape_since": -1,
            "landing_ground_contact_seen": False,
            "landing_flare_started": False,
            "update_terminal_route_gui": lambda: None,
            "update_team_dap_gui": lambda: None,
            "rapierson": lambda: None,
            "togglerapiermode": lambda _mode: None,
            "nervson": lambda: None,
        })
        self.host.call("replay_production_landing_step")
        self.assertEqual(g.get_value("step"), "landing")
        self.assertGreaterEqual(g.get_value("landing_preflare_escape_since"), 0)
        severe_sink["ut"] += 0.6
        self._set_row(severe_sink, True, False, step="landing")
        g["terminal_route"] = route
        g["step"] = "landing"
        g["dap"]["aoa"] = {"target_aoa": 0, "target_bank": 0, "base_pitch": 0}
        g["terminal_route_target_arrow_enabled"] = False
        g["terminal_route_target_arrow_active"] = False
        self.host.call("replay_production_landing_step")
        self.assertEqual(g.get_value("step"), "TEAM")
        self.assertEqual(route["phase"], "go_around")
        go_arounds = [detail for name, detail in self.host.events if name == "terminal_go_around"]
        self.assertTrue(go_arounds)
        self.assertIn("escape_reason=pullup_clearance", go_arounds[-1])
        self.assertIn("pullup_margin=-", go_arounds[-1])
        self.assertIn("remaining_response_delay=", go_arounds[-1])

    def test_commit_gate_rejects_missing_or_stale_far_and_gpws_pullup(self):
        config = terminal_config()
        harness = Runtime(function_source(LIB / "terminal_route.ks", "terminal_preflare_commit_decision"))
        eligible = {
            "phase": "final", "region": "preflare", "high_energy": False,
            "contact": False, "terrain_pullup": False, "gear": True,
            "distance": 1490, "along_track": 1489, "height": 275,
            "profile_error": 5.5, "cross_track": 2, "heading_error": 0.1,
            "bank": 0.1, "speed": 131, "speed_scale": 1,
            "vertical_speed": -34, "far_valid": True, "far_age": 0.3,
            "exit_margin": 52,
        }
        self.assertTrue(harness.call("terminal_preflare_commit_decision", eligible, config))
        self.assertFalse(harness.call("terminal_preflare_commit_decision",
                                     dict(eligible, far_valid=False), config))
        self.assertFalse(harness.call("terminal_preflare_commit_decision",
                                     dict(eligible, far_age=1.6), config))
        self.assertFalse(harness.call("terminal_preflare_commit_decision",
                                     dict(eligible, exit_margin=-1), config))
        self.assertFalse(harness.call("terminal_preflare_commit_decision",
                                     dict(eligible, terrain_pullup=True), config))
        for rejected in (
            {"gear": False}, {"contact": True}, {"high_energy": True},
            {"region": "shallow"}, {"vertical_speed": -46}, {"speed": 100},
        ):
            self.assertFalse(harness.call(
                "terminal_preflare_commit_decision", dict(eligible, **rejected), config
            ), rejected)

    def test_committed_preflare_escape_transfers_to_powered_team_goaround(self):
        self.use_historical_approach_configuration()
        route = None
        commanded_gear = False
        commanded_brakes = False
        for sample in self.samples:
            self._set_row(sample, commanded_gear, commanded_brakes)
            if route is None:
                route = self.host.call("terminal_route_init")
                route["phase"] = "final"
                route["last_phase_change_time"] = sample["ut"]
            self.host.call("terminal_route_update", route)
            commanded_gear = route["gear"]
            commanded_brakes = route["airbrake"]
        g = self.host.kos.globals
        g["terminal_route"] = route
        g["step"] = "TEAM"
        self.host.call("terminal_route_fly", route)
        self.host.call("replay_production_landing_handoff")
        self.assertTrue(g.get_value("landing_preflare_active"))

        # The first unsafe sample starts the source persistence timer.
        poor_path = dict(self.samples[-1], ut=self.samples[-1]["ut"] + 0.02,
                         altitude=1228, radar_altitude=40, vertical_speed=-33)
        self._set_row(poor_path, True, False, step="landing")
        g["terminal_route"] = route
        g["step"] = "landing"
        self.host.call("replay_production_landing_step")
        self.assertEqual(g.get_value("step"), "landing")
        self.assertGreaterEqual(g.get_value("landing_preflare_escape_since"), 0)

        # A persistent unsafe profile above 35 m returns ownership to TEAM in
        # the same tick; its final landing block cannot overwrite escape power.
        poor_path = dict(poor_path, ut=poor_path["ut"] + 0.6)
        self._set_row(poor_path, True, False, step="landing")
        g["terminal_route"] = route
        g["step"] = "landing"
        g["dap"]["aoa"] = {"target_aoa": 0, "target_bank": 0, "base_pitch": 0}
        g["terminal_route_target_arrow_enabled"] = False
        g["terminal_route_target_arrow_active"] = False
        g["update_terminal_route_gui"] = lambda: None
        g["update_team_dap_gui"] = lambda: None
        g["rapierson"] = lambda: None
        g["togglerapiermode"] = lambda _mode: None
        g["nervson"] = lambda: None
        self.host.call("replay_production_landing_step")
        self.assertEqual(g.get_value("step"), "TEAM")
        self.assertEqual(route["phase"], "go_around")
        self.assertEqual(route["go_around_reason"], "committed_preflare_unstable")
        self.assertEqual(route["propulsion_mode"], "air")
        self.assertEqual(route["recovery_throttle_floor"], self.config["GoAround"]["recovery_throttle"])
        self.assertEqual(g.get_value("dapthrottle"), self.config["GoAround"]["recovery_throttle"])
        self.assertTrue(any(name == "terminal_go_around" and
                            "committed_preflare_unstable" in detail
                            for name, detail in self.host.events))


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
