"""Real .ks terrain guidance against independent obstacle geometry at 2,000 IPU."""
from copy import deepcopy
import json
import math
from pathlib import Path
import unittest

from tools.pos_sim.kos_runtime import Runtime, OpcodeScheduler
from tools.pos_sim.kos_script_runtime import ScriptRuntime
from tools.pos_sim.math3d import Vec
from test_contingency import FixtureHost
from test_navigation_math import source_function

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT/'Script/Libraries/Poseidon_SSTO'
SOURCE = (LIB/'terrain_navigation.ks').read_text()
MAIN = (ROOT/'Script/Poseidon_SSTO/Poseidon_SSTO_Orbit_Main.ks').read_text()


def departure_startup_source():
    start = MAIN.index('if not departure_route["valid"] {')
    end = MAIN.index('\nuntil running = false{', start)
    return MAIN[start:end]


def departure_loop_guard():
    start = MAIN.index('until running = false{')
    return MAIN[start:MAIN.index('\n', start)].strip()


def production_config():
    runtime = ScriptRuntime(ROOT, FixtureHost())
    text = (LIB/'craft_Poseidon_SSTO.ks').read_text()
    start = text.index('local Poseidon_SSTO is lex().')
    end = text.index('global AVES is Poseidon_SSTO.')+len('global AVES is Poseidon_SSTO.')
    runtime.load_source(text[start:end], 'production-craft-config')
    return runtime.globals.get_value('aves')


class TerrainPoint:
    """Independent body-fixed obstacle field, not the onboard path predictor."""
    radius = 600000

    def __init__(self, lat, lng, field):
        self.lat, self.lng, self.field = lat, lng, field

    @property
    def terrainheight(self):
        east = self.radius*math.radians(self.lng)*math.cos(math.radians(self.lat))
        north = self.radius*math.radians(self.lat)
        return self.field(east, north)


