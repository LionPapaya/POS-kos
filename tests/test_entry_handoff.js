// Portable source-executing regression tests. This restricted translation runs
// actual production helper bodies; it is not a kOS scheduler or FAR simulation.
// Input: {control, charts, math, catalog, replay}; result is a test summary.
function runEntryHandoffTests(sources) {
  let assertions=0;
  const assert=(condition,message)=>{assertions++;if(!condition)throw Error(message);};
  function extract(source,name) {
    const start=source.search(new RegExp('function '+name+'\\s*\\{','i'));
    assert(start>=0,'missing function '+name);
    const open=source.indexOf('{',start);let depth=1,end=open+1;
    const stripped=source.replace(/\/\/[^\r\n]*/g,m=>' '.repeat(m.length));
    while(depth) {if(stripped[end]==='{')depth++;if(stripped[end]==='}')depth--;end++;assert(end<=source.length,'unclosed function');}
    return stripped.slice(open+1,end-1);
  }
  function translate(source,name) {
    let body=extract(source,name),params=[];
    body=body.replace(/parameter ([\s\S]*?)\./g,(_,p)=>{params.push(p.replace(/\bis\b/g,'='));return '';});
    body=body.replace(/<>/g,'!==').replace(/(?<=[\w\]\)])\s*=\s*(?!=)/g,' === ')
      .replace(/\band\b/g,'&&').replace(/\bor\b/g,'||').replace(/\bnot\b/g,'!')
      .replace(/:(\w+)/g,'.$1').replace(/\breturn\s*\./g,'return;')
      .replace(/\blocal (\w+) (?:is|to) /g,'let $1 = ')
      .replace(/\bset ([\s\S]*?) to ([\s\S]*?)\.(?=\s|})/g,'$1 = $2;')
      .replace(/\breturn ([\s\S]*?)\.(?=\s|})/g,'return $1;')
      .replace(/\bfor (\w+) in ([^{]+)\{/g,'for (const $1 of $2) {')
      .replace(/\bif ([^{]+)\{/g,'if ($1) {')
      .replace(/\.(?=\s|})/g,';');
    return `function ${name}(${params.join(',')}){${body}}`;
  }
  const lex=(...args)=>{const r={};for(let i=0;i<args.length;i+=2)r[args[i]]=args[i+1];
    Object.defineProperty(r,'copy',{get(){return {...r};}});return r;};
  const list=(...args)=>{Object.defineProperty(args,'add',{value(x){this.push(x);}});return args;};
  const range=(start,end)=>Array.from({length:Math.max(0,end-start)},(_,i)=>start+i);
  const max=Math.max,min=Math.min,abs=Math.abs,mod=(a,b)=>a%b;
  const cos=a=>Math.cos(a*Math.PI/180),round=(v,p)=>+v.toFixed(p);
  const entry_chart_catalog=sources.catalog.map(page=>page.map(record=>lex(...Object.entries(record).flat())));
  const dap=lex('dap_mode','auto','str_mode','aoa','dt',.2,
    'aoa',lex('aoa_pitch',34,'aoa_yaw',359,'aoa_roll',0,'smooth_target_aoa',18,'smooth_target_bank',-50,'smooth_base_pitch',-30),
    'aerostr',lex('targetPitch',-20,'targetDirection',1,'targetRoll',-45),
    'css',lex('pitch_out',-10,'yaw_out',1,'roll_out',-20),
    'envelope',lex('max_aoa',25),
    'handoff',lex('active',false,'protected',false,'pitch',0,'yaw',0,'bank',0));
  const ship={altitude:21000},AVES={TEAMAltitude:25000,Pitch_rate:{low:9,high:4},Rotation_rate:{low:18,high:10}};
  const pitch_for_prograde=()=>9,events=[];
  let chart_builds=0,chart_events=0;
  let entry_chart_selection=lex('ready',false,'pages',list());
  const Team_interface=lex('target_latlng',{});
  const entry_display_prediction_samples=()=>{chart_builds++;return list(lex('energy',330000,'range',950000),lex('energy',160000,'range',10000));};
  const entry_nominal_energy_height=()=>321000,calcdistance_m=()=>925000;
  const flight_log_entry_charts=()=>chart_events++;
  const flight_log_event=(...args)=>events.push(args);
  // Direct eval keeps test fixtures lexical while evaluating the source bodies.
  const code=[translate(sources.math,'changeRate'),
    ...['dap_smooth_baseline','dap_smooth_angle','dap_handoff_step','dap_protection_handoff'].map(n=>translate(sources.control,n)),
    ...['entry_chart_extent','entry_chart_choose','entry_chart_select'].map(n=>translate(sources.charts,n)),
    translate(sources.guidance,'reentry_select_entry_charts')].join('\n');
  return eval(code+`\n(${function tests(){
    assert(abs(dap_smooth_baseline(-2,2,.2,4)+1.2)<1e-9,'baseline crossing zero slew');
    assert(dap_smooth_baseline(2,0,1,4)===0,'zero is a command');
    assert(dap_smooth_baseline(2,-30,-1,4)===2,'backward clock must hold');
    assert(dap_smooth_baseline(30,-30,8,9)===25.5,'slow solve cannot create catch-up jump');
    assert(abs(dap_smooth_angle(359,1,.1,10)-360)<1e-9,'shortest yaw wrap');
    assert(abs(dap_smooth_angle(-179,179,.1,10)+180)<1e-9,'shortest bank wrap');
    dap_protection_handoff(true);
    assert(dap.handoff.pitch===34 && dap.handoff.protected,'protection recorded immediately');
    dap.aoa.aoa_pitch=-14;dap.aoa.aoa_yaw=1;dap.aoa.aoa_roll=-50;
    dap_protection_handoff(false);
    assert(abs(dap.aoa.aoa_pitch-32.2)<1e-9,'48 degree handback limited to 1.8');
    assert(abs(dap.aoa.smooth_base_pitch-9)<1e-9,'baseline rebased from applied protection command');
    assert(dap.aoa.smooth_target_bank===0,'background bank slew reset on release');
    assert(dap.handoff.active,'capture continues across ticks');
    // A new emergency interrupts the dampener immediately.
    dap.aoa.aoa_pitch=5;dap.aoa.aoa_yaw=90;dap.aoa.aoa_roll=0;
    dap_protection_handoff(true);
    assert(dap.handoff.pitch===5 && !dap.handoff.active,'new protection bypasses old capture');
    dap.str_mode='aerostr';dap_protection_handoff(false);
    assert(abs(dap.aerostr.targetPitch-3.2)<1e-9,'aerostr handback limited');
    dap.str_mode='aoa';dap.dap_mode='css';
    dap.aoa.aoa_pitch=20;dap_protection_handoff(true);dap_protection_handoff(false);
    assert(abs(dap.css.pitch_out-18.2)<1e-9,'CSS handback limited');
    dap.dap_mode='off';dap_protection_handoff(false);
    assert(!dap.handoff.active && !dap.handoff.protected,'off releases capture ownership');
    // Moving demands and irregular control intervals must obey every-step bounds.
    let h=lex('pitch',34,'yaw',359,'bank',0,'active',true);
    for(let i=0;i<500;i++){
      let previous={...h},dt=[.02,.12,.2,.38][i%4],p=i<250?-30:15;
      dap_handoff_step(h,p,i%2?1:359,i<250?-50:40,dt,9,18);
      assert(abs(h.pitch-previous.pitch)<=dt*9+1e-9,'pitch per-step bound');
      assert(abs(h.yaw-previous.yaw)<=dt*18+1e-9,'yaw per-step bound');
      assert(abs(h.bank-previous.bank)<=dt*18+1e-9,'bank per-step bound');
    }
    h=lex('pitch',34,'yaw',359,'bank',0,'active',true);
    for(let i=0;i<100;i++)dap_handoff_step(h,-14,1,-50,.2,9,18);
    assert(!h.active,'handback completes and does not remain latched');
    const samples=list(lex('energy',330000,'range',950000),lex('energy',250000,'range',600000),lex('energy',160000,'range',10000));
    let ex=entry_chart_extent(samples,210000,260000);
    assert(ex.valid && ex.range_min<450000 && ex.range_max>600000,'segment intersections include sparse boundaries');
    ex=entry_chart_extent(list(lex('energy',220000,'range',300000),lex('energy',220000,'range',500000)),210000,260000);
    assert(ex.valid && ex.range_min===300000 && ex.range_max===500000,'constant-energy segment keeps both range endpoints');
    let pages=entry_chart_select(samples,321000,925000);
    assert(pages.length===5 && pages.every(p=>p.fits),'five fitting charts chosen');
    assert(pages[0].energy_max>=340000,'high energy ceiling selected');
    assert(pages[1].range_min<=ex.range_min,'lower page two range selected');
    assert(pages[3].range_min===0 && pages[4].range_min===0,'unpredicted tail uses zero range');
    let uncovered=entry_chart_select(list(),2000000,3000000);
    assert(!uncovered[0].fits && uncovered[0].range_min===0 && uncovered[0].range_max===2000000,'catalog overflow explicitly marked on broad fallback');
    const solved=lex('converged',true,'converged_sim',lex('controll_inputs',{}));
    reentry_select_entry_charts(solved);
    const cached=entry_chart_selection.pages;
    for(let i=0;i<100;i++)reentry_select_entry_charts(solved);
    assert(chart_builds===1 && chart_events===1 && entry_chart_selection.pages===cached,'selection and trace sampling occur once');
    entry_chart_selection=lex('ready',false,'pages',list());
    reentry_select_entry_charts(lex('converged',false));
    assert(chart_builds===1,'failed prediction cannot latch chart selection');
    reentry_select_entry_charts(solved);
    assert(chart_builds===2 && chart_events===2,'explicit target reset permits fresh chart selection');
    // Recorded geometry replay tests fit selection, not an aerodynamic prediction.
    let replay=(sources.replay||[]).map(p=>lex('energy',p[0],'range',p[1]));
    let replayPages=replay.length?entry_chart_select(list(...replay),replay[0].energy,replay[0].range):[];
    for(const point of replay){
      let n=point.energy>=260000?0:point.energy>=210000?1:point.energy>=170000?2:point.energy>=140000?3:4;
      let p=replayPages[n];
      assert(point.energy>=p.energy_min && point.energy<=p.energy_max && point.range>=p.range_min && point.range<=p.range_max,'flight 525 geometry contained');
    }
    return {assertions,events:events.map(e=>e[0]),replayPoints:replay.length,chartImages:pages.map(p=>p.image)};
  }.toString()})()`);
}

// Run under Node: node tests/test_entry_handoff.js [recorded-geometry.json]
if(typeof require!=='undefined' && require.main===module){
  const fs=require('node:fs'),path=require('node:path');
  const root=path.resolve(__dirname,'..'),lib=path.join(root,'Script/Libraries/Poseidon_SSTO');
  const read=p=>fs.readFileSync(p,'utf8');
  const sources={control:read(path.join(lib,'control.ks')),charts:read(path.join(lib,'entry_charts.ks')),
    guidance:read(path.join(lib,'entry_guid.ks')),math:read(path.join(root,'Script/Libraries/lib_math.ks')),
    catalog:JSON.parse(read(path.join(root,'Script/Libraries/gui_images/entry_charts/catalog.json'))),
    replay:process.argv[2]?JSON.parse(read(process.argv[2])):[]};
  console.log(JSON.stringify(runEntryHandoffTests(sources),null,2));
}
