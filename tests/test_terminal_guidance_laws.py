"""Real-KerboScript regression tests for terminal descent safety laws."""
from pathlib import Path
import math
import re
import unittest

from tools.pos_sim.kos_runtime import OpcodeScheduler, Runtime
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


class TerminalGuidanceLawTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        route = LIB / "terminal_route.ks"
        aero = ROOT / "Script/Libraries/lib_aerostr.ks"
        names = (
            "terminal_mass_speed_scale",
            "terminal_sink_arrest_prediction",
            "terminal_preflare_predictive_fraction",
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
            + function_source(aero, "calculate_glideslope_pitch_command")
            + "\n"
            + function_source(aero, "calculate_preflare_pullup_command")
        )
        cls.config = terminal_config()

    def test_heavy_fast_aircraft_gets_earlier_predictive_pullup(self):
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

        prediction = self.kos.call(
            "terminal_preflare_predictive_fraction",
            -38, -8, 3800, 1500, 400, 149, 46.73, 149, self.config,
        )
        self.assertGreater(prediction["fraction"], 0)
        self.assertLess(prediction["fraction"], 1)
        steep_untriggered = self.kos.call(
            "calculate_preflare_pullup_command", "steep", 14, 0, 5, 15, 20, 0,
        )
        steep_triggered = self.kos.call(
            "calculate_preflare_pullup_command", "steep", 14, 0, 5, 15, 20,
            prediction["pitch_floor_fraction"],
        )
        self.assertFalse(steep_untriggered["active"])
        self.assertAlmostEqual(steep_triggered["fraction"], prediction["pitch_floor_fraction"])
        pullup = self.kos.call(
            "calculate_preflare_pullup_command",
            "steep", 0, -8, 5, 15, 20, prediction["pitch_floor_fraction"],
        )
        self.assertTrue(pullup["active"])
        self.assertGreater(pullup["command"], 0)

    def test_preview_blends_continuously_across_preflare_start(self):
        distances = tuple(range(2500, 399, -200)) + tuple(range(400, -1, -25))
        fractions = [self.kos.call(
            "terminal_preflare_predictive_fraction", -6.5, -6.5, distance,
            1500, 400, 125, 36, 125, self.config,
        )["fraction"] for distance in distances]
        self.assertEqual(fractions[0], 0)
        self.assertGreater(fractions[1], 0)
        self.assertGreater(fractions[4], 0)
        self.assertGreater(fractions[5], fractions[4])
        self.assertAlmostEqual(fractions[distances.index(400)], 1)
        self.assertAlmostEqual(fractions[-1], 0)
        self.assertTrue(all(abs(later-earlier) < 0.12
                            for earlier, later in zip(fractions, fractions[1:])))
        self.assertTrue(any(distance > 1500 and fraction > 0
                            for distance, fraction in zip(distances, fractions)))
        self.assertTrue(any(distance < 1500 and fraction > 0
                            for distance, fraction in zip(distances, fractions)))

    def test_recovered_shallow_sink_keeps_guidance_preview_without_a_pitch_floor(self):
        for distance, region in ((1500, "preflare"), (1000, "preflare"),
                                 (400, "shallow"), (200, "shallow")):
            prediction = self.kos.call(
                "terminal_preflare_predictive_fraction", -6.5, -6.5, distance,
                1500, 400, 125, 36, 125, self.config,
            )
            self.assertGreater(prediction["fraction"], 0)
            self.assertEqual(prediction["pitch_floor_fraction"], 0)
            command = self.kos.call(
                "calculate_preflare_pullup_command", region, 0, -2, 5, 15, 20,
                prediction["pitch_floor_fraction"],
            )
            self.assertEqual(command["command"], -2)
            self.assertFalse(command["active"])
        at_shallow_start = self.kos.call(
            "terminal_preflare_predictive_fraction", -6.5, -6.5, 400,
            1500, 400, 125, 36, 125, self.config,
        )
        self.assertAlmostEqual(at_shallow_start["fraction"], 1)

    def test_independent_delayed_response_stays_above_clearance_for_light_and_heavy_cases(self):
        def integrate(mass, airspeed, initial_vs):
            target_vs = -airspeed * 0.0524077793
            dt = 0.1
            delay = 2.0 + max(0, mass / self.config["max_landing_mass"] - 1)
            delayed = [-8.0] * int(round(delay / dt))
            distance = 5200.0
            # Start on the independent steep glide path (the production
            # planner's geometry is not reused by this plant model).
            altitude = distance * 0.268
            vertical_speed = initial_vs
            min_altitude = altitude
            desired_history = []
            while distance > 400:
                gradient_fraction = max(0, min(1, (1500-distance)/1100))
                gradient = 0.268 + (0.0524077793-0.268)*gradient_fraction
                normal_vs = -airspeed*gradient
                preview = self.kos.call("terminal_preflare_predictive_fraction",
                    vertical_speed,target_vs,distance,1500,400,airspeed,mass,airspeed,self.config)
                desired_vs = normal_vs*(1-preview["fraction"])+target_vs*preview["fraction"]
                desired_history.append(desired_vs)
                pitch = self.kos.call("calculate_glideslope_pitch_command",
                    desired_vs,vertical_speed,airspeed,7,0.8,-20,25)
                region = "steep"
                if distance <= 1500:
                    region = "preflare"
                if distance <= 400:
                    region = "shallow"
                pullup = self.kos.call("calculate_preflare_pullup_command",region,0,
                    pitch["command"],5,15,20,preview["pitch_floor_fraction"])
                delayed.append(pullup["command"])
                applied_pitch = delayed.pop(0)
                # Independent conservative plant: delayed pitch authority, a
                # bounded sink response, and a mass penalty. It does not reuse
                # the onboard arrest acceleration predictor.
                acceleration = max(-0.25,min(1.25,applied_pitch*0.06))
                acceleration *= (36/max(36,mass))**0.25
                vertical_speed += acceleration*dt
                altitude += vertical_speed*dt
                min_altitude = min(min_altitude,altitude)
                distance -= airspeed*dt
            return vertical_speed,min_altitude,desired_history

        light = integrate(36,125,-32)
        heavy = integrate(46.73,149,-38)
        self.assertGreater(light[1],75)
        self.assertGreater(heavy[1],75)
        for actual_vs, airspeed in ((light[0],125),(heavy[0],149)):
            target_vs = -airspeed * 0.0524077793
            self.assertGreaterEqual(actual_vs,target_vs-10)
            self.assertLessEqual(actual_vs,target_vs+6)
        self.assertLess(max(abs(b-a) for a,b in zip(light[2],light[2][1:])),2.5)
        self.assertLess(max(abs(b-a) for a,b in zip(heavy[2],heavy[2][1:])),2.5)

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
        self.assertIn("global POS_LOG_SCHEMA_VERSION is 31.", logger.read_text())
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
        self.assertEqual(len(header), 47)
        self.assertEqual(len(values), len(header))
        self.assertEqual(values[-3], "closed")
        logger_runtime.kos.globals.get_value("terminal_route_debug")["preflare_pitch_floor_fraction"] = 0.35
        values = logger_runtime.call("flight_log_terminal_energy_columns").split(",")[1:]
        self.assertEqual(values[-1], "0.35")
        fallback_source = column_source.replace("if false {", "if true {", 1)
        logger_runtime.kos.load_source(fallback_source,"terminal_logger_default_fields")
        fallback_values = logger_runtime.call("flight_log_terminal_energy_columns").split(",")[1:]
        self.assertEqual(len(fallback_values),len(header))
        self.assertIn("terminal_preflare_profile_deficit_height", header)
        self.assertIn("terminal_preflare_absolute_arrest_height", header)
        self.assertIn("terminal_dump_lf_paired_floor", header)
        self.assertIn("terminal_descent_arrest_margin", header)
        self.assertIn("terminal_preflare_pitch_floor_fraction", header)


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