class TerrainNavigationTest(unittest.TestCase):
    def setUp(self):
        self.aves = production_config()
        self.cfg = self.aves['Envelope']['Terrain']['Navigation']
        navigation = (ROOT/'Script/Libraries/lib_navigation.ks').read_text()
        names = ('navigation_longitude_delta','get_geoposition_along_heading','calcdistance_m','heading_between')
        math_names = ('terrain_heading_delta','terrain_departure_height_gain',
            'terrain_path_create','terrain_path_advance',
            'terrain_scan_state','terrain_scan_start','terrain_scan_advance',
            'terrain_alignment_command','terrain_departure_course')
        math_source = '\n'.join(source_function(SOURCE,n) for n in math_names)
        self.kos = Runtime(math_source+'\n'+'\n'.join(source_function(navigation,n) for n in names))
        self.hosted = ScriptRuntime(ROOT,FixtureHost())
        self.hosted.load_source(SOURCE+'\n'+'\n'.join(source_function(navigation,n) for n in names),'terrain-source')
        craft = (LIB/'craft_Poseidon_SSTO.ks').read_text()
        integration_names = ('find_active_runway','calcdistance_m','heading_between',
                             'navigation_longitude_delta','takeoff_runway_geometry')
        self.hosted.load_source('\n'.join(source_function(navigation,n) for n in integration_names)+'\n'+
            '\n'.join(source_function(craft,n) for n in
                      ('normalized_heading_error','takeoff_performance','assess_takeoff_runway')),
            'production-runway-integration')
        self.field = lambda east,north: 0
        self.kos.globals.update(ship=dict(body=dict(radius=600000,hasocean=True,
            mu=9.81*600000**2),geoposition=self.point(0,0),mass=69.5,altitude=5),
            time={'seconds':0},latlng=self.point,
            arctan2=lambda y,x:math.degrees(math.atan2(y,x)))
        self.hosted.globals.update({k:self.kos.globals.get_value(k) for k in ('ship','time','latlng','arctan2')})

    def point(self, lat, lng):
        return TerrainPoint(lat,lng,lambda e,n:self.field(e,n))

    def call(self, name, *args):
        if name in ('terrain_navigation_config','terrain_departure_plan'):
            return self.hosted.globals.get_value(name)(*args)
        return self.kos.call(name,*args)

    def path(self, offset=0, speed=230, height=1400, vs=0, departure=False):
        return self.call('terrain_path_create',self.point(0,0),0,offset,0,speed,height,vs,9.81,self.cfg,departure)

    def departure_path(self, sample_spacing=None, navigation_config=None):
        navigation_config = dict(self.cfg) if navigation_config is None else navigation_config
        if sample_spacing is not None:
            navigation_config['sample_spacing'] = sample_spacing
        path = self.call('terrain_path_create',self.point(0,0),0,0,0,300,5,0,9.81,
                         navigation_config,True)
        return self.finish(path,navigation_config)

    def finish(self, path, navigation_config=None):
        navigation_config = self.cfg if navigation_config is None else navigation_config
        steps = 0
        while not path['done']:
            self.call('terrain_path_advance',path,navigation_config)
            steps += 1
            self.assertLess(steps,200)
        return path

    def test_detects_5km_wall_far_beyond_old_seven_second_probe(self):
        self.field = lambda e,n: 5000 if n >= 7000 else 0
        path = self.finish(self.path())
        self.assertLess(path['margin'],-3000)
        self.assertGreater(path['conflict_time'],7)
        self.assertEqual(path['threat_height'],5000)
        self.assertGreaterEqual(path['range'],15000)

    def test_small_left_turn_clears_wall_when_straight_path_cannot(self):
        # A narrow mountain front 7 km ahead. Corridor edges, not just the
        # centreline, must pass it. Symmetric right side is deliberately blocked.
        self.field = lambda e,n: 5000 if n >= 9000 and e >= -200 else 0
        self.assertLess(self.finish(self.path())['margin'],0)
        left = self.finish(self.path(-5))
        self.assertGreater(left['margin'],self.cfg['escape_margin'])
        self.assertLess(self.finish(self.path(5))['margin'],0)

    def test_near_wall_cannot_be_avoided_by_instantaneous_heading_change(self):
        self.field = lambda e,n: 5000 if 1000 <= n <= 1500 and abs(e) < 300 else 0
        for offset in (0,-5,5,-30,30,-60,60):
            self.assertLess(self.finish(self.path(offset))['margin'],0)

    def test_corridor_edges_find_obstacle_missed_by_centreline(self):
        self.field = lambda e,n: 5000 if 2950 <= n <= 3050 and e > 50 else 0
        self.assertLess(self.finish(self.path())['margin'],0)

    def test_no_credit_for_unachieved_commanded_climb_and_ocean_is_solid(self):
        self.field = lambda e,n: -1000
        descending = self.finish(self.path(height=200,vs=-20))
        self.assertLess(descending['margin'],0)
        self.assertEqual(descending['threat_height'],0)
        self.field = lambda e,n: 5000 if n >= 7000 else 0
        self.assertLess(self.finish(self.path(vs=100))['margin'],0)

    def test_departure_climb_profile_delays_and_ramps_without_sampling_drift(self):
        gain = lambda distance: self.call('terrain_departure_height_gain',distance,self.cfg)
        self.assertAlmostEqual(gain(0),0)
        self.assertAlmostEqual(gain(250),6.25)
        self.assertAlmostEqual(gain(1000),25)
        self.assertAlmostEqual(gain(1250),33.984375)
        self.assertAlmostEqual(gain(2000),93.75)
        self.assertAlmostEqual(gain(3000),250)
        self.assertAlmostEqual(gain(4000),450)
        self.assertLess(gain(1250),0.20*1250)
        for boundary in (self.cfg['departure_climb_delay'],
                         self.cfg['departure_climb_delay']+self.cfg['departure_climb_ramp']):
            with self.subTest(boundary=boundary):
                self.assertAlmostEqual(gain(boundary-0.001),gain(boundary+0.001),places=3)

        final_bottoms = []
        for spacing in (125,250,375):
            path = self.departure_path(sample_spacing=spacing)
            self.assertAlmostEqual(path['distance'],self.cfg['departure_range'])
            self.assertAlmostEqual(path['bottom']-path['initial_bottom'],
                                   gain(path['distance']),places=7)
            final_bottoms.append(path['bottom'])
        self.assertLess(max(final_bottoms)-min(final_bottoms),1e-8)

    def test_departure_profile_clears_1500m_obstacle_at_10km_but_not_5km_wall(self):
        self.field = lambda e,n: 1500 if n >= 10000 else 0
        departure = self.departure_path()
        self.assertGreaterEqual(departure['margin'],0)

        # The former constant 2.5% climb credit would not clear this same hill.
        old_profile = dict(self.cfg)
        old_profile['departure_gradient'] = old_profile['departure_initial_gradient']
        old_departure = self.departure_path(navigation_config=old_profile)
        self.assertLess(old_departure['margin'],0)

        self.field = lambda e,n: 5000 if n >= 7000 else 0
        wall = self.departure_path()
        self.assertLess(wall['margin'],0)

    def scan_path(self, scan, now, course=0, height=1400, speed=230, vs=0):
        self.call('terrain_scan_start',scan,self.point(0,0),course,speed,height,vs,9.81,self.cfg,now)
        elapsed = 0
        while scan['paths']:
            _, profile = self.kos.call_timed('terrain_scan_advance',scan,self.cfg,now+elapsed,
                                           ipu=2000,tick_seconds=.02)
            elapsed += profile.elapsed_time+.1
            self.assertLess(elapsed,3)
        return now+elapsed+.2

    def test_incremental_scan_publishes_left_escape_without_waiting_for_all_candidates(self):
        self.field = lambda e,n: 5000 if n >= 9000 and e >= -200 else 0
        scan = self.call('terrain_scan_state')
        now = self.scan_path(scan,0)
        self.assertLess(scan['central_margin'],0)
        self.assertFalse(scan['escape_valid'])
        central_ut = scan['central_ut']
        now = self.scan_path(scan,now)
        self.assertTrue(scan['escape_valid'])
        self.assertEqual(scan['escape_offset'],-5)
        self.assertLess(now,5)
        self.assertGreater(scan['escape_margin'],50)
        now = self.scan_path(scan,now)
        self.assertGreater(scan['central_ut'],central_ut)
        self.assertEqual(scan['phase'],'candidate')

    def plan(self, orbital=0):
        self.kos.globals['ship']['geoposition'] = self.point(0,0)
        scheduler = OpcodeScheduler(ipu=2000,tick_seconds=.02)
        self.hosted.scheduler = scheduler
        try:
            plan = self.call('terrain_departure_plan',dict(heading=0,altitude=0),
                             dict(liftoff_distance_m=1800),orbital,self.cfg)
        finally:
            self.hosted.scheduler = None
        return plan,scheduler.profile()

    def area_15_runway_metadata(self):
        # Real Area-15 runway endpoint coordinates and elevation from
        # lib_location_constants.ks. Runway 31's end is the reciprocal runway
        # 13 start, matching the production aliasing rule in that file.
        start_31 = self.point(-60.6101231793587,39.3817317024422)
        start_13 = self.point(-60.4656073371585,39.0415304340361)
        return ({'kerbin': {
            'Area-15_runway_31_start':start_31,
            'Area-15_runway_31_end':start_13,
            'Area-15_runway_13_start':start_13,
            'Area-15_runway_13_end':start_31}},
            {'Area-15_runway':1371})

    def actual_runway_assessment(self, geoposition, runways, elevations):
        ship = dict(mass=69.5,altitude=1371,geoposition=geoposition,
                    body=dict(name='Kerbin',radius=600000,mu=9.81*600000**2,hasocean=True))
        self.hosted.globals.update(ship=ship,aves=self.aves,
            location_constants=runways,kerbinrunwayalt=elevations,
            compass_for=lambda:0)
        runway = self.hosted.globals.get_value('find_active_runway')()
        self.hosted.globals['compass_for'] = lambda:runway['heading']
        prediction = self.hosted.globals.get_value('assess_takeoff_runway')(runway)
        return runway,prediction

    def test_preflight_builds_waypoints_around_wall_before_orbital_alignment(self):
        self.field = lambda e,n: 5000 if 9000 <= n <= 12000 and abs(e) < 400 else 0
        plan, profile = self.plan()
        self.assertTrue(plan['valid'],plan)
        self.assertGreater(abs(plan['first_course']),5)
        self.assertGreaterEqual(plan['margin'],0)
        self.assertEqual(len(plan['waypoints']),18)
        self.assertGreater(profile.waits,0)
        self.assertEqual(profile.max_opcodes_in_update,2000)
        # Every sampled waypoint also clears the independent obstacle field.
        self.assertTrue(all(p.terrainheight == 0 for p in plan['waypoints']))

    def test_preflight_holds_when_all_routes_blocked_and_unknown_runway(self):
        self.field = lambda e,n: 5000 if math.hypot(e,n) >= 4000 else 0
        plan,_ = self.plan()
        self.assertFalse(plan['valid'])
        self.assertEqual(plan['reason'],'terrain_blocked')
        result = self.call('terrain_departure_plan',dict(heading=-1,altitude=-1),{},0,self.cfg)
        self.assertFalse(result['valid'])
        self.assertEqual(result['reason'],'unknown_runway')

    def test_actual_runway_lookup_and_takeoff_assessment_feed_terrain_plan(self):
        self.field = lambda e,n: 0
        runways,elevations = self.area_15_runway_metadata()
        start_31 = runways['kerbin']['Area-15_runway_31_start']
        runway,prediction = self.actual_runway_assessment(start_31,runways,elevations)

        self.assertEqual(runway['location'],'Area-15')
        self.assertEqual(runway['runway_num'],'31')
        self.assertGreaterEqual(runway['heading'],0)
        self.assertEqual(runway['altitude'],1371)
        self.assertNotIn('selected',runway)
        self.assertIn('liftoff_distance_m',prediction)
        self.assertGreater(prediction['liftoff_distance_m'],0)

        scheduler = OpcodeScheduler(ipu=2000,tick_seconds=.02)
        self.hosted.scheduler = scheduler
        try:
            plan = self.call('terrain_departure_plan',runway,prediction,0,self.cfg)
        finally:
            self.hosted.scheduler = None
        self.assertTrue(plan['valid'],plan)
        self.assertEqual(plan['reason'],'sampled_corridor')
        self.assertEqual(plan['model_initial_gradient'],self.cfg['departure_initial_gradient'])
        self.assertEqual(plan['model_climb_delay'],self.cfg['departure_climb_delay'])
        self.assertEqual(plan['model_climb_ramp'],self.cfg['departure_climb_ramp'])
        self.assertFalse(plan['model_valid'])
        planned_offset = self.hosted.globals.get_value('calcdistance_m')(start_31,plan['origin'])
        self.assertAlmostEqual(planned_offset,
            prediction['liftoff_distance_m']*self.cfg['liftoff_distance_fraction'],places=5)
        self.assertEqual(plan['origin'].terrainheight,0)
        self.assertEqual(plan['waypoints'][0].terrainheight,0)
        self.assertEqual(scheduler.profile().max_opcodes_in_update,2000)
        self.assertGreater(scheduler.profile().waits,0)

    def test_real_lookup_no_match_and_incomplete_runway_metadata_hold_cleanly(self):
        self.field = lambda e,n: 0
        runways,elevations = self.area_15_runway_metadata()
        _,prediction = self.actual_runway_assessment(
            self.point(0,0),{'kerbin':{}},elevations)
        no_match = self.hosted.globals.get_value('find_active_runway')()
        self.assertEqual(no_match['heading'],-1)
        self.assertEqual(no_match['altitude'],-1)
        self.assertEqual(no_match['distance_m'],9999999999)
        self.assertNotIn('selected',no_match)
        result = self.call('terrain_departure_plan',no_match,prediction,0,self.cfg)
        self.assertFalse(result['valid'])
        self.assertEqual(result['reason'],'unknown_runway')

        for incomplete in ({},{'heading':0},{'altitude':1371}):
            with self.subTest(incomplete=incomplete):
                result = self.call('terrain_departure_plan',incomplete,prediction,0,self.cfg)
                self.assertFalse(result['valid'])
                self.assertEqual(result['reason'],'unknown_runway')

    def test_missing_or_invalid_takeoff_distance_returns_held_plan(self):
        for prediction in ({},{'reason':'invalid_inputs','liftoff_distance_m':0},
                           {'liftoff_distance_m':-1}):
            with self.subTest(prediction=prediction):
                result = self.call('terrain_departure_plan',
                    {'heading':0,'altitude':0},prediction,0,self.cfg)
                self.assertFalse(result['valid'])
                self.assertEqual(result['reason'],'invalid_takeoff_prediction')

    def test_mass_penalty_is_local_and_alignment_pitch_stays_capped(self):
        heavy = self.call('terrain_navigation_config',self.cfg,100)
        self.assertLess(heavy['departure_gradient'],self.cfg['departure_gradient'])
        self.assertLess(heavy['departure_initial_gradient'],self.cfg['departure_initial_gradient'])
        mass_factor = (self.cfg['reference_mass']/100)**2
        self.assertAlmostEqual(heavy['departure_gradient'],self.cfg['departure_gradient']*mass_factor)
        self.assertAlmostEqual(heavy['departure_initial_gradient'],
                               self.cfg['departure_initial_gradient']*mass_factor)
        reference_mass = self.call('terrain_navigation_config',self.cfg,69.5)
        self.assertEqual(reference_mass['departure_gradient'],self.cfg['departure_gradient'])
        self.assertEqual(reference_mass['departure_initial_gradient'],self.cfg['departure_initial_gradient'])
        self.assertEqual(self.cfg['departure_gradient'],.20)
        self.assertEqual(self.cfg['departure_initial_gradient'],.025)
        ascent = self.aves['Ascent']
        command = lambda vs: self.call('terrain_alignment_command',50,vs,12,14,4,ascent)
        good,weak,descending = command(15),command(5),command(-2)
        self.assertEqual(abs(good['bank']),45)
        self.assertLess(abs(weak['bank']),abs(good['bank']))
        self.assertEqual(descending['bank'],0)
        self.assertGreater(good['pitch_floor'],0)
        self.assertEqual(ascent['alignment_max_pitch'],30)
        self.assertLessEqual(good['pitch_floor'],ascent['alignment_max_pitch'])
        self.assertGreater(good['aoa'],12)
        self.assertGreater(descending['pitch_floor'],0)
        self.assertLessEqual(descending['pitch_floor'],ascent['alignment_max_pitch'])

    def test_alignment_command_does_not_ratchet_with_measured_aoa_or_pitch(self):
        ascent = self.aves['Ascent']
        nominal = self.call('terrain_alignment_command',15,8,12,18,6,ascent)
        high_measured = self.call('terrain_alignment_command',15,8,38,85,6,ascent)
        low_measured = self.call('terrain_alignment_command',15,8,0,-10,6,ascent)
        self.assertEqual(nominal,high_measured)
        self.assertEqual(nominal,low_measured)
        self.assertLessEqual(nominal['aoa'],ascent['alignment_max_aoa'])
        self.assertLessEqual(nominal['pitch_floor'],ascent['alignment_max_pitch'])

    def test_passed_waypoint_is_not_flown_back_to(self):
        route = dict(valid=True,index=0,origin=self.point(0,0),
                     waypoints=[self.point(.05,0),self.point(.1,0)])
        course = self.call('terrain_departure_course',route,self.point(.06,0),90,self.cfg)
        self.assertEqual(route['index'],1)
        self.assertAlmostEqual(course,0)


