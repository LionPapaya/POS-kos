"""A confirmed deorbit site survives failed entry solves without runway search."""
from pathlib import Path
import re
import unittest
from tools.pos_sim.kos_script_runtime import ScriptRuntime
from tools.pos_sim.math3d import Vec

ROOT=Path(__file__).resolve().parents[1]
GUID=(ROOT/'Script/Libraries/Poseidon_SSTO/entry_guid.ks').read_text()

def function_source(name):
    start=re.search(r'^function '+name+r'\s*\{',GUID,re.M).start()
    following=re.search(r'^function ',GUID[start+1:],re.M)
    return GUID[start:start+1+following.start()] if following else GUID[start:]

class ConfirmedTargetTest(unittest.TestCase):
    def test_failed_solve_retries_confirmed_site_without_alternate_prediction(self):
        class Host:
            maximum_loop_iterations=1000
            def builtins(self):return {}
            def resolve_name(self,name):raise NameError(name)
        kos=ScriptRuntime(ROOT,Host())
        kos.load_source('\n'.join(function_source(name) for name in
            ('entry_selection_result','entry_confirmed_selection','reentry_recovery_update')),'entry target')
        calls=[]
        target=dict(target_latlng='confirmed-point',target_altitude=22000,team_interface_box='box')
        def forbidden(*args):raise AssertionError('alternate runway search ran')
        kos.globals.update(team_interface=target,location='KSC',runway_nr='09',runway_start='start',
            runway_end='end',runway_heading=90,runway_altitude=70,reentry_selected_site_locked=True,
            time={'seconds':100},ship={'altitude':60000},aves={'TEAMAltitude':22000},
            entry_basic_next_update=200,entry_solver_next_retry_time=0,entry_rejected_runways={},
            entry_select_runway=forbidden,current_simstate=lambda:{},
            reentry_basic_update=lambda:None,reentry_live_control_update=lambda:None,
            reentry_apply_target=lambda sel:calls.append(('apply',sel['location'],sel['runway'])),
            flight_log_event=lambda *args:calls.append(args),flight_log_entry_solver_result=lambda *_:None,
            flight_log_entry_recovery=lambda *_:None,entry_display_empty_path=lambda _:dict())
        def solve(state,alt,point,box,*args):
            calls.append(('solve',point))
            return dict(converged=False,error={'str':'no solution'})
        kos.globals['calc_entry_traj']=solve
        kos.globals.get_value('reentry_recovery_update')()
        self.assertIn(('solve','confirmed-point'),calls)
        self.assertEqual(kos.globals['location'],'KSC')
        self.assertEqual(kos.globals['runway_nr'],'09')
        self.assertEqual(kos.globals['entry_solver_next_retry_time'],110)
        self.assertTrue(kos.globals['basice_reentry_guidance'])
        self.assertTrue(all(c[1:] == ('KSC','09') for c in calls if c[0]=='apply'))
        self.assertTrue(any(c[0]=='entry_target_search' and 'reason=confirmed_site' in c[1] for c in calls))

class DeorbitLoggerTest(unittest.TestCase):
    def test_extra_deorbit_fields_preserve_all_performance_level_cadences(self):
        class Host:
            maximum_loop_iterations=1000
            def builtins(self):return {}
            def resolve_name(self,name):raise NameError(name)
        logger=(ROOT/'Script/Libraries/Poseidon_SSTO/flight_log.ks').read_text()
        start=logger.index('function flight_log_maneuver_observe')
        end=logger.index('function ',start+1)
        kos=ScriptRuntime(ROOT,Host());kos.load_source(logger[start:end],'deorbit logger')
        ship=dict(facing=dict(vector=Vec(1,0,0)),control=dict(mainthrottle=0),mass=50,
                  availablethrust=120,thrust=0,liquidfuel=1500,altitude=100000,
                  apoapsis=100000,periapsis=100000,orbit=dict(inclination=0))
        node=dict(deltav=Vec(100,0,0),eta=1000)
        kos.globals.update(ship=ship,warp=0,time=dict(seconds=0))
        events=[];kos.globals['flight_log_event']=lambda *a:events.append(a)
        for level,count in [(0,0),(1,0),(2,1),(3,3)]:
            with self.subTest(level=level):
                events.clear();kos.globals['pos_log_level']=level
                evidence=dict(phase='aligning',burn_seen=False,next_sample=0)
                for ut in (0,.02,.04):
                    kos.globals['time']['seconds']=ut
                    kos.globals.get_value('flight_log_maneuver_observe')(node,30,evidence,True)
                samples=[e[1] for e in events if e[0]=='maneuver_sample']
                self.assertEqual(len(samples),count)
                for sample in samples:
                    for field in ('actual_thrust=0','lf=1500','altitude=100000'):
                        self.assertIn(field,sample)

if __name__=='__main__':unittest.main()
