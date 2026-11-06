// Execute production scalar KerboScript helpers; recorded-input replay is not a FAR simulation.
// Run: node tests/test_landing_flare_policy.cjs [optional flight.csv]
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync('Script/Libraries/Poseidon_SSTO/terminal_route.ks','utf8');
function translate(name){
  const start=source.indexOf('function '+name+' {');assert(start>=0,name);
  const open=source.indexOf('{',start);let depth=1,end=open+1;
  while(depth){if(source[end]==='{')depth++;if(source[end]==='}')depth--;end++;assert(end<=source.length);}
  let body=source.slice(open+1,end-1).replace(/\/\/[^\r\n]*/g,'');
  const params=body.match(/parameter ([\s\S]*?)\./)[1].replace(/\bis\b/g,'=');
  body=body.replace(/parameter [\s\S]*?\./,'')
    .replace(/(?<=[\w\]\)])\s*=\s*(?!=)/g,' === ').replace(/<>/g,'!==')
    .replace(/\band\b/g,'&&').replace(/\bor\b/g,'||').replace(/\bnot\b/g,'!').replace(/\^/g,'**')
    .replace(/\bmin\(/g,'Math.min(').replace(/\bmax\(/g,'Math.max(').replace(/\bsqrt\(/g,'Math.sqrt(')
    .replace(/\blocal (\w+) (?:is|to) /g,'let $1 = ')
    .replace(/\bset ([\s\S]*?) to ([\s\S]*?)\.(?=\s|})/g,'$1 = $2;')
    .replace(/\breturn ([\s\S]*?)\.(?=\s|})/g,'return $1;')
    .replace(/\bif ([^{]+)\{/g,'if ($1) {')
    .replace(/\.(?=\s*(?:\r?\n|}))/g,';');
  assert(!/\b(?:let\s+)?(?:velocity|ship|body|time|altitude|throttle|steering)\s*=(?!=)/i.test(body));
  return `function ${name}(${params}){${body}}`;
}

function lex(...args){const result={};for(let i=0;i<args.length;i+=2)result[args[i]]=args[i+1];return result;}
const config=fs.readFileSync('Script/Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks','utf8');
function numericConfig(begin,end){const text=config.slice(config.indexOf(begin),config.indexOf(end,config.indexOf(begin)));
 return Object.fromEntries([...text.matchAll(/"(\w+)"\s*,\s*(-?\d+(?:\.\d+)?)/g)].map(m=>[m[1],+m[2]]));}
const landing=numericConfig('Poseidon_SSTO:add("Landing"','Poseidon_SSTO:add("HacDistance"');
const gate=numericConfig('"FinalEnergyGate",lex(', '"rehold_energy"');
const commit=numericConfig('"LandingCommit",lex(', '// A runway may');
assert.equal(landing.touchdown_vertical_speed,-.7);assert.equal(gate.maximum_turn_speed,350);
const ctx=vm.createContext({Math,lex,abs:Math.abs});
for(const name of ['terminal_landing_descent_command','terminal_landing_flare_command',
 'terminal_landing_corridor_command','terminal_final_energy_hold_needed','terminal_final_energy_ready',
 'approach_brake_band','terminal_landing_speed_command','landing_brake_decision','terminal_landing_minimum_speed'])
 vm.runInContext(translate(name),ctx);
const descent=ctx.terminal_landing_descent_command,flare=(height,entry,previous=0)=>ctx.terminal_landing_flare_command(height,entry,previous,landing);
let groups=0;function check(name,test){test();groups++;console.log('PASS',name);}
check('height flare survives conflicting position request on either side of threshold',()=>{
 for(const entry of [-5.15,-1.87]){
  let previous=0;
  for(const height of [35,30,25,20,15,10,5,3]){
   const planned=flare(height,entry,previous).desired_vs;
   const selected=descent(planned,-999);
   assert.equal(selected,planned);assert(selected<0);assert(selected>=previous||previous===0);
   previous=planned;
  }
  assert(Math.abs(previous-landing.touchdown_vertical_speed)<1e-9);
 }
 assert.equal(descent(-5,-3),-3);
 const planned=flare(20,-5.15).desired_vs;
 const old=Math.max(-7.3,Math.min(planned,-6.25));
 assert(old<planned-2,'fixture must expose flight 489 position override');
 assert.equal(descent(planned,-7.3),planned);
});
check('production clearance protection still rejects unsafe sink and allows normal touchdown',()=>{
 const glide={shallow_aimpoint:100,angle2:.0524077793};
 const unsafe=ctx.terminal_landing_corridor_command(180,16.4,-7.73,125,1.22,6,landing,glide);
 assert(unsafe.unsafe);assert(unsafe.clearance_margin<0);
 const normal=ctx.terminal_landing_corridor_command(-10,2,-2,125,1,6,landing,glide);
 assert(!normal.unsafe);
});
check('excess energy diverts before threshold; fast entry and low approaches retain protection',()=>{
 assert(ctx.terminal_final_energy_hold_needed(336,10500,12898,8007,gate));
 assert(!ctx.terminal_final_energy_hold_needed(1442,24000,100000,8000,gate));
 assert(!ctx.terminal_final_energy_hold_needed(130,40,2000,800,gate));
 assert(!ctx.terminal_final_energy_hold_needed(130,10000,100,8000,gate));
 assert(!ctx.terminal_final_energy_hold_needed(130,3000,2000,100,gate));
 assert(!ctx.terminal_final_energy_ready(2000,100,gate));
 assert(!ctx.terminal_final_energy_ready(100,800,gate));
 assert(ctx.terminal_final_energy_ready(100,100,gate));
 assert(ctx.terminal_final_energy_ready(-1000,-100,gate));
});
check('airborne flare retains speed support and never forces brakes by height',()=>{
 for(const height of [35,11,10,9.66,5.6,3,1,0]){
  const support=ctx.terminal_landing_speed_command(119.4,121.1,.74,1,false,height,landing,125);
  assert(support.command>0,'airborne speed support cut at '+height+' m');
  assert.equal(ctx.landing_brake_decision(false,123,false,height,landing,1),false);
 }
 assert.equal(ctx.landing_brake_decision(false,140,false,5,landing,1),true,
  'speed-band airbraking remains available for overspeed');
 for(const height of [0,1,5,15]){
  assert.equal(ctx.terminal_landing_speed_command(119,121,.1,1,true,height,landing,125).command,0);
  assert.equal(ctx.landing_brake_decision(false,100,true,height,landing,1),true,
   'latched contact keeps wheel braking during bounce');
 }
});
check('110 m/s gate is limited to low height inside the runway footprint',()=>{
 const floor=(along,cross,height,length=1200,scale=1)=>ctx.terminal_landing_minimum_speed(
  along,cross,height,length,scale,landing,commit);
 assert.equal(commit.minimum_speed,120);
 assert.equal(floor(-600,0,5.6),110);
 assert.equal(floor(0,15,10),110);
 assert.equal(floor(-1200,-15,0),110);
 for(const [along,cross,height,length] of [[1,0,5,1200],[-1201,0,5,1200],
  [-600,15.1,5,1200],[-600,0,10.1,1200],[-600,0,-1,1200],[0,0,5,0]])
  assert.equal(floor(along,cross,height,length),120);
 assert.equal(floor(-600,0,5,1200,1.2),132,'heavy craft retains mass speed scaling');
});
const input=process.argv[2];
if(input)check('flight 489 real height-based requests replace the conflicting position command',()=>{
 const lines=fs.readFileSync(input,'utf8').trim().split(/\r?\n/),header=lines.shift().split(',');
 const ix=k=>{const i=header.indexOf(k);assert(i>=0,k);return i;};
 const rows=lines.map(l=>l.split(','));
 const divert=rows.find(r=>+r[ix('ut')]>17889954&&+r[ix('ut')]<17890124&&
  ctx.terminal_final_energy_hold_needed(+r[ix('airspeed')],+r[ix('altitude')]-+r[ix('runway_altitude')],
   +r[ix('terminal_energy_margin')],-+r[ix('terminal_profile_error')],gate));
 assert(divert,'initial approach must divert into energy holding');
 assert(+divert[ix('terminal_along_track')]>10000,'divert must occur well before the failed threshold pass');
 console.log('energy holding triggered on recorded state at UT',divert[ix('ut')],
  'with',Math.round(+divert[ix('terminal_along_track')]),'m before threshold');
 for(const [begin,end,entry] of [[17890525.2588752,17890528.1588751,-5.15],[17890949.5388657,17890954.0188656,-1.87]]){
  const selectedRows=rows.filter(r=>r[ix('step')]==='landing'&&+r[ix('ut')]>=begin&&+r[ix('ut')]<=end);
  assert(selectedRows.length>5);
  let previous=0,conflicts=0;
  for(const r of selectedRows){
   const height=+r[ix('altitude')]-+r[ix('runway_altitude')];
   const planned=flare(height,entry,previous).desired_vs;previous=planned;
   const floor=+r[ix('terminal_along_track')]>0?+r[ix('landing_corridor_vs')]:-999;
   const selected=descent(planned,floor);
   assert(selected>=planned);assert(selected<0);
   const old=+r[ix('landing_target_vs')];if(selected>old+1)conflicts++;
  }
  assert(conflicts>5,'replay must demonstrate actual overridden flare samples');
  console.log('replayed',selectedRows.length,'samples, corrected',conflicts,'conflicting requests');
 }
});
console.log('Passed',groups,'regression groups; KSP/FAR flight verification remains required.');