class TerrainControlTest(unittest.TestCase):
    def setUp(self):
        self.aves = production_config()
        self.runtime = ScriptRuntime(ROOT,FixtureHost())
        self.runtime.load_source(SOURCE,'terrain-navigation')
        control = (LIB/'control.ks').read_text()
        names = ('envelope_terrain_reset','envelope_terrain_refresh','envelope_run_recovery')
        self.runtime.load_source('\n'.join(source_function(control,n) for n in names),'terrain-controller')
        self.cfg = self.aves['Envelope']['Terrain']
        self.scan = self.runtime.globals.get_value('terrain_scan_state')()
        self.env = dict(state='normal',terrain_navigation=self.scan,
            terrain_bounds={'bottomalt':1400},terrain_next_scan=999,terrain_worst_clearance=1000,
            terrain_clear_timer=0,terrain_required_clearance=150)
        self.commands = []
        self.g = self.runtime.globals
        self.g.update(aves=self.aves,time={'seconds':20},dap={'envelope':self.env,'aoa':{'aoa_yaw':0,'aoa_pitch':0,'aoa_roll':0}},
            ship=dict(geoposition='craft',altitude=1405,verticalspeed=0,body=dict(mu=9.81*600000**2,radius=600000),
                      velocity={'surface':Vec(0,230,0)},up={'vector':Vec(1,0,0)}),
            step='ascent_alignment',roll_for=lambda:0,compass_for_prograde=lambda:0,pitch_for_prograde=lambda:0,
            envelope_terrain_inhibit_reason=lambda *a:'',
            terrain_scan_advance=lambda *a:None,
            aoa_bank_management=lambda *a:self.commands.append(a),
            heading=lambda *a:a)
        self.scan.update(next_start=999,central_margin=-3000,central_ut=19,
            completed_ut=19,escape_valid=True,escape_course=-5,escape_offset=-5,
            escape_snapshot_course=0,escape_margin=100)

    def call(self,name,*args):
        return self.g.get_value(name)(*args)

    def test_long_threat_commands_left_escape_before_near_gpws_triggers(self):
        self.call('envelope_terrain_refresh',self.env,self.cfg,.1)
        self.assertEqual(self.env['state'],'terrain_pullup')
        self.assertEqual(self.scan['mode'],'turn')
        self.call('envelope_run_recovery')
        self.assertGreater(self.commands[-1][1],0)  # left bank convention
        self.assertLessEqual(self.commands[-1][1],25)

    def test_stale_or_wrong_track_escape_falls_back_to_wings_level(self):
        for edit in (dict(completed_ut=0),dict(escape_snapshot_course=40)):
            with self.subTest(edit=edit):
                self.scan.update(edit)
                self.call('envelope_terrain_refresh',self.env,self.cfg,.1)
                self.assertEqual(self.scan['mode'],'climb')
                self.call('envelope_run_recovery')
                self.assertEqual(self.commands[-1][1],0)

    def test_threat_and_stale_scan_cannot_release_protection(self):
        self.env.update(state='terrain_pullup',terrain_clear_timer=10)
        self.g['ship']['verticalspeed']=20
        self.call('envelope_terrain_refresh',self.env,self.cfg,.1)
        self.assertEqual(self.env['state'],'terrain_pullup')
        self.assertEqual(self.env['terrain_clear_timer'],0)
        self.scan.update(central_margin=1000,central_ut=0)
        self.call('envelope_terrain_refresh',self.env,self.cfg,.1)
        self.assertEqual(self.env['state'],'terrain_pullup')

    def test_clear_lateral_escape_can_release_in_level_flight(self):
        self.env.update(state='terrain_pullup',terrain_clear_timer=0)
        self.scan.update(central_margin=1000,central_ut=19)
        for _ in range(16): self.call('envelope_terrain_refresh',self.env,self.cfg,.1)
        self.assertEqual(self.env['state'],'normal')
        self.assertTrue(self.env['restore_steering'])

    def test_inhibit_discards_old_escape(self):
        self.call('envelope_terrain_reset',self.env,'inhibited','landing_final_captured',True)
        self.assertFalse(self.env['terrain_navigation']['escape_valid'])
        self.assertEqual(self.env['terrain_navigation']['mode'],'idle')


