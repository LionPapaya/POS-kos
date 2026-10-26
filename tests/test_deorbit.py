"""Real KerboScript analytic planner versus independent two-body invariants."""
import math
from pathlib import Path
import unittest
from tools.pos_sim.kos_runtime import Runtime, OpcodeScheduler
from tools.pos_sim.math3d import Vec, dot

SOURCE = Path(__file__).resolve().parents[1]/'Script/Libraries/Poseidon_SSTO/deorbit.ks'
MU=3.5316e12

class DeorbitTest(unittest.TestCase):
    def setUp(self):
        self.kos=Runtime(SOURCE.read_text())
        # Runtime lacks these standard kOS scalar primitives/constants.
        self.kos.globals['constant']['pi']=math.pi
        self.kos.globals['constant']['g0']=9.80665
        self.kos.globals['mod']=lambda x,y: x%y
        self.kos.globals['arctan2']=lambda y,x: math.degrees(math.atan2(y,x))
        self.kos.scheduler=OpcodeScheduler(ipu=2000,tick_seconds=.02)
        self.cfg=self.kos.call('deorbit_config')
    def arc(self, height=100000, radial=0, speed=None):
        radius=600000+height
        speed=speed or math.sqrt(MU/radius)
        return self.kos.call('deorbit_arc',MU,Vec(radius,0,0),Vec(radial,speed,0),630000,670000)
    def test_circular_altitude_span_and_invariants(self):
        for height in (80000,100000,500000,2000000):
            with self.subTest(height=height):
                arc=self.arc(height)
                self.assertTrue(arc['valid'])
                r=arc['entry_r'];v=arc['entry_v']
                self.assertAlmostEqual(r.mag,670000,places=6)
                radius=600000+height
                after=math.sqrt(MU/radius)-arc['delta_v']
                energy=after**2/2-MU/radius
                self.assertAlmostEqual(v.mag**2/2-MU/r.mag,energy,places=6)
                self.assertAlmostEqual(radius*after,math.sqrt(r.mag**2*v.mag**2-dot(r,v)**2),places=3)
                a=-MU/(2*energy)
                e=math.sqrt(1-(radius*after)**2/(MU*a))
                self.assertAlmostEqual(a*(1-e),630000,places=5)
                self.assertLess(dot(r,v),0)
                self.assertGreater(arc['coast_time'],0)
                self.assertLess(arc['coast_time'],2*math.pi*math.sqrt(a**3/MU))
                self.assertEqual(arc['normal'],0)
                self.assertEqual(arc['radial'],0)
    def test_elliptical_inbound_and_outbound(self):
        for radial in (-500,500):
            arc=self.arc(500000,radial,1700)
            self.assertTrue(arc['valid'])
            # Independent small-step velocity-Verlet trajectory to the interface.
            r=Vec(1100000,0,0);original=Vec(radial,1700,0)
            v=original*(1-arc['delta_v']/original.mag)
            dt=.1;elapsed=0
            while r.mag>670000 and elapsed<arc['coast_time']+dt:
                acc=r*(-MU/r.mag**3)
                next_r=r+v*dt+acc*(dt*dt/2)
                v=v+(acc+next_r*(-MU/next_r.mag**3))*(dt/2)
                r=next_r;elapsed+=dt
            self.assertLess(abs(elapsed-arc['coast_time']),.2)
            self.assertLess((r-arc['entry_r']).mag,400)
    def test_rotation_and_plane_envelope_fuel_limits(self):
        rotated=self.kos.call('deorbit_rotate',Vec(600000,0,0),Vec(0,0,1),90)
        self.assertLess((rotated-Vec(0,600000,0)).mag,1e-7)
        arc=self.arc()
        angle=850000/600000
        entry=arc['entry_r'].normalized
        along=Vec(-entry.y,entry.x,0)
        target=(entry*math.cos(angle)+along*math.sin(angle))*600000
        result=self.kos.call('deorbit_score',arc,target,600000,self.cfg)
        self.assertTrue(result['valid'],result['reason'])
        self.assertAlmostEqual(result['range_m'],850000)
        self.assertFalse(self.kos.call('deorbit_score',self.arc(),target+Vec(0,0,300000),600000,self.cfg)['valid'])
        self.cfg['available_dv']=1
        self.assertEqual(self.kos.call('deorbit_score',self.arc(),target,600000,self.cfg)['reason'],'dv_or_fuel_limit')
    def test_incremental_scan_uses_future_states_and_finishes(self):
        self.kos.globals['ship']={'body':{'mu':MU,'radius':600000,'position':Vec(0,0,0),'angularvel':Vec(0,0,0),'atm':{'height':70000}}}
        calls=[]
        def position(craft,ut):
            calls.append(ut)
            return Vec(700000,0,0)
        self.kos.globals['positionat']=position
        self.kos.globals['velocityat']=lambda craft,ut: {'orbit':Vec(0,math.sqrt(MU/700000),0)}
        arc=self.kos.call('deorbit_arc',MU,Vec(700000,0,0),Vec(0,math.sqrt(MU/700000),0),600000+self.kos.call('deorbit_periapsis_for_height',100000),660000)
        entry=arc['entry_r'].normalized
        angle=850000/600000
        target=(entry*math.cos(angle)+Vec(-entry.y,entry.x,0)*math.sin(angle))*600000
        state={'done':False,'cfg':self.cfg,'epoch':0,'next_ut':120,'end_ut':140,
               'step_seconds':10,'target_r':target,'spin_axis':Vec(0,0,1),
               'spin_rate':0,'best_cost':1e30,'result':{'valid':False},
               'sample_count':0,'feasible_count':0,'last_rejection':''}
        for _ in range(3): state=self.kos.call('deorbit_step',state)
        self.assertTrue(state['done'])
        self.assertEqual(calls,[120,130,140])
        self.assertTrue(state['result']['valid'])
        self.assertEqual(state['result']['entry_ut'],120+arc['coast_time'])
        self.kos.call('deorbit_step',state)
        self.assertEqual(len(calls),3)

    def test_invalid_geometry(self):
        self.assertFalse(self.arc(60000)['valid'])
        self.assertFalse(self.kos.call('deorbit_arc',MU,Vec(700000,0,0),Vec(0,0,0),630000,670000)['valid'])

