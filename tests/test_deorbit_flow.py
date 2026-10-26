"""Real POS3 orchestration: ownership, modes, rejection and entry handoff."""
from pathlib import Path
from types import SimpleNamespace as NS
import unittest
from tools.pos_sim.kos_script_runtime import ScriptRuntime
from tools.pos_sim.math3d import Vec

ROOT=Path(__file__).resolve().parents[1]
LIB=ROOT/'Script/Libraries/Poseidon_SSTO'

class FlowHost:
    maximum_loop_iterations=1000
    def __init__(self):
        self.nodes=[];self.events=[];self.executions=0;self.engine_calls=0;self.scans=0
        self.body=NS(name='Kerbin',radius=600000,atm=NS(height=70000))
        self.ship=NS(body=self.body,periapsis=100000,apoapsis=100000,
                     orbit=NS(eccentricity=0,hasnextpatch=False,inclination=0),
                     availablethrust=120,mass=50,liquidfuel=1500)
    def resolve_name(self,name):
        if name=='ship':return self.ship
        if name=='time':return NS(seconds=0)
        if name=='hasnode':return bool(self.nodes)
        if name=='nextnode' and self.nodes:return self.nodes[0]
        raise NameError(name)
    def node(self,ut,radial,normal,prograde):
        return NS(time=ut,normal=normal,radialout=radial,prograde=prograde,deltav=Vec(abs(prograde),0,0),
                  orbit=NS(periapsis=10000,eccentricity=.1,hasnextpatch=False))
    def begin(self,*args):
        self.scans+=1
        return dict(done=False,next_ut=100,epoch=0,end_ut=1000,sample_count=2,feasible_count=1,last_rejection='',result=dict(valid=True,
                    node_ut=1000,radial=0,normal=0,prograde=-100,delta_v=100,
                    entry_ut=1500,entry_speed=2300,entry_angle=-5,range_m=850000,crossrange_m=0))
    def scan_step(self,state):
        state['done']=state['next_ut']>100
        state['next_ut']+=100
        return state
    def execute(self,node):
        self.executions+=1
        self.ship.periapsis=10000
        self.nodes.remove(node)
        return dict(success=True,reason='complete',remaining_dv=0)
    def engines(self):self.engine_calls+=1
    def builtins(self):
        return dict(node=self.node,flight_log_event=lambda *a:self.events.append(a),
                    nervson=self.engines,rapiersoff=lambda:None,ship_isp=lambda:800,
                    calculate_burn_time=lambda *a:60,deorbit_begin=self.begin,
                    deorbit_step=self.scan_step,deorbit_execute=self.execute)
    def command(self,kind,value):
        if kind=='print':return
        if kind=='add':self.nodes.append(value)
        else:raise AssertionError((kind,value))
    def action(self,*args):pass
    def physics_tick(self,*args):pass

class FlowTest(unittest.TestCase):
    def make(self,mode='auto'):
        h=FlowHost();r=ScriptRuntime(ROOT,h)
        r.load_source((LIB/'deorbit.ks').read_text(),str(LIB/'deorbit.ks'))
        # Reinstall scenario boundary adapters after loading the pure planner.
        for key,val in h.builtins().items():r.globals[key]=val
        r.load_source((LIB/'deorbit_flow.ks').read_text(),str(LIB/'deorbit_flow.ks'))
        r.globals.update(step='Deorbit',substep='',reentry_mode=mode,abort_flag=False,
                         deorbit_scan_active=False,deorbit_scan={},runway_start=NS(lat=0,lng=0),
                         location='KSC',runway_nr='09',dap=dict(dap_mode='auto',setup=lambda:None),
                         recovery_result=dict(complete=False))
        r.globals['constant']['g0']=9.80665
        return h,r
    def update(self,r):r.globals.get_value('reentry_deorbit_update')()
    def test_auto_yields_search_then_executes_and_hands_off(self):
        h,r=self.make();self.update(r)
        self.assertEqual(h.scans,1);self.assertEqual(h.executions,0)
        self.assertEqual(r.globals['step'],'Deorbit')
        self.update(r)
        self.assertEqual(h.executions,1);self.assertEqual(h.nodes,[])
        self.assertEqual(r.globals['step'],'reentry_low')
        self.assertIn('deorbit_plan_ready',[e[0] for e in h.events])
    def test_executor_preserves_terminal_fuel_reserve(self):
        h,r=self.make('Ex');h.nodes=[h.node(1000,0,0,-100)]
        h.ship.liquidfuel=200
        self.update(r)
        self.assertEqual(h.executions,0)
        self.assertEqual(r.globals['recovery_result']['reason'],'insufficient_fuel_after_terminal_reserve')

    def test_manual_does_not_plan_or_command_engines(self):
        h,r=self.make('Man');self.update(r)
        self.assertEqual((h.scans,h.executions,h.engine_calls),(0,0,0))
        h.ship.periapsis=20000;self.update(r)
        self.assertEqual(r.globals['step'],'reentry_low')
    def test_executor_requires_node_and_does_not_plan(self):
        h,r=self.make('Ex');self.update(r)
        self.assertEqual(r.globals['recovery_result']['reason'],'executor_requires_map_node')
        h,r=self.make('Ex');h.nodes=[h.node(1000,0,0,-100)];self.update(r)
        self.assertEqual((h.scans,h.executions),(0,1))
    def test_unreachable_site_existing_node_and_pilot_handoff_do_not_burn(self):
        for case,reason in [('pole','site_not_reachable_from_orbital_plane'),
                            ('existing','resolve_existing_nodes_first'),('pilot','pilot_cancelled')]:
            with self.subTest(case=case):
                h,r=self.make()
                if case=='pole':r.globals['runway_start']=NS(lat=90,lng=0)
                if case=='existing':h.nodes=[h.node(1000,0,0,-100)]
                if case=='pilot':r.globals['dap']['dap_mode']='manual'
                self.update(r)
                self.assertEqual(h.executions,0);self.assertEqual(h.engine_calls,0)
                self.assertEqual(r.globals['recovery_result']['reason'],reason)
    def test_executor_rejects_plane_change_and_failed_burn_stays_out_of_entry(self):
        h,r=self.make('Ex');h.nodes=[h.node(1000,0,50,-100)];self.update(r)
        self.assertEqual(h.executions,0)
        self.assertEqual(r.globals['recovery_result']['reason'],'node_plane_change')
        h,r=self.make('Ex');h.nodes=[h.node(1000,0,0,-100)]
        r.globals['deorbit_execute']=lambda _:dict(success=False,reason='lost_thrust',remaining_dv=80)
        self.update(r)
        self.assertEqual(r.globals['step'],'end')
        self.assertEqual(r.globals['recovery_result']['reason'],'lost_thrust')

    def test_partial_burn_keeps_entry_control_but_pilot_cancel_does_not(self):
        for reason,expected in [('lost_thrust','reentry_low'),('cancelled','end')]:
            with self.subTest(reason=reason):
                h,r=self.make('Ex');h.nodes=[h.node(1000,0,0,-100)]
                def partial(_):
                    h.ship.periapsis=20000
                    return dict(success=False,reason=reason,remaining_dv=20)
                r.globals['deorbit_execute']=partial
                self.update(r)
                self.assertEqual(r.globals['step'],expected)
                if expected=='reentry_low':self.assertIn('deorbit_partial_entry',[e[0] for e in h.events])

if __name__=='__main__':unittest.main()