class AscentRecoveryControlTest(unittest.TestCase):
    def setUp(self):
        self.aves = production_config()
        self.runtime = ScriptRuntime(ROOT,FixtureHost())
        self.runtime.load_source(SOURCE,'terrain-navigation')
        control = (LIB/'control.ks').read_text()
        self.runtime.load_source('\n'.join(source_function(control,name) for name in
            ('envelope_upset_release','envelope_run_recovery')),'upset-recovery-control')
        aerostr = (ROOT/'Script/Libraries/lib_aerostr.ks').read_text()
        self.runtime.load_source(source_function(aerostr,'aoa_bank_management'),'aoa-controller')
        self.g = self.runtime.globals
        self.g.update(aves=self.aves,step='ascent_alignment',
            ship={'airspeed':150},time={'seconds':10},
            compass_for_prograde=lambda:0,pitch_for_prograde=lambda:0,
            heading=lambda *args:args)
        self.release_config = self.aves['Envelope']

    def call(self,name,*args):
        return self.g.get_value(name)(*args)

    def release(self,envelope=None,*,pitch=10,speed=150,bank=0,aoa=5,rate=0,dt=.5,
                entry_recovery=False):
        envelope = envelope or {'stable_timer':0,'max_aoa':30}
        self.g['ship']={'airspeed':speed}
        result = self.call('envelope_upset_release',envelope,self.release_config,
            entry_recovery,aoa,rate,bank,pitch,dt)
        return result,envelope

    def recovery_pitch(self,state,*,prograde_pitch,maximum_aoa=30):
        scan = self.g.get_value('terrain_scan_state')()
        scan['mode']='climb'
        envelope={'state':state,'max_aoa':maximum_aoa,'terrain_navigation':scan}
        dap={'envelope':envelope,'aoa':{'aoa_yaw':0,'aoa_pitch':0,'aoa_roll':0}}
        self.g.update(dap=dap,step='ascent_alignment',
            pitch_for_prograde=lambda:prograde_pitch,compass_for_prograde=lambda:0)
        self.call('envelope_run_recovery')
        return dap['aoa']['aoa_pitch']

    def test_ascent_release_rejects_vertical_slow_bank_and_unstable_states(self):
        rejected = (
            {'pitch':89},
            {'speed':109},
            {'bank':31},
            {'aoa':16},
            {'rate':2.1},
            {'pitch':-1},
        )
        for condition in rejected:
            with self.subTest(condition=condition):
                envelope={'stable_timer':0,'max_aoa':30}
                result,_=self.release(envelope,**condition)
                self.assertFalse(result)
                self.assertEqual(envelope['stable_timer'],0)

    def test_ascent_release_requires_two_continuous_seconds_of_stability(self):
        envelope={'stable_timer':0,'max_aoa':30}
        result,_=self.release(envelope,dt=.5)
        self.assertFalse(result)
        self.assertEqual(envelope['stable_timer'],.5)
        result,_=self.release(envelope,pitch=89,dt=.1)
        self.assertFalse(result)
        self.assertEqual(envelope['stable_timer'],0)
        for _ in range(3):
            result,_=self.release(envelope,dt=.5)
            self.assertFalse(result)
        result,_=self.release(envelope,dt=.5)
        self.assertTrue(result)
        self.assertEqual(envelope['stable_timer'],2)

    def test_ascent_recovery_release_accepts_the_35_degree_limit(self):
        self.assertEqual(self.release_config['departure_recovery_max_pitch'],35)
        envelope={'stable_timer':0,'max_aoa':30}
        for index in range(4):
            result,_=self.release(envelope,pitch=35,dt=.5)
            self.assertEqual(result,index == 3)
        self.assertEqual(envelope['stable_timer'],2)

        rejected={'stable_timer':0,'max_aoa':30}
        result,_=self.release(rejected,pitch=35.1,dt=.5)
        self.assertFalse(result)
        self.assertEqual(rejected['stable_timer'],0)

    def test_reentry_and_general_release_rules_are_unchanged(self):
        self.g['step']='speed_build'
        result,_=self.release(pitch=35,speed=0,bank=170,aoa=5,rate=100)
        self.assertTrue(result)

        self.g['step']='reentry_low'
        envelope={'stable_timer':0,'max_aoa':30}
        result,_=self.release(envelope,pitch=-20,speed=0,dt=.5,entry_recovery=True)
        self.assertFalse(result)
        self.assertEqual(envelope['stable_timer'],.5)
        result,_=self.release(envelope,pitch=-20,speed=0,dt=.5,entry_recovery=True)
        self.assertTrue(result)
        self.assertEqual(envelope['stable_timer'],1)

    def test_ascent_upset_pullup_is_capped_but_gpws_and_zero_aoa_are_exempt(self):
        upset_pitch=self.recovery_pitch('upset_pullup',prograde_pitch=80)
        self.assertLessEqual(upset_pitch,30)
        self.assertEqual(upset_pitch,30)

        gpws_pitch=self.recovery_pitch('terrain_pullup',prograde_pitch=15)
        self.assertGreater(gpws_pitch,30)

        zero_aoa_pitch=self.recovery_pitch('upset_zero_aoa',prograde_pitch=80)
        self.assertEqual(zero_aoa_pitch,80)


