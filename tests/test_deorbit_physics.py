"""Finite NERV burns: real .ks executor against the independent orbital plant.

This stops at burn completion; atmospheric lift/FAR and landing remain KSP
validation. Logging is a passive stub and cannot affect the trajectory.
"""
import math
import os
from pathlib import Path
import re
import unittest
from tools.pos_sim.bodies import stock_body
from tools.pos_sim.kos_runtime import OpcodeScheduler
from tools.pos_sim.kos_script_runtime import ScriptRuntime
from tools.pos_sim.math3d import Vec
from tools.pos_sim.physics import PhysicsSimulator
from tools.pos_sim.pos5_host import Pos5Host, ShipHost, propagate_kepler

ROOT=Path(__file__).resolve().parents[1]
LIB=ROOT/'Script/Libraries/Poseidon_SSTO'

class BurnShip(ShipHost):
    @property
    def maxthrust(self):return self.host.vehicle.thrust_kn
    @property
    def thrust(self):return self.host.state.throttle*self.availablethrust

class BurnHost(Pos5Host):
    def __init__(self,height):
        super().__init__(ROOT,liquid_fuel_units=1500)
        self.body=stock_body('Kerbin')
        self.simulator=PhysicsSimulator(self.body,self.vehicle,dt=.02)
        radius=self.body.radius+height
        self.state.position=Vec(radius,0,0)
        self.state.velocity=Vec(0,math.sqrt(self.body.mu/radius),0)
        self.state.forward=Vec(0,-1,0)
        self.ship=BurnShip(self)
        self.nerv_enabled=True
    def builtins(self):
        result=super().builtins()
        result.update(ship_isp=lambda:800,flight_log_event=self.flight_log_event,
                      flight_log_maneuver_observe=lambda *a:None,flight_log_tick=lambda *a:None,
                      update_readouts=lambda:None,update_reentry_gui=lambda:None)
        return result
    def physics_tick(self,dt):
        # Route actual executor locks to the independent host, instead of DAP.
        if self.runtime:
            self.runtime.globals['dapthrottle']=self.runtime.globals.get('throttle',0)
            self.dap['vector']['targetVector']=self.runtime.globals.get('steering',self.state.forward)
        super().physics_tick(dt)

class BurnPhysicsTest(unittest.TestCase):
    def test_finite_burn_establishes_atmospheric_periapsis_at_low_and_high_orbits(self):
        for height in (80000,2000000):
            with self.subTest(height=height):
                h=BurnHost(height);r=ScriptRuntime(ROOT,h);h.runtime=r
                r.globals['constant'].update(g0=9.80665,pi=math.pi)
                r.load_source((LIB/'deorbit.ks').read_text(),str(LIB/'deorbit.ks'))
                r.load_source((LIB/'deorbit_execute.ks').read_text(),str(LIB/'deorbit_execute.ks'))
                helpers=(ROOT/'Script/Libraries/lib_orbital_nodes.ks').read_text()
                for name in ('calculate_burn_time','half_burn_time'):
                    match=re.search(r'^function '+name+r'\s*\{.*?^}',helpers,re.M|re.S)
                    r.load_source(match.group(),name)
                arc=r.globals.get_value('deorbit_arc')(
                    h.body.mu,h.state.position,h.state.velocity,
                    h.body.radius+r.globals.get_value('deorbit_periapsis_for_height')(height),660000)
                self.assertTrue(arc['valid'])
                node=h.node(600,0,0,-arc['delta_v']);h.nodes.append(node)
                half=r.globals.get_value('half_burn_time')(node)
                # Skip most coast analytically; execute alignment/ignition and
                # every finite-thrust plant tick at 2000 IPU / 0.02 seconds.
                h.warp_to(node.time-half-30)
                h.state.forward=node.deltav.normalized
                r.globals.update(abort_flag=False,running=True,step='Deorbit',dap=h.dap)
                h.dap['dap_mode']='auto'
                r.scheduler=OpcodeScheduler(ipu=2000,tick_seconds=.02,on_tick=r._physics_tick)
                result=r.globals.get_value('deorbit_execute')(node)
                self.assertTrue(result['success'],result)
                self.assertLess(result['remaining_dv'],.21)
                self.assertLess(h.ship.periapsis,70000)
                expected_pe=r.globals.get_value('deorbit_periapsis_for_height')(height)
                self.assertLess(abs(h.ship.periapsis-expected_pe),10000)
                self.assertGreater(h.ship.liquidfuel,200)
                self.assertEqual(r.globals['throttle'],0)
                self.assertEqual(r.globals['warp'],0)
                evidence_dir=os.environ.get('POS_DEORBIT_EVIDENCE')
                if evidence_dir:
                    # Let the independent plant consume the returned zero
                    # throttle command before recording the terminal sample.
                    h.physics_tick(.02)
                    h.record_sample(force=True)
                    h.write_trace(Path(evidence_dir)/f'burn_{height}_trace.csv')
                    h.write_events(Path(evidence_dir)/f'burn_{height}_events.csv')

if __name__=='__main__':unittest.main()
