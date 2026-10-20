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
        math_names = ('terrain_heading_delta','terrain_path_create','terrain_path_advance',
            'terrain_scan_state','terrain_scan_start','terrain_scan_advance',
            'terrain_alignment_command','terrain_departure_course')
        math_source = '\n'.join(source_function(SOURCE,n) for n in math_names)
        self.kos = Runtime(math_source+'\n'+'\n'.join(source_function(navigation,n) for n in names))
        self.hosted = ScriptRuntime(ROOT,FixtureHost())
        self.hosted.load_source(SOURCE+'\n'+'\n'.join(source_function(navigation,n) for n in names),'terrain-source')
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

    def finish(self, path):
        steps = 0
        while not path['done']:
            self.call('terrain_path_advance',path,self.cfg)
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
            plan = self.call('terrain_departure_plan',dict(selected=True,heading=0,altitude=0),
                             dict(liftoff_distance_m=1800),orbital,self.cfg)
        finally:
            self.hosted.scheduler = None
        return plan,scheduler.profile()

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
        result = self.call('terrain_departure_plan',dict(selected=False),{},0,self.cfg)
        self.assertFalse(result['valid'])
        self.assertEqual(result['reason'],'unknown_runway')

    def test_mass_penalty_is_local_and_early_turn_preserves_pitch_and_climb(self):
        heavy = self.call('terrain_navigation_config',self.cfg,100)
        self.assertLess(heavy['departure_gradient'],self.cfg['departure_gradient'])
        self.assertEqual(self.cfg['departure_gradient'],.025)
        ascent = self.aves['Ascent']
        command = lambda vs: self.call('terrain_alignment_command',50,vs,12,14,4,ascent)
        good,weak,descending = command(15),command(5),command(-2)
        self.assertEqual(abs(good['bank']),45)
        self.assertLess(abs(weak['bank']),abs(good['bank']))
        self.assertEqual(descending['bank'],0)
        self.assertGreaterEqual(good['pitch_floor'],14)
        self.assertGreater(good['aoa'],12)
        self.assertGreaterEqual(descending['pitch_floor'],good['pitch_floor'])

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


class TerrainLoggingTest(unittest.TestCase):
    def setUp(self):
        self.runtime = ScriptRuntime(ROOT,FixtureHost())
        logger = (LIB/'flight_log.ks').read_text()
        names = ('flight_log_terrain_header','flight_log_terrain_columns',
                 'flight_log_terrain_observe','flight_log_departure_plan')
        self.runtime.load_source(SOURCE+'\n'+'\n'.join(source_function(logger,n) for n in names),'logger-terrain')
        self.scan = self.runtime.globals.get_value('terrain_scan_state')()
        self.events = []
        self.g = self.runtime.globals
        self.g.update(dap={'envelope':{'terrain_navigation':self.scan}},time={'seconds':10},
            pos_log_level=1,pos_log_last_terrain_choice='',
            flight_log_event=lambda *a:self.events.append(a))

    def call(self,name,*args):
        return self.g.get_value(name)(*args)

    def test_terrain_columns_match_header_with_and_without_departure(self):
        for has_route in (False,True):
            if has_route:
                self.g['departure_route']={'valid':True,'index':2,'waypoints':[1,2,3],'margin':25}
                self.g['ascent_alignment_debug']={'pitch_floor':18,'bank':20,'aoa':15}
            self.assertEqual(len(self.call('flight_log_terrain_header').split(',')),
                             len(self.call('flight_log_terrain_columns').split(',')))
        self.assertIn(',True,2,3,25,18,20,15',self.call('flight_log_terrain_columns'))

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
    def alignment(self, orbital_course=0, first_course=0, vs=11):
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
            calculate_heading=lambda *a:orbital_course,compass_for_prograde=lambda:0,
            pitch_for_prograde=lambda:4,pitch_for=lambda:14,calc_aoa=lambda:12,
            update_team_dap_gui=lambda:None,check_abort=lambda *a:{'abort':False},
            normalized_heading_error=lambda a,b:(a-b+180)%360-180,
            flight_log_event=lambda *a:None)
        main=(ROOT/'Script/Poseidon_SSTO/Poseidon_SSTO_Orbit_Main.ks').read_text()
        # Source helper counts nested braces; the tested block is production.
        from test_ascent_abort import source_block
        runtime.load_source(source_block(main,'if step = "ascent_alignment"{'),'actual-alignment-step')
        return g

    def test_clear_aligned_departure_resumes_acceleration_without_waypoint_speed_hold(self):
        g=self.alignment()
        self.assertEqual(g.get_value('step'),'speed_build')
        self.assertEqual(g.get_value('dapthrottle'),1)

    def test_planned_dogleg_cannot_be_skipped_by_initial_runway_alignment(self):
        g=self.alignment(first_course=-15)
        self.assertEqual(g.get_value('step'),'ascent_alignment')
        self.assertEqual(g.get_value('departure_route')['index'],0)

    def test_early_turn_preserves_pitch_and_unloads_bank_when_climb_is_lost(self):
        g=self.alignment(orbital_course=45,first_course=45)
        self.assertLess(g.get_value('dap')['aoa']['target_bank'],0)
        self.assertGreaterEqual(g.get_value('ascent_alignment_debug')['pitch_floor'],14)
        weak=self.alignment(orbital_course=45,first_course=45,vs=-2)
        self.assertEqual(weak.get_value('dap')['aoa']['target_bank'],0)
        self.assertEqual(weak.get_value('dapthrottle'),1)