class TerrainLoggingTest(unittest.TestCase):
    def setUp(self):
        self.runtime = ScriptRuntime(ROOT,FixtureHost())
        self.aves = production_config()
        logger = (LIB/'flight_log.ks').read_text()
        names = ('flight_log_terrain_header','flight_log_terrain_columns',
                 'flight_log_terrain_observe','flight_log_departure_plan')
        self.runtime.load_source(SOURCE+'\n'+'\n'.join(source_function(logger,n) for n in names),'logger-terrain')
        self.scan = self.runtime.globals.get_value('terrain_scan_state')()
        self.events = []
        self.g = self.runtime.globals
        self.g.update(aves=self.aves,dap={'envelope':{'terrain_navigation':self.scan}},time={'seconds':10},
            pos_log_level=1,pos_log_last_terrain_choice='',
            flight_log_event=lambda *a:self.events.append(a))

    def call(self,name,*args):
        return self.g.get_value(name)(*args)

    def test_terrain_columns_match_header_with_and_without_departure(self):
        self.assertIn('global POS_LOG_SCHEMA_VERSION is 36.',(LIB/'flight_log.ks').read_text())
        header = self.call('flight_log_terrain_header').split(',')
        default_columns = self.call('flight_log_terrain_columns').split(',')
        self.assertEqual(header[-1],'alignment_pitch_limit')
        self.assertEqual(len(header),len(default_columns))
        self.assertEqual(default_columns[-1],'0')

        self.g['departure_route']={'valid':True,'index':2,'waypoints':[1,2,3],'margin':25}
        self.g['ascent_alignment_debug']={'pitch_floor':18,'bank':20,'aoa':15}
        populated_columns = self.call('flight_log_terrain_columns').split(',')
        self.assertEqual(len(header),len(populated_columns))
        self.assertEqual(populated_columns[-4:],['18','20','15','30'])
        self.assertIn(',True,2,3,25,18,20,15,30',','.join(populated_columns))

    def test_low_mode_logs_escape_transitions_once_and_none_has_no_events(self):
        self.g['pos_log_level']=0
        self.call('flight_log_terrain_observe')
        self.assertFalse(self.events)
        self.g['pos_log_level']=1
        self.call('flight_log_terrain_observe')
        self.call('flight_log_terrain_observe')
        self.scan.update(mode='turn',escape_offset=-5,escape_valid=True)
        self.call('flight_log_terrain_observe')
        self.assertEqual(len(self.events),2)
        self.assertIn('mode=turn',self.events[-1][1])
        self.assertIn('scan_age=',self.events[-1][1])

    def test_plan_logs_waypoint_coordinates_without_querying_terrain(self):
        class LogPoint:
            lat,lng=1,2
            @property
            def terrainheight(self): raise AssertionError('logger must remain passive')
        self.call('flight_log_departure_plan',dict(valid=True,reason='sampled_corridor',
            first_course=-5,margin=50,mass=69,waypoints=[LogPoint()]))
        self.assertEqual([e[0] for e in self.events],['departure_plan','departure_plan_waypoint'])

    def test_departure_climb_model_event_is_low_mode_only_and_path_math_has_no_io(self):
        route_plan=dict(valid=True,reason='sampled_corridor',first_course=0,margin=5,mass=69.5,
            waypoints=[],model_gradient=.20,model_speed=300,sample_spacing=250,model_valid=False,
            model_initial_gradient=.025,model_climb_delay=1000,model_climb_ramp=2000)
        self.g['pos_log_level']=0
        self.call('flight_log_departure_plan',route_plan)
        self.assertFalse(self.events)

        self.g['pos_log_level']=1
        self.call('flight_log_departure_plan',route_plan)
        climb_events=[event for event in self.events if event[0]=='departure_climb_model']
        self.assertEqual(len(climb_events),1)
        detail=climb_events[0][1]
        for expected in ('initial_gradient=0.025','established_gradient=0.2',
                         'delay_distance=1000','ramp_distance=2000',
                         'alignment_pitch_limit=30','model_valid=False'):
            self.assertIn(expected,detail)

        path_source=source_function(SOURCE,'terrain_path_advance')
        self.assertIn('terrain_departure_height_gain(',path_source)
        for io_marker in ('flight_log','log ','print ','open(','read(','write('):
            with self.subTest(io_marker=io_marker):
                self.assertNotIn(io_marker,path_source.lower())


