"""Execute the onboard executor with deterministic control/node faults."""
from pathlib import Path
from types import SimpleNamespace as NS
import unittest
from tools.pos_sim.kos_runtime import OpcodeScheduler
from tools.pos_sim.kos_script_runtime import ScriptRuntime
from tools.pos_sim.math3d import Vec

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'Script/Libraries/Poseidon_SSTO/deorbit_execute.ks'

class Host:
    maximum_loop_iterations = 10000
    def __init__(self, fault=None):
        self.time = NS(seconds=0.)
        self.ship = NS(availablethrust=100., maxthrust=100., thrust=100., mass=10., liquidfuel=100.,
                       facing=NS(vector=Vec(1,0,0)), control=NS(pilotmainthrottle=0., mainthrottle=0.))
        self.node = NS(time=15., prograde=10., normal=0., radialout=0., deltav=Vec(10,0,0), eta=15.)
        self.nodes=[self.node]
        self.fault=fault
        self.commanded=0.
        self.events=[]
    def attach_runtime(self,runtime): self.runtime=runtime
    def builtins(self):
        return dict(ship_isp=lambda:800., half_burn_time=lambda n:2., calculate_burn_time=lambda *a:4.,
                    flight_log_event=lambda *a:self.events.append(a), flight_log_maneuver_observe=lambda *a:None,
                    update_readouts=lambda:None, update_reentry_gui=lambda:None, flight_log_tick=lambda *a:None)
    def resolve_name(self,name):
        values={'time':self.time,'ship':self.ship,'hasnode':bool(self.nodes),'nextnode':self.nodes[0] if self.nodes else None}
        if name in values: return values[name]
        raise NameError(name)
    def lock(self,name,value):
        if name==('name','throttle'): self.commanded=value
    def unlock(self,*args): pass
    def action(self,*args): pass
    def command(self,kind,value):
        if kind=='remove': self.nodes.remove(value)
        else: raise AssertionError(kind)
    def physics_tick(self,dt):
        self.time.seconds+=dt
        self.node.eta=self.node.time-self.time.seconds
        if self.commanded>0 and self.fault!='stall':
            self.node.deltav=Vec(max(0,self.node.deltav.mag-dt*5*self.commanded),0,0)
        if self.time.seconds>1:
            if self.fault=='abort': self.runtime.globals['abort_flag']=True
            if self.fault=='edit': self.node.prograde=20.
            if self.fault=='remove': self.nodes=[]
            if self.fault=='mode': self.runtime.globals['dap']={'dap_mode':'off'}
            if self.fault=='step': self.runtime.globals['step']='end'
        if self.fault=='lost': self.ship.thrust=0.

class ExecutorTest(unittest.TestCase):
    def run_executor(self,fault=None,configure=None):
        host=Host(fault)
        runtime=ScriptRuntime(ROOT,host)
        host.runtime=runtime
        runtime.load_source(SOURCE.read_text(),str(SOURCE))
        runtime.globals.update(abort_flag=False, running=True, step='Deorbit', dap={'dap_mode':'auto'})
        runtime.globals['constant']['g0']=9.80665
        if configure: configure(host)
        runtime.scheduler=OpcodeScheduler(ipu=2000,tick_seconds=.02,on_tick=runtime._physics_tick)
        result=runtime.globals.get_value('deorbit_execute')(host.node)
        self.assertEqual(host.commanded,0.)
        self.assertEqual(host.ship.control.pilotmainthrottle,0.)
        self.assertLess(host.time.seconds,60)
        return result,host
    def test_guard_enforces_deadline_and_fault_priority(self):
        host=Host()
        runtime=ScriptRuntime(ROOT,host)
        runtime.load_source(SOURCE.read_text(),str(SOURCE))
        sample=dict(cancelled=False,owned=True,edited=False,available=100,fuel=10,
                    elapsed=101,deadline=100,burning=False,stalled=0,unpowered=0)
        guard=runtime.globals.get_value('deorbit_execute_guard')
        self.assertEqual(guard(sample),'timeout')
        sample['cancelled']=True
        self.assertEqual(guard(sample),'cancelled')

    def test_success_removes_only_completed_node(self):
        result,host=self.run_executor()
        self.assertTrue(result['success'])
        self.assertLessEqual(result['remaining_dv'],.2)
        self.assertEqual(host.nodes,[])
    def test_faults_stop_and_retain_node(self):
        for fault,reason in [('abort','cancelled'),('mode','cancelled'),('step','cancelled'),('edit','node_edited'),
                             ('remove','node_lost'),('stall','no_progress'),('lost','lost_thrust')]:
            with self.subTest(fault=fault):
                result,host=self.run_executor(fault)
                self.assertFalse(result['success'])
                self.assertEqual(result['reason'],reason)
                if fault!='remove': self.assertEqual(host.nodes,[host.node])
    def test_preflight_rejections(self):
        for reason,configure in [
            ('insufficient_lead_time',lambda h:setattr(h.node,'eta',1)),
            ('excessive_coast',lambda h:setattr(h.node,'eta',90000)),
            ('insufficient_fuel',lambda h:setattr(h.ship,'liquidfuel',.001)),
            ('no_thrust',lambda h:setattr(h.ship,'availablethrust',0)),
            ('node_lost',lambda h:h.nodes.insert(0,NS())),
            ('not_aligned',lambda h:setattr(h.ship.facing,'vector',Vec(0,1,0)))]:
            with self.subTest(reason=reason):
                result,host=self.run_executor(configure=configure)
                self.assertEqual(result['reason'],reason)
                self.assertIn(host.node,host.nodes)

if __name__=='__main__': unittest.main()
