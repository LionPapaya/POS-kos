// Executes translated production kOS bodies with deterministic UI, clock and
// FAR boundaries. This checks orchestration, not Unity scheduling/FAR accuracy.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
function translate(source){
  const strings=[];
  let s=source.replace(/"[^"\n]*"|\/\/[^\n]*/g,m=>{
    if(m.startsWith('//'))return '';
    strings.push(m);return `STRTOKEN${strings.length-1}`;
  });
  s=s.replace(/RUNONCEPATH\([^;]*?\)\./gi,'');
  s=s.replace(/function (\w+)\s*\{\s*(?:parameter ([^.]+)\.)?/gi,(_,n,p)=>`function ${n}(${p||''}) {`);
  s=s.replace(/\bparameter\b/g,'let');
  s=s.replace(/<>/g,'!==').replace(/(?<=[\w\]\)])\s*=\s*(?!=)/g,' === ')
    .replace(/\band\b/gi,'&&').replace(/\bor\b/gi,'||').replace(/\bnot\b/gi,'!')
    .replace(/\^/g,'**').replace(/:(\w+)/g,(_,n)=>'.'+n.toLowerCase())
    .replace(/\b(?:local|global) (\w+) (?:is|to) /gi,'let $1 = ')
    .replace(/\bset ([\w.]+) to \{/gi,'$1 = () => {')
    .replace(/\bset ([\s\S]*?) to ([\s\S]*?)\.(?=\s|})/gi,'$1 = $2;')
    .replace(/\bunlock (\w+)\./gi,'unlock("$1");')
    .replace(/\bbrakes off\./gi,'brakesOff();')
    .replace(/\bwait 0\./gi,'tick();')
    .replace(/\bclearScreen\./gi,'')
    .replace(/\bprint ([^;]*?)\.(?=\s|})/gi,'print($1);')
    .replace(/\bdefined (\w+)/gi,'defined("$1")')
    .replace(/\buntil ([^{]+)\{/gi,'while (!($1)) {')
    .replace(/\bif ([^{]+)\{/gi,'if ($1) {')
    .replace(/\.(?=\s|})/g,';');
  return s.replace(/STRTOKEN(\d+)/g,(_,n)=>strings[n]);
}
const helpers=translate(read('Script/Libraries/Poseidon_SSTO/aerobrake.ks'));
const main=translate(read('Script/Poseidon_SSTO/Poseidon_SSTO_Aerobrake.ks'));
const lex=(...args)=>Object.fromEntries(Array.from({length:args.length/2},(_,i)=>[args[2*i],args[2*i+1]]));
let checks=0;
function check(cond,msg){checks++;assert.ok(cond,msg);}
function environment(){
  const env={check,lex,abs:Math.abs,max:Math.max,min:Math.min,sqrt:Math.sqrt,list:(...a)=>a,
    round:(n,p=0)=>+n.toFixed(p),CONFIG:{},print:()=>{},pos_gui_window_style:()=>{},calc_aoa:()=>25,
    kuniverse:{realtime:0},KUNIVERSE:null,events:[],unlocks:[],ticks:0,brakeCalls:0,aeroCalls:[],stepCalls:[],
    SHIP:{altitude:60000,periapsis:45000,apoapsis:100000,verticalspeed:-100,
      body:{atm:{exists:true,height:70000},mu:3.5316e12,radius:600000,angularvel:0}},
    AVES:{EGAOA:h=>h>40000?30:20}};
  env.KUNIVERSE=env.kuniverse;
  env.dap={dap_mode:'css',str_mode:'aerostr',aoa:{},handoff:{active:true,protected:true},envelope:{restore_steering:true},
    dap_mode_set:{dapmode:'css'},setup(){},update(){env.controlUpdates++},
    set_aoa_auto(){env.autoAttached=true;env.dap.dap_mode='auto';env.dap.str_mode='aoa';env.dap.dap_mode_set.dapmode='auto';},
    set_off(){env.dap.dap_mode='off';env.dap.dap_mode_set.dapmode='off';},
    set_css(){env.dap.dap_mode='css';env.dap.dap_mode_set.dapmode='css';}};
  env.controlUpdates=0;env.dapthrottle=0;
  env.time={seconds:0};env.flight_log_begin=()=>{};
  env.flight_log_event=(...a)=>env.events.push(a);env.flight_log_tick=()=>{};
  env.unlock=n=>env.unlocks.push(n);env.brakesOff=()=>env.brakeCalls++;
  env.defined=n=>n in env;env.main_dap_mode_menu={index:1};
  env.current_simstate=()=>({altitude:60000,position:{mag:660000},velocity:{sqrmagnitude:4000000},surfvel:{mag:2000}});
  env.gravitacc=()=>0;
  env.sim_aeroaccel_load=(...a)=>{env.aeroCalls.push(a);return 0;};
  env.update_simstate_total_accel=(state,acc,dt)=>{
    env.stepCalls.push(dt);return env.nextState||state;
  };
  env.vcrs=()=>({sqrmagnitude:660000**2*2000**2});env.vdot=()=>1;
  env.widgets=[];
  function widget(text='',value=0){const w={text,value,style:{},pressed:value,
    show(){},dispose(){env.disposed=true;}};
    for(const method of ['addhbox','addvbox','addlabel','addhslider','addcheckbox','addbutton'])
      w[method]=(t,v)=>{const child=widget(t,method==='addhslider'?t:v);env.widgets.push(child);return child;};
    return w;
  }
  env.GUI=()=>widget();
  env.tick=()=>{env.ticks++;env.kuniverse.realtime+=.02;env.time.seconds+=.02;
    if(env.onTick)env.onTick(env);if(env.ticks>300)throw Error('runaway main loop');};
  env.runpath=p=>{env.handoff={path:p,mode:env.dap.dap_mode,cached:env.dap.dap_mode_set.dapmode,
    steering:env.dap.str_mode,unlocks:[...env.unlocks],disposed:env.disposed};};
  return env;
}
function run(env,code){return Function('env',`with(env){${helpers}\n${code}}`)(env);}
let e=environment();
run(e,`
const t=aerobrake_prediction_tracker();
check(aerobrake_prediction_due(t,0,30,false,0),'initial preview');
aerobrake_prediction_begin(t,0,30,false,0);
check(!aerobrake_prediction_due(t,10,30,false,1),'exactly ten is below trigger');
check(!aerobrake_prediction_due(t,11,30,false,2),'change waits for stability');
check(!aerobrake_prediction_due(t,12,30,false,3.5),'motion resets debounce');
check(!aerobrake_prediction_due(t,12,30,false,5.49),'not yet two seconds');
check(aerobrake_prediction_due(t,12,30,false,5.5),'stable significant bank change');
aerobrake_prediction_begin(t,12,30,false,5.5);
check(!aerobrake_prediction_due(t,12,41,false,6),'AoA debounce');
check(aerobrake_prediction_due(t,12,41,false,8),'AoA trigger');
aerobrake_prediction_begin(t,12,41,false,8);
check(!aerobrake_prediction_due(t,13,42,false,27.99),'small changes wait for periodic update');
check(aerobrake_prediction_due(t,14,43,false,28),'periodic refresh even while inputs move');
aerobrake_prediction_begin(t,14,43,false,28);
check(!aerobrake_prediction_due(t,14,43,true,29),'mode change debounce');
check(aerobrake_prediction_due(t,14,43,true,31),'mode change refresh');
`);
e=environment();
run(e,`
const t=aerobrake_prediction_tracker();
const j=aerobrake_prediction_begin(t,-45,25,false,0);
check(aerobrake_prediction_matches(j,-45,25,false),'matching controls');
check(!aerobrake_prediction_matches(j,45,25,false),'bank sign matters');
aerobrake_prediction_step(j);
check(j.steps===1 && stepCalls[0]===10,'one exact ten-second step');
check(aeroCalls[0][2][0]===25 && aeroCalls[0][2][1]===-45,'fixed AoA and signed bank reach sampler');
KUNIVERSE.realtime=2;
aerobrake_prediction_step(j);
check(j.status==='timed out' && j.steps===1,'deadline prevents another integration');
KUNIVERSE.realtime=0;
const capped=aerobrake_prediction_begin(t,0,25,true,0);capped.steps=2000;
aerobrake_prediction_step(capped);
check(capped.status==='step limit','finite horizon even with stalled clock');
const schedule=aerobrake_prediction_begin(t,60,0,true,0);
aerobrake_prediction_step(schedule);
check(aeroCalls.at(-1)[2][0]===30,'AVES schedule evaluated at simulated altitude');
schedule.state.altitude=30000;aerobrake_prediction_step(schedule);
check(aeroCalls.at(-1)[2][0]===20,'schedule follows evolving simulated state');
`);
// Production conic calculation checked against an independently constructed
// ellipse at periapsis, and a hyperbolic state.
e=environment();
const mu=e.SHIP.body.mu,rp=670000,ra=900000,a=(rp+ra)/2;
e.nextState={altitude:70001,position:{mag:rp},velocity:{sqrmagnitude:mu*(2/rp-1/a)},surfvel:{mag:2000}};
e.vcrs=()=>({sqrmagnitude:rp**2*e.nextState.velocity.sqrmagnitude});
run(e,`
const j=aerobrake_prediction_begin(aerobrake_prediction_tracker(),0,25,false,0);
aerobrake_prediction_step(j);
check(j.status==='complete' && abs(j.apoapsis-300000)<0.00001,'final osculating apoapsis');
nextState.velocity.sqrmagnitude=2*SHIP.body.mu/nextState.position.mag+100;
const escape=aerobrake_prediction_begin(aerobrake_prediction_tracker(),0,25,false,0);
aerobrake_prediction_step(escape);
check(escape.status==='escape (unbound)','unbound result has no fake apoapsis');
`);
e=environment();e.nextState={altitude:-10};
run(e,`
const j=aerobrake_prediction_begin(aerobrake_prediction_tracker(),0,25,false,0);
aerobrake_prediction_step(j);check(j.status==='impact / stopped','impact terminates');
`);
e=environment();
e.update_simstate_total_accel=state=>{e.kuniverse.realtime=2.01;return {...state,altitude:70001};};
run(e,`
const j=aerobrake_prediction_begin(aerobrake_prediction_tracker(),0,25,false,0);
aerobrake_prediction_step(j);check(j.status==='timed out','late exit result discarded');
`);
// A solve can time out while the real control loop keeps receiving updates.
e=environment();let timeoutSeen=false;
e.onTick=env=>{
  if(env.ticks===110){
    timeoutSeen=env.widgets.some(w=>w.text==='Predicted final Ap: timed out');
    env.widgets.find(w=>w.text==='Cancel - return to POS').onclick();
  }
};
run(e,main);
check(timeoutSeen && e.controlUpdates===110,'timeout leaves DAP and cancel responsive');
check(e.stepCalls.length<110,'no further integration after deadline');
for(const mode of ['css','off','auto']){
  e=environment();e.dap.dap_mode=mode;e.main_dap_mode_menu.index=mode==='css'?1:mode==='off'?2:0;
  e.onTick=env=>{env.widgets.find(w=>w.text==='Cancel - return to POS').onclick();
    env.SHIP.apoapsis=60000;}; // Cancel wins even when automatic capture also becomes true.
  run(e,main);
  check(e.autoAttached,'assistant explicitly attaches AoA control');
  check(e.disposed && !e.handoff,'cancel disposes GUI and suppresses POS3');
  check(e.controlUpdates===1 && e.brakeCalls===2,'no assistant commands after cancel');
  check(e.dap.dap_mode===(mode==='css'?'css':'off'),'pilot mode restored without stale AUTO');
  check(e.main_dap_mode_menu.index===(mode==='css'?1:2),'launcher selection agrees with owner');
  check(e.unlocks.includes('throttle') && e.unlocks.includes('steering'),'locks released');
  check(!e.dap.envelope.restore_steering && !e.dap.handoff.active,'stale steering restoration cleared');
}
e=environment();e.onTick=env=>{env.SHIP.altitude=70001;env.SHIP.verticalspeed=100;};run(e,main);
check(!e.handoff && e.disposed && e.dap.dap_mode==='css','normal exit returns to pilot/launcher');
check(e.events.some(a=>a[0]==='aerobrake_atmosphere_exit'),'normal exit logged');
e=environment();e.SHIP.apoapsis=60000;run(e,main);
check(e.handoff.path==='0:/POS3.ks' && e.handoff.mode==='auto' && e.handoff.steering==='aoa','explicit POS3 owner');
check(e.handoff.cached==='off' && e.handoff.disposed && e.handoff.unlocks.includes('steering'),'old owner released before POS3');
// The launcher's OFF branch cannot call the DAP protection update.
const launcher=read('Script/POS.ks');
check(/if dap\["dap_mode"\] = "off" \{[\s\S]*?\} else \{ DAP:update\(\)\. \}/.test(launcher),'launcher OFF remains passive');
console.log(`PASS: ${checks} aerobraking assertions (production source with stubbed KSP/FAR boundaries)`);