class DepartureHoldStartupTest(unittest.TestCase):
    def run_startup(self, route, override=False):
        runtime = ScriptRuntime(ROOT, FixtureHost())
        calls = []
        events = []
        g = runtime.globals
        g.update(running=True, step='launch', departure_route=route,
            aves={'Takeoff':{'override_preflight_refusals':override}},
            ascent_rendezvous_enabled=False, dap={},
            lex=lambda *args: dict(zip(args[::2],args[1::2])),
            print=lambda *args:None,
            flight_log_event=lambda *args:events.append(args),
            recovery_register_engines=lambda:calls.append('register'),
            rapierson=lambda:calls.append('activate'))
        runtime.load_source(departure_startup_source(),'actual-departure-startup')
        return runtime, g, calls, events

    def test_held_route_stops_before_engine_initialization_and_ascent(self):
        runtime, g, calls, events = self.run_startup(
            {'valid':False,'reason':'terrain_blocked'})
        self.assertFalse(g.get_value('running'))
        self.assertEqual(g.get_value('step'),'launch')
        self.assertEqual(calls,[])
        self.assertEqual(events,[('departure_takeoff_held','reason=terrain_blocked')])
        g['ascent_entered'] = False
        # Keep the production UNTIL predicate and use a sentinel as its body.
        runtime.load_source(departure_loop_guard() +
            ' set ascent_entered to true. }','actual-ascent-loop-entry-guard')
        self.assertFalse(g.get_value('ascent_entered'))

    def test_valid_route_still_initializes_engines(self):
        _, g, calls, events = self.run_startup({'valid':True,'reason':'clear'})
        self.assertTrue(g.get_value('running'))
        self.assertEqual(g.get_value('step'),'launch')
        self.assertEqual(calls,['register','activate'])
        self.assertEqual(events,[])

    def test_override_attempts_departure_without_claiming_route_is_safe(self):
        for reason in ('terrain_blocked','unknown_runway','invalid_takeoff_prediction'):
            with self.subTest(reason=reason):
                route = {'valid':False,'reason':reason}
                runtime, g, calls, events = self.run_startup(route, override=True)
                self.assertTrue(g.get_value('running'))
                self.assertEqual(calls,['register','activate'])
                self.assertEqual(route,{'valid':False,'reason':reason})
                self.assertEqual(events,[('departure_takeoff_overridden',
                    'reason='+reason+'|fallback=orbital_course|in_flight_protection=active')])
                g['ascent_entered'] = False
                runtime.load_source(departure_loop_guard() +
                    ' set ascent_entered to true. set running to false. }',
                    'overridden-ascent-loop-entry')
                self.assertTrue(g.get_value('ascent_entered'))

    def test_enabled_override_does_not_replace_a_valid_route(self):
        route = {'valid':True,'reason':'clear'}
        _, g, calls, events = self.run_startup(route, override=True)
        self.assertTrue(g.get_value('running'))
        self.assertTrue(route['valid'])
        self.assertEqual(calls,['register','activate'])
        self.assertEqual(events,[])

    def test_production_override_defaults_to_false(self):
        self.assertIs(production_config()['Takeoff']['override_preflight_refusals'],False)