if __name__=='__main__': unittest.main()

class DeorbitPassSearchTest(unittest.TestCase):
    """Search real onboard code with independently propagated source orbits."""
    def search(self, height, inclination, site_lat=0, site_lng=0):
        from tools.pos_sim.pos5_host import propagate_kepler
        kos=Runtime(SOURCE.read_text())
        kos.globals['constant']['pi']=math.pi
        kos.globals['mod']=lambda x,y:x%y
        kos.globals['arctan2']=lambda y,x:math.degrees(math.atan2(y,x))
        r=Vec(600000+height,0,0)
        speed=math.sqrt(MU/r.mag)
        inc=math.radians(inclination)
        v=Vec(0,speed*math.cos(inc),speed*math.sin(inc))
        omega=2*math.pi/21549.425
        period=2*math.pi*math.sqrt(r.mag**3/MU)
        body=dict(mu=MU,radius=600000,position=Vec(0,0,0),angularvel=Vec(0,0,omega),
                  atm=dict(height=70000,exists=True))
        kos.globals['ship']=dict(body=body,periapsis=height,orbit=dict(period=period))
        kos.globals['time']=dict(seconds=0)
        kos.globals['positionat']=lambda craft,ut:propagate_kepler(r,v,ut,MU)[0]
        kos.globals['velocityat']=lambda craft,ut:dict(orbit=propagate_kepler(r,v,ut,MU)[1])
        phi=math.radians(site_lat);lng=math.radians(site_lng)
        target=dict(position=Vec(math.cos(phi)*math.cos(lng),math.cos(phi)*math.sin(lng),math.sin(phi))*600000)
        kos.scheduler=OpcodeScheduler(ipu=2000,tick_seconds=.02)
        cfg=kos.call('deorbit_config')
        state=kos.call('deorbit_begin',target,cfg)
        count=0
        while not state['done']:
            state=kos.call('deorbit_step',state)
            count+=1
            self.assertLess(count,1100)
        return state['result'],kos,state

    def test_complete_search_circular_prograde_inclined_and_retrograde(self):
        for height in (80000,500000,2000000):
            for inc in (0,45,180):
                with self.subTest(height=height,inclination=inc):
                    result,kos,state=self.search(height,inc)
                    self.assertTrue(result['valid'],result['reason'])
                    self.assertGreater(result['range_m'],650000)
                    self.assertLess(result['range_m'],1600000)
                    self.assertLess(abs(result['crossrange_m']),120000)
                    self.assertLess(result['delta_v'],500)
                    self.assertEqual(result['normal'],0)
                    self.assertLess(result['node_ut'],state['end_ut'])

    def test_equatorial_orbit_cannot_target_pole(self):
        result,_,_=self.search(100000,0,90)
        self.assertFalse(result['valid'])

    def test_target_rotation_and_wait_for_later_pass(self):
        result,_,_=self.search(2000000,45,35,179)
        self.assertTrue(result['valid'],result['reason'])
        self.assertGreater(result['node_ut'],120)