def wall_escape_scenario():
    """Long-range source loop with a deliberately climb-incapable truth plant.

    This isolates horizontal avoidance. Roll response and Cartesian motion are
    integrated independently at 0.02 s. It is not a FAR/whole-aircraft model.
    Near-field scans are held clear to prove the long-range layer alone reacts.
    """
    runtime = ScriptRuntime(ROOT,FixtureHost())
    runtime.load_source(SOURCE,'terrain-navigation')
    navigation = (ROOT/'Script/Libraries/lib_navigation.ks').read_text()
    control = (LIB/'control.ks').read_text()
    aero = (ROOT/'Script/Libraries/lib_aerostr.ks').read_text()
    runtime.load_source('\n'.join(source_function(navigation,n) for n in
        ('navigation_longitude_delta','get_geoposition_along_heading'))+'\n'+
        '\n'.join(source_function(control,n) for n in ('envelope_terrain_refresh','envelope_run_recovery'))+
        '\n'+source_function(aero,'aoa_bank_management'),'long-range-control')
    aves = production_config()
    scan = runtime.globals.get_value('terrain_scan_state')()
    env = dict(state='normal',terrain_navigation=scan,terrain_bounds={'bottomalt':1400},
        terrain_next_scan=999,terrain_worst_clearance=1000,terrain_clear_timer=0,
        terrain_required_clearance=150)
    field = lambda e,n: 5000 if n >= 9000 and e >= -200 else 0
    point = lambda lat,lng:TerrainPoint(lat,lng,field)
    truth = dict(east=0.,north=0.,height=1400.,speed=230.,course=0.,bank=0.,vs=0.,time=0.)
    aoa = dict(aoa_pitch=0,aoa_yaw=0,aoa_roll=0)
    ship = dict(geoposition=point(0,0),altitude=1405,verticalspeed=0,
        body=dict(mu=9.81*600000**2,radius=600000,hasocean=True),
        velocity={'surface':Vec(0,230,0)},up={'vector':Vec(0,0,1)})
    g = runtime.globals
    g.update(aves=aves,time={'seconds':0},dap={'envelope':env,'aoa':aoa},ship=ship,
        step='speed_build',envelope_terrain_inhibit_reason=lambda *a:'',
        compass_for_prograde=lambda:truth['course'],roll_for=lambda:truth['bank'],
        pitch_for_prograde=lambda:math.degrees(math.atan2(truth['vs'],truth['speed'])),
        heading=lambda *a:a,latlng=point)
    trace,events=[],[]
    def integrate(dt):
        # Native physics, not a call to the onboard predictor. No positive
        # vertical acceleration is available even if it commands 20 deg AoA.
        command_bank = -aoa['aoa_roll'] if env['state']=='terrain_pullup' else 0
        truth['bank'] += (command_bank-truth['bank'])*min(1,dt/.8)
        truth['course'] += math.degrees(9.81*math.tan(math.radians(truth['bank']))/truth['speed'])*dt
        truth['speed'] += 10*dt
        truth['east'] += truth['speed']*math.sin(math.radians(truth['course']))*dt
        truth['north'] += truth['speed']*math.cos(math.radians(truth['course']))*dt
        truth['vs'] = -3*abs(truth['bank'])/25
        truth['height'] += truth['vs']*dt
        truth['time'] += dt
        g['time']['seconds']=truth['time']
        ship.update(geoposition=point(math.degrees(truth['north']/600000),math.degrees(truth['east']/600000)),
                    altitude=truth['height']+5,verticalspeed=truth['vs'])
        env['terrain_bounds']['bottomalt']=truth['height']
        ship['velocity']['surface']=Vec(truth['speed']*math.sin(math.radians(truth['course'])),
            truth['speed']*math.cos(math.radians(truth['course'])),truth['vs'])
    scheduler = OpcodeScheduler(ipu=2000,tick_seconds=.02,on_tick=integrate)
    runtime.scheduler=scheduler
    last_mode=''
    while truth['north'] < 12500 and truth['time'] < 50:
        runtime.globals.get_value('envelope_terrain_refresh')(env,aves['Envelope']['Terrain'],.1)
        if env['state']=='terrain_pullup': runtime.globals.get_value('envelope_run_recovery')()
        if scan['mode'] != last_mode:
            events.append(dict(time=truth['time'],mode=scan['mode'],course=scan['escape_course']))
            last_mode=scan['mode']
        clearance=truth['height']-field(truth['east'],truth['north'])
        trace.append(dict(**truth,clearance=clearance,mode=scan['mode'],
            state=env['state'],command_bank=aoa['aoa_roll'],command_pitch=aoa['aoa_pitch'],
            scan_age=truth['time']-scan['central_ut'],margin=scan['central_margin']))
        if clearance <= 0: break
        scheduler.wait(.1)
    runtime.scheduler=None
    return dict(passed=truth['north']>=12500 and min(x['clearance'] for x in trace)>0,
        trace=trace,events=events,profile=scheduler.profile().__dict__,
        limitations='Climb-incapable Cartesian roll/turn plant; not FAR or a whole-aircraft replay.')


class TerrainClosedLoopTest(unittest.TestCase):
    def test_lateral_escape_clears_wall_without_positive_climb_authority(self):
        result=wall_escape_scenario()
        self.assertTrue(result['passed'],result['events'])
        self.assertTrue(any(e['mode']=='turn' for e in result['events']))
        first_turn=next(e for e in result['events'] if e['mode']=='turn')
        self.assertLess(first_turn['time'],5)
        self.assertTrue(all(row['vs']<=0 for row in result['trace']))
        self.assertTrue(all(abs(row['command_bank'])<=25 for row in result['trace']))
        self.assertEqual(result['profile']['max_opcodes_in_update'],2000)


class DepartureIntegrationTest(unittest.TestCase):
    def alignment(self, orbital_course=0, first_course=0, vs=11,
                  prograde_pitch=4,current_pitch=14,measured_aoa=12):
        runtime=ScriptRuntime(ROOT,FixtureHost())
        runtime.load_source(SOURCE,'terrain-navigation')
        navigation=(ROOT/'Script/Libraries/lib_navigation.ks').read_text()
        runtime.load_source('\n'.join(source_function(navigation,n) for n in
            ('navigation_longitude_delta','calcdistance_m','heading_between')),'navigation')
        aves=production_config()
        point=lambda lat,lng:TerrainPoint(lat,lng,lambda *a:0)
        route=dict(valid=True,index=0,origin=point(0,0),first_course=first_course,
                   waypoints=[point(.2,.2 if orbital_course else 0)])
        g=runtime.globals
        g.update(ascent=aves['Ascent'],departure_config=aves['Envelope']['Terrain']['Navigation'],
            departure_route=route,ship=dict(geoposition=point(0,0),latitude=0,verticalspeed=vs,airspeed=180,
                                          body={'radius':600000}),
            dap={'aoa':{},'aerostr':{}},targetinclination=0,step='ascent_alignment',
            inclination_command={'valid':True,'heading':orbital_course,'mode':'direct',
                                 'northbound':True,'latitude_error':0},
            calculate_heading=lambda *a:orbital_course,compass_for_prograde=lambda:0,
            pitch_for_prograde=lambda:prograde_pitch,pitch_for=lambda:current_pitch,
            calc_aoa=lambda:measured_aoa,
            update_team_dap_gui=lambda:None,check_abort=lambda *a:{'abort':False},
            normalized_heading_error=lambda a,b:(a-b+180)%360-180,
            flight_log_event=lambda *a:None)
        main=(ROOT/'Script/Poseidon_SSTO/Poseidon_SSTO_Orbit_Main.ks').read_text()
        # Source helper counts nested braces; the tested block is production.
        from test_ascent_abort import source_block
        runtime.load_source(source_block(main,'if step = "ascent_alignment"{'),'actual-alignment-step')
        return runtime,g

    def test_clear_aligned_departure_resumes_acceleration_without_waypoint_speed_hold(self):
        _,g=self.alignment()
        self.assertEqual(g.get_value('step'),'speed_build')
        self.assertEqual(g.get_value('dapthrottle'),1)

    def test_planned_dogleg_cannot_be_skipped_by_initial_runway_alignment(self):
        _,g=self.alignment(first_course=-15)
        self.assertEqual(g.get_value('step'),'ascent_alignment')
        self.assertEqual(g.get_value('departure_route')['index'],0)

    def test_early_turn_preserves_lift_and_unloads_bank_when_climb_is_lost(self):
        _,g=self.alignment(orbital_course=45,first_course=45)
        self.assertLess(g.get_value('dap')['aoa']['target_bank'],0)
        self.assertGreater(g.get_value('ascent_alignment_debug')['pitch_floor'],0)
        self.assertLessEqual(g.get_value('ascent_alignment_debug')['pitch_floor'],
                             g.get_value('ascent')['alignment_max_pitch'])
        _,weak=self.alignment(orbital_course=45,first_course=45,vs=-2)
        self.assertEqual(weak.get_value('dap')['aoa']['target_bank'],0)
        self.assertEqual(weak.get_value('dapthrottle'),1)

    def test_final_controller_pitch_cap_handles_high_prograde_and_current_pitch(self):
        runtime,g=self.alignment(prograde_pitch=80,current_pitch=85,measured_aoa=38)
        aerostr=(ROOT/'Script/Libraries/lib_aerostr.ks').read_text()
        runtime.load_source(source_function(aerostr,'aoa_bank_management'),'actual-aoa-controller')
        aoa=g.get_value('dap')['aoa']
        g.get_value('aoa_bank_management')(aoa['target_aoa'],aoa['target_bank'])
        requested=aoa['aoa_pitch']
        self.assertGreater(requested,20)
        control=(LIB/'control.ks').read_text()
        self.assertIn('set dap["aoa"]["aoa_pitch"] to terrain_alignment_pitch(',control)
        final_command=g.get_value('terrain_alignment_pitch')(
            requested,g.get_value('ascent_alignment_debug'),g.get_value('ascent'))
        pitch_limit=g.get_value('ascent')['alignment_max_pitch']
        self.assertEqual(pitch_limit,30)
        self.assertLessEqual(final_command,pitch_limit)
        self.assertEqual(final_command,pitch_limit)
