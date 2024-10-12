global boottime to time:seconds.
global debug to 0. // shows input and output for triggered item. use for checking which modules are called for failed trigger. logging is better.
global dbglog to 0. // 0 = OFF 1 = LOG  2= Detailed Log 3 = advanced LOG WITH METER/FUEL CHECK AND STARTUP SPAM (you probably dont want 3) 4, manual entry only, color logging 5, manual entry only, skips logging for start
global colorprint to 1. // fancy colors?
Global ForceMon to -1. // set to force specific monitorif over 0, will use forcemon-1 for trg mon
SET FASTBOOT TO 0. // REMOVES PAUSES FROM LOAD ITEMS LIST 

// file names
local cnt to 0.
LIST PROCESSORS IN coreList.
for i in corelist {if i:TAG = "" set i:TAG to "C"+cnt. set cnt to cnt+1.}
global proot is "0:/". //path():root. 
global SubDirSV IS proot+"ShipAutoSV/".                   //directory for auto option save
global Autofile is ship:name+"-"+core:tag+".json".        //filename for auto option save
global AutofileBAK is ship:name+"-"+core:tag+".bak.json". //filename for BKP option save
global DebugLog to proot+"KosHud.log".                       //filename for log file. 


//check

//Next update plans
  //Auto load backup if exists and current time is prior to backup time
  //lock control from here
  //REACTORS

//goals for later
    //scroll info list if on bot or top row
    //CYCLE FIELDS
    //SMART LOAD, CHECK IF TIME IS < LAST SAVRED TIME, IF SO, LOAD BKP IF SMART LOAD IS SELECTED
    //headless mode

// things to fix
  //check how it handles docking
  //check if 2 vehicles same docking
  //sounds

//items to update 

//STRETCH GOALS
  //autopilot speed toggle MAIN engines mode
  //make continue work on liist auto
  //check name saved for payloadpart
  //add to orbit to autopiilot
  //add copy to other core
  //make PAL work
  //hover option. (when i need it)
  //add option to change monitor in flight

//probably wont work or wont bother with
  //add biome to auto state //Need to figure out if i can get a list of all biomes on current SOI or wont work.
//#endregion

 //#region set start vars
set config:ipu to 200.
global loadattempts to 0.
local fileList is list().
local found is false.
list files in fileList.
for file in fileList {if file = DebugLog set found to true.}
IF found = true  DELETEPATH(DebugLog).
IF exists(DebugLog) and NOT (DEFINED mchkcnt){ 
  DELETEPATH(DebugLog).
 IF dbglog > 0{
    log2file("################################################################################").
    log2file("|                              KERBAL HUD SYSTEM                               |").
    log2file("|                              BY  FUZZYMEEP TWO                               |").
    log2file("|                                VERSION 1.06                                  |").
    log2file("|___________________________________LOADING____________________________________|").
    log2file("################################################################################").
 }
}
global CrewCap to 0.
global CrewAct to list().
until ship:unpacked and ship:loaded  wait 1.
if ship:hassuffix("CREWCAPACITY"){
  if ship:crewcapacity > 0{
    set crewcap to ship:crewcapacity.
    if ship:hassuffix("CREW") if ship:crew:length > 0 set CrewAct to ship:crew.}
}
clearscreen.
GLOBAL HEIGHT TO 0.
global headless to 0. // for future implimentation
IF  SHIP:status = "LANDED" or SHIP:status = "PRELAUNCH"{
  SET BRAKES TO TRUE. // brakes and check height on launch.
  IF ALT:RADAR > 0 {SET HEIGHT TO HEIGHT-(0-(ALT:RADAR)).}
  ELSE{IF ALT:RADAR < 0 {SET HEIGHT TO HEIGHT+(0-(ALT:RADAR)).}}
}
//wait for monitors to load
if CrewCap > 0 and CrewAct:length > 0 {//crewed = wait for iva
   if DbgLog > 0 log2file("WAITING FOR MONITORS").
until addons:kpm:getmonitorcount() > 0  wait 1.}else{ //uncrewed = restart a few times then go headless 
  IF NOT (DEFINED mchkcnt)global mchkcnt to 0.
  if not (addons:kpm:getmonitorcount() > 0 or mchkcnt > 9){
    set mchkcnt to mchkcnt+1.
    if DbgLog > 0 log2file("NoMonitors: "+mchkcnt+" of 10 waiting"+(10-mchkcnt+1)/2+" SECONDS TO RETRY" ).
    wait (10-mchkcnt+1)/2.
    IF exists("0:/boot/KOSHUD.ks") run "0:/boot/KOSHUD.ks".
  }
  if mchkcnt > 9 set headless to 1.
  unset mchkcnt.
}
set config:ipu to 2000.
if dbglog > 3{
  if DbgLog > 0 log2file("startup logging skipped").
  set dbglog to -1.
}
SET QUICKREBOOT TO 1. //SKIPS ITEM DETECT ON match //2 loads all from file on fingerprint match
IF NOT (DEFINED PRTCount){global PRTCount to SHIP:PARTS:LENGTH.}else{if prtcount <> SHIP:PARTS:LENGTH{Set quickreboot to 0. set PRTCount to SHIP:PARTS:LENGTH.}} 
global FuelUpdRate to "Fast".
global ClrMin to 0.
if colorprint > 0 set ClrMin to 9.
global acp to 7.
GLOBAL LOADBKP TO 0.
global printpause to 0.
GLOBAL SAVEBKP TO 0.
global twr to 0.
global LFX to 0.
global saveflag to 0.
global widthlim to 80.
global heightlim to 18.
global dctnmode to 0.
global cmdln to 0.
global meterpart to 0.
global ActionWait to 0.
GLOBAL STPREV TO "".
GLOBAL BOTPREV TO "".
global lastdir to "+".
GLOBAL linklock to 0.
global setdelay to 0.
global Curdelay to 0.
global WarnOut to "".
Global WarnLst to "".
global HDItm to 1.
global HDTag to 1.
global HDItmB to 1.
global newhud to 1.
global HDTagB to 1.
global pscnt to 0.
global apsel to 1.
global h5mode to 0.
global senseskp to 0.
GLOBAL DCPRes TO 0.
global Lscroll to list(0,0).
global scanlist to list().
global adjmode to "num".
global lastinput to  time:seconds.
GLOBAL MISSINGPART TO 0.
global AutoSetAct to 1.
global AutoSetMode to 1.
global AutoRstMode to 1.
global ItemLastRun to 0.
global refreshRateSlow to 5.
global refreshRateFast to 1.
GLOBAL VLIMSTRT TO 10000.
global PLIMSTRT to 90.
global LLIMSTRT to 40.
GLOBAL HLIMSTRT TO 5000.
GLOBAL VLIM TO VLIMSTRT.
GLOBAL PLIM TO PLIMSTRT.
GLOBAL LLIM TO LLIMSTRT.
GLOBAL HLIM TO HLIMSTRT.
global plimadj to 0.
global ln14 to 0.
global HLon to 0.
GLOBAL HLPARTS TO 0.
global flyadj to list(0,0,0,0,0,0,0).
global AgState to list(AG1,ag2,ag3,ag4,ag5,ag6,ag7,ag8,ag9,ag10,0,RCS,ABORT,GEAR,lights,BRAKES).
global AgSPrev to AgState:copy.
global ALTPRV to ship:altitude.
GLOBAL VSPDPRV TO SHIP:verticalspeed.
GLOBAL SPDPRV TO SHIP:VELOCITY:SURFACE:MAG.
global RFSBAak to refreshRateSlow.
global NextGoodField to 0.
global lostparts to list().
GLOBAL PRINTQ IS QUEUE().
GLOBAL THRTFIX TO 0.
GLOBAL THRTPREV TO THROTTLE.
GLOBAL AUTOBRAKE TO 2. //2 IS BRAKES ON UNDER 50% THROTTLE AND LANDED, 0 IS OFF, 1 IS ON.
GLOBAL AUTOLOCK TO 2. //AUTO LOCK MOVABLE PARTS AFTER MOVE 0 = off up to 5 seconds
global IsPayload to list(0,core:part).
set IsPayload to checkdcp(core:part,"payload").
//VARS NEEDED FOR CALLS.
GLOBAL ID TO "".
set bigempty2 to"                                                                              ".
set bigempty to"                                                                           ".
SET LNstp TO 1.
global MeterGoodLast to 0.
global MeterCheckCur to 1.
GLOBAL V0 to GetVoice(0).
global rowT1 to "".
global rowT2 to "".
global senselist to list(0,0,0,0,0,0).
global Speeds to list(list(""," VRY SLOW ","   SLOW   ","  NORMAL  ","  DOUBLE  ","  TRIPLE  ","   QUAD   "),
                      list("",100         ,200        ,500          ,1000        ,1500        ,2000)).
GLOBAL SPEEDSET TO LIST(3,6,2,6).
GLOBAL CPUSPD TO SPEEDSET[0].
global rowval to 0.
global rtech to 0.
global mks to 0.
global REMETER TO 0.
global zop to 1.
global forcerefresh to 0.
global RunAuto to 1.
global MonAutoCyc to 1.
global BtnActn to 0.
global airmax to 0.
global monitorIndex to -1.
    global HudOpts to list(0).
    global ItemListHUD to list().
    global ItemList to list(0).
      global prtTagList to list(List(0)).
          set prtList to list(List(List(0))).
            global GrpOpsList to list(List(List(0))).
            set GrpDspList to list(List(List(0))).
            global GrpDspList2 to list(List(List(0))).
            global GrpDspList3 to list(List(List(0))).
            global AutoDspList to list(List(List(0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0))).
            global autoRstList to list(List(List(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0))).
            global AutoValList to list(List(List(0))).
            global AutoRscList to list(List(List(0))).
            global AutoTRGList to list(List(List(0))).
global botrow to bigempty2.
global paidmeter to 0.
global aplim to 1.
GLOBAL ActionQNew to list().
global HdngSet to list(list(9,0  ,0   ,0   ,0   ,0      ,0   ,60 ,40  ,60 ), //set
                       list(9,359, 180, 180,5000,1000000, 500,180,5000,180), //max
                       list(9,0  ,-180,-180,0   ,0      ,-500,0  ,0   ,0  ), //min
                       list(9,1  ,1   ,1   ,0   ,0      ,0   ,1  ,0   ,0  )). //on/off
                       if ship:type = "plane" set aplim to 3.
GLOBAL MONITORID TO 0.
global mtrcur to list(0,100,5,1,1,1,1,list(),list()). //mtrvalmin[0],mtrvalmax[1],mtrvaladj[2],mtroptnmin[3],mtroptnmax[4],mtroptn[5],curfield[6], curfield ops in[7], curfield ops out[8].
global StrLock to 0.
global cmlist to list().
global TrgLim to 1.
global  FindCl to lexicon("GREEN","").
        FindCl:add("RED","[#FF0000]").
        FindCl:add("CYN","[#00FFFF]").
        FindCl:add("YLW","[#FFFF00]").
        FindCl:add("WHT","[#FFFFFF]"). 
        FindCl:add("BLU","[#0000FF]").
        FindCl:add("BLK","[#000000]").  
        FindCl:add("PRP","[#FF00FF]").
        FindCl:add("ORN","[#ffae00]").
        FindCl:add("YRN","[#ffb300]").
        FindCl:add("RRN","[#ff6200]").
        FindCl:add("YGR","[#c8ff00]").
        FindCl:add("GRN","[#00ff00]").
global  FindCl2 to lexicon(
" TURN ON  ", "RED", " TURN OFF ","CYN","  DELETE  ","ORN"," TRANSMIT ","WHT", " SET TRGT ", "WHT"," DPST RSC ","WHT","SPRNG AUTO","GRN","SPRNG MAN ","GRN", " RUN TEST ","WHT","  EXTEND  ","CYN", "clamped", "CYN", "unclamped", "WHT",
"  DEPLOY  ","CYN" ,"  RETRACT ","RED" ," LIGHT OFF","ORN"," LIGHT ON ","WHT"," MODE OFF ","YLW"  ," MODE ON  ","PRP","   FIRE   ","ORN"," DECOUPLE ","CYN", "DECOUPLED ","RED","BAY CLOSED","WHT"," BAY OPEN ","ORN",
" CRNT TRG ","WHT","SET TARGET","ORN"
). 
global  FindCl3 to lexicon(
"Active"  ,"CYN","Inactive"  ,"RED","NORMAL"     ,"CYN","INVERTED","RED","True"  ,"CYN","False","RED","All"  ,"WHT","Decreasing","ORN","Increasing"    ,"CYN","Descent"    ,"ORN","Ascent","CYN","Both","WHT","Departure","ORN","Approach","CYN",
"KSC Loss","ORN","Total Loss","RED","Initialized","WHT","nominal" ,"WHT","closed","RED","safe" ,"WHT","risky","ORN","immediate" ,"RED","Main Throttle" ,"WHT","Independent","ORN","off"   ,"RED","on"  ,"CYN","playing"  ,"WHT","paused"  ,"ORN",
"foward","CYN","reverse","ORN","SAS Only","ORN","Pilot Only","YLW","port(CCW)","YLW","stbd(CW)","orn","locked","ORN","free", "wht","retracted","WHT", "extended", "CYN", "enabled", "CYN", "disabled","RED", "yes", "CYN", "no","RED", "engaged", "CYN",
 "disengaged","RED","counterclockwise","CYN","clockwise","WHT","None","CYN","Repeat","ORN","Ping Pong","PRP","None-Restart","WHT","Moving...","YLW"
). 

global actnlist to list(1,"","","","").
Global biomecur to "UNKNOWN".
global trimwords to list("Experiment","Sina","-MLEM","-MGS","-MGC","#LOC_AA_","_title","title", "DISPENSER", "Flight Computer").
global ReplWRDS to list(list("deploy Dir:True"  ,"deploy Dir:False"    ,"Current RPM","Effective Air Speed","deploy direction","Group:"    ,"wet"        , "dry"   ,"specific impulse","docking acquire force","rotation locked","safe to deploy?","deactivate at ec %","activate at ec %", "discharge rate","missiles/target","alternator output","SAS Only","Pilot Only","min altitude" ,"unclamp tuning ","standby mode ","mincombatspeed","\","electric charge","rotation direction","invert direction","kos average power","command state","kos disk space","powercoupler","No PDUs in Range"),
                        list("deploy Dir:Inverted","deploy Dir:Normal" ,"RPM"        ,"Eff.Speed"           ,"deploy Dir"      , "Group:AGX","Afterburner","normal", "SPi"            ,"Force"                , "rot. lock"     , "Safety"        ,"deact.ec%"         ,"act ec %"        , "disch. rate"   ,"Msl/trg"        , "E/C OUT"          ,"SAS"    ,"Pilot"     ,"min alt."     ,"clamp"          ,"standby"      ,"min cmbt spd"  ,"/","E/C"            ,"dir"               ,"dir"             ,"kos PWR"          ,"command"      ,"dsk space"     ,"PWR-CPL"     ,"No PDUs")).
//global trimwords2 to list("idle","percent").
global MODESHRT TO lIST(15, " OFF", " SPD"," ALT"," AGL"," EC "," RSC ","THRT","PRES", " SUN","TEMP","GRAV"," ACC"," TWR","STAT","FUEL"). 
GLOBAL MODELONG TO LIST(15,"    OFF   ","   SPEED  "," ALTITUDE "," ALT AGL  ","ELEC. CHRG"," RESOURCE "," THROTTLE "," PRESSURE ","   SUN    ","   TEMP   ","  GRAVITY ","  ACCEL.  ","   TWR    ","  STATUS  ","   FUEL   ").
GLOBAL STATUSOPTS TO LIST(12,"LANDED","SPLASHED","PRELAUNCH","FLYING","SUB_ORBITAL","ORBITING","ESCAPING","DOCKED","APOAPSIS","PERIAPSIS","NEXT NODE","TRANSITION").
GLOBAL STATUSSAVE TO LIST("LANDED","SPLASHED","PRELAUNCH","ORBITING").
GLOBAL STATUSSPACE TO LIST("SUB_ORBITAL","ORBITING","ESCAPING").
GLOBAL STATUSLAND TO LIST("LANDED","SPLASHED","PRELAUNCH","FLYING").
GLOBAL STATUSFLY TO LIST("FLYING","SUB_ORBITAL").
GLOBAL MJEB TO LIST(
  list("PROGRADE"      , "RETROGRADE"     , "NORMAL"     , "ANTI NORMAL"    , "RADIAL OUT"     , "RADIAL IN"     , "KILL ROT"          , "deact SMARTACS"    , "LAND SOMEWHERE", "LAND @ KSC", "PANIC!","TRNSLTRN OFF"   ,"TRNSLTRN VERT"        ,"TRNSLTRN ZERO SPD"     ,"TRNSLTRN +1 SPD"     ,"TRNSLTRN -1 SPD"     ,"TRNSLTRN TGL H/S"       ,"ASCENT AP TGL"  ),
  list("orbit prograde","orbit retrograde","orbit normal","orbit antinormal","orbit radial out","orbit radial in","orbit kill rotation","deactivate smartacs","land somewhere" ,"land at ksc","panic!" ,"translatron off","translatron keep vert","translatron zero speed","translatron +1 speed","translatron -1 speed","translatron toggle h/s","ascent ap toggle")).
GLOBAL StsSelection TO 1.
global buttons to addons:kpm:buttons.
global AutoMinMax to list(0,list(0,0)).
for i in range (2,modelong[0]+1){AutoMinMax:add(list(0,list(0,0),list(0,0))).}
//CHECK ADDONS
global agx to 0.
if ADDONS:AVAILABLE("AGX") set AGX to Addons:AGX.
if addons:available("RT") set RTech to addons:RT.
global mjb to 0.
global mjpart to 0.
if ship:modulesnamed("MechJebCore"):length > 0 {
  set mjb to 1.
  if core:part:hasmodule("mechjebcore") set mjpart to core:part. 
  else{for p in ship:parts if core:part:hasmodule("mechjebcore") {set mjpart to p. break.}}
}
//#endregion
//#region set lists
global  autotaglist to listadd(list("ModuleScienceExperiment"),TrimModules(list("ModuleProceduralFairing","DischargeCapacitor","ModuleScienceLab","BDModulePilotAI","MissileFire","ModuleScienceLab","usi_converter","usi_harvester","DMModuleScienceAnimateGeneric","ModuleAnimationGroup", "WOLF_SurveyModule","SCANexperiment","ModuleOrbitalSurveyor","ModuleRoboticController"))).
global AnimModAlt to listadd(list("ModuleAnimateGeneric"),TrimModules(list("ModuleAnimationGroup","DMModuleScienceAnimateGeneric","USIAnimation","scansat"))).
global lightMod to list("Lights"     , "  LIGHTS  ","ModuleLight","ModuleNavLight", "ModuleColorChanger","ModuleAnimateGeneric").
global lightmodskp to list("RetractableLadder","ModuleDockingNode"). //ADD MODULES WITH BUILTIN LIGHTS TO SKIP ADD TO LIGHT
global lightChkskp to list("ModuleScienceConverter","ModuleScienceLab","ModuleWheelDeployment","RetractableLadder"). //ADD MODULES WITH BUILTIN LIGHTS TO SKIP light check to keep parts from turning their own lights on and off with actions
global AGMod to list("Action Group"  ," ACTN GRP ","").
global FlyMod to list("Flight Control","FLGHT CTRL","").
global CMDMod to list("Command"      , " COMMAND  ","ModuleCommand","MechJebCore", "kOSProcessor").
global CntrlMod to list("control srf", "CNTRL SURF","ModuleControlSurface","SyncModuleControlSurface", "ModuleAeroSurface").
global CntrlFldList to list("authority limiter", "deploy angle").
global engMod to list("Engines"      , " ENGINES  ","ModuleEnginesFX","ModuleEngines","FSengineBladed","MultiModeEngine","ProceduralSRB").// (name, name for hud, module1, module2)
global INTMod to list("Intake"       , "  INTAKES ","ModuleResourceIntake").
global dcpMod to list("Decoupler"    , "DECOUPLERS","ModuleDecouple","ModuleAnchoredDecoupler","ModuleAnchoredDecouplerBdb").
global DcpModAlt to dcpMod:sublist(2,dcpMod:length).
global gearMod to list("Gear"        , "   GEAR   ","ModuleWheelDeployment", "ModuleAnimateGeneric","ModuleWheelMotor").
global chuteMod to list("Parachute"  , "PARACHUTES","ModuleParachute","RealChuteModule").
global ladMod to list("Ladder"       , "  LADDER  ","RetractableLadder").
global bayMod to list("Cargo Bay"    , "CARGO BAYS","ModuleCargoBay", "Hangar").
global DOCKMod to list("Docking Port", "  DOCKING ","ModuleDockingNode","ModuleGrappleNode").
global RWMod to list("Reaction Wheel", " RCTNWHEEL","ModuleReactionWheel").
global slrMod to list("Solar Panel"  , "   POWER  ","ModuleDeployableSolarPanel","KopernicusSolarPanel","ModuleResourceConverter","modulegenerator").
global RCSMod to list("RCS"          , "   RCS    ", "ModuleRCSFX").
global drillMod to list("Drill"      , "  DRILLS  ","ModuleResourceHarvester", "ModuleAsteroidDrill", "ModuleCometDrill").
global radMod to list("Radiator"     , " RADIATORS","ModuleActiveRadiator","ModuleDeployableRadiator","ModuleSystemHeatRadiator").
global scimod to list("Experiment"   , "XPERIMENTS","ModuleScienceExperiment","ModuleResourceScanner","DMModuleScienceAnimateGeneric", "WOLF_SurveyModule","SCANexperiment","SCANsat","ModuleOrbitalSurveyor","ModuleBiomeScanner").
global SciRun to list("run","log","irradiate", "perform", "start", "measure","report"," observ","scan","take","survey").
global sciModAlt  to listadd(list("ModuleScienceExperiment"),TrimModules(list("DMModuleScienceAnimateGeneric","ModuleAnimationGroup", "WOLF_SurveyModule","SCANexperiment","ModuleOrbitalSurveyor","SCANsat"))).
global sciModData to listadd(list("ModuleScienceExperiment"),TrimModules(list("ModuleScienceExperiment","DMModuleScienceAnimateGeneric","SCANexperiment","ModuleOrbitalSurveyor", "scansat"))).
global antMod to list("Antenna"      , " ANTENNAS ","ModuleDeployableAntenna","modulertantenna", "ModuleRTAntennaPassive","ModuleDataTransmitter","ModuleAnimateGeneric").
global AntModAlt to list("ModuleDeployableAntenna","modulertantenna", "ModuleRTAntennaPassive","ModuleDataTransmitter","ModuleAnimateGeneric").
global FWMod to list("Firework"      , " FIREWRKS ","ModulePartFirework").
global ISRUMod to list("Converter"   , "   ISRU   ","ModuleResourceConverter").
global LabMod to list("Science Lab"  , " SCI-LAB  ","ModuleScienceLab","ModuleScienceConverter").
global RBTMod to list("Robotics"     , " ROBOTICS ","ModuleRoboticServoPiston","ModuleRoboticServoRotor","ModuleRoboticServoHinge","ModuleRoboticRotationServo","ModuleRoboticController","").
global SMRTMod to list("Smart Parts" , " SMRT PRT ","Stager","Altimeter","SmartOrbit","DPLD","SmartSRB"," Speedometer","Timer","ProxSensor").

//MKS MOD
global MksDrlMod to list("MKS Harvest"," MKS HRVST","usi_harvester").
global MksDrlModAlt to MksDrlMod:sublist(2,MksDrlMod:length).
global PWRMod to list("MKS Resources", " MKS RSC  ","usi_converter").
global PWRModALT to PWRMod:sublist(2,PWRMod:length).
global DEPOMod to list("MKS Depot"   , " MKS DPOT ","Wolf_Depotmodule").
global habMod to list("MKS Deployable", " MKS DPLY ","USIAnimation","USI_BasicDeployableModule").
global CnstMod to list("MKS Constructor"    , " CONSTRCT ","OrbitalKonstructorModule", "ModuleKonFabricator").
global DcnstMod to list("MKS Deconstructor", " DCNSTRCT ","ModuleDekonstructor").
global ACDMod to list("MKS Academy"  , " MKS ACDMY","spaceacademy").
//OTHER MODS
global CapMod to list("Capacitor"    , "CAPACITOR ","DischargeCapacitor").
global BDPMod to list("BD Pilot", " BD PILOT ","BDModulePilotAI").
global CMMod to list("Countermeasure", "CNTRMSURES","CMDropper").
global RadarMod to list("Radar"      , "  RADAR   ","ModuleRadar").
global FRNGMod to list("Fairing"     , "  FAIRING ","ModuleProceduralFairing").
global WMGRMod to list("Weapon Manager", " WEAPONS  ","MissileFire").

//#endregion
//#region Check BootLoop and Monitor
IF CORE:MESSAGES:EMPTY{}ELSE{
  SET RECEIVED TO CORE:MESSAGES:POP.
    if RECEIVED:content < 0 {set loadattempts to 0.}
    else{SET loadattempts TO 1+RECEIVED:CONTENT.}
}
if loadattempts > 2 set config:ipu to 1000. 
SendBoot().
if height > 1000 set height to 0.
if not (defined monitorGUID) global monitorGUID to 0.
desktop().
print "LOAD ATTEMPTS:"+loadattempts+"        ("+(3-loadattempts)+" MORE TO TRIGGER BOOTLOOP FIX)" at (1,heightlim). wait loadattempts.
if dbglog > 0 log2file("LOAD ATTEMPTS:"+loadattempts+"        ("+(3-loadattempts)+" MORE TO TRIGGER BOOTLOOP FIX)").
IF loadattempts > 2 BootLoopFix().
IF file_exists(autofile){global LISTIN TO READJSON(SubDirSV + autofile).
    IF not (DEFINED monitorselected){
       IF DEFINED listin{
        set MONITORID to listin[8].
        if monitorid > 0 {IF MONITORID:substring(0,7) = "0000000" SET FORCEMON TO MONITORID:substring(7,1):TONUMBER+1.ELSE SET monitorGUID TO listin[8].}
      }
        local totalMonitors to addons:kpm:getmonitorcount() - 1.
          for index in range(0, totalMonitors){
             if forcemon > 0 {
            if index = forcemon-1 {
              set monitorGUID to addons:kpm:getguidshort(index). 
              set buttons:currentmonitor to index.
              set id to addons:kpm:getguidshort(index).
              global monitorselected to 1. 
              PRINT "MONITOR FORCED TO MON "+index at (1,heightlim).WAIT 1.
              if dbglog > 0 log2file("MONITOR FORCED TO MON "+index).
               break. 
            }}
            if addons:kpm:getguidshort(index) = monitorGUID {
              set buttons:currentmonitor to index.
              set id to addons:kpm:getguidshort(index).
              global monitorselected to 1.
              PRINT "MONITOR LOADED FROM MEMORY" at (1,heightlim). set fastboot to 1. WAIT 1.
              if dbglog > 0 log2file("MONITOR LOADED FROM MEMORY").											  
            }
          }
    }
  }
IF not (DEFINED monitorselected) {setmonvis().}else{IF monitorselected = 0 setmonvis().}
IF NOT (DEFINED setupdone){loadship().}ELSE{
  IF QUICKREBOOT > 0 {IF file_exists(autofile){loadAutoSettings().}}ELSE {loadship().}}
HudFuction().
    if loadbkp = 2 { set LNstp to 1. set line to 1. DESKTOP(). loadship(0). HudFuction().}
//#endregion
//#region Ship Setup
function desktop{
  clearScreen.
  for i in range (0,heightlim){
                     local po to "|                                                                              |".
    if i = 0 or i = heightlim-1 set po to "################################################################################".
    if i = 8           set po to "|                              KERBAL HUD SYSTEM                               |".
    if i = 9           set po to "|                              BY  FUZZYMEEP TWO                               |".
    if i = 10          set po to "|                                VERSION 1.06                                  |".
    if i = 15          set po to "|___________________________________LOADING____________________________________|".
    print po at (0,i).
}}
Function LoadShip{
   SpeedBoost().
   if DbgLog > 0 log2file("LOADSHIP" ).
  local parameter runop is 1.
      set loading to 0.
    set loadperstep to 1.
    set listinc to 0.
    local rc to 0.
    local la to 2-runop.
  if runop = 1 {DESKTOP(). firststrun().} else set listinc to 0.
  Function firststrun{
    if DbgLog > 0 log2file("FIRSTRUN" ).
  //#region set lists and tags
    global PrtListIn to SetPartList(ship:parts).
    loadbar().
    AutoTag(). //get science part names
      local prtlstintmp to list().
      for prt in PrtListIn{if prt:tag <> "" prtlstintmp:add(prt).}
      set PrtListIn to prtlstintmp:copy.
    set lighttag to makelists(lightMod,"lighttag").
    set AGTag to  makelists(AGMod,"AGTag").
    set FlyTag to makelists(FlyMod,"FlyTag").
    set CMDTag to makelists(CMDMod,"CMDTag").
    set CntrlTag to makelists(CntrlMod,"CntrlTag").
    set engtag to makelists(engMod,"engtag").
    set IntTag to makelists(INTmod,"IntTag").
    set dcptag to makelists(dcpMod,"dcptag").
    set geartag to makelists(gearMod,"geartag").
    set chutetag to makelists(chuteMod,"chutetag").
    set ladtag to makelists(ladMod,"ladtag").
    set baytag to makelists(bayMod,"baytag").
    set Docktag to makelists(DOCKMod,"Docktag").
    set RWtag to makelists(RWMod,"RWtag").
    set slrtag to makelists(slrMod,"slrtag").
    set RCStag to makelists(RCSMod,"RCStag").
    set drilltag to makelists(drillMod,"drilltag").
    set radtag to makelists(radMod,"radtag").
    set scitag to makelists(scimod,"scitag").
    set anttag to makelists(antMod,"anttag").
    set FWtag to makelists(FWMod,"FWtag").
    set ISRUTag to makelists(ISRUMod,"ISRUTag").
    set Labtag to makelists(LabMod,"Labtag").
    set RBTTag to makelists(RBTMod,"RBTTag").
    set SMRTtag to makelists(SMRTMod,"SMRTtag").
    //MKS MOD
    set MksDrlTag to makelists(MksDrlMod,"MksDrlTag").
    set PWRTag to makelists(PWRMod,"PWRTag").
    set DEPOTag to makelists(DEPOMod,"DEPOTag").
    set habTag to makelists(habMod,"habTag").
    set CnstTag to makelists(CnstMod,"CnstTag").
    set DcnstTag to makelists(DcnstMod,"DcnstTag").
    set ACDTag to makelists(ACDMod,"ACDTag").
    //OTHER MODS
    set CapTag to makelists(CapMod,"CapTag").
    //BDA MOD (KEEP LAST TO MAKE WMGR QUICKLY ACCESSABLE)
    set BDPtag to makelists(BDPMod,"BDPtag").
    set CMtag to makelists(CMMod,"CMtag").
    set Radartag to makelists(RadarMod,"Radartag").
    set FRNGtag to makelists(FRNGMod,"FRNGtag").
    set WMGRtag to makelists(WMGRMod,"WMGRtag").
    set itemlist[0] to listinc.
    ItemListHUD:INSERT(0,listinc).
  }
   local pc to 3.
   loadbar().
   if AutoDspList[0]:length < itemlist[0]  addlist().
    IF (DEFINED listin){IF LOADBKP <> 2 {printrow(GetColor("Loading Auto Settings.","CYN",0)). loadAutoSettings(la).set LNstp to LNstp-1.}} loadbar().
    IF LOADBKP = 2 {set pc to 2. set rc to 1. printrow(GetColor("Loading Backup Settings.","ORN",0)). loadAutoSettings(la). set LNstp to LNstp-1.} loadbar(). 
    if GrpdspList:length < itemlist[0]+1 or GrpdspList:length < itemlist[0]+1 or runop = 0 or rc = 1 or LFX > 0{
        printrow(GetColor("Adjusting for Loaded Settings.","WHT",0)). dsplistfix().  loadbar().
    }
    if runop <> 0 or LOADBKP = 2{
      //set GrpdspList[flytag][1] to 1.
      if AutoDspList[0]:length < itemlist[0]  addlist().
      printrow(GetColor("Checking Part Availability.","YLW",0)).partcheck(pc). loadbar().
      if dcptag <> 0{printrow(GetColor("Checking Decoupler Parts.","ylw",0)). DcpGauges(prtTagList[dcptag]).} loadbar().
      printrow(GetColor("Setting Auto Triggers.","WHT",0)).SetAutoTriggers(2). loadbar(). 
      printrow(GetColor("Saving Auto Settings.","PRP",0)). SaveAutoSettings(0). loadbar(). 
      printrow(GetColor("Setting Module Commands.","WHT",0)). SetModules().    loadbar(). 
      printrow(GetColor("Checking Ship Resources.","YLW",0)). ISRUcheck().     loadbar(). 
      printrow(GetColor("Checking Module States.","YLW",0)).  CheckSettings(). loadbar(). 
      printrow(GetColor("Checking Sensor Availability.","YLW",0)). checkmodeavail(). loadbar().
      set LOADBKP to 0.
    }
    FOR i IN RANGE(1, 79) {
      print "#" at (i,16).
    IF FASTBOOT = 0 wait.01.
    }
      if AutoDspList[0]:length < itemlist[0]  addlist().
      GLOBAL ActiveMeter to list().
      FOR TMP IN RANGE (0,ITEMLIST[0]+1) ActiveMeter:add(1).
      global setupdone to 1.
      if DbgLog > 0 log2file("STARTUP DONE").
      if dbglog = -1{
        log2file("logging resumed").
        set dbglog to 4.
      }

  
  //#endregion setup done
    function makelists{
      local parameter ModulesIn, tagnameIn.
      local typename to modulesin[0].
      local HUDname to modulesin[1].
      local modules to modulesin:sublist(2,modulesin:length).
      local hasmod to 0.
      if typename <> "Action Group" and  typename <> "Flight Control"{
        for m in modules{
          set hasmod to SHIP:MODULESNAMED(m).
          if hasmod:length > 0 break.
        }
      IF hasmod = 0 {if listinc > 1 loadbar(). return 0.}
      if DbgLog > 2 log2file("MAKE LIST "+tagnameIn+"-"+LISTTOSTRING(modulesin)).
      global tempTAGS TO TAGCHECK(typename,modules).
      }else{
        if typename = "Action Group"set tempTAGS to list(16,"AG1","AG2","AG3","AG4","AG5","AG6","AG7","AG8","AG9","AG10", "THROTTLE","RCS","ABORT","GEAR","LIGHTS","BRAKES").
        if typename = "Flight Control"set tempTAGS to list(12,"HEADING","PROGRADE", "RETROGRADE", "NORMAL", "ANTI NORMAL", "RADIAL OUT", "RADIAL IN", "TARGET", "ANTI TARGET", "MANEUVER", "STABILITY ASSIST", "STABILITY").
         }
        if typename = "Command"{set cmdln to tempTAGS[0]. if mjb > 0{ set temptags to listadd(temptags,MJEB[0]). sET TEMPTAGS[0] TO tempTAGS:LENGTH-1.}}
      if tempTAGS[0] = 0{if listinc > 1 loadbar(). return 0.}
        else{
          set listinc to listinc+1. 
          ItemList:add(typename).
          prtlist:add(list(list(tagnameIn+"/"+listinc))).
          GrpOpsList:add(list(0)).
          ItemListHUD:add(HUDname).
          prtTagList:add(list(tempTAGS[0])).
          set prttaglistR to "".
        }
        if listinc > 1 loadbar(). 
        if tempTAGS[0] <> 0{
          FOR i IN RANGE(1, tempTAGS[0]+1) {
            set prttaglistR to prttaglistR+tempTAGS[I]+",".
            prtTagList[listinc]:add(tempTAGS[I]).
            local prt to list().
            for m in modules{
              if SHIP:MODULESNAMED(m):length > 0 {
                //if dbglog > 2 log2file("         "+"    MODULE:"+m).
                for p in SHIP:PARTSDUBBED(tempTAGS[I]){
                  if p:hasmodule(m){
                    //if dbglog > 2 log2file("         "+p).
                    if typename = "Lights" {
                      
                      if m="ModuleColorChanger" or m="ModuleAnimateGeneric"{if not p:getmodule(m):hasaction("toggle lights") set p to "".}
                      if p:typename <> "string" for md in lightmodskp{ if p:hasmodule(md) {set p to "". break.}}
                    }
                    if p <>"" and not prt:contains(p)prt:add(p).
                  }
                }
              }
            }
            if typename = "Action Group" prt:add(core:part). 
            if typename = "Flight Control" prt:add(core:part). 
            if typename = "Command" and mjb > 0 prt:add(mjpart).
            prt:insert(0, prt:length). 
            prtList[listinc]:add(prt).
          } 
          LOCAL TG TO " Tags". IF tempTAGS[0] = 1 SET TG TO " Tag".
         if typename ="Experiment" or typename ="Action Group" or  typename ="Flight Control" or  typename ="Command" {printrow(tempTAGS[0]+":"+typename +TG+" Found").}else{printrow(tempTAGS[0]+":"+typename +TG+" Found:"+prttaglistR).}
        }
        loadbar(). 
        if tempTAGS[0] <> 0{
          dsplists(tempTAGS[0]+1,typename,listinc,1).
          if typename = "Lights" { print "|       Tagged Lights Found. Lights Will Turn on With Matching Tags" at (0,LNstp).SET LNstp TO LNstp+1.}
        }
        loadbar().
        FUNCTION TAGCHECK{
          local PARAMETER tname, ml.
          if DbgLog > 1 log2file("   TAGCHECK:"+TNAME+" Mods:"+LISTTOSTRING(ml)).
          local tl to list(). 
          for m in ml{
            LOCAL ModFound TO 0.
            LOCAL MDLGD TO 0.
            LOCAL TGLGD TO 0..
              for p in PrtListIn {
                if p:hasmodule(m) {
                  SET ModFound TO 1.
                  local t to p:Tag. 
                  if not tl:contains(p:tag) {
                    SET TGLGD TO 0.
                    if tname = "Converter" {
                      if p:name:contains("fuelcell") set t to "".}
                    else{
                    if tname = "Solar Panel" {
                      if p:name:contains("ISRU") set t to "".
                      //set ModFound to 1.
                      }
                    else{
                    if tname = "Cargo Bay" {
                      if p:hasmodule("ModuleProceduralFairing") set t to "".}
                    else{
                    if tname = "Lights"{
                      if p:hasmodule("ModuleColorChanger") {if not p:getmodule("ModuleColorChanger"):hasaction("toggle lights") set t to "".}
                        else{
                          if p:hasmodule("ModuleAnimateGeneric") {if not p:getmodule("ModuleAnimateGeneric"):hasaction("toggle lights") set t to "".}
                        }
                          for md in lightmodskp if p:hasmodule(md) {set t to "". break.}
                      }
                    else{
                    if tname = "Antenna" {
                      if p:hasmodule("ModuleRTAntenna"){if p:getmodule("ModuleRTAntenna"):hasfield("omni range") or rtech = 0 {set t to "".}}
                      if p:hasmodule("ModuleAnimateGeneric"){local aa to p:getmodule("ModuleAnimateGeneric"):allactions. for a in aa{if not a:contains("anten") and not p:hasmodule("ModuleRTAntenna") set t to "".}}}
                    else{
                    if tname = "Gear"{
                      if p:hasmodule("ModuleAnimateGeneric"){
                        if not p:hasmodule("ModuleWheelDeployment"){
                          if not p:getmodule("ModuleAnimateGeneric"):hasaction("toggle leg"){set t to "".}}}}
                    else{
                    if tname = "RCS" {
                      if p:hasmodule("ModuleRCSFX"){
                        if p:getmodule("ModuleRCSFX"):hasevent("show actuation toggles"){p:getmodule("ModuleRCSFX"):doevent("show actuation toggles").}}}
                    else{
                    if tname = "Engines" {
                      if p:hasmodule("ModuleGimbal"){
                        if p:getmodule("ModuleGimbal"):hasevent("show actuation toggles"){p:getmodule("ModuleGimbal"):doevent("show actuation toggles").}}}
                    else{

                    }}}}}}}}
                    if t <>"" tl:add(t).
                  }
                  if MDLGD = 0 and dbglog > 2 {log2file("       MOD:"+M ). SET MDLGD TO 1.}
                  if dbglog > 2 AND t <>"" {
                    IF TGLGD = 0 {log2file("           TAG:"+t). SET TOUT TO T.}
                    IF P:TAG = TOUT log2file("               "+P ).
                    SET TGLGD TO 1.
                  }
                }
              }
              //if ModFound = 1 break.
              }
          tl:insert(0, tl:length). 
          if TL:empty{SET TL TO LIST(0).}
          return tl.
        }
        if tempTAGS[0] = 0{return 0.}else{return listinc.}
    }
    function dsplistfix{
      if DbgLog > 0 log2file("dsplistfix" ).
            set  GrpOpsList to list(List(List(0))).
            set  GrpDspList to list(List(List(0))).
            set  GrpDspList2 to list(List(List(0))).
            set  GrpDspList3 to list(List(List(0))).
            set ItemListHUD to list().
            local loadp to 28. if colorprint > 0{ set loadp to loadp+9. PRINT " " AT (80,LNstp-1).}
        for I in Range(1,ItemList[0]+1){
          GrpOpsList:add(list(0)).
          set loadp to loadp+1. print "." at (loadp,LNstp-1).
          dsplists(prtTagList[I][0]+1, prtList[I][0][0]:split("/")[1]:tonumber,i,2).
        }
        ItemListHUD:insert(0,ItemListHUD:length).
    }
    function dsplists{ 
          local parameter Tgin, typename, lnc, opin. //this is to fix mismatched lists, it looks redundant, but is very important.
            if opin = 2{
              local HUDname to "          ".
              if typename = lighttag {set typename to "Lights". set HUDname to  "  LIGHTS  ".}else{
              if typename = AGtag {set typename to "Action Group". set HUDname to " ACTN GRP ".}else{
              if typename = Flytag {set typename to "Flight Control". set HUDname to "FLGHT CTRL".}else{
              if typename = CMDTag {set typename to "command". set HUDname to  " COMMAND  ".}else{
              if typename = Cntrltag {set typename to "control srf". set HUDname to  "CNTRL SURF".}else{
              if typename = engtag {set typename to "Engines". set HUDname to  " ENGINES  ".}else{
              if typename = Inttag {set typename to "Intake". set HUDname to  "  INTAKES ".}else{
              if typename = dcptag {set typename to "Decoupler". set HUDname to  "DECOUPLERS".}else{
              if typename = geartag {set typename to "Gear". set HUDname to  "   GEAR   ".}else{
              if typename = chutetag {set typename to "Parachute". set HUDname to  "PARACHUTES".}else{
              if typename = ladtag {set typename to "Ladder". set HUDname to  "  LADDER  ".}else{
              if typename = baytag {set typename to "Cargo Bay". set HUDname to  "CARGO BAYS".}else{
              if typename = Docktag {set typename to "Docking Port". set HUDname to  "  DOCKING ".}else{
              if typename = RWtag {set typename to "Reaction Wheel". set HUDname to  " RCTNWHEEL".}else{
              if typename = slrtag {set typename to "Solar Panel"  . set HUDname to  "   POWER  ".}else{
              if typename = RCStag {set typename to "RCS". set HUDname to  "   RCS    ".}else{
              if typename = drilltag {set typename to "Drill". set HUDname to  "  DRILLS  ".}else{
              if typename = radtag {set typename to "Radiator". set HUDname to  " RADIATORS".}else{
              if typename = scitag {set typename to "Experiment". set HUDname to  "XPERIMENTS".}else{
              if typename = anttag {set typename to "Antenna". set HUDname to  " ANTENNAS ".}else{
              if typename = FWtag {set typename to "Firework". set HUDname to  " FIREWRKS ".}else{
              if typename = ISRUtag {set typename to "Converter". set HUDname to  "   ISRU   ".}else{
              if typename = Labtag {set typename to "Science Lab". set HUDname to  " SCI-LAB  ".}else{
              if typename = RBTtag {set typename to "Robotics". set HUDname to  " ROBOTICS ".}else{
              if typename = SMRTtag {set typename to "Smart Parts". set HUDname to  " SMRT PRT ".}else{
              //MKS MOD
              if typename = MksDrltag {set typename to "MKS Harvest". set HUDname to " MKS HRVST".}else{
              if typename = PWRtag {set typename to "MKS Resources". set HUDname to  " MKS RSC  ".}else{
              if typename = DEPOtag {set typename to "MKS Depot". set HUDname to  " MKS DPOT ".}else{
              if typename = habtag {set typename to "MKS Deployable". set HUDname to  " MKS DPLY ".}else{
              if typename = Cnsttag {set typename to "MKS Constructor". set HUDname to  " CONSTRCT ".}else{
              if typename = Dcnsttag {set typename to "MKS Deconstructor". set HUDname to  " DCNSTRCT ".}else{
              if typename = ACDtag {set typename to "MKS Academy". set HUDname to  " MKS ACDMY".}else{
              //OTHER MODS
              if typename = Captag {set typename to "Capacitor". set HUDname to  "CAPACITOR ".}else{
              if typename = BDPtag {set typename to "BD Pilot". set HUDname to  " BD PILOT ".}else{
              if typename = CMtag {set typename to "Countermeasure". set HUDname to  "CNTRMSURES".}else{
              if typename = Radartag {set typename to "Radar". set HUDname to  "  RADAR   ".}else{
              if typename = FRNGtag {set typename to "Fairing". set HUDname to  "  FAIRING ".}else{
              if typename = WMGRtag {set typename to "Weapon Manager". set HUDname to  " WEAPONS  ".}else{
              }}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
              ItemListHUD:add(HUDname).
            }
            if DbgLog > 2{ 
              log2file("        dsplist:"+typename ).
              log2file(+"         Tgin:"+Tgin+" typename:"+typename+" lnc:"+lnc+" opin:"+opin ).
            }
          FOR i IN RANGE(1, tgin+1) {
              local t to list(                             " TURN ON  "," TURN OFF ","          ","          ","          ","          ","          ","          ").  
              if typename =  "Solar Panel"  {set t to list("  ENABLE  "," DISABLE  ","  EXTEND  ","  RETRACT ","          ","          ","          ","          ").}else{
              if typename ="Ladder"
              or typename = "control srf"   {set t to list("  EXTEND  "," RETRACT  ","          ","           ","          ","          ","          ","          ").}else{
              if typename ="Decoupler" {set t to      list(" DECOUPLE ","DECOUPLED "," XFEED OFF"," XFEED ON "," INFLATE  "," DEFLATE  ","          ","          ").}else{ 
              if typename ="Antenna" {set t to        list("  EXTEND  ","  RETRACT ","          ","          ","XMIT DATA ","XMIT DATA ","          ","          ").}else{ 
              if typename ="Gear" {set t to           list("  EXTEND  ","  RETRACT ","          ","          ","          ","          ","          ","          ").} else{
              if typename ="Command" {set t to        list("CNTRL FROM","CNTRL FROM"," TGL HBRNT"," TGL HBRNT"," CLCT SCI "," CLCT SCI ","          ","          ").} else{
              if typename ="Cargo Bay" {set t to      list("BAY CLOSED "," BAY OPEN ","          ","          ","          ","          ","          ","          ").} else{
              if typename ="Parachute" {set t to      list("   ARM    ","   ARMED  ","    CUT   ","    CUT   ","          ","          ","          ","          ").} else{
              if typename ="Drill" {set t to          list("  EXTEND  ","  RETRACT ","  TOGGLE  ","  TOGGLE  ","          ","          ","          ","          ").} else{
              if typename ="Experiment"  {set t to    list(" RUN TEST "," RUN TEST ","  DEPLOY  ","  RETRACT ","          ","          ","          ","          ").} else{
              if typename ="Lights"      {set t to    list(" LIGHT OFF"," LIGHT ON "," BLINK OFF"," BLINK ON ","          ","          ","          ","          ").} else{
            if typename = "Docking Port"{set t to    list("NOT DOCKED"," SEPERATE ","  EXTEND  ","  RETRACT "," XFEED OFF"," XFEED ON ","          ","          ").} else{
              if typename = "Converter"  {set t to    list("  TOGGLE  ","  TOGGLE  ","          ","          ","          ","          ","          ","          ").} else{
              if typename = "firework"   {set t to    list("   FIRE   ","   FIRE   ","          ","          ","          ","          ","          ","          ").} else{
              if typename = "Robotics"   {set t to    list(" TGL DPLY "," TGL DPLY "," TGL LOCK "," TGL LOCK ","          ","          ","          ","          ").} else{
              if typename = "Capacitor"  {set t to    list("DISCHARGE ","DISCHARGE "," CHG ENAB "," CHG ENAB "," CHG DISAB"," CHG DISAB","          ","          ").} else{
              if typename = "Radar"      {set t to    list(" TURN ON  "," TURN OFF ","PREV TRGT ","PREV TRGT ","NEXT TRGT ","NEXT TRGT ","          ","          ").} else{
          if typename = "Reaction Wheel"{set t to    list(" TURN ON  "," TURN ON  "," TURN OFF "," TURN OFF ","          ","          ","          ","          ").} else{
              if typename = "Science Lab"{set t to    list("STRT RSRCH","STOP RSRCH","XMIT SCNCE","XMIT SCNCE","          ","          ","          ","          ").} else{
              if typename = "Countermeasure"{set t to list("   FIRE   ","   FIRE   ","          ","          ","          ","          ","          ","          ").} else{
              if typename = "Fairing"    {set t to    list(" JETTISON "," JETTISON ","          ","          ","          ","          ","          ","          ").} else{
              if typename ="MKS Harvest" {set t to    list("  EXTEND  ","  RETRACT "," STRT DRL "," STOP DRL ","          ","          ","          ","          ").} else{
              if typename = "MKS Depot"  {set t to    list(" ESTABLISH","          ","          ","          ","          ","          ","          ","          ").} else{
              if typename = "MKS Deployable"{set t to list("  DEPLOY  ","  DEPLOY  ","          ","          ","          ","          ","          ","          ").} else{
              if typename = "MKS Resources"{set t to  list("  START   ","   STOP   ","          ","          ","          ","          ","          ","          ").} else{
              if typename = "MKS Academy"  {set t to  list("  TRAIN   "," TRAINING "," LEVEL UP "," LEVEL UP ","          ","          ","          ","          ").} else{
            if typename = "MKS Constructor"{set t to  list(" CONSTRCT "," CONSTRCT "," FABRICTE "," FABRICTE ","ENAB CNSTR","ENAB CNSTR","          ","          ").} else{
            if typename ="Flight Control"  {set t to list(" TURN ON  "," TURN OFF ","          ","          "," DSP HERE ","ALWAYS DSP","          ","          ").} else{
          if typename = "MKS Deconstructor"{set t to list(" DECNSTRCT"," DECNSTRCT","          ","          ","          ","          ","          ","          ").} else{
          if typename = "Weapon Manager"{set t to    list("   FIRE   ","   FIRE   "," TGL GUARD"," TGL GUARD","  CHF/FLR "," CHF/FLR  ","          ","          ").} else{
          if typename = "BD Pilot"{       set t to    list(" TURN ON  "," TURN OFF "," STDBY OFF"," STDBY ON ","  CLAMPED ","UNCLAMPED ","          ","          ").} else{
              if typename = "Engines" and i < tgin+1{
                local k to i. if i > tgin-1 set k to tgin-1.
                FOR j IN RANGE(1, prtlist[lnc][k][0]) {
                  local prt2 to prtlist[lnc][k][J].
                      if prt2:hasmodule("MultiModeEngine"){if not t:contains("TOGL MODE "){set t[2]to "TOGL MODE ".set t[3] to"TOGL MODE ".}}
                      if prt2:hasmodule("ModuleGimbal"){if not t:contains(" TGL GMBL "){set t[4]to " TGL GMBL ".set t[5] to" TGL GMBL ".}}
                      }}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
              t:insert(0, t:length). 
              GrpOpsList[lnc]:add(t).
              
              if i = 1{
                local ladd1 to list(1).
                local ladd3 to list(1).
                local ladd5 to list(1).
                local ladd0 to list(t[0]).
                local laddu0 to list(15).
                local laddu1 to list(15).
                for l in range (0,tgin+1){
                  ladd0:add(0).
                  ladd1:add(1).
                  ladd3:add(3).
                  ladd5:add(5).
                  laddu0:add(0).
                  laddu1:add(1).
                }
               GrpDspList:add(ladd1:copy).
              GrpDspList2:add(ladd3:copy).
              GrpDspList3:add(ladd5:copy).
              if opin = 1{
                AutoDspList:add(laddu1:copy).
                autoRstList:add(laddu1:copy).
                AutoValList:add(laddu0:copy).
                AutoRscList:add(laddu0:copy).
                AutoTRGList:add(laddu1:copy).
                AutoRscList[0]:add(1).
                AutoTRGList[0]:add(laddu0:copy).
              }
            }
          }
        }
    FUNCTION AutoTag{
      if DbgLog > 0  log2file("AUTOTAG" ).
     if colorprint > 0 PRINT "  " AT (80,1).
      print printrow(GetColor("Setting Auto Tags.","WHT",0)).  
      local loadp to 17. if colorprint > 0{ set loadp to loadp+9. PRINT " " AT (80,LNstp-1).}
      local cnt2 to 0.
          for m in autotaglist{set loadp to loadp+1. print "." at (loadp,LNstp-1).
          if dbglog > 2 log2file("    Module:"+m).
            set cnt to 1.
            if SHIP:MODULESNAMED(m):length <> 0 {
              FOR prt IN PrtListIn {
                  IF prt:hasmodule("ModuleScienceExperiment") {
                    local pm to prt:GETmodule("ModuleScienceExperiment").
                    IF pm:HASACTION("log pressure data") SET senselist[3] TO 1.
                    IF pm:HASACTION("log gravity data")  SET senselist[1] TO 1.
                    IF pm:HASACTION("log temperature")   SET senselist[4] TO 1.
                    IF pm:HASACTION("log seismic data")  SET senselist[0] TO 1.
                  }
                  IF prt:hasmodule("ModuleGPS") {
                    if prt:TAG = ""  set prt:TAG to prt:TITLE+cnt.
                    IF prt:GETmodule("ModuleGPS"):HASfield("biome") {SET senselist[5] TO 1. set BSensor to prt. }
                  }
                  IF prt:hasmodule("ModuleDeployableSolarPanel") OR prt:hasmodule("KopernicusSolarPanel") SET senselist[2] TO 1.
                  IF prt:hasmodule("CMDropper")  cmlist:add(prt).
                if prt:TAG = "" {
                IF prt:hasmodule("ModuleGPS") {set prt:TAG to prt:TITLE+cnt.}
                else{
                  IF sciModAlt:contains(m){ if prt:hasmodule(m) {set cnt2 to cnt2+1. set prt:TAG to CNT2+":"+prt:TITLE.}}
                  ELSE{
                    IF prt:hasmodule("CMDropper"){set prt:TAG to prt:TITLE.}
                      ELSE{
                        if prt:hasmodule(m){
                            local tgt to prt:TITLE. 
                            for wd in trimwords set tgt to Removespecial(tgt,wd).
                            if tgt:contains("weapon manager") set tgt to tgt:REPLACE("weapon manager", "WM-").
                            set prt:TAG to tgt+cnt.
                          set cnt to cnt+1.}}}}			 
                          if dbglog > 2 and prt:TAG <> "" log2file("      "+prt+"-"+prt:TAG).
                }														
              }
            }
          }
          LOCAL SENSORPRINT TO "Sensors Found:".  
                  IF senselist[3] = 1 SET SENSORPRINT TO SENSORPRINT+"Pressure,".
                  IF senselist[1] = 1 SET SENSORPRINT TO SENSORPRINT+"Gravity,".
                  IF senselist[4] = 1 SET SENSORPRINT TO SENSORPRINT+"Temperature,".
                  IF senselist[0] = 1 SET SENSORPRINT TO SENSORPRINT+"Acceleration,".
                  IF senselist[2] = 1 SET SENSORPRINT TO SENSORPRINT+"Light,".
                  if SENSORPRINT <> "Sensors Found:" printrow(SENSORPRINT).
                  global alltagged to ship:ALLTAGGEDPARTS():copy.
                  global PrtListcur to SetPartList(ship:ALLTAGGEDPARTS(),1).
    }
    function checkmodeavail{
                    if colorprint > 0 PRINT " " AT (80,LNstp-1).
                    IF senselist[3] = 0 SET AutoValList[0][0][3][8]  TO -1.
                    IF senselist[1] = 0 SET AutoValList[0][0][3][11] TO -1. 
                    IF senselist[4] = 0 SET AutoValList[0][0][3][10] TO -1.
                    IF senselist[0] = 0 SET AutoValList[0][0][3][12] TO -1.
                    IF senselist[2] = 0 SET AutoValList[0][0][3][9]  TO -1.
                    IF DCPTAG       = 0 SET AutoValList[0][0][3][15] TO -1.
                    if senselist[0]+senselist[1]+senselist[2]+senselist[3]+senselist[4]=0 set senseskp to 1.
    }
    Function DcpGauges{
      local parameter Taglist.
      if colorprint > 0 PRINT " " AT (80,LNstp-1).
      local dcpprt to list("").
      local prt to 0.
      global DcpPrtList to list("0").
      FOR i IN RANGE(1, Taglist[0]+1) {
        DcpPrtList:add(list()).
        FOR j IN RANGE(1, PrtList[dcptag][I][0]+1) {
            set prt to PrtList[dcptag][I][J]. 
           if prt:hassuffix("children") if prt:children:empty = false{set dcpprt to prt:children.}else{set dcpprt to list("").}
          if j=1 DcpPrtList[I]:add(PrtList[dcptag][I][0]).
          for itm in dcpprt {
          IF not DcpPrtList[I]:contains(itm) and itm <> "" DcpPrtList[I]:add(itm).}
        }
        if DcpPrtList[I]:length = 1 DcpPrtList[I]:add("").
      }
      
    }
    function SetModules {
      local loadp to 24. if colorprint > 0{ set loadp to loadp+9. PRINT " " AT (80,LNstp-1).}
        local a to itemlist[0].
        local b to list("").
        local c to list(0,0).
        set b to  FillList(b, 12).
        global MeterList to list(
          list(a,list(a),list(a)), //meterlist[0][0] = current option name //meterlist[0][1] = Active part Module names //meterlist[0][2] = active part options
          list(a),                 //meterlist[1][tagnum] = attached part Module names 
          list(a),                 //meterlist[2][tagnum] = attached part options
          LIST(0),                 //meterlist[3][tagnum] = name for report vals when no field to pull 
          LIST(0)).                //meterlist[4][tagnum]1/2 = addon on/off 
        global Modulelist to list( // USED TO SUPPORT OLD LIST BASED CODE, WILL REMOVE EVENTUALLY
          list(b:copy), //Modulelist[0][tagnum] =MODULE 1 INFO   (TO SUPPORT OLD CODE AND PARTIALLY RECOGNIZED PARTS) 
          list(b:copy), //Modulelist[1][tagnum] = MODULE 1 INFO  (TO SUPPORT OLD CODE AND PARTIALLY RECOGNIZED PARTS) 
          list(b:copy)). //Modulelist[2][tagnum] = REPORT VALUESS (TO SUPPORT OLD CODE AND PARTIALLY RECOGNIZED PARTS) 
          GLOBAL MtrOps TO LIST(c:copy).
          GLOBAL ALTVAL TO 0.
        for k in range (1,itemlist[0]+1) {
          if k < 3 MeterList[0]:add(list(0)). MeterList[1]:add(list(0)). MeterList[2]:add(list(0)).  MeterList[3]:add(list(0)). MeterList[4]:add(list(list(),list())).
          Modulelist[0]:add(list(b:copy)). Modulelist[1]:add(list(b:copy)). Modulelist[2]:add(list(b:copy)).
          MtrOps:add(c:copy).
          }
         global MtrSpecList to list("ModuleOverheatDisplay").
              if DbgLog > 0 log2file("SET MODULES" ).
                        set loadp to loadp+1. print "." at (loadp,LNstp-1).

      global  RPTWords to lexicon(
      "extend", "EXTENDED","retract","RETRACTED","decouple","DECOUPLED","activate","ACTIVATED"      ,"shutdown" ,"SHUT DOWN"       ,"Toggle Mode"        ,"MODE TOGGLED"  ,"toggle gimbal"  ,"GIMBAL TOGGLED","Enable Crossfeed","CROSSFEED ENABLED"
      ,"open","OPENED"    ,"close"  ,"CLOSED"   ,"arm"     ,"ARMED"    ,"disarm"  ,"DISARMED"       ,"cut chute","CHUTE CUT"       ,"deploy chute"       ,"CHUTE DEPLOYED","deploy"         ,"DEPLOYED"      ,"start"           ,"STARTED"
      ,"stop","STOPPED"   , "toggle","TOGGLED","transmit","TRANSMITTED","blink on","BLINK TURNED ON","blink off","BLINK TURNED OFF","discharge capacitor","DISCHARGING   ","enable recharge","CHARGING"      ,"Launch"          , "LAUNCHED"
      ,"Use Minutes", "SWITCHED TO SECONDS"   , "Use Seconds","SWITCHED TO MINUTES","disable recharge", "RECHARGE DISABLED","Reset", "RESET","target PREV","PREVIOUS TARGET","target next","NEXT TARGET","countermeasure","COUNTERMEASURE FIRED"
      ). 


      //good5b check lander
      if lighttag > 0  {local ctag to lighttag.    set  MeterList[3][ctag] to "LIGHT".
          set modulelist[0][ctag] to list("Action"      ,"ModuleLight"           ,"lights on"          ,"lights off"         ,"ModuleLight"             ,"blink on"          ,"blink off"         ).
          set modulelist[1][ctag] to list("Action"      ,"ModuleNavLight"        ,"turn light on"      ,"turn light off"     ,""                        ,""                  ,""                  ). 
          set modulelist[2][ctag] to list("light status","light status"          ," TURNED ON "        ," TURNED OFF "       ,"off"                     ," BLINK TURNED  ON "," BLINK TURNED OFF ").
          set  MeterList[1][ctag] to TrimModules(lightMod:sublist(2,lightMod:length)).
          set  MeterList[2][ctag] to LIST(
            list(""                                        ,"blink period","pitch angle", "light emission"),
            list("status/light status/blink/light emission","0.2/2/0.1"   ,"0/180/5"    , "False/True/0"),
            list("Names"                                   ,""            ,""           , "Inactive/Active/0")).
      } 


      //Good5
      if CMDtag > 0  {local ctag to CMDtag. set  MeterList[3][ctag] to "COMMAND".
          set modulelist[0][ctag] to list("Action" ,"ModuleCommand","control from here","control from here"  ,"ModuleCommand" ,"toggle hibernation"    ,"toggle hibernation"           ,"ModuleScienceContainer","collect all","collect all"               ).
          set modulelist[1][ctag] to list(""). 
          set modulelist[2][ctag] to list(" "      ,""             ," CONTROL FROM HERE","CONTROL FROM HERE" ,""              ," HIBERNATTION TOGGLED" ," HIBERNATTION TOGGLED"        ,""                      ," SCIENCE COLLECTED" ," SCIENCE COLLECTED").
          set  MeterList[1][ctag] to TrimModules(listadd(CMDMod:sublist(2,CMDMod:length),list("ModulePowerCoupler","ModuleOverheatDisplay","ModulePowerDistributor","MKSModule"))).
          set  MeterList[2][ctag] to LIST(
            list(""                                                                                      ),
            list(       "comm signal/comm first hop dist/command state/core temp/thermal efficiency/powercoupler/pdu range/kos disk space/kos average power" ),
            list("Values/           /                  /            /          /                  /             /         /               /ec\s            "),
            list("style/           /                  /             /Mp-0-0   /Mp-0-100          /              /         /              /                 ")).
      }
      //good5
      if engtag > 0    {local ctag to engtag. set  MeterList[3][ctag] to "ENGINE".
          local fldsout to       "Status/mode/Gimbal/current rpm/specific impulse/collective/fuel flow/burn time/alternator output".
          local Stylout to "Style/      /    /       /Mn-0-1000/                 /          /         /         /                 ".
          local ValOut  to "Values/     /    /       /           /s              /          /u        /s        /ec\s".
          set modulelist[0][ctag] to list("Event"  ,"ModuleEnginesFX"             ,"activate engine"    ,"shutdown engine"    ,"MultiModeEngine"         ,"Toggle Mode"      ,"Toggle Mode"       ,"ModuleGimbal","toggle gimbal" ,"toggle gimbal"  ).
          set modulelist[1][ctag] to list("Event"  ,"ModuleEngines"               ,"activate engine"    ,"shutdown engine"    ,""                        ,""                 ,""                  ,""             ,""              ,""              ).
          set modulelist[2][ctag] to list(" "      ,"Status"                      ," ACTIVATED "        ," SHUT DOWN "        ,"mode"                    ," MODE TOGGLED"    ,"MODE TOGGLED"      ,"gimbal"       ,"GIMBAL TOGGLED","GIMBAL TOGGLED").
          set  MeterList[1][ctag] to TrimModules(listadd(engMod:sublist(2,engMod:length),list("Modulegimbal","ModuleAlternator"))).
          global engmods to TrimModules(engMod:sublist(2,engMod:length-3)).
          set  MeterList[2][ctag] to LIST(
            list(""      ,"thrust limiter", "Throttle"                    ,"Max RPM"        ,"Steering Response" ,"gimbal"       ,"gimbal limit" ,"pitch"             ,"yaw"               ,"roll"   ),
            list(fldsout ,"0/100/1"       ,"false/true/0"                 ,"100/1000/25"    ,"0.0/15/0.1"       , "False/True/0" ,"0/100/1"      , "False/True/0"     , "False/True/0"     , "False/True/0"   ),
            list("Names" ,""              ,"Main Throttle/Independent/0"  ,""               ,""                , "free/locked/0" ,""             , "Inactive/Active/0", "Inactive/Active/0", "Inactive/Active/0" ),
            list("BotRow5/pitch/yaw/roll"),
            list(Stylout),
            list(ValOut)).
      }

      //good5a
      if ladtag > 0    {local ctag to ladtag. set  MeterList[3][ctag] to "LADDER".
          set modulelist[0][ctag] to list("Event"  ,"RetractableLadder"           ,"extend ladder"     ,"retract ladder"     ).
          set modulelist[1][ctag] to list(""       ,""                            ,""                  ,""                   ).
          set modulelist[2][ctag] to list(" "      ,""                            ," EXTENDED"         ," RETRACTED"         ).
          //set  MeterList[1][ctag] to TrimModules(ladMod:sublist(2,ladMod:length)).
      } 

      //good5a
      if DcpTag > 0    {local ctag to DcpTag. set  MeterList[3][ctag] to "DECOUPLER".
          set modulelist[0][ctag] to list("Event"  ,"ModuleDecouple"              ,"decouple"          ,""                    ,"ModuleToggleCrossfeed"  ,"Enable Crossfeed" , "disable crossfeed" ,"ModuleAnimateGeneric" ,"inflate"         ,"deflate"         ).
          set modulelist[1][ctag] to list("Event"  ,"ModuleAnchoredDecoupler"     ,"decouple"          ,""                    ,""                       ,""                 ,""                   ,""                     ,""         ,""         ).
          set modulelist[2][ctag] to list(" "      ,""                            ," DECOUPLED"        ," ATTACHED"           ,""                        ,"CROSSFEED ENABLED","CROSSFEED DISABLED",""                     ," INFLATED"         ," DEFLATED"         ).
          set meterlist[4][ctag] to list(list("jettison"),list(),list(),list(),list("inflate","deflate","deploy"),list()).
          set  MeterList[1][ctag] to TrimModules(listadd(dcpMod:sublist(2,dcpMod:length),list("ModuleToggleCrossfeed","ModuleAnimateGeneric","MODULEJETTISON"))).
      }         

      //good5z problems with spring /friction/ steering manual auto display, ksp menu actions not changing doesnt help
      if geartag > 0   {local ctag to geartag.  set  MeterList[3][ctag] to "GEAR".
          set modulelist[0][ctag] to list("Action" ,"ModuleWheelDeployment"       ,"extend/retract"    ,"extend/retract"     ,"ModuleWheelSteering"     ,"toggle steering"  ,"toggle steering"   ,"ModuleWheelSteering" ,"toggle steering"  ,"toggle steering"   ).
          set modulelist[1][ctag] to list("Event"  ,"ModuleAnimateGeneric"        ,"extend"            ,"retract"            ,""                        ,""                 ,""                  ,""                    ,""                 ,""                  ). 
          set modulelist[2][ctag] to list("state"  ,"state"                       ," EXTENDED"         ," RETRACTED"         ,"Retracted"               ,""                 ,""                  ,"steering"            ,"STEERING ENABLED" ,"STEERING DISABLED" ).
          set MeterList[1][ctag] to TrimModules(listadd(GEARMod:sublist(2,GEARMod:length),list("ModuleWheelSuspension","ModuleWheelSteering","ModuleWheelBrakes","ModuleWheelBase"))).
          set  MeterList[2][ctag] to LIST(
            list(""                               , "steering"          , "steering: direction","steering angle limiter","steering response","brakes"  ,"friction control","spring strength" ,"damper strength"  , "deploy shielded"   ,"drive limiter" ),
            list("state/status/steering/motor"    , "False/True/0"      ,"False/True/0"        ,"0/30/1"               ,"0.1/10/0.1"        ,"0/200/10","0.0/10/0.1"      ,"0.05/3/0.05"     ,"0.05/2/0.05"      ,"False/True/0"       ,"0/100/1"       ),
            list("Names"                          , "Disabled/Enabled/0","Normal/Inverted/0"   ,""                     , ""                 , ""       , ""               , ""               , ""                , "disabled/enabled/0", ""             )).
      }

      //good5a
      if baytag > 0    {local ctag to baytag. set  MeterList[3][ctag] to "BAY".
          set modulelist[0][ctag] to list("Event"  ,"ModuleAnimateGeneric"        ,"open"              ,"close"      ).
          set modulelist[1][ctag] to list("Event"  ,"hangar"                      ,"open gates"        ,"close gates"). 
          set modulelist[2][ctag] to list(" "      ,"STATUS"                      ," OPENED"           ," CLOSED"    ).
          set  MeterList[1][ctag] to TrimModules(bayMod:sublist(2,bayMod:length)).
          set  MeterList[1][ctag] to TrimModules(listadd(bayMod:sublist(2,bayMod:length),list("ModuleAnimateGeneric","SimpleHangarStorage"))).
          //set  MeterList[2][ctag] to LIST(
          //    list(""      ),
          //    list("status/hangar name/vessels/stored mass/stored cost/used volume")).
      } 

      //Good5
      if chutetag > 0  {local ctag to chutetag. set  MeterList[3][ctag] to "CHUTE".
          set modulelist[0][ctag] to list("Action" ,"RealChuteModule"             ,"arm parachute"     ,"disarm parachute"  ,"RealChuteModule"          ,"cut chute"      ,"cut chute"           ,"RealChuteModule","deploy chute","deploy chute").
          set modulelist[1][ctag] to list("Event"  ,"moduleparachute"             ,"deploy chute"      ,"disarm"             ,"moduleparachute"         ,"cut chute"        ,"cut chute"         ,""               ,""            ,""            ,""). 
          set modulelist[2][ctag] to list(" "      ,"altitude"                    ," ARMED"            ," DISARMED"          ,"safe to deploy?"         ," CHUTE CUT"       ," CHUTE CUT"        ,""              ).
          set  MeterList[1][ctag] to TrimModules(chuteMod:sublist(2,chuteMod:length-1)).//REMOVE -1 AFTER TESTING REALCHUTE
          set  MeterList[2][ctag] to LIST(
            list(""                                                        ,"min pressure"   ,"altitude"     ,"spread angle"  ,"deploy mode"),
            list(       "altitude/min pressure/spread angle/safe to deploy?","0.01/0.75/0.01" ,"50/5000/50"   ,"0/10/1"        ,"0/1/2/-1"),
            list("Values/M       /kPa        /            / "               ,"kPa"            ,"M"            ,""              ,""),
            list("Names"                                                   ,""               ,""             ,""              ,"safe/risky/immediate/-1")).
      }
      //good5
      if slrtag > 0    {local ctag to slrtag. set  MeterList[3][ctag] to "GENERATOR".
          set modulelist[0][ctag] to list("Event"  ,"ModuleDeployableSolarPanel"   ,"extend Solar Panel" ,"retract Solar Panel" ,"ModuleAnimateGeneric" ,"extend arm"     ,"retract arm").
          set modulelist[1][ctag] to list("Action" ,"ModuleResourceConverter"       ,"start fuel cell"    ,"STOP fuel cell").
          set modulelist[2][ctag] to list(" "      ,"Sun exposure"                  ," ENABLED"           ," DISABLED"          ,""                        ," EXTENDED"   ," RETRACTED" ).
          set  MeterList[1][ctag] to TrimModules(listadd(slrMod:sublist(2,slrMod:length),list("ModuleAnimateGeneric"))).
          set  MeterList[2][ctag] to LIST(
              list(""                     ),
              list("sun exposure/energy flow/generator/efficiency/status")).///fuel cell wont work. bad vals when full
              set meterlist[4][ctag] to list(list("activate"),list("shutdown"),list("deploy","extend"),list("retract")).
      } 

      //good5
      if drilltag > 0  {local ctag to drilltag. set  MeterList[3][ctag] to "DRILL".
          set modulelist[0][ctag] to list("Event" ,"ModuleAnimationGroup"         ,"deploy drill"       ,"retract drill"      ,""                        ,""               ,""                  ,"ModuleOverheatDisplay",""               ,""                  ).
          set modulelist[1][ctag] to list("Action",""                            ,""                  ,""                   ,"ModuleResourceHarvester" ,"toggle surface harvester" ,"toggle surface harvester", ""                    ,""                  ,""                  ). 
          set modulelist[2][ctag] to list(" "      ,""                            ," DEPLOYED"          ," RETRACTED"         ,"ore rate"                ," TOGGLED        " ," TOGGLED           ","core temp"            ,""                  ,""                  ).
          set  MeterList[1][ctag] to TrimModules(listadd(DrillMod:sublist(2,DrillMod:length),list("ModuleOverheatDisplay","ModuleAnimationGroup"))).
          set  MeterList[2][ctag] to LIST(
              list(""                     ),
              list(       "ore rate/core temp/thermal efficiency"),//surface harvester display wont work throws bad values if RC menu not up
              list("Style/         /Mp-0-0   /Mp-0-100   ")).
      } 

      //good5
      if radtag > 0    {local ctag to radtag. set  MeterList[3][ctag] to "RADIATOR".
          set modulelist[0][ctag] to list("Event" ,"ModuleDeployableRadiator"     ,"extend radiator"       ,"retract Radiator"       ,"" ,"" ,"").
          set modulelist[1][ctag] to list(""      ,"ModuleSystemHeatRadiator"     ,"activate radiator"     ,"shutdown radiator"      ,""                        ,""               ,""                  ).
          set modulelist[2][ctag] to list(" "      ,""                            ," EXTENDED / ACTIVATED" ," RETRACTED / DEACTIVATED" ,"cooling"                 ," ACTIVATED      " ,"DEACTIVATED"       ).
          set  MeterList[1][ctag] to TrimModules(RadMod:sublist(2,RadMod:length)).
          set  MeterList[2][ctag] to LIST(
              list(""                     ),
              list(      "cooling/radiator efficiency"),
              list("Style/Mp-0-100/Mp-0-100")).
      } 

      //GOOD3 (add collect science to cmd pod //didn't work)
      if scitag > 0    {local ctag to scitag. set  MeterList[3][ctag] to "EXPERIMENT".
          set modulelist[0][ctag] to list("Action","ModuleScienceExperiment"       ,"getname"            ,"getname"            ,""                        ,""               ,""                  ,"ModuleScienceExperiment","delete data"      ," "                  ).
          set modulelist[1][ctag] to list("Event" ,""                            ,""                  ,""                   ,"ModuleAnimationGroup"   ,"deploy"          ,"retract"            ,"ModuleScienceExperiment","delete data"      ," "                  ).
          set modulelist[2][ctag] to list(" "     ,""                            ," RUN"               ," DELETED"           ,""                        ,"DEPLOYED"        ,"RETRACTED"          ,""                    ,"DELETED"           ," "                  ).
      } 

      //good5
      if anttag > 0    {local ctag to anttag. set  MeterList[3][ctag] to "ANTENNA".
          local antoff to "off". if rtech = 0 set antoff to "retracted".
          set modulelist[0][ctag] to list("Event" ,"ModuleDeployableAntenna"       ,"extend antenna"    ,"retract antenna"    ,"ModuleAnimateGeneric"    ,"extend antennas" ,"retract antennas"   ,"ModuleDataTransmitter","transmit data"    ,"transmit data").
          set modulelist[1][ctag] to list("Action","ModuleRTAntenna"                 ,"activate"          ,"deactivate"         ,""                        ,""                ,""                   ,""                    ,""                 ,"").
          set modulelist[2][ctag] to list("Status","Status"                          ," EXTENDED"         ," RETRACTED"         ,antoff                    ,""                ,""                   ,""                    ,""                 ,"").
          set  MeterList[1][ctag] to TrimModules(ANTMod:sublist(2,ANTMod:length)).
          set  MeterList[2][ctag] to LIST(
              list(""                                           ,"Set Target","deactivate at ec %","activate at ec %"),
              list("status/target/dish range/omni range/energy" ,"0/0/0/-2"  ,"0/100/1"           ,"0/100/1")).
      }

      //good5
      if Docktag > 0    {local ctag to Docktag.  set  MeterList[3][ctag] to "DOCKING PORT".
          set modulelist[0][ctag] to list("Event" ,"ModuleDockingNode"             ,"undock"            ,"undock"             ,"ModuleAnimateGeneric"    ,"open"              ,"close"              ,"ModuleToggleCrossfeed"    ,"Enable Crossfeed" , "disable crossfeed").
          set modulelist[1][ctag] to list(""      ,"ModuleGrappleNode"             ,"undock"            ,"undock"             ,""                        ,""                  ,""                   ,""                         ,""                 ,"").
          set modulelist[2][ctag] to list(" "     ,"Status"                        ," DECOUPLED"        ," ATTACHED"          ,""                        ," OPENED"           ," CLOSED",""         ,""                         ,"CROSSFEED ENABLED","CROSSFEED DISABLED").
          set MeterList[1][ctag] to TrimModules(listadd(DockMod:sublist(2,DockMod:length),"ModuleAnimateGeneric")).
          Set MeterList[2][ctag] to LIST(
              list(""                                            ,"docking acquire force","rotation locked"), 
              list("status/docking acquire force/rotation locked","0/220/5"               , "false/true/0")).
      }

      //GOOD5
      if CntrlTag > 0 {local ctag to CntrlTag. set  MeterList[3][ctag] to "CONTROL SURFACE".
          set modulelist[0][ctag] to list("Event" ,"ModuleControlSurface"          ,"toggle deploy"     ,"toggle deploy"      ,"ModuleControlSurface"    ,"activate control","deactivate control").
          set modulelist[1][ctag] to list("Action","SyncModuleControlSurface"      ,"toggle deploy"     ,"toggle deploy"      ,"SyncModuleControlSurface","activate control","deactivate control").
          set modulelist[2][ctag] to list("Deploy",""                              ," EXTENDED"         ," RETRACTED"          ,"False"                   ," ENABLED"         ," DISABLED").
          set  MeterList[1][ctag] to TrimModules(CntrlMod:sublist(2,CntrlMod:length)).
          set  MeterList[2][ctag] to  
            LIST(list(""                                                          ,"pitch"             ,"yaw"               ,"roll"              ,"authority limiter"  , "deploy angle"   , "deploy direction" ),
            list("authority limiter/deploy angle/deploy direction/pitch/yaw/roll" , "False/True/0"     , "False/True/0"     , "False/True/0"     ,"-25/25/1"           , "-25/25/1"       , "False/True/0"         ),
            list("Names"                                                          , "Active/Inactive/0", "Active/Inactive/0", "Active/Inactive/0",""                   , ""               , "Normal/Inverted/0"    ),
            list("BotRow/pitch/yaw/roll")).
      }

      //good2
      if ISRUTag > 0    {local ctag to ISRUTag. set  MeterList[3][ctag] to "CONVERTER".
          set modulelist[0][ctag] to list("Action" ,"ModuleISRU"                    ,"start isru "       ,"start isru "        ,"ModuleOverheatDisplay").
          set modulelist[1][ctag] to list(""        ,""                              ,""                  ,""                   ,""                     ).
          set modulelist[2][ctag] to list(" "       ,""                              ," CONVERTING"       ," NOT CONVERTING"    ,"Core Temp"            ).
      }

      //GOOD5
      if CapTag > 0     {local ctag to CapTag. set  MeterList[3][ctag] to "CAPACITOR".
          set modulelist[0][ctag] to list("Action"  ,"DischargeCapacitor"            ,"discharge capacitor","enable recharge"    ,"DischargeCapacitor"     ,"enable recharge" ,"enable recharge"  ,"DischargeCapacitor","disable recharge","disable recharge").
          set modulelist[1][ctag] to list(""        ,""                              ,""                    ,""                 ,""                       ,""                ,""                   ,""                ,""                ,"").
          set modulelist[2][ctag] to list(" "       ,"Status"                        ," DISCHARGING"        ," CHARGING"        ,""                       ," CHARGE ENABLED "," CHARGE ENABLED   ",""                ,"CHARGE DISABLED   ","CHARGE DISABLED   ").
          set  MeterList[1][ctag] to TrimModules(CAPMod:sublist(2,CAPMod:length)).
          set  MeterList[2][ctag] to LIST(
              list(""                     ,"discharge rate"), 
              list("status/discharge rate","40/80/1"        ),
              list("FuelLeft"             ,"Stored Charge"  )).
      }

      //GOOD5
      if Radartag > 0    {local ctag to Radartag. set MeterList[3][ctag] to "RADAR".
          set modulelist[0][ctag] to list("Event"  ,"ModuleRadar"                   ,"enable radar"      ,"disable radar"      ,""              ,""                ,""                   ,""             ,""         ,""         ).
          set modulelist[1][ctag] to list("Action" ,""                              ,""                  ,""                   ,"ModuleRadar"   ,"target PREV"    ,"target PREV"         ,"ModuleRadar"  ,"target next" ,"target next"         ).
          set modulelist[2][ctag] to list(" "      ,"current locks"                 ," RADAR ON"         ," RADAR OFF"         ,""              ," PREVIOUS TARGET"," PREVIOUS TARGET"   ,""             ," NEXT TARGET"," NEXT TARGET"         ).
          set  MeterList[1][ctag] to TrimModules(RadarMod:sublist(2,RadarMod:length)).
          set  MeterList[2][ctag] to LIST(
              list(""                     ),
              list("current locks")).
      }

      //good5
      if Inttag > 0     {local ctag to Inttag. set MeterList[3][ctag] to "INTAKE".
          set modulelist[0][ctag] to list("Action" ,"ModuleResourceIntake"          ,"open intake"       ,"close intake"      ,"ModuleResourceIntake"    ,""                  ,""                   ,"ModuleResourceIntake",""         ,""         ).
          set modulelist[1][ctag] to list(""        ,""                              ,""                  ,""                   ,""                      ,""                  ,""                   ,""                    ,""         ,""         ).
          set modulelist[2][ctag] to list(""        ,"status"                        ,"INTAKE OPENED     ","INTAKE CLOSED    ","closed"                    ,""                  ,""                   ,"effective air speed" ,""         ,""         ).
          set  MeterList[1][ctag] to TrimModules(INTMod:sublist(2,INTMod:length)).
          set  MeterList[2][ctag] to LIST(
              list(""                     ),
              list("status/flow/effective air speed")).
      }

      //GOOD3
      if FWtag > 0      {local ctag to FWtag. set MeterList[3][ctag] to "FIREWORK".
          set modulelist[0][ctag] to list("Event" ,"ModulePartFirework"             ,"Launch"            ,"Launch"  ).
          set modulelist[1][ctag] to list(""      ,""                              ,""                  ,""        ).
          set modulelist[2][ctag] to list(" "     ,""                              ,"LAUNCHED"          ,"LAUNCHED").
      }

      //good5
      if RBTTag > 0      {local ctag to RBTTag. set MeterList[3][ctag] to "ROBOTIC PART".
          set modulelist[0][ctag] to list("ACTION","ModuleRoboticServoPiston"      ,"toggle piston"     ,""                    ,"ModuleRoboticServoPiston","toggle locked"           ,""                   ).
          set modulelist[1][ctag] to list(""       ,""                              ,""                  ,""                    ,""                        ,""                        ,""                   ).
          set modulelist[2][ctag] to list(" "      ,"current extension"             ,"MOVING"            ,"MOVING"              ,"locked"                  ,"LOCK TOGGLED   "         ,"LOCK TOGGLED       ").
          set  MeterList[1][ctag] to TrimModules(listadd(RBTMod:sublist(2,RBTMod:length),"ModuleResourceAutoShiftState")).
          set MeterList[2][ctag] to list(5).
          for md in rbtMod{
            if ship:modulesnamed(md):length > 0{
              if md = "ModuleRoboticServoPiston"{
                  MeterList[2][RBTtag]:add(list(
                  list("ModuleRoboticServoPiston/ModuleResourceAutoShiftState","force limit(%)"   , "target extension",  "traverse rate" , "damping" , "locked"     , "motor"              , "on power loss"   , "use percentage"    ,"shutdown electric charge%", "restart electric charge%" ),
                  list("current extension/locked/target extension/motor"      ,"0/100/1"          , "0.00/5/.05"      ,  "0.0/2/0.1"     , "0/200/5" ,"False/True/0","False/True/0"        ,"False/True/0"     ,"False/True/0"       ,"0.0/100/0.5"              ,"0.0/100/.05"     ),
                  list("Names"                                                ,""                 ,""                 ,""                ,""         ,"No/Yes/0"    ,"Disengaged/Engaged/0","Free/Locked/0"    ,"Disabled/Enabled/0" ,""                         ,""              ))).
              }else{
              if md = "ModuleRoboticServoRotor"{
                  MeterList[2][RBTtag]:add(list(
                  list("ModuleRoboticServoRotor/ModuleResourceAutoShiftState" ,"torque limit(%)"  , "rpm limit"       ,"rotation direction"           , "invert direction" , "brake"  , "locked"     , "motor"              , "on power loss"   , "use percentage"    ,"shutdown electric charge%", "restart electric charge%" ),
                  list("current rpm/locked/rpm limit/motor/rotation direction" ,"0/100/1"         , "0/460/5"         ,"False/True/0"                 , "False/True/0"     , "0/200/5","False/True/0","False/True/0"        ,"False/True/0"     ,"False/True/0"       ,"0.0/100/0.5"              ,"0.0/100/.05"     ),
                  list("Names"                                                ,""                 ,""                 ,"clockwise/counterclockwise/0" ,"normal/inverted/0" ,""        ,"No/Yes/0"    ,"Disengaged/Engaged/0","Free/Locked/0"    ,"Disabled/Enabled/0" ,""                         ,""              ))).
              }else{
              if md = "ModuleRoboticServoHinge"{
                  MeterList[2][RBTtag]:add(list(
                  list("ModuleRoboticServoHinge/ModuleResourceAutoShiftState","torque limit(%)"   , "target angle"    ,  "traverse rate" , "damping" , "locked"     , "motor"              , "on power loss"   , "use percentage"    ,"shutdown electric charge%", "restart electric charge%" ),
                  list("current angle/locked/target angle/motor"             ,"0/100/1"           , "-180.0/180/5"    ,  "0/180/1"       , "0/200/5" ,"False/True/0","False/True/0"        ,"False/True/0"     ,"False/True/0"       ,"0.0/100/0.5"              ,"0.0/100/.05"     ),
                  list("Names"                                               ,""                  ,""                 ,""                ,""         ,"No/Yes/0"    ,"Disengaged/Engaged/0","Free/Locked/0"    ,"Disabled/Enabled/0" ,""                         ,""              ))).
              }else{
              if md = "ModuleRoboticRotationServo"{
                  MeterList[2][RBTtag]:add(list(
                  list("ModuleRoboticRotationServo/ModuleResourceAutoShiftState" ,"torque limit(%)", "target angle"   , "invert direction" , "brake"  ,  "traverse rate" , "damping" , "locked"     , "motor"              , "on power loss"   , "use percentage"    ,"shutdown electric charge%", "restart electric charge%" ),
                  list("current angle/locked/target angle/motor"                 ,"0/100/1"        , "-180.0/180/5"   , "False/True/0"     , "0/200/5",  "0/180/1"       , "0/200/5" ,"False/True/0","False/True/0"        ,"False/True/0"     ,"False/True/0"       ,"0.0/100/0.5"              ,"0.0/100/.05"     ),
                  list("Names"                                                   ,""               ,""                ,"normal/inverted/0" ,""        ,""                ,""         ,"No/Yes/0"    ,"Disengaged/Engaged/0","Free/Locked/0"    ,"Disabled/Enabled/0" ,""                         ,""              ))).
              }else{
                if md = "ModuleRoboticController"{
                  MeterList[2][RBTtag]:add(list(
                  list("ModuleRoboticController/ModuleResourceAutoShiftState"                   ,"play position", "play speed"       ,"enabled"     , "play/pause"        ,"play direction"   , "loop mode"                             ,"controller priority"),
                  list("sequence/play position/play\pause/play speed/loop mode\play direction"  ,"0.0/5/0.1"    , "0/100/1"          ,"False/True/0", "0/1/-1"            ,"0/1/-1"           , "0/1/2/3/-1"                            ,"1/5/1"              ),
                  list("Names"                                                                  , ""            ,""                  , ""           , "playing/paused/-1" ,"foward/reverse/-1", "None/Repeat/Ping Pong/None-Restart/-1" ,""                   ))).
                }
              }}}}}}
      }

      //Good5
      if SMRTtag > 0   {local ctag to SMRTtag. set MeterList[3][ctag] to "SMART PART".
          set modulelist[0][ctag] to list("Action"      ,"Stager"                     ,"activate detection" ,"deactivate detection",""     ,""                     ,""                   ,""      ,""      ,""     ).
          set modulelist[1][ctag] to list("Action"      ,"Timer"                      ,"Start countdown"   ,""                     ,"Timer", "Use Minutes"         , "Use Seconds"       , "Timer", "Reset", "Reset"    ). 
          set modulelist[2][ctag] to list("Active"      ,""                           ," TURNED ON "       ," TURNED OFF "        ,"False", " SWITCHED TO SECONDS","SWITCHED TO MINUTES",""      ," RESET", " RESET").
                  set MeterList[1][ctag] to TrimModules(SMRTMod:sublist(2,SMRTMod:length)).
                  set MeterList[2][ctag] to list(8).
                  local groupops to "0/1/2/3/4/5/6/7/8/9/10/11/12/13/14/15/16/-1".
                  if agx <> 0{
                    set groupops to "stage/Action Group(AGX)/NoAct/NoAct/NoAct/NoAct/NoAct/NoAct/NoAct/NoAct/NoAct/lights/RCS/SAS/BRAKES/ABORT/GEAR/-1".
                  }
                  for md in SMRTMod{
                    if ship:modulesnamed(md):length > 0{
                      if md = "stager"{
                          MeterList[2][ctag]:add(list(
                          list("Stager"                              ,"percentage", "Group"                                      , "Group:" ,"Active"      ),
                          list("active/resource/trigger when/monitor","0/100/1"   , "0/1/2/3/4/5/6/7/8/9/10/11/12/13/14/15/16/-1", "0/250/1","False/True/0"),
                          list("Names"                               ,""          , groupops                                     ,""        ,""            ))).
                      }else{
                        if md = "Altimeter"{ MeterList[2][ctag]:add(list(
                          list("Altimeter"        ,"kilometers","meters"   , "Group"                                      , "Group:" , "use agl"     , "auto reset"  ,"Trigger on"           ,"Active"      ),
                          list("active/trigger on","0/1000/25" ,"0/1000/25", "0/1/2/3/4/5/6/7/8/9/10/11/12/13/14/15/16/-1", "0/250/1", "false/True/0", "false/True/0","All/Ascent/Descent/-1","False/True/0"),
                          list("Names"            ,""          ,""         , groupops                                     ,""       ,""              ,""             ,""                     ,""            ))).
                      }else{
                        if md = "SmartOrbit"{ MeterList[2][ctag]:add(list(
                          list("SmartOrbit"       ,"kilometers"  ,"meters"   , "Group"                                      , "Group:", "auto reset"  ,"Trigger on"                   ,"Active"      ),
                          list("active/trigger on","0/1000/25"   ,"0/1000/25", "0/1/2/3/4/5/6/7/8/9/10/11/12/13/14/15/16/-1", "0/250/1", "false/True/0","All/Decreasing/Increasing/-1","False/True/0"),
                          list("Names"            ,""            ,""         , groupops                                     ,""        ,""             ,""                            ,""            ))).
                      }else{
                          if md = "SmartSRB"{ MeterList[2][ctag]:add(list(
                          list("SmartSRB"       ,"srb twr %"  , "Group"                                         , "Group:"),
                          list("srb twr %"        ,"100/150/5"   , "0/1/2/3/4/5/6/7/8/9/10/11/12/13/14/15/16/-1", "0/250/1"),
                          list("Names"            ,""            , groupops                                     ,""))).
                      }else{
                        if md = "ProxSensor"{ MeterList[2][ctag]:add(list(
                          list("ProxSensor"                        ,"channel"  ,"distance" , "Group"                                      , "Group:", "auto reset"   ,"Trigger on"                ,"Active"      ),
                          list("active/channel/distance/trigger on","0/20/1"   ,"0/2000/25", "0/1/2/3/4/5/6/7/8/9/10/11/12/13/14/15/16/-1", "0/250/1", "false/True/0","Both/Departure/Approach/-1","False/True/0"),
                          list("Names"                             ,""         ,""         , groupops                                     ,""        ,""             ,""                          ,""            ))).
                        }else{
                        if md = "Timer"{ MeterList[2][ctag]:add(list(
                          list("Timer"                                ,"seconds","minutes"  , "Group"                                      , "Group:", "auto reset"  ,"Trigger on"                 ,"Active"      ),
                          list("Active/remaining time/seconds/minutes","0/120/1","0/360/1"  , "0/1/2/3/4/5/6/7/8/9/10/11/12/13/14/15/16/-1", "0/250/1", "false/True/0","Both/Departure/Approach/-1","False/True/0"),
                          list("Names"                                ,""       ,""         , groupops                                     ,""        ,""             ,""                          ,""            ))).
                        }else{
                        if md = "Speedometer"{ MeterList[2][ctag]:add(list(
                          list("Speedometer"       ,"speed"   ,"speed mode"                           , "Group"                                      , "Group:", "auto reset"  ,"Trigger on"                   ,"Active"      ),
                          list("active/trigger on","0/1000/5","surface/horizontal/vertical/orbital/-1", "0/1/2/3/4/5/6/7/8/9/10/11/12/13/14/15/16/-1", "0/250/1", "false/True/0","All/Decreasing/Increasing/-1","False/True/0"),
                          list("Names"            ,""        ,""                                      , groupops                                     ,""        ,""             ,""                            ,""            ))).
                        }else{
                        if md = "DPLD"{ MeterList[2][ctag]:add(list(
                          list("DPLD"             , "Group"                                      , "Group:", "auto reset"  ,"Trigger on"                         ,"Active"      ),
                          list("active/trigger on", "0/1/2/3/4/5/6/7/8/9/10/11/12/13/14/15/16/-1", "0/250/1", "false/True/0","KSC Loss/Total Loss/Initialized/-1","False/True/0"),
                          list("Names"            , groupops                                     ,""        ,""             ,""                                  ,""            ))).
                      }else{
                        }}}}}}}}
                    }
                  }
      } 
        //GOOD5 
      if rwtag > 0      {local ctag to rwtag. set MeterList[3][ctag] to "REACTION WHEEL".
          set modulelist[0][ctag] to list("Action" ,"ModuleReactionWheel"           ,"activate wheel"  ,"activate wheel"     ,"ModuleReactionWheel"     ,"deactivate wheel","deactivate wheel").
          set modulelist[1][ctag] to list(""       ,""                              ,""                  ,""                 ,""                        ,""                ,""                ).
          set modulelist[2][ctag] to list(" "      ,""                              ," ENABLED          "," ENABLED          ",""                       ," DISABLED"       ,"DISABLED"        ).
          set  MeterList[1][ctag] to TrimModules(rwMod:sublist(2,rwMod:length)).
          set  MeterList[2][ctag] to LIST(
              list(""                               ,"reaction wheels"              , "wheel authority"),
              list("reaction wheels/wheel authority","0/1/2/-1"                     , "0/100/5"        ),
              list("Names"                          ,"normal/SAS Only/Pilot Only/-1","")).
      }

      //GOOD5
      if RCStag > 0    {local ctag to RCStag. set MeterList[3][ctag] to "RCS".
          set modulelist[0][ctag] to list("Action"    ,"ModuleRCSFX"                ,"toggle rcs thrust" ,"toggle rcs thrust").
          set modulelist[1][ctag] to list(""       ,""                           ,""                     ,""                 ).
          set modulelist[2][ctag] to list("RCS"    ,""                           ," RCS ON"              ," RCS OFF","False"            ).
          set MeterList[1][ctag] to TrimModules(RCSMod:sublist(2,RCSMod:length)).
          set MeterList[2][ctag] to  LIST(
            list(""                                                 ,"thrust limiter" ,"pitch"             ,"yaw"               ,"roll"              ,"fore/aft"          ,"port/stbd"         ,"dorsal/ventral"    ,"fore by throttle"  ,"always full action"             ),
            list("pitch/yaw/roll/fore\aft/port\stbd/dorsal\ventral" ,"0/100/1"        , "False/True/0"     , "False/True/0"     , "False/True/0"     , "False/True/0"     , "False/True/0"     , "False/True/0"     , "False/True/0"     , "False/True/0"     ),
            list("Names"                                            ,""               , "Inactive/Active/0", "Inactive/Active/0", "Inactive/Active/0", "Inactive/Active/0", "Inactive/Active/0", "Inactive/Active/0", "Inactive/Active/0", "Inactive/Active/0"),
            list("BotRow/pitch/yaw/roll"),
            list("BotRow5/fore\aft/port\stbd/dorsal\ventral")
            ).
      }

      //good5
      if Labtag > 0 {local ctag to Labtag. set MeterList[3][ctag] to "LAB".
          set modulelist[0][ctag] to list("Action"  ,"ModuleScienceConverter" ,"START RESEARCH"   ,"STOP RESEARCH"     ,"ModuleScienceLab","transmit science"  ,"transmit science","ModuleScienceContainer","collect all","collect all"  ). 
          set modulelist[1][ctag] to list("").
          set modulelist[2][ctag] to list("research","inactive"               ," RESEARCH STARTED"," RESEARCH STOPPED" ,"inactive"        ," XMITTING SCIENCE "," XMITTING SCIENCE ",""                     ," SCIENCE COLLECTED" ," SCIENCE COLLECTED").
          set  MeterList[1][ctag] to TrimModules(LabMod:sublist(2,LabMod:length)).
          set  MeterList[1][ctag] to TrimModules(listadd( LabMod:sublist(2,LabMod:length),list("ModuleScienceContainer"))).
          set  MeterList[2][ctag] to LIST(
              list(""                               ), 
              list("lab status/data/rate/research/science")).
      }

      //good5
      if CMtag > 0 {local ctag to CMtag. set MeterList[3][ctag] to "COUNTERMEASURE". 
          set modulelist[0][ctag] to list("EVENT"     ,"CMDropper"                   ,"fire countermeasure","fire countermeasure").
          set modulelist[1][ctag] to list(""       ,""                            ,""                      ,""                   ).
          set modulelist[2][ctag] to list(" "      ,""                            ," COUNTERMEASURE OUT"   ," COUNTERMEASURE OUT").
          set  MeterList[1][ctag] to TrimModules(CmMod:sublist(2,CmMod:length)).
          set  MeterList[2][ctag] to LIST(
              list(""        ), 
              list(""        ),////
              list("FuelLeft","auto/EMPTY/READY"  )).
      }

      //good2
      if FRNGtag > 0 {local ctag to FRNGtag. set MeterList[3][ctag] to "FAIRING".
          set modulelist[0][ctag] to list("EVENT"     ,"ModuleProceduralFairing"    ,"deploy"              ,"").
          set modulelist[1][ctag] to list(""       ,""                            ,""                      ,""      ).
          set modulelist[2][ctag] to list(" "      ,""                            ,"DEPLOYED"                 ," READY",""      ).
      }

      //GOOD5
      if WMGRtag > 0 {local ctag to WMGRtag.  set MeterList[3][ctag] to "WEAPON MANAGER".
          set modulelist[0][ctag] to list("Action"   ,"MissileFire"                 ,"fire guns (hold)","fire guns (hold)"     ,"MissileFire"             ,"toggle guard mode" ,"toggle guard mode" ,"CMDropper" ,"fire countermeasure","fire countermeasure").
          set modulelist[1][ctag] to list(""       ,""                            ,""                  ,""                     ,""                        ,""                  ,""                  ,""          ,""                   ,""           ).
          set modulelist[2][ctag] to list(" "      ,"weapon"                      ," FIRING"           ," DISABLED"            ,"Team"                    ," GUARD TOGGLED"    ," GUARD TOGGLED"    ,""          ," COUNTERMEASURE OUT"," COUNTERMEASURE OUT").
          set MeterList[1][ctag] to TrimModules(WMGRMod:sublist(2,WMGRMod:length)).
          set MeterList[2][ctag] to  LIST(
            list(""                           , "Weapon"  ,"missiles/target"),
            list("weapon/team/missiles\target", "0/0/0/-2","1/18/1"         )).
      }

      //good5
      if BDPtag > 0 {local ctag to BDPtag. Set MeterList[3][ctag] to "AI PILOT ".
      LOCAL DSP TO "default alt./min altitude/max speed/mincombatspeed/max g/max aoa".
          set modulelist[0][ctag] to list("Event"  ,"BDModulePilotAI"           ,"activate pilot"     ,"deactivate pilot"     ,"BDModulePilotAI"         ).
          set modulelist[1][ctag] to list(""       ,""                          ,""                   ,""                     ,""                        ).
          set modulelist[2][ctag] to list(" "      ,""                          ," ACTIVATED"         ," DEACTIVATED"         ,""                        ).
          set  MeterList[1][ctag] to TrimModules(BDPMod:sublist(2,BDPMod:length)).
          set  MeterList[2][ctag] to LIST(
            list(""        ,"default alt." ,"min altitude" ,"steer factor"  ,"steer ki"   ,"STEER LIMITER","steer damping"  ,"max speed" ,"takeoff speed" ,"mincombatspeed" ,"idle speed" ,"max g"     ,"max aoa" ,"orbit "               ,"unclamp tuning "      ,"standby mode "),
            list(DSP       ,"500/15000/50" ,"150/6000/50"  ,"0.05/1/.05"    ,"0.05/1/.05" ,"0.05/1/.05"   ,"1/8/.5"         ,"20/800/10" ,"10/200/5"      ,"20/200/5"       ,"10/200/5"   ,"2/45/.25"  ,"0/85/.5" , "False/True/0"        , "False/True/0"        , "False/True/0"),
            list("AltVal/1","500/100000/50","150/30000/50" ,"0.05/200/.05"  ,"0.05/20/.05","0.05/1/.05"   ,"1/100/.5"       ,"20/3000/10","10/2000/5"     ,"20/2000/5"      ,"10/3000/5"  ,"2/1000/.25","0/180/.5", "False/True/0"        , "False/True/0"        , "False/True/0"), 
            list("Names"   ,""             , ""            , ""             , ""          , ""            , ""              , ""         , ""             , ""              , ""          , ""         , ""       , "port(CCW)/stbd(CW)/0", "clamped/unclamped/0" , "off/on/0"    ),
            list("STATE-Land/min altitude/takeoff speed/idle speed/mincombatspeed/max g/max aoa")
            ).      
      }
      //if mks = 1{//needs 5
      //good3
      if MksDrlTag > 0 {local ctag to MksDrlTag. Set MeterList[3][ctag] to "MKS DRILL". 
          set modulelist[0][ctag] to list("Event"  ,"ModuleAnimationGroup"       ,"deploy"           ,"retract"               ,"usi_harvester"           ,"togle converter"  ,"toggle converter"  ,"mksmodule"    ,""         ,""         ,"ModuleOverheatDisplay" ,""         ,""         ).
          set modulelist[1][ctag] to list(""       ,""                           ,""                 ,""                      ,""                        ,""                 ,""                  ,""             ,""         ,""         ,""                      ,""         ,""         ).
          set modulelist[2][ctag] to list(" "      ,""                           ," DEPLOYED"        ," RETRACTED",""                        ,""                 ,""                  ,"governor"     ,""         ,""         ,"Core Temp"             ,""         ,""         ).
          set  MeterList[1][ctag] to TrimModules(listadd(MksDrlMod:sublist(2,MksDrlMod:length),list("ModuleOverheatDisplay","ModuleAnimationGroup"))).
        //  set  MeterList[2][ctag] to LIST(
        //      list(""                     ),
        //      list(       "ore rate/core temp/thermal efficiency"),
        //      list("Style/         /Mp-0-0   /Mp-0-100   ")).
      }

      //good2                    
      if DEPOtag > 0 {local ctag to DEPOtag. Set MeterList[3][ctag] to "DEPO".
          set modulelist[0][ctag] to list("Event"  ,"Wolf_Depotmodule"           ,"establish depot"  ,""                      ).
          set modulelist[1][ctag] to list(""       ,""                           ,""                 ,""                      ).
          set modulelist[2][ctag] to list(" "      ,"wolf biome"                 ," DEPOT ESTABLISHED"," DEACTIVATED         ").
          set  MeterList[1][ctag] to TrimModules(DEPOMod:sublist(2,DEPOMod:length)).
      }

      //good2
      if habtag > 0 {local ctag to habtag. Set MeterList[3][ctag] to "HABITAT".
          set modulelist[0][ctag] to list("Event"   ,"USIAnimation"               ,"toggle module"    ,"toggle module"         ,"USI_BasicDeployableModule",""                 ,""                  ,""             ,""         ,""         ).
          set modulelist[1][ctag] to list(""       ,"USI_BasicDeployableModule"  ,"deposit resources","deposit resources"     ,""                         ,""                 ,""                  ,""             ,""         ,""         ).
          set modulelist[2][ctag] to list(" "      ,""                           ,"TOGGLED"          ,"TOGGLED "              ,"paid"                     ,""                 ,""                  ,""             ,""         ,""         ).
          set  MeterList[1][ctag] to TrimModules(HABMod:sublist(2,HABMod:length)).
      }

      //good2
      if CnstTag > 0 {local ctag to CnstTag. Set MeterList[3][ctag] to "KONSTRUCTOR".
          set modulelist[0][ctag] to list("Event"   ,"OrbitalKonstructorModule"  ,"open konstructor" ,"open konstructor"      ,"ModuleKonFabricator"     ,"konfabricator"    ,"konfabricator"     ,"ModuleKonstructionForeman","enable konstruction","enable konstruction").
          set modulelist[1][ctag] to list(""       ,""                           ,""              ,""                         ,""                        ,""                 ,""                  ,""                         ,""                   ,""         ).
          set modulelist[2][ctag] to list(" "      ,""                           ,"TOGGLED"       ,"TOGGLED"                  ,""                        ,""                 ,""                  ,""                         ,""                   ,""         ).
          set  MeterList[1][ctag] to TrimModules(CnstMod:sublist(2,CnstMod:length)).
      } 

      //good2
      if DcnstTag > 0 {local ctag to DcnstTag. Set MeterList[3][ctag] to "DECONSTRUCTOR".
          set modulelist[0][ctag] to list("Event"   ,"ModuleDekonstructor"      ,"dekonstructor"    ,"dekonstructor").
          set modulelist[1][ctag] to list(""       ,""                           ,""              ,""                ).
          set modulelist[2][ctag] to list(" "      ,""                           ,"       "       ,"        "        ).
          set  MeterList[1][ctag] to TrimModules(DcnstMod:sublist(2,DcnstMod:length)).
      }

      //good2
      if PWRtag > 0 {local ctag to PWRtag. Set MeterList[3][ctag] to "CONVERTER".
          set modulelist[0][ctag] to list("Event"   ,"usi_converter"              ,"start reactor"     ,"stop reactor"         ,"ModuleOverheatDisplay"    ,""                 ,""                 ,"mksmodule"  ,""         ,""         ).
          set modulelist[1][ctag] to list(""        ,""                           ,""                  ,""                     ,""                         ,""                 ,""                 ,""            ,""           ,""         ).
          set modulelist[2][ctag] to list(" "       ,""                           ," STARTED"          ," STOPPPED"            ,"Core Temp"                ," "                ,""                 ,"governor"    ,""           ,""         ).
          set  MeterList[1][ctag] to TrimModules(PWRMod:sublist(2,PWRMod:length)).
      }

      //good2                                                           
      if ACDtag > 0 {local ctag to ACDtag. Set MeterList[3][ctag] to "ACADEMY".
          set modulelist[0][ctag] to list("Event"   ,"spaceacademy"               ,"conduct training"  ,"conduct training"    ,"ModuleExperienceManagement","level up crew"    ,"level up crew").
          set modulelist[1][ctag] to list(""       ,""                           ,""                  ,""                    ,""                          ,""                 ,""             ).
          set modulelist[2][ctag] to list(" "      ,""                           ,"             "     ,"             "       ,""                          ," "                ,""             ).
          set  MeterList[1][ctag] to TrimModules(listadd(ACDMod:sublist(2,ACDMod:length),list("ModuleExperienceManagement"))).
      }
      //}
      //good5
      if AGtag > 0 {local ctag to AGtag. set MeterList[3][ctag] to "ACTION GROUP".
          set modulelist[0][ctag] to list("AG"     ,"AG"  ,""          ,"").
          set modulelist[1][ctag] to list(""       ,""    ,""          ,""           ).
          set modulelist[2][ctag] to list(" "      ,""    ," TURNED ON"," TURNED OFF").
      }
      //good5
      if Flytag > 0 {local ctag to Flytag. set MeterList[3][ctag] to "FLIGHT CONTROL".
          set modulelist[0][ctag] to list("AG"     ,"AG"                         ,""           ,"").
          set modulelist[1][ctag] to list(""       ,""                           ,""          ,""           ).
          set modulelist[2][ctag] to list(" "      ,""                           ," TURNED ON"," TURNED OFF").
      }
      FOR i IN RANGE(1, ItemList[0]+1) {
        IF modulelist[0][I]:LENGTH < 11 set modulelist[0][I] to FillList(modulelist[0][I], 12).
        IF modulelist[1][I]:LENGTH < 11 set modulelist[1][I] to FillList(modulelist[1][I], 12).
        IF modulelist[2][I]:LENGTH < 11 set modulelist[2][I] to FillList(modulelist[2][I], 12).
      }   
    }
    Function CheckSettings{local loadp to 22. if colorprint > 0{ set loadp to loadp+9. PRINT " " AT (80,LNstp-1).}
    if DbgLog > 0 log2file("CHECK SETTINGS" ).
    local CHECKPRT TO 0.
      for I in Range(1,ItemList[0]+1){
        set loadp to loadp+1. print "." at (loadp,LNstp-1).
        for j in Range(1,prtTagList[I][0]+1){
          LOCAL L TO 1.
          if i = agtag or i = flytag or (i = CMDTag and j > cmdln) break.
          //if i = CMDTag and j > cmdln break. 
          for k in range (1,4){IF K = 4 BREAK.
            local ModSt to CheckModule(i,j,k,L).
            if ModSt <> " "{
              if modst = "Bad Part" break.
              if k = 1 set GrpDspList[I][J] to ModSt.
              if k = 2 set GrpDspList2[I][J] to ModSt.
              if k = 3 set GrpDspList3[I][J] to ModSt.
            }
            SET L TO 0.
          }
        }
      }
    }
    function CheckModule {
      local parameter Inum, tagnum, optn is 1, L IS 0.
          function SetTrgVars2{
            local parameter inlst,fldin is 0, evactin is 0.
            if DbgLog > 2 log2file("     SETTRGVARS2-MODULE:"+INLST[0]+" EVENT1ON:"+inlst[1]+" EVENT1OFF:"+inlst[2]).
            if evactin = 0 set ea1 to inlst[4].
              if inlst[0] <> "" and inlst[0] <> module2 set module1 to inlst[0]. 
              if inlst[1] <> "" and inlst[1] <> Event2On  set Event1On  to inlst[1].
              if inlst[2] <> "" and inlst[2] <> Event2Off set Event1Off to inlst[2]. 
            if fldin > -1{
              if fldin = 0 set fld to " ". else set fld to fldin.
            }
          }
          function clearev2{
            local parameter op is 0.
            if dbglog > 2 log2file("        CLEAREV2").
            if op = 0 {
              set event1on to "". set event1off to "". set module1 to "".
              set event2on to "". set event2off to "". set module2 to "".
            }else{
              set Event1Off to event1on. set fld to " ".
              if op = 1 {set Event1Off to "". set Event2Off to "".}
              if op = 2 {set Event1On  to "". set Event2On  to "".}
            }
          }
      local MDL to modulelist[0][inum].
      local MDL2 to modulelist[1][inum].
      local MDL3 to modulelist[2][inum].
      local opset to 0.
      local optn3 to optn*3.
      local optn2 to optn3-1.
      local optn1 to optn3-2.
      local CMans to " ".
      local Module1 to MDL[optn1].
      local Module2 to MDL2[optn1].
      local Event1On to MDL[optn2].
      local Event1Off to MDL[optn3].
      local Event2On to MDL2[optn2].
      local Event2Off to MDL2[optn3].
      local modov to "".
      if Event1On+Event1Off+Event2On+Event2Off <> ""{
        if DbgLog > 0{ 
          log2file("   CHECK MODULE-"+ITEMLIST[Inum]+"("+Inum+")"+PRTTAGLIST[Inum][tagnum]+"("+tagnum+")-"+optn ).
          IF dbglog > 2{
            log2file("     modulesPri:-"+LISTTOSTRING(MDL) ).
            log2file("     modulesAlt:-"+LISTTOSTRING(MDL2) ).
            log2file("     Report Val:-"+LISTTOSTRING(MDL3) ).
          }
        }
      if MeterList[1][inum][0] <> 0 set modov to TrimModules2(MeterList[1][inum],inum,tagnum).
          if inum = AGTag {set opset to 1.
            if tagnum = 1  and ag1  = True {set opset to 2.}else{
            if tagnum = 2  and ag2  = True {set opset to 2.}else{
            if tagnum = 3  and ag3  = True {set opset to 2.}else{
            if tagnum = 4  and ag4  = True {set opset to 2.}else{
            if tagnum = 5  and ag5  = True {set opset to 2.}else{
            if tagnum = 6  and ag6  = True {set opset to 2.}else{
            if tagnum = 7  and ag7  = True {set opset to 2.}else{
            if tagnum = 8  and ag8  = True {set opset to 2.}else{
            if tagnum = 9  and ag9  = True {set opset to 2.}else{
            if tagnum = 10 and ag10 = True {set opset to 2.}else{
            if tagnum = 11 and THROTTLE > 0 {set opset to 2.}else{
            if tagnum = 12 and RCS = True {set opset to 2.}else{
            if tagnum = 13 and ABORT = True {set opset to 2.}else{
            if tagnum = 14 and GEAR = True {set opset to 2.}else{
            if tagnum = 15 and LIGHTS = True {set opset to 2.}ELSE{
            if tagnum = 16 and BRAKES = True {set opset to 2.}
            }}}}}}}}}}}}}}}
          }
          else{
          if inum = FlyTag {
            set opset to 1.
            IF tagnum = 1 {if steeringmanager:enabled = TRUE set OPSET to 2.}
            ELSE{
              if sasmode =  Removespecial(prtTagList[Flytag][tagnum]," ") and SAS = true {set opset to 2. set StrLock to tagnum.}
            }
          }
          else{
        local pl to prtList[inum][tagnum].
        set pl to pl:sublist(1, pl:length).
        local Pnum to "".
        IF L = 1 {set Pnum to getgoodpart(inum,tagnum,2). SET CHECKPRT TO prtlist[inum][tagnum][pnum].}
        if pnum = 0 {if dbglog > 0 log2file("     NO GOOD PART"). return "Bad Part".}
        local p to CHECKPRT.
        local fld to mdl3[0]. 
        local op to mdl3[4]. 
        local ea1 to MDL[0].
        local ea2 to MDL2[0]. 
            if inum = lighttag{
          SET PRFX TO "LIGHT ".
          IF P:hasmodule("modulecommand") or optn > 1 set fld to " ".
          if optn = 1{
            local ccc to              getactions("Actions"+Pnum,MeterList[1][inum],inum, tagnum,optn,1,list("on"),list("off")).
            if  ccc[3] = 0 set ccc to getactions("Actions"+Pnum,MeterList[1][inum],inum, tagnum,optn,5,list("on"),list("off")).
            if  ccc[3] = 0 or ccc[0] = "moduleanimategeneric" {
              set ccc to getactions("Actions"+Pnum,MeterList[1][inum],inum, tagnum,optn,2,list("toggle light"),list("toggle light")).
              if ccc[3] > 0 {set ccc[3] to getactions("OnOff"+Pnum,MeterList[1][inum],inum, tagnum,optn,3,list("on"),list("off")).}
            }
            if  ccc[3] > 0 {
              clearev2().
              SetTrgVars2(CCC,-1).
              if ccc[0] = "moduleanimategeneric" {
                set Event1Off to Event1On. 
                set fld to " ".    
                clearev2(ccc[3]).         
                if ccc[3] = 1 {set Event1Off to "". set Event2Off to "".}
                if ccc[3] = 2 {set Event1On to "". set Event2On to "".}
              }
            }
          }
        }
            else{
            if inum = ENGtag {
              IF optn = 1 {
                clearev2().
                local lon to list("on", "activate").
                local loff to list("off","shutdown").
                local Elst to MeterList[1][inum].
                if p:hasmodule("FSengineBladed"){if getEvAct(p,"FSengineBladed","Status",30,-1,2):contains("inactive") set loff to list(""). else set lon to list("").}
                else{
                    if p:hassuffix("modes") if P:modes:length > 1 if not P:primarymode set Elst to list("MultiModeEngine").
                    if p:hassuffix("ignition"){if p:ignition = false {set loff to list(""). set OPSET to 1.} else {set lon to list(""). set OPSET to 2.}}  
                }
                local ccc to getactions("Actions"+Pnum,Elst,inum,tagnum,optn,3,lon,loff,2).
                if  ccc[3] > 0 SetTrgVars2(CCC,-1).
              }
              IF optn = 3 {
                if p:hasmodule("ModuleGimbal"){set fld to "GIMBAL". set op to False. set ea1 to "Action".set ea2 to "Action".}
                if p:hasmodule("FSswitchEngineThrustTransform"){
                    local ccc to getactions("Actions"+Pnum,list("FSswitchEngineThrustTransform"),inum, tagnum,optn,3,list("reverse"),list("normal"),2).
                    if  ccc[3] > 0 SetTrgVars2(CCC,-1).
                }
              }
            }
            else{
            if inum = geartag{
            IF pl[0]:hasmodule(module2) set fld to " ".
            if getactions("OnOff"+Pnum,AnimModAlt ,inum, tagnum,1,1,list("extend"),list("retract")) <> 0{
              local ccc to getactions("Actions"+Pnum,AnimModAlt,inum, tagnum,optn,1,list("extend"),list("retract")).
              if  ccc[3] > 0 SetTrgVars2(CCC,-1).
            }
            }
            else{
            if inum = PWRTag {
              local fl to "".
              set fl to prtlist[pwrtag][tagnum][1]:getmodule("usi_converter"):allfieldnames[0]. 
              set Event1On to "start"+fl. 
              set Event1Off to "stop"+fl.
            }
            else{
            if inum = dcptag{
              if optn = 1{
              local ct to 0.
                for pt in pl {
                  for md in DcpModAlt{
                    if pt:hasmodule(md){set ct to ct+1.
                      if ct = 1 set module1 to md. 
                      if ct = 2 set module2 to md.
                  }
                }
                }
              }

            }
            else{
            if inum = CNTRLtag {
              if  p:hasmodule("ModuleAeroSurface")set module1 to "ModuleAeroSurface".
            }
            else{
            if inum = Docktag {
              if optn = 1 if p:hassuffix("HASPARTNER") IF p:HASPARTNER = TRUE RETURN 2. ELSE RETURN 1.
              if optn = 2 if p:hassuffix("STATE") IF p:STATE ="DISABLED" RETURN 3.
            }ELSE{
            if mks = 1 {
              if inum = MksDrlTag {
                local ccc to getactions("Actions"+Pnum,list("usi_harvester"),inum, tagnum, optn, 0,list("start","activate"),list("stop","deactivate"),2).
                clearev2().
                if  ccc[3] > 0 SetTrgVars2(CCC,-1).
                }
            }
          }}}}}}}
            if modov = "" set modsout to list(module1,module2). else set modsout to modov.
            if fld <>" "{ 
              local ddd to getactions("Actions"+Pnum,modsout,inum, tagnum,optn,4,list(fld),list("zzz"),2).
              set opset to ddd[3].
              set module1 to ddd[0]. 
              set module2 to "".
              set fld to ddd[1]. 
              LOCAL FldVal to ddd[2]. 
              if FldVal = op set opset to 1. else set opset to 2. 
              if modov = "" set modsout to list(module1,module2).
            }
                else{
                if opset = 0 {if ea1 = "Event" or ea2 = "Event"   set opset to getactions("OnOff"+Pnum,modsout,inum, tagnum,optn,1,list(Event1On,Event2On),list(Event1Off,Event2Off),2).}
                if opset = 0 {if ea1 = "Action" or ea2 = "Action" set opset to getactions("OnOff"+Pnum,modsout,inum, tagnum,optn,2,list(Event1On,Event2On),list(Event1Off,Event2Off),2).}
                if opset = 0 {                                    set opset to getactions("OnOff"+Pnum,modsout,inum, tagnum,optn,3,list(Event1On,Event2On),list(Event1Off,Event2Off),2).}
                  }}}
                  if opset = 1 {
                    if optn =1  SET CMans TO 1.
                    IF optn =2  SET CMans TO 3.
                    IF optn =3  SET CMans TO 5.
                    SET ANS2 TO "OFF".
                  }
                  if opset = 2 {                  
                    if optn =1  SET CMans TO 2.
                    IF optn =2  SET CMans TO 4.
                    IF optn =3  SET CMans TO 6.
                    SET ANS2 TO "ON".
                  }
                  IF dbglog > 2{
                    log2file("      "+"Module1:"+ MDL[optn1]+" Module2:"+ MDL2[optn1] ).
                    log2file("      "+" Event2On:"+ MDL2[optn2]+" Event2Off:"+ MDL2[optn3]).
                    log2file("      "+" Event1On:"+ MDL[optn2]+" Event1Off:"+ MDL[optn3]).
                  if DbgLog > 1 AND CMANS:TYPENAME <> "STRING" log2file("      "+mdl3[CMans]+"("+ANS2+")").
                }
      
    }  
                return CMans.
      }
  }
function printrow{
      local parameter var, wt is 2.
      set lns to floor((var:length/(widthlim-2))+1).
      if  LNstp = 8 or LNstp = 7 {
        print "                                        " at (20,8). 
        print "                                        " at (20,9). 
        print "                                        " at (20,10). 
      }
      if LNstp = 14 or LNstp+lns > 14 {
      if wt = 0 return 1. else print "More in "+wt+" seconds..." at (1,LNstp). 
      if (FASTBOOT = 0 AND loadattempts < 3) or wt <> 2 wait wt. 
      if wt = 2{
      for z in range(1,LNstp+1) print "|"+Bigempty2+"|" at(0,z). 
      set LNstp to 1.
      }
      }
      print var at (1,LNstp).
      if DbgLog > 0 log2file("   PRINTROW:"+var ).
      set LNstp to LNstp+lns.
      return 0.
    }
function ISRUcheck{
      if colorprint > 0 PRINT " " AT (80,LNstp-1).
      if DbgLog > 2 log2file("   ISRUcheck and settings lists" ).
      if ISRUTag <> 0 {
      set isruoptlst to list().
      local pt to prtList[ISRUTag][1][1].
          for mdls in pt:modules {
            local t to pt:getmodule(mdls):allfieldnames.
            if t:length > 0 if not isruoptlst:contains(t[0]) isruoptlst:ADD(t[0]).
          }
      isruoptlst:insert(0, isruoptlst:length).}
        if PWRTag <> 0 set mks to 1.
        if HABTag <> 0 set mks to 1.
        if DEPOTag <> 0 set mks to 1.
        if MksDrlTag <> 0 set mks to 1.

        //set Control Surface Limits
        if CntrlTag > 0 {
          if DbgLog > 1 log2file("      setting Control Surface Limits" ).
          local ladd to list(0).
          for i in range(0,CntrlFldList:length) ladd:add(0).
          global CNTRLLimLst to list(ladd:copy).
          for t in range(1,prtTagList[CntrlTag][0]+1){
            if DbgLog > 1 log2file("            TAG:"+prttaglist[cntrltag][t]+"("+t+")").
            CNTRLLimLst:add(ladd:copy).
            for m in MeterList[1][CntrlTag] {
              local p to prtlist[CntrlTag][t][getgoodpart(CntrlTag,t)].
              if p:hasmodule(m){
              if DbgLog > 1 log2file("              MOD:"+m+":"+p).
                local act to 0.
                local cnt to 0.
                for fld in CntrlFldList{
                  if DbgLog > 1 log2file("                FIELD:"+fld ).
                  set CNTRLLimLst[t][0] to round(getEvAct(p,M,FLD,30,-1,3),0).
                  if DbgLog > 1 log2file("                    INIT("+prttaglist[CntrlTag][T]+")set to :"+CNTRLLimLst[t][0]).
                  set cnt to cnt+1.
                  local trg to 0.
                for k in range (0,200){
                set trg to trg+50.
                  set act to ceiling(getEvAct(p,M,FLD,40,trg,3),0).
                    if trg > act {
                      set CNTRLLimLst[t][cnt] to act. 
                      getEvAct(p,M,FLD,40,CNTRLLimLst[t][0],3).
                      if DbgLog > 1 log2file("                    MAX("+prttaglist[CntrlTag][T]+")set to :"+CNTRLLimLst[t][cnt]).
                      break.
                    }
                  }
                }
              }
            }
          }
        }
      //set DCP PARTS
      global DcpXtraMod to list().
      for itm in list(MeterList[1][ENGTag],MeterList[1][Chutetag],MeterList[1][CntrlTag]){
       if itm:istype("list") for itm2 in itm{DcpXtraMod:add(itm2).}
      }
      local rscl to getRSCList(ship:resources,2).
      global rsclist to rscl[0].
      global RscNum to rscl[1].
      global rsclist2 to rscl[2].
      global prsclist to list("").
      

}
function SetPartList{
local parameter lin, OPT2 IS 0.
if dbglog > 1 log2file("    SET PART LIST").
set checktime to time:seconds.
local prtltmp to list().
  IF OPT2 = 1 {set lin to CheckAttached(lin).}
for prt in lin{
  if prt:tag <> "" or opt2 = 0{
    if dbglog > 2 log2file("        PART:"+prt).
    local opt to checkdcp(prt,"payload").
    if IsPayload[0] = 0 and opt[0] = 0 prtltmp:add(prt).
    if IsPayload[0] = 1 and opt[0] = 1 prtltmp:add(prt).
  }
}
return prtltmp.
}
function getRSCList{
  local parameter lin, opt is 0. 
  if dbglog > 0 log2file("    GET RESOURCE LIST").
  if dbglog > 1 for itm in lin log2file("     "+itm).
  local count to 0.
  local loadp to 23. if colorprint > 0{ set loadp to loadp+9. PRINT " " AT (80,LNstp-1).}
  local RscL to list().
  local RscL2 to list().
  local RscN to lexicon().
  for RSC in lin{
        if opt = 2 {set loadp to loadp+1. print "." at (loadp,LNstp-1).}
      IF rsc:name = "ElectricCharge" {RscL:add(list(rsc:name, "Electric Charge",rsc:capacity,count)). RscN:add(rsc:name,count). IF OPT > 0 set ecmax to rsc:capacity.}else{
      IF rsc:name = "IntakeAir" {RscL:add(list(rsc:name, "Intake Air",rsc:capacity,count)). RscN:add(rsc:name,count).  IF OPT > 0  set airmax to rsc:capacity.}else{          
      IF rsc:name = "XenonGas" {RscL:add(list(rsc:name, "Xenon Gas",rsc:capacity,count)). RscN:add(rsc:name,count).}else{
      IF rsc:name = "LiquidHydrogen" {RscL:add(list(rsc:name, "Liquid Hydrogen",rsc:capacity,count)). RscN:add(rsc:name,count).}else{
      IF rsc:name = "LiquidOxygen" {RscL:add(list(rsc:name, "Liquid Oxygen",rsc:capacity,count)). RscN:add(rsc:name,count).}else{
      IF rsc:name = "LiquidFuel" {RscL:add(list(rsc:name, "Liquid Fuel",rsc:capacity,count)). RscN:add(rsc:name,count).}else{
      IF rsc:name = "SolidFuel" {RscL:add(list(rsc:name, "Solid Fuel",rsc:capacity,count)). RscN:add(rsc:name,count).}else{
        if mks = 1{
          IF rsc:name = "EnrichedUranium" {RscL:add(list(rsc:name, "Enriched Uranium",rsc:capacity,count)). RscN:add(rsc:name,count).}else{
          IF rsc:name = "ColonySupplies" {RscL:add(list(rsc:name, "Colony Supplies",rsc:capacity,count)). RscN:add(rsc:name,count).}else{
          IF rsc:name = "SpecialisedParts" {RscL:add(list(rsc:name, "Specialised Parts",rsc:capacity,count)). RscN:add(rsc:name,count).}else{
          IF rsc:name = "MaterialKits" {RscL:add(list(rsc:name, "Material Kits",rsc:capacity,count)). RscN:add(rsc:name,count).}else{
          IF rsc:name = "RefinedExotics" {RscL:add(list(rsc:name, "Refined Exotics",rsc:capacity,count)). RscN:add(rsc:name,count).}else{
          IF rsc:name = "DepletedFuel" {RscL:add(list(rsc:name, "Depleted Fuel",rsc:capacity,count)). RscN:add(rsc:name,count).}else{
          IF rsc:name = "DepletedUranium" {RscL:add(list(rsc:name, "Depleted Uranium",rsc:capacity,count)). RscN:add(rsc:name,count).}else{
          IF rsc:name = "MetallicOre" {RscL:add(list(rsc:name, "Metallic Ore",rsc:capacity,count)). RscN:add(rsc:name,count).}else{
          IF rsc:name = "ExoticMinerals" {RscL:add(list(rsc:name, "Exotic Minerals",rsc:capacity,count)). RscN:add(rsc:name,count).}else{
          IF rsc:name = "RareMetals" {RscL:add(list(rsc:name, "Rare Metals",rsc:capacity,count)). RscN:add(rsc:name,count).}else{
          IF rsc:name = "SpecializedParts" {RscL:add(list(rsc:name, "Specialized Parts",rsc:capacity,count)). RscN:add(rsc:name,count).}
          else{RscL:add(list( rsc:name, rsc:name,rsc:capacity,count)). RscN:add(rsc:name,count).}}}}}}}}}}}
        }else{ RscL:add(list( rsc:name, rsc:name,rsc:capacity,count)). RscN:add(rsc:name,count).}}}}}}}}
        Rscl2:add(RSCL[count][1]).
    set count to count+1.
  }
  return list(rscl,RscN,RscL2).
}
function loadbar{
SET LOADING TO LOADING+loadperstep.
for st in range(1,loading) print "#" at (st,16).
    if LOADING > widthlim-3 {PRINTLINE("",0,16). set LOADING to 0.}
}
//#endregion
//#region Auto Functions
Function SetAutoTriggers{ 
  if DbgLog > 0 log2file("SET AUTO TRIGGERS:" ).
  local parameter op is 1.
  global AutoItemLst to list(0). 
  global AutotagLstUP to list(0). 
  global AutotagLstDN to list(0).  
  global AutotagLstNAUP to list(0).
  global AutotagLstNADN to list(0).     
  global AutoLst to list(0).
  local loadp to 21.  if colorprint > 0{ set loadp to loadp+9. PRINT " " AT (80,LNstp-1).}
  for j in range(1,MODESHRT:LENGTH){AutoLst:add(list(0)). AutoItemLst:add(list(0)).
  if op = 2 {set loadp to loadp+1. print "." at (loadp,LNstp-1).}
  if dbglog > 1 log2file("    "+MODELONG[j]). 
  for k in range (1,5){AutoItemLst[J]:add(list(0)). AutoLst[J]:add(list(0)).}
    for u in range(1,3){
      if u = 3 break.
      for i in range (1,itemlist[0]+1){AutoLst[J][u]:add(list(0)). AutoLst[J][u+2]:add(list(0)).
        for t in range (1,prtTAGList[I][0]+1){if t = 1 AND U = 1 and j = 1{AutotagLstUP:add(list(0)). AutotagLstDN:add(list(0)). AutotagLstNAUP:add(list(0)). AutotagLstNADN:add(list(0)).}
          if AutovalList[I][T] <> 0 and abs(AutoDspList[I][T]) = j{
            IF U = 1 {
              IF AutovalList[I][T] > 0 {
                if AutoDspList[I][T] > 1 {
                  AutoLst[J][U][I]:add(ABS(AutovalList[I][T])).
                  if not AutotagLstUP[I]:contains(t) AutotagLstUP[I]:add(t).
                  if not AutoItemLst[J][U]:contains(i) AutoItemLst[J][U]:add(i).
                }else{
                    AutoLst[J][U+2][I]:add(ABS(AutovalList[I][T])).
                    if not AutotagLstNAUP[I]:contains(t) AutotagLstNAUP[I]:add(t).
                    if not AutoItemLst[J][U+2]:contains(i) AutoItemLst[J][U+2]:add(i). 
                }
              }
            }ELSE{
              IF U = 2 {
                IF AutovalList[I][T] < 0 {
                  if AutoDspList[I][T] > 1 {
                    AutoLst[J][U][I]:add(ABS(AutovalList[I][T])).
                    if not AutotagLstDN[I]:contains(t) AutotagLstDN[I]:add(t).
                    if not AutoItemLst[J][U]:contains(i) AutoItemLst[J][U]:add(i). 
                  }else{
                    AutoLst[J][U+2][I]:add(ABS(AutovalList[I][T])).
                    if not AutotagLstNADN[I]:contains(t) AutotagLstNADN[I]:add(t).
                    if not AutoItemLst[J][U+2]:contains(i) AutoItemLst[J][U+2]:add(i). 
                  }
                }
              }
            }     
          }
      }
    }
  }
}
setAutoMinMax().
}
function UpdateAutoTriggers{
  local parameter Updnnum, ModeNum, ItmNum, TgNum, opt is 0.
              IF dbglog > 0{
                log2file("UPDATEAUTOTRIGGERS:"+Removespecial(MODELONG[modenum])).
                log2file("   Updnnum:"+Updnnum+"-ModeNum:"+ModeNum+"-ItmNum:"+ItmNum+"-TgNum:"+TgNum+"-opt:"+opt ).
                IF dbglog > 1{
                  log2file("   UpdateAutoTriggers (autoRstList[ItmNum][TgNum]("+autoRstList[ItmNum][TgNum]+"),AutoDspList[ItmNum][TgNum]("+AutoDspList[ItmNum][TgNum]+"),ItmNum("+ItmNum+"),TgNum("+TgNum+"))." ).
                  log2file("   IF AutovalList[ItmNum][TgNum] > 0:"+ AutovalList[ItmNum][TgNum] ).
                  log2file("   if AutoDspList[ItmNum][TgNum] > 1 and AutoDspList[ItmNum][TgNum] = ModeNum " ).
                  log2file("   if "+AutoDspList[ItmNum][TgNum]+" > 1 and "+AutoDspList[ItmNum][TgNum]+" = "+ModeNum ).
                  log2file("   AutoLst["+ModeNum+"][1]["+ItmNum+"]:"+LISTTOSTRING(AutoLst[ModeNum][1][ItmNum]) ).
                  log2file("   AutoLst["+ModeNum+"][2]["+ItmNum+"]:"+LISTTOSTRING(AutoLst[ModeNum][2][ItmNum]) ).
                  log2file("   AutoLst["+ModeNum+"][3]["+ItmNum+"]:"+LISTTOSTRING(AutoLst[ModeNum][3][ItmNum]) ).
                  log2file("   AutoLst["+ModeNum+"][4]["+ItmNum+"]:"+LISTTOSTRING(AutoLst[ModeNum][4][ItmNum]) ).
                  if AutotagLstUP[ItmNum]:length > 1 log2file("    AutotagLstUP["+ItmNum+"]:"+LISTTOSTRING(AutotagLstUP[ItmNum]) ).
                  if AutotagLstDN[ItmNum]:length > 1 log2file("    AutotagLstDN["+ItmNum+"]:"+LISTTOSTRING(AutotagLstDN[ItmNum]) ).
                  if  AutotagLstNAup[ItmNum]:length > 1 log2file("   AutotagLstNAup["+ItmNum+"]:"+LISTTOSTRING(AutotagLstNAup[ItmNum]) ).
                  if  AutotagLstNADN[ItmNum]:length > 1 log2file("   AutotagLstNADN["+ItmNum+"]:"+LISTTOSTRING(AutotagLstNADN[ItmNum]) ).
                }
              }
            if AutoDspList[ItmNum][TgNum] > 1 and AutoDspList[ItmNum][TgNum] = ModeNum and AutovalList[ItmNum][TgNum] <> 0{
              if not AutoLst[ModeNum][Updnnum][ItmNum]:contains(ABS(AutovalList[ItmNum][TgNum])) AutoLst[ModeNum][Updnnum][ItmNum]:add(ABS(AutovalList[ItmNum][TgNum])).
              if not AutoItemLst[ModeNum][Updnnum]:contains(ItmNum) AutoItemLst[ModeNum][Updnnum]:add(ItmNum).
              IF AutovalList[ItmNum][TgNum] > 0 {
                if not AutotagLstUP[ItmNum]:contains(TgNum) AutotagLstUP[ItmNum]:add(TgNum).
                if AutotagLstDN[ItmNum]:contains(TgNum) AutotagLstDN[ItmNum]:remove(AutotagLstDN[ItmNum]:find(TgNum)).
              }
              IF  AutovalList[ItmNum][TgNum] < 0 {
                if not AutotagLstDN[ItmNum]:contains(TgNum) AutotagLstDN[ItmNum]:add(TgNum).
                if AutotagLstUP[ItmNum]:contains(TgNum) AutotagLstUP[ItmNum]:remove(AutotagLstUP[ItmNum]:find(TgNum)).
              }
              if AutotagLstNADN[ItmNum]:contains(TgNum) AutotagLstNADN[ItmNum]:remove(AutotagLstNADN[ItmNum]:find(TgNum)).
              if AutotagLstNAup[ItmNum]:contains(TgNum) AutotagLstNAup[ItmNum]:remove(AutotagLstNAup[ItmNum]:find(TgNum)).
            }
                if DbgLog > 1{
                  log2file("  post update triggers").
                  if AutotagLstUP[ItmNum]:length > 1 log2file("    AutotagLstUP["+ItmNum+"]:"+LISTTOSTRING(AutotagLstUP[ItmNum]) ).
                  if AutotagLstDN[ItmNum]:length > 1 log2file("    AutotagLstDN["+ItmNum+"]:"+LISTTOSTRING(AutotagLstDN[ItmNum]) ).
                  if  AutotagLstNAup[ItmNum]:length > 1 log2file("   AutotagLstNAup["+ItmNum+"]:"+LISTTOSTRING(AutotagLstNAup[ItmNum]) ).
                  if  AutotagLstNADN[ItmNum]:length > 1 log2file("   AutotagLstNADN["+ItmNum+"]:"+LISTTOSTRING(AutotagLstNADN[ItmNum]) ).
                }

      if opt = 0 UpdateAutoMinMax(ModeNum). else setAutoMinMax(). //maybe check length to to fulll update on values with values using autotaglist lengths..
}
function checkautotrigger{
  local parameter inlist.
  for itm in inlist if itm <> 0 return 1.
  return 0.
}
function setAutoMinMax{
  if dbglog > 0 log2file("SET AUTO MIN MAX"). 
        set SpdTrgsUP to  minmax(AutoLst[2][1],"SpdTrgsUP").  set SpdTrgsDN to  minmax(AutoLst[2][2],"SpdTrgsDN"). 
        set AltTrgsUP to  minmax(AutoLst[3][1],"AltTrgsUP").  set AltTrgsDN to  minmax(AutoLst[3][2],"AltTrgsDN"). 
        set AGLTrgsUP to  minmax(AutoLst[4][1],"AGLTrgsUP").  set AGLTrgsDN to  minmax(AutoLst[4][2],"AGLTrgsDN"). 
        set ECTrgsUP to   minmax(AutoLst[5][1],"ECTrgsUP").  set ECTrgsDN to   minmax(AutoLst[5][2],"ECTrgsDN"). 
        set RSCTrgsUP to  minmax(AutoLst[6][1],"RSCTrgsUP").  set RSCTrgsDN to  minmax(AutoLst[6][2],"RSCTrgsDN"). 
        set ThrtTrgsUP to minmax(AutoLst[7][1],"ThrtTrgsUP").  set ThrtTrgsDN to minmax(AutoLst[7][2],"ThrtTrgsDN").    
        set PresTrgsUP to minmax(AutoLst[8][1],"PresTrgsUP").  set PresTrgsDN to minmax(AutoLst[8][2],"PresTrgsDN").  
        set SunTrgsUP  to minmax(AutoLst[9][1],"SunTrgsUP").  set SunTrgsDN  to minmax(AutoLst[9][2],"SunTrgsDN").  
        set TempTrgsUP to minmax(AutoLst[10][1],"TempTrgsUP"). set TempTrgsDN to minmax(AutoLst[10][2],"TempTrgsDN"). 
        set GravTrgsUP to minmax(AutoLst[11][1],"GravTrgsUP"). set GravTrgsDN to minmax(AutoLst[11][2],"GravTrgsDN"). 
        set AccTrgsUP  to minmax(AutoLst[12][1],"AccTrgsUP"). set AccTrgsDN  to minmax(AutoLst[12][2],"AccTrgsDN"). 
        set TWRTrgsUP  to minmax(AutoLst[13][1],"TWRTrgsUP"). set TWRTrgsDN  to minmax(AutoLst[13][2],"TWRTrgsDN"). 
        set StsTrgsUP  to minmax(AutoLst[14][1],"StsTrgsUP"). set StsTrgsDN  to minmax(AutoLst[14][2],"StsTrgsDN"). set StsTrgs to GetSTSList(AutoLst[14][1]). 
        set FuelTrgsUP to minmax(AutoLst[15][1],"FuelTrgsUP"). set FuelTrgsDN to minmax(AutoLst[15][2],"FuelTrgsDN").
        logtrgs().
}
function UpdateAutoMinMax{
  local parameter mdnm. 
                if DbgLog > 0 log2file("       UPDATE AUTO MIN MAX - "+ MODELONG[mdnm] ).               
  if mdnm = 2 { set SpdTrgsUP to  minmax(AutoLst[2][1],"SpdTrgsUP").  set SpdTrgsDN to  minmax(AutoLst[2][2],"SpdTrgsDN").}else{
  if mdnm = 3 { set AltTrgsUP to  minmax(AutoLst[3][1],"AltTrgsUP").  set AltTrgsDN to  minmax(AutoLst[3][2],"AltTrgsDN").}else{
  if mdnm = 4 { set AGLTrgsUP to  minmax(AutoLst[4][1],"AGLTrgsUP").  set AGLTrgsDN to  minmax(AutoLst[4][2],"AGLTrgsDN").}else{
  if mdnm = 5 { set ECTrgsUP to   minmax(AutoLst[5][1],"ECTrgsUP").  set ECTrgsDN to   minmax(AutoLst[5][2],"ECTrgsDN").}else{
  if mdnm = 6 { set RSCTrgsUP to  minmax(AutoLst[6][1],"RSCTrgsUP").  set RSCTrgsDN to  minmax(AutoLst[6][2],"RSCTrgsDN").}else{
  if mdnm = 7 { set ThrtTrgsUP to minmax(AutoLst[7][1],"ThrtTrgsUP").  set ThrtTrgsDN to minmax(AutoLst[7][2],"ThrtTrgsDN").}else{
  if mdnm = 8 { set PresTrgsUP to minmax(AutoLst[8][1],"PresTrgsUP").  set PresTrgsDN to minmax(AutoLst[8][2],"PresTrgsDN").}else{
  if mdnm = 9 { set SunTrgsUP  to minmax(AutoLst[9][1],"SunTrgsUP").  set SunTrgsDN  to minmax(AutoLst[9][2],"SunTrgsDN").}else{
  if mdnm = 10{ set TempTrgsUP to minmax(AutoLst[10][1],"TempTrgsUP"). set TempTrgsDN to minmax(AutoLst[10][2],"TempTrgsDN").}else{
  if mdnm = 11{ set GravTrgsUP to minmax(AutoLst[11][1],"GravTrgsUP"). set GravTrgsDN to minmax(AutoLst[11][2],"GravTrgsDN").}else{
  if mdnm = 12{ set AccTrgsUP  to minmax(AutoLst[12][1],"AccTrgsUP"). set AccTrgsDN  to minmax(AutoLst[12][2],"AccTrgsDN").}else{
  if mdnm = 13{ set TWRTrgsUP  to minmax(AutoLst[13][1],"TWRTrgsUP"). set TWRTrgsDN  to minmax(AutoLst[13][2],"TWRTrgsDN").}else{
  if mdnm = 14{ set StsTrgsUP  to minmax(AutoLst[14][1],"StsTrgsUP"). set StsTrgsDN  to minmax(AutoLst[14][2],"StsTrgsDN"). set StsTrgs to GetSTSList(AutoLst[14][1]).}else{
  if mdnm = 15{ set FuelTrgsUP to minmax(AutoLst[15][1],"FuelTrgsUP"). set FuelTrgsDN to minmax(AutoLst[15][2],"FuelTrgsDN").}}}}}}}}}}}}}}
  logtrgs().
}
function logtrgs{
        IF dbglog > 1{
          log2file("        SpdTrgsUP:"+LISTTOSTRING(SpdTrgsUP) +" SpdTrgsDN:"+LISTTOSTRING(SpdTrgsDN) ). 
          log2file("        AltTrgsUP:"+LISTTOSTRING(AltTrgsUP) +" AltTrgsDN:"+LISTTOSTRING(AltTrgsDN) ). 
          log2file("        AGLTrgsUP:"+LISTTOSTRING(AGLTrgsUP) +" AGLTrgsDN:"+LISTTOSTRING(AGLTrgsDN) ). 
          log2file("        ECTrgsUP:"+LISTTOSTRING(ECTrgsUP) +" ECTrgsDN:"+LISTTOSTRING(ECTrgsDN) ). 
          log2file("        RSCTrgsUP:"+LISTTOSTRING(RSCTrgsUP) +" RSCTrgsDN:"+LISTTOSTRING(RSCTrgsDN) ). 
          log2file("        ThrtTrgsUP:"+LISTTOSTRING(ThrtTrgsUP) +" ThrtTrgsDN:"+LISTTOSTRING(ThrtTrgsDN) ).
          log2file("        PresTrgsUP:"+LISTTOSTRING(PresTrgsUP) +" PresTrgsDN:"+LISTTOSTRING(PresTrgsDN) ).
          log2file("        SunTrgsUP:"+LISTTOSTRING(SunTrgsUP)  +" SunTrgsDN:"+LISTTOSTRING(SunTrgsDN)  ).
          log2file("        TempTrgsUP:"+LISTTOSTRING(TempTrgsUP) +" TempTrgsDN:"+LISTTOSTRING(TempTrgsDN) ). 
          log2file("        GravTrgsUP:"+LISTTOSTRING(GravTrgsUP) +" GravTrgsDN:"+LISTTOSTRING(GravTrgsDN) ). 
          log2file("        AccTrgsUP:"+LISTTOSTRING(AccTrgsUP)  +" AccTrgsDN:"+LISTTOSTRING(AccTrgsDN)  ). 
          log2file("        TWRTrgsUP:"+LISTTOSTRING(TWRTrgsUP)  +" TWRTrgsDN:"+LISTTOSTRING(TWRTrgsDN)  ). 
          log2file("        StsTrgsUP:"+LISTTOSTRING(StsTrgsUP)  +" StsTrgsDN:"+LISTTOSTRING(StsTrgsDN)  ). 
          log2file("        FuelTrgsUP:"+LISTTOSTRING(FuelTrgsUP) +" FuelTrgsDN:"+LISTTOSTRING(FuelTrgsDN) ).
        }
}
function minmax {
  local parameter listL, MD IS "".
  local Lmin to 9999999.
  local Lmax to 0.
  LOCAL FND TO 0.
  for i in range (1,itemlist[0]+1){ 
    LOCAL ML TO 0.
    for item in listL[I]{
      if item<> 0 {
        IF dbglog > 2{
          IF ML = 0 log2file("           MIN MAX:"+MD).
          log2file("              "+ITEMLIST[I]+":"+ITEM).
          SET ML TO 1.
          SET FND TO 1.
        }
        if item < Lmin set Lmin to item.
        if item > Lmax set Lmax to item.
      }
    }
  }
  if lmin = 9999999 set lmin to 0.
  if lmin = LMAX set lmin to 0. 
  IF dbglog > 2 AND FND > 0 log2file("                  MIN:MAX "+Lmin+":"+Lmax).
  return list(Lmin, Lmax).  
}
function GetSTSList {
  parameter listL.
  LOCAL LST IS LIST(0).
  for i in range (1,itemlist[0]+1){for item in listL[I]{if item<> 0 {if NOT LST:CONTAINS(ITEM) LST:ADD(item).}}}
  return lst.  
}
function loadAutoSettings{
  if dbglog > 0 log2file("    LOAD AUTO SETTINGS").
  parameter opt is 0.
  local loadp to 22.  if colorprint > 0{ set loadp to loadp+9. PRINT " " AT (80,LNstp-1).}
    local refreshTimer to TIME:seconds.
    local isdone to 0.
          local line to 2.
          local rchhk to 0.
    if loadbkp = 2 {IF file_exists(autofileBAK) set LISTIN TO READJSON(SubDirSV + autofileBAK). set line to 1.}
      global AutoDspListTMP to  listin[0]:copy.
      global  autovallistTMP to listin[1]:copy.
      global  itemlistTMP to    listin[2]:copy.
      global  prttaglistTMP to  listin[3]:copy.
      global  prtlistTMP to     listin[4]:copy.
      global autoRstListTMP to  listin[5]:copy.
      global AutoRscListTMP to  listin[6]:copy.
      global AutoTRGListTMP to  listin[7]:copy.
          local lstoff to 0.
          for i in range (1,itemlistTMP[0]+1){
            //if dbglog > 2 log2file("      ITEM:"+I).
            for T in range (1,prtTAGListTMP[I][0]+1){if t = prtTAGListTMP[I][0]+1 break.
            //if dbglog > 2 log2file("         TAG:"+T).
              local tmplist to ship:partstagged(prttaglistTMP[I][T]).
                FOR P IN RANGE (1,prtListTMP[I][T][0]+1){if p = prtListTMP[I][T][0]+1 break.
                //if dbglog > 2 log2file("          PART:"+p).
                  local tmplist2 to tmplist:copy.
                  local i1 to itemlist:find(itemlistTMP[I]).
                  //if dbglog > 2 log2file("          ITEM1:"+I1).
                  if i1 > 0 {
                  local t1 to prttagList[I1]:find(prttagListTMP[I][T]).
                    //if dbglog > 2 log2file("              tag1:"+T1).
                      if t1 > 0 {
                        if prtlist[I1][T1][0]+1 > p{
                          if prtlisttmp[I][T][P]:tostring = core:part:tostring and prtlist[I1][T1][P]:tostring <> core:part:tostring 
                            set prtlisttmp[I][T][P] to prtlist[I1][T1][P].
                        }
                      }
                  }
                  if tmplist2:tostring:contains(prtlisttmp[I][T][P]:tostring){
                    for itm in tmplist2{
                      if itm:tostring = prtlisttmp[I][T][P]:tostring{
                        set prtlisttmp[I][T][P] to itm.
                        tmplist:remove(tmplist:find(itm)).
                        break.
                      }
                    }
                  }
                }
              }
          }
      if itemlistTMP[0] > itemlist[0] set lstoff to 1. 
      else if itemlistTMP[0] < itemlist[0] set lstoff to 2.
      if lstoff = 0 {if dbglog > 2 log2file("    ITEMLIST LENGTH:"+itemlist[0]+"="+itemlisttmp[0]).
        for i2 in range(1,itemlist[0]+1){
          if prtTagListTMP[i2][0]      > prtTagList[i2][0] set lstoff to 1. 
          else if prtTagListTMP[i2][0] < prtTagList[i2][0] set lstoff to 2.
          if autotrglisttmp[0][i2]:length      > autotrglist[0][i2]:length set lstoff to 1. 
          else if autotrglisttmp[0][i2]:length < autotrglist[0][i2]:length set lstoff to 2.
          if lstoff = 0 {if dbglog > 2 log2file("      TAGLIST LENGTH:"+itemlist[i2]+"("+i2+"):"+prtTagList[i2][0]+"="+prtTagListTMP[i2][0]).
            for t2 in range(1,prtTagList[i2][0]+1){
              if dbglog > 2 log2file("        TAG:"+T2+":"+prtTagList[i2][T2]+"="+prtTagListTMP[i2][T2]).
              if prtlistTMP[i2][t2][0]      > prtlist[i2][t2][0] set lstoff to 1. 
              else if prtlistTMP[i2][t2][0] < prtlist[i2][t2][0] set lstoff to 2.
              if lstoff <> 0 break. else if dbglog > 2 log2file("         PARTLIST LENGTH:"+prtTagList[i2][t2]+"("+t2+"):"+prtlist[i2][t2][0]+"="+prtlistTMP[i2][t2][0]).
            }
          }
          if lstoff <> 0 break.
        }
      }

      if lstoff > 0 evenlist(lstoff).
      if loadattempts > 0 set autovallisttmp[0][0][0] to autovallisttmp[0][0][0]+loadattempts.
      local imin to min(itemlistTMP[0], itemlist[0]).
      local tmin is min(prttaglistTMP[1][0], prttaglist[1][0]).
      local pmin is min(prtlistTMP[1][1][0], prtlist[1][1][0]).
      local ioff to 0. local toff to 0. local poff to 0. 
      if imin < max(itemlistTMP[0], itemlist[0]) set ioff to 1.
      if tmin < max(prttaglistTMP[1][0], prttaglist[1][0]) set toff to 1.
      if pmin < max(prtlistTMP[1][1][0], prtlist[1][1][0]) set poff to 1.
        if LOADBKP<>2{
        for i in range(1,imin){
          if opt = 1 set loadp to loadp+1. print "." at (loadp,LNstp-1).
          if itemlist[I] <> itemlistTMP[I]{
            set ioff to ioff+1. 
            set ioff to ioff+1. 
            if dbglog > 2 log2file("      Item OFF:"+itemlistTMP[I]+"("+I+")"+"/"+itemlist[I]+"("+itemlist[0]+")").
          }
          for t in range(1,min(prttaglistTMP[I][0], prttaglist[I][0])){
            if t < tmin  if prttaglist[I][T] <> prttaglistTMP[I][T]{
              set toff to toff+1. 
              set toff to ioff+1.
              if dbglog > 2 log2file("       Tag OFF:"+itemlistTMP[I]+"("+I+")"+"-"+prttaglistTMP[I][t]+"("+i+")"+"/"+itemlist[I]+"("+I+")"+"-"+prttaglist[I][t]+"("+t+")").
              }
            for p in range(1,min(prtlistTMP[I][T][0], prtlist[I][T][0])){
              if p < pmin if prtlist[I][T][P]:TOSTRING <> prtlistTMP[I][T][P]:TOSTRING{
                if NOT prtlist[I][T][P]:hasmodule("ModuleCommand"){
                  set poff to poff+1. set poff to ioff+1.
                   if dbglog > 2 log2file("      Part OFF:"+itemlistTMP[I]+"("+I+")"+"-"+prttaglistTMP[I][t]+"("+T+")"+"-"+prtlistTMP[I][T][p]+"("+P+")"+"/"+itemlist[I]+"("+I+")"+"-"+prttaglist[I][t]+"("+t+")"+"-"+prtlist[I][T][p]+"("+p+")").
                }
              }
            }
          }
        }
        }else {set ioff to 0. set toff to 0. set poff to 0.}
      IF autovallistTMP[0][0][0] > 1000 and ioff = 0 and toff = 0 and poff = 0 {set line to LNstp. set LNstp to LNstp+1.
       if autovallistTMP[0][0][0] > 1000 button7(). //else if autovallistTMP[0][0][0] = 1002 button11().
       }else{DESKTOP(). 
        if ioff = 0 {print "itemlist match" at (1,line). set line to line+1.}else{print "itemlist mismatch" at (1,line).set line to line+1.}
        if toff = 0 {print "Taglist match"  at (1,line). set line to line+1.}else{print  "Taglist mismatch" at (1,line).set line to line+1.}
        if poff = 0 {print "Partlist match" at (1,line). set line to line+1.}else{print "Partlist mismatch" at (1,line).set line to line+1.}
        print "load settings?" at (1,line). set line to line+1.
        PRINT "|    YES   |    NO    | AUTO LOAD|" at (0,heightlim).
        if loadbkp <> 2 IF file_exists(autofileBAK) PRINT "| lOAD BKP  |          |" AT (33,heightlim).
        }     
      //#region buttons 
      set v0:wave to "sawtooth".
      function button7{ALOAD(rchhk,lstoff).
       SET isDone to 1.   set refreshTimer to TIME:seconds+1000000.
       //SET LOADBKP TO 0.
      }buttons:setdelegate(7,button7@).
      
      function button8{
        SET LOADBKP TO 0.
        set refreshTimer to TIME:seconds+1000000.
        print GetColor("Settings discarded.","ORN",0)at (1,line).
        set line to line+1.
         IF file_exists(autofile) DELETEPATH(SubDirSV +autofile). 
         SET isDone to 1.
        }buttons:setdelegate(8,button8@).
      function button9{
         set refreshTimer to TIME:seconds+1000000.
        print "Settings will be loaded automatically on match."at (1,line). 
        set autovallisttmp[0][0][0] to 1001. set line to line+1. set LNstp to line+1. ALOAD(rchhk,lstoff).
        SET isDone to 1.
        
        }buttons:setdelegate(9,button9@).
      function button10{
        SET LOADBKP TO 2.
        SET isDone to 1.
        set rchhk to 1.
        set refreshTimer to TIME:seconds+1000000.
        }buttons:setdelegate(10,button10@).
      //function button11{
        // set refreshTimer to TIME:seconds+1000000.
        //print "Backup will be loaded automatically on match."at (1,line). 
        //set autovallisttmp[0][0][0] to 1002. set line to line+1. 
        //SET LOADBKP TO 2.
        //SET isDone to 1.
        //set rchhk to 1.
        //set refreshTimer to TIME:seconds+1000000.
        //}buttons:setdelegate(11,button11@).
      //#endregion buttons
      local tmebk to 0.
      until isDone > 0 {
        local tme to ROUND((10- (TIME:SECONDS - refreshTimer)),0).
        if tmebk <> tme {PRINTLINE("Auto Selecting Yes in " + tme + " SECONDS      ",0,17). set tmebk to tme.}
        if tme < 1 {button7().}
      }
      //if loadbkp = 2 {set LNstp to 1. set line to 1. DESKTOP(). loadship(0). HudFuction().}
      
        function evenlist{
          LOCAL lINSERTED TO LIST().
          LOCAL PARAMETER OPIN.
          if dbglog > 1 log2file("    evenlist:"+opin).
          IF dbglog > 2{log2file("      ITEMLIST   :"++LISTTOSTRING(itemlist)).
                         log2file("      ITEMLISTTMP:"+LISTTOSTRING(itemlistTMP)).
                         }
          local itl to list(0).
          IF OPIN = 1{
                for k in range (1,itemlistTMP[0]+1){
                  if not prtListTMP[k][0][0]:tostring:contains("/") set prtListTMP[k][0][0] to "temp"+"/"+0.
                  IF DBGLOG > 2 log2file(prtListTMP[k][0][0]).
                  itl:add(prtListTMP[k][0][0]:split("/")[0]).
                }
            for i in range (1,itemlistTMP[0]+1){
              if dbglog > 2 log2file("      ITEM:"+I).
              if i < itemlistTMP[0]+1 {
                //if i = itemlistTMP[0]+1 break.
                if prtList:length = i prtList:add(list(list("temp"+"/"+0))).
                if AutoDspList[0]:length = i AutoDspList[0]:add(list(0)).
                if prtList[I][0][0]:tostring <> prtlistTMP[I][0][0]:tostring or prtList:length = i{
                  local pl0 to prtList[I][0][0]:split("/").
                  local plT to prtListTMP[I][0][0]:split("/").
                  if dbglog > 2{log2file("      ITEM:"+I). log2file("      "+prtList[I][0][0]+":"+prtListTMP[I][0][0]).}
                  if plt[0] <> pl0[0] {
                    if pl0[1]:tonumber < itl:find(pl0[0]) or itl:find(pl0[0]) = -1{
                      lINSERTED:ADD(I).
                      local ADout to list(list(0)).
                      local AD0ut to list(list(0)).
                      local AVout to list(list(0)).
                      local itmout to "na".
                      local tgout to list(1,"NONE").
                      local ptout to list(list(0)).
                      local arout to list(list(0)).
                      local acout to list(list(0)).
                      local ac0ut to list(list(0)).
                      local atout to list(list(0)).
                      local a0out to list(list(0)).
                      if itl:find(pl0[0])-1 = pl0[1]:tonumber {
                        set ADout to AutoDspListTMP[I].
                        set AD0ut to AutoDspListTMP[0][I].
                        set AVout to autovallistTMP[I].
                        set itmout to itemlistTMP[I].
                        set tgout to prttaglistTMP[I].
                        set ptout to prtlistTMP[I].
                        set arout to autoRstListTMP[I].
                        set acout to AutoRscListTMP[I].
                        set ac0ut to AutoRscListTMP[0][I].
                        set atout to AutoTRGListTMP[I].
                        set a0out to AutoTRGListTMP[0][I].
                      }
                      IF dbglog > 2{
                        log2file("AutoDspList:insert(" + i + "):" + listtostring(ADout:copy) + ")") .
                        log2file("AutoDspList[0]:insert(" + i + "):" + listtostring(AD0ut:copy) + ")") .
                        log2file("autovalList:insert(" + i + "):" + listtostring(AVout:copy) + ")") .
                        log2file("itemList:insert(" + i + "):" + itmout + ")") .
                        log2file("prttagList:insert(" + i + "):" + listtostring(tgout:copy) + ")") .
                        log2file("prtList:insert(" + i + "):" + listtostring(listtostring(ptout:copy)) + ")") .
                        log2file("autoRstList:insert(" + i + "):" + listtostring(arout:copy) + ")") .
                        log2file("AutoRscList:insert(" + i + "):" + listtostring(acout:copy) + ")") .
                        log2file("AutoRscList[0]:insert(" + i + "):" + ac0ut + ")") .
                        log2file("AutoTRGList:insert(" + i + "):" + listtostring(atout:copy) + ")") .
                        log2file("AutoTRGList[0]:insert(" + i + "):" + listtostring(a0out:copy) + ")") .
                      }
                      AutoDspList:insert(i,ADout:copy).
                      AutoDspList[0]:insert(i,AD0ut:copy).
                      autovallist:insert(i,AVout:copy) .
                      itemlist:insert(i,itmout).
                      prttaglist:insert(i,tgout:copy).
                      prtlist:insert(i,ptout:copy).
                      autoRstList:insert(i,arout:copy).
                      AutoRscList:insert(i,acout:copy).
                      AutoRscList[0]:insert(i,ac0ut).
                      AutoTRGList:insert(i,atout:copy). 
                      AutoTRGList[0]:insert(i,a0out:copy). 
                      if plt[1]:tonumber = i {
                        set prtList[I] to prtListtmp[I].
                        set prtList[I][0][0] to plt[0]+"/"+plt[1].
                        tagfix(plt[0],plt[1]).
                      }
                    }
                  }else{
                    if prttaglist[i][0] > prttaglisttmp[i][0] prtfix(i).
                    if plt[1]:tonumber = i {
                      ToTMP(i,plt).
                      tagfix(plt[0],plt[1]).
                    }
                  }
                  wait 0.01.
                }//ELSE{if prttaglist[i][0] > prttaglisttmp[i][0] prtfix(i).}
              }
            }
          }
          IF OPIN = 2{
                for k in range (1,itemlist[0]+1){
                  if not prtList[k][0][0]:tostring:contains("/") set prtList[k][0][0] to "temp"+"/"+0.
                  if dbglog > 1 log2file("      "+prtList[k][0][0]).
                  itl:add(prtList[k][0][0]:split("/")[0]).
                }
            for i in range (1,itemlist[0]+1){
              if dbglog > 2 log2file("      ITEM:"+I).
              if i < itemlist[0]+1 {
                if prtListTMP:length = i prtListTMP:add(list(list("temp"+"/"+0))).
                if AutoDspListTMP[0]:length = i AutoDspListTMP[0]:add(list(0)).
                if prtListTMP[I][0][0]:tostring <> prtlist[I][0][0]:tostring or prtListTMP:length = i{
                  local plt to prtListTMP[I][0][0]:split("/").
                  local pl0 to prtList[I][0][0]:split("/").
                  if dbglog > 2{log2file("      ITEM:"+I). log2file("      "+prtList[I][0][0]+":"+prtListTMP[I][0][0]).}
                  if pl0[0] <> plt[0] {
                    if plt[1]:tonumber < itl:find(plt[0]) or itl:find(plt[0]) = -1{
                      lINSERTED:ADD(I).
                      local ADout to list(list(0)).
                      local AD0ut to list(list(0)).
                      local AVout to list(list(0)).
                      local itmout to "na".
                      local tgout to list(1,"NONE").
                      local ptout to list(list(0)).
                      local arout to list(list(0)).
                      local acout to list(list(0)).
                      local ac0ut to list(list(0)).
                      local atout to list(list(0)).
                      local a0out to list(list(0)).
                      if itl:find(plt[0])-1 = plt[1]:tonumber or not prttaglistTMP:contains(pl0[0]){
                        set ADout to AutoDspList[I].
                        set AD0ut to AutoDspList[0][I].
                        set AVout to autovallist[I].
                        set itmout to itemlist[I].
                        set tgout to prttaglist[I].
                        set ptout to prtlist[I].
                        set arout to autoRstList[I].
                        set acout to AutoRscList[I].
                        set ac0ut to AutoRscList[0][I].
                        set atout to AutoTRGList[I].
                        set a0out to AutoTRGList[0][I].
                      }
                      IF dbglog > 2{
                        log2file("          AutoDspListTMP:insert(" + i + "):" + listtostring(ADout:copy) + ")") .
                        log2file("          AutoDspListTMP[0]:insert(" + i + "):" + listtostring(AD0ut:copy) + ")") .
                        log2file("          autovallistTMP:insert(" + i + "):" + listtostring(AVout:copy) + ")") .
                        log2file("          itemlistTMP:insert(" + i + "):" + itmout + ")") .
                        log2file("          prttaglistTMP:insert(" + i + "):" + listtostring(tgout:copy) + ")") .
                        log2file("          prtListTMP:insert(" + i + "):" + listtostring(ptout:copy) + ")") .
                        log2file("          autoRstListTMP:insert(" + i + "):" + listtostring(arout:copy) + ")") .
                        log2file("          AutoRscListTMP:insert(" + i + "):" + listtostring(acout:copy) + ")") .
                        log2file("          AutoRscListTMP[0]:insert(" + i + "):" + ac0ut + ")") .
                        log2file("          AutoTRGListTMP:insert(" + i + "):" + listtostring(atout:copy) + ")") .
                        log2file("          AutoTRGListTMP[0]:insert(" + i + "):" + listtostring(a0out:copy) + ")") .
                      }
                      
                      AutoDspListTMP:insert(i,ADout:copy) .
                      AutoDspListTMP[0]:insert(i,AD0ut:copy) .
                      autovallistTMP:insert(i,AVout:copy) .
                      itemlistTMP:insert(i,itmout).
                      prttaglistTMP:insert(i,tgout:copy).
                      prtListTMP:insert(i,ptout:copy).
                      autoRstListTMP:insert(i,arout:copy) .
                      AutoRscListTMP:insert(i,acout:copy) .
                      AutoRscListTMP[0]:insert(i,ac0ut) .
                      AutoTRGListTMP:insert(i,atout:copy) . 
                      AutoTRGListTMP[0]:insert(i,a0out:copy).
                      if pl0[1]:tonumber = i {
                        set prtListTMP[I] to prtList[I].
                        set prtListTMP[I][0][0] to pl0[0]+"/"+pl0[1].
                        tagfix(pl0[0],pl0[1]).
                      }
                    }
                  }
                  else{
                    IF dbglog > 2 log2file("            TAGS-LENGTH:"+prtTagList[I][0]+ " TMP-LENGTH:"+prtTagListTMP[I][0]).
                      if prttaglist[i][0] > prttaglisttmp[i][0] prtfix(i).
                      if pl0[1]:tonumber = i {
                        ToTMP(i,pl0).
                        tagfix(pl0[0],pl0[1]).
                      }
                  }
                    //IF lINSERTED:LENGTH> 0{CheckLink(I).}
                  wait 0.01.
                }ELSE{if prttaglist[i][0] > prttaglisttmp[i][0] prtfix(i).}
              }
            }
            IF lINSERTED:LENGTH> 0{
              FOR i in range (1,itemlist[0]+1){CheckLink(I).}
            
            }
          }
          set itemlist[0] to itemlist:length-1.
          set itemlistTMP[0] to itemlistTMP:length-1.
          if dbglog > 2{log2file("      ITEMLIST   :"++LISTTOSTRING(itemlist)).
                        log2file("      ITEMLISTTMP:"+LISTTOSTRING(itemlistTMP)).
                        }
          set LFX to 1.
          function CheckLink{
            local parameter CLI.
            if cli > itemlist:length-1 return.
            IF dbglog > 2 log2file("          CHECK LINK("+CLI+"):"+ITEMLIST[CLI]).
            FOR T IN RANGE(1,prtTagListtmp[CLI][0]+1){           IF T = prtTagListtmp[CLI][0]+1          BREAK. IF dbglog > 2 log2file("            CHECK TAG("+T+"):"+prtTagList[CLI][T]).
              FOR J IN RANGE(0,AutoDspListTMP[0][CLI][T]:LENGTH){IF J = AutoDspListTMP[0][CLI][T]:LENGTH BREAK. IF dbglog > 2 log2file("             LINK:("+J+"):"+AutoDspListTMP[0][CLI][T][J]).
                local itm1 to AutoDspListTMP[0][CLI][T][J].
                IF itm1:TOSTRING:CONTAINS("-"){
                  local splt to itm1:split("-").
                    IF SPLT:LENGTH > 2 {
                    LOCAL NmIn TO (SPLT[0]:TONUMBER).
                    local addmore to 0.
                    for k in lINSERTED if nmin > k-1 set addmore to addmore+1.
                    local NmMore to NmIn+addmore.
                      IF addmore > 0 {IF dbglog > 2 log2file("                  CHANGING "+SPLT[0]+" TO "+NmMore).
                        SET SPLT[0] TO NmMore:TOSTRING.
                        IF SPLT:LENGTH = 4 SET AutoDspListTMP[0][CLI][T][J] TO splt[0]+"-"+splt[1]+"-"+splt[2]+"-"+splt[3].
                        IF SPLT:LENGTH = 3 SET AutoDspListTMP[0][CLI][T][J] TO splt[0]+"-"+splt[1]+"-"+splt[2].
                        IF dbglog > 2 log2file("                    LINKout:("+J+"):"+AutoDspListTMP[0][CLI][T][J]).
                      }
                    }
                  }
                }
              }
          }
          function ToTMP{
            local parameter TTI, ttplt.
                          set prtList[TTI] to prtListtmp[TTI].
                          set AutoDspList[TTI] to AutoDspListtmp[TTI].
                          set autovallist[TTI] to autovallisttmp[TTI].
                          set itemlist[TTI] to itemlisttmp[TTI].
                          set prttaglist[TTI] to prttaglisttmp[TTI].
                          set prtlist[TTI] to prtlisttmp[TTI].
                          set autoRstList[TTI] to autoRstListtmp[TTI].
                          set AutoRscList[TTI] to AutoRscListtmp[TTI].
                          set AutoRscList[0][TTI] to AutoRscListtmp[0][TTI].
                          set AutoTRGList[TTI] to AutoTRGListtmp[TTI].
                          set AutoTRGList[0][TTI] to AutoTRGListtmp[0][TTI].
                          set prtList[TTI][0][0] to ttplt[0]+"/"+ttplt[1].
                          IF dbglog > 2{
                            log2file("          set prtList:"+ prtList[TTI]+" to "+prtListTMP[TTI]).
                            log2file("          set AutoDspList:"+ AutoDspList[TTI]+" to "+AutoDspListTMP[TTI]).
                            log2file("          set autovallist:"+ autovallist[TTI]+" to "+autovallistTMP[TTI]).
                            log2file("          set itemlist:"+ itemlist[TTI]+" to "+itemlistTMP[TTI]).
                            log2file("          set prttaglist:"+ prttaglist[TTI]+" to "+prttaglistTMP[TTI]).
                            log2file("          set prtlist:"+ prtlist[TTI]+" to "+prtListTMP[TTI]).
                            log2file("          set autoRstList:"+ autoRstList[TTI]+" to "+autoRstListTMP[TTI]).
                            log2file("          set AutoRscList:"+ AutoRscList[TTI]+" to "+AutoRscListTMP[TTI]).
                            log2file("          set AutoRscList:"+ AutoRscList[TTI][0]+" to "+AutoRscListTMP[TTI][0]).
                            log2file("          set AutoTRGList:"+ AutoTRGList[TTI]+" to "+AutoTRGListTMP[TTI]).
                            log2file("          set AutoTRGList:"+ AutoTRGList[0][TTI]+" to "+AutoTRGListTMP[0][TTI]).
                            log2file("          set prtList:"+ prtList[TTI][0][0]+" to "+ttplt[0]+"/"+ttplt[1]).
                          }
          }
          function prtfix{
          local parameter i.              
          if dbglog > 2 log2file("      PRTFIX:"+I).
          if i > itemlist:length-1 return.
                  for t in range (1,prttaglist[i]:length){
                    if dbglog > 2 log2file("          TAG:"+T).
                    if not prttaglistTMP[i]:contains(prttaglist[i][t]) {
                        IF dbglog > 2{
                        log2file("          INSERTED prtListTMP:"+listtostring(prtList[I][t])).
                        log2file("          INSERTED AutoDspListTMP:"+AutoDspList[I][t]).
                        log2file("          INSERTED AutoDspListTMP[0]:"+AutoDspList[0][I][t]).
                        log2file("          INSERTED autovallistTMP:"+autovallist[I][t]).
                        log2file("          INSERTED prttaglistTMP:"+prttaglist[I][t]).
                        log2file("          INSERTED autoRstListTMP:"+autoRstList[I][t]).
                        log2file("          INSERTED AutoRscListTMP:"+AutoRscList[I][t]).
                        log2file("          INSERTED AutoTRGListTMP:"+AutoTRGList[I][t]).
                        log2file("          INSERTED AutoTRGListTMP[0]:"+AutoTRGList[0][I][t]).
                        }
                      AutoDspListTMP[i]:insert(t,AutoDspList[i][t]) .
                      AutoDspListTMP[0][i]:insert(t,AutoDspList[0][i][t]) .
                      autovallistTMP[i]:insert(t,autovallist[i][t]) .
                      prttaglistTMP[i]:insert(t,prttaglist[i][t]).
                      prtListTMP[i]:insert(t,prtList[i][t]:copy).
                      autoRstListTMP[i]:insert(t,autoRstList[i][t]) .
                      AutoRscListTMP[i]:insert(t,AutoRscList[i][t]) .
                      AutoTRGListTMP[i]:insert(t,AutoTRGList[i][t]) .  
                      AutoTRGListTMP[0][i]:insert(t,AutoTRGList[0][i][t]) .                     
                    }
                  }
                set prttaglistTMP[i][0] to prttaglistTMP[i]:length-1. 
                set prttaglist[i][0] to prttaglist[i]:length-1.      
        }
        }
        function tagfix{
          local parameter tagin, namein.
          set tagin to tagin:tostring.
          if namein:typename="string" set namein to namein:tonumber.
          IF dbglog > 2 log2file("        TagFix:"+TAGIN+"-"+namein).
          if tagin = "lighttag"{set lighttag to namein.}else{
          if tagin = "AGTag"{set AGTag to namein.}else{
          if tagin = "FlyTag"{set FlyTag to namein.}else{
          if tagin = "CMDTag"{set CMDTag to namein.}else{
          if tagin = "CntrlTag"{set CntrlTag to namein.}else{
          if tagin = "engtag"{set engtag to namein.}else{
          if tagin = "Inttag"{set Inttag to namein.}else{
          if tagin = "dcptag"{set dcptag to namein.}else{
          if tagin = "geartag"{set geartag to namein.}else{
          if tagin = "chutetag"{set chutetag to namein.}else{
          if tagin = "ladtag"{set ladtag to namein.}else{
          if tagin = "baytag"{set baytag to namein.}else{
          if tagin = "Docktag"{set Docktag to namein.}else{
          if tagin = "RWtag"{set RWtag to namein.}else{
          if tagin = "slrtag"{set slrtag to namein.}else{
          if tagin = "RCStag"{set RCStag to namein.}else{
          if tagin = "drilltag"{set drilltag to namein.}else{
          if tagin = "radtag"{set radtag to namein.}else{
          if tagin = "scitag"{set scitag to namein.}else{
          if tagin = "anttag"{set anttag to namein.}else{
          if tagin = "FWtag"{set FWtag to namein.}else{
          if tagin = "ISRUTag"{set ISRUTag to namein.}else{
          if tagin = "Labtag"{set Labtag to namein.}else{
          if tagin = "RBTTag"{set RBTTag to namein.}else{
          if tagin = "SMRTtag"{set SMRTtag to namein.}else{
          //MKS MOD
          if tagin = "MksDrlTag"{set MksDrlTag to namein.}else{
          if tagin = "PWRTag"{set PWRTag to namein.}else{
          if tagin = "DEPOTag"{set DEPOTag to namein.}else{
          if tagin = "habTag"{set habTag to namein.}else{
          if tagin = "CnstTag"{set CnstTag to namein.}else{
          if tagin = "DcnstTag"{set DcnstTag to namein.}else{
          if tagin = "ACDTag"{set ACDTag to namein.}else{
          //OTHER MODS
          if tagin = "CapTag"{set CapTag to namein.}else{
          //BDA MOD (KEEP LAST TO MAAKE WMGR QUICKLY ACCESSABLE)
          if tagin = "BDPtag"{set BDPtag to namein.}else{
          if tagin = "CMtag"{set CMtag to namein.}else{
          if tagin = "Radartag"{set Radartag to namein.}else{
          if tagin = "FRNGtag"{set FRNGtag to namein.}else{
          if tagin = "WMGRtag"{set WMGRtag to namein.}else{ IF dbglog > 2 log2file("        FAILED:").
          }}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
        }
        FUNCTION ALOAD{
        local parameter rcheck is 0, loff is 0.
        if dbglog > 1 log2file("      ALOAD:Recheck="+rcheck).
        SET autovallist TO autovallistTMP:copy. SET isDone to 1.
        SET AutoDspList TO AutoDspListTMP:copy. 
        SET autoRstList TO autoRstListTMP:copy.
        SET AutoRscList TO AutoRscListTMP:copy.
        SET AutoTRGList TO AutoTRGListTMP:copy.
        if loff <> 0{
          SET itemlist TO itemlistTMP:copy.
          SET prtlist TO prtlistTMP:copy.
          SET prttaglist TO prttaglistTMP:copy.
        }
        if AutoDspList[0]:length < itemlist:length or AutoValList[0][0]:length < 5 addlist().
        set HdngSet to autovallist[0][0][1].
        SET HEIGHT TO autovallist[0][0][2].
        set refreshRateSlow to autovallist[0][0][4][0].
        set refreshRateFast to autovallist[0][0][4][1].
        if debug = 0 set debug to autovallist[0][0][4][2].
        //if dbglog = 0 set dbglog to autovallist[0][0][4][3]. 
        set HLon to autovallist[0][0][4][4].
        set SPEEDSET[0] TO SFL(autovallist[0][0][4],5,SPEEDSET[0]).
        set SPEEDSET[1] TO SFL(autovallist[0][0][4],6,SPEEDSET[1]).
        set SPEEDSET[2] TO SFL(autovallist[0][0][4],7,SPEEDSET[2]).
        set SPEEDSET[3] TO SFL(autovallist[0][0][4],8,SPEEDSET[3]).
        SaveAutoSettings().
        if rcheck = 1 LoadShip(0).
        FUNCTION SFL{
          LOCAL PARAMETER VALIN, LNIN, VALST.
          IF VALIN:LENGTH-1 < LNIN RETURN VALST. else set valin to valin[lnin].
          IF VALIN < 1 RETURN VALST.
          return VALIN.
        }
      }
    }
//#endregion
function HudFuction{
  initialset().
  HudFuctionMain().
  function initialset{
    SET CPUSPD TO SPEEDSET[0].
    global DispInfo to 0.
    global HDXT TO "     ".
    global ploc to 13.
    global pwdt to 14.
    global pwdt2 to 28.
    global pwdt3 to 14.
    global ploc2 to ploc+1+pwdt. //ploc+14
    global ploc3 to ploc2+1+pwdt2. //ploc+44.
    global axsel to 1.
    global fo to 0.
    global foblink to 0.
    if IsPayload[0] = 1 {set RunAuto to 0. SET refreshRateSlow TO 10. set refreshRateFast to 10. set RFSBAak to refreshRateSlow.}
    if SHIP:status = "PRELAUNCH" set RunAuto to 2.
    global runautobak to RunAuto.
    global APaxis TO LIST(9,"pitch","yaw","roll","speed","alt","V-SPD","Pitch Lim","Roll Lim","AOA Lim").    
    global HudRstMdLst to list(4," DISABLE  ","CHANGE DIR"," RESET UP "," RESET DN ").
    global ShipStatPREV to " ".
    global ShipStatPREV2 to "NONE".
    global FlState to " ".
    global RscSelection to 0.
    global Trim to 0.
    global partnumprv to 1.
    global anttrgsel to 1.
    global scipart to 1.
    Global EnabSel to 1.
    Global ModeSel to 1.
    global ConvRSC to 1.
    global BayLst to list(0).
    global BayTrg to list(0).
    global BaySel to 1.
    global SciDsp to "".
    if refreshRateFast < 1 set refreshRateFast to 1.
    if refreshRateSlow < 1 set refreshRateSlow to 1.
    global MtrPrtSel to list(0,0,0,0,0,0,0,0,0).
    global enghud to list().
    for i in range(1, prtTagList[engtag][0]*2+2) enghud:insert(0,0).
    global AUTOHUD TO LIST(0,1,"  OVER ").
    global EmptyHud to "          ".
    global fuelmon to 0.
    global hudstart to 17.
    global RowSel to 1.
    global HSel to list(0).
    global HUDOP TO 1.
    global HUDOPPREV TO 1.
    global AutoAdjByLst to list(7,1,5,10,100,1000,10000,100000).
    global fieldlist to list("").
    global AUTOHUDBK TO AUTOHUD.
    global HudOptsL to list(0).
    global HudOptsR to list(0). 
    HudOptsL:add(list(0,"PREV    "   ,"PREV    "   ,"THRUST  "   ,"        "   ,"        "   ,"PREV    "   ,"PREV    "   ,"PREV    "   ,"PREV    "   ,"        "   )).
    HudOptsL:add(list(0,"GROUP       ","PART      ","LIM DN     ","           ","AUTO DIR   ","ACTION     ","TARGET     ","AXIS       ","WEAPON     ","LIM DN  "  )).
    HudOptsL:add(list(0,"NEXT       ","NEXT       ","THRUST     ","           ","AUTO ADJ BY","NEXT       ","NEXT       ","NEXT       ","NEXT       ","        ")).
    HudOptsL:add(list(0,"GROUP   "   ,"PART  "     ,"LIM UP "    ,"       "    ,"       "    ,"ACTION "    ,"TARGET "    ,"AXIS    "   ,"WEAPON  "   ,"LIM UP "    )).
    HudOptsL:add(list(0,"      "     ,"      "     ,"       "    ,"      "     ,"      "     ,"      "     ,"      "     ,"      "     ,"      "     ,"       "    )).
    HudOptsL:add(list(0,"      "     ,"      "     ,"       "    ,"      "     ,"      "     ,"      "     ,"      "     ,"      "     ,"      "     ,"       "    )).
    HudOptsL:add(list(0,"      "     ,"      "     ,"       "    ,"      "     ,"      "     ,"      "     ,"      "     ,"      "     ,"      "     ,"       "    )).
    HudOptsL:add(list(0,"      "     ,"      "     ,"       "    ,"      "     ,"      "     ,"      "     ,"      "     ,"      "     ,"      "     ,"       "    )).
    HudOptsR:add(list(0,"       LIST","       LIST","       LIST","       LIST","       AUTO","       LIST","       LIST","       LIST","       LIST","       LIST")).
    HudOptsR:add(list(0,  "   UP "   ,  "   UP "   ,  "   UP "   ,  "   UP "   ,  "   UP "   ,  "   UP "   ,  "   UP "   ,  "   UP "   ,  "   UP "   ,  "   UP "   )).
    HudOptsR:add(list(0,"    LIST"   ,"    LIST"   ,"    LIST"   ,"    LIST"   ,"    AUTO"   ,"    LIST"   ,"    LIST"   ,"    LIST"   ,"    LIST"   ,"    LIST"   )).
    HudOptsR:add(list(0,"    DOWN"   ,"    DOWN"   ,"    DOWN"   ,"    DOWN"   ,"    DOWN"   ,"    DOWN"   ,"    DOWN"   ,"    DOWN"   ,"    DOWN"   ,"    DOWN"   )).
    HudOptsR:add("AUTO").
    HudOptsR:add("      ").
    HudOptsR:add(list(0,"   SET AUTO"    ,"   SET AUTO"    ,"   SET AUTO"    ,"   SET AUTO"    ,"     CANCEL"     ,"           "    ,"           "    ,"           "    ,"           "    ,"           "    )).
    HudOptsR:add(list(0,"    "       ,"    "       ,"    "       ,"    "       ,"      "     ,"EXP "       ,"    "       ,"    "       ,"    "       ,"    "       )).
    local hdspot to 0.
    local ins to 0.
    local findtags to list("rotor","prop","Nuclear").
    FOR eg IN RANGE(1, prtTagList[engtag][0]+1) {
        if hdspot > enghud:length break.
        if dbglog > 2 log2file("        ENG:"+eg+"  SPOT:"+hdspot+" ins:"+ins).
        local md2 to 0.
        local p1 to prtTagList[engtag][eg].
        local p2 to prtList[engtag][eg][1].
        if p2:hassuffix("modes") if P2:modes:length > 1     set md2 to 102.
        if p2:hasmodule("FSengineBladed")                   set md2 to 102.
        if p2:hasmodule("FSswitchEngineThrustTransform")    set md2 to 102.
        if dbglog > 2 log2file("        PART:"+p2+"  TAG:"+p1+" md2:"+md2).
        set enghud[hdspot] to eg.
        if md2 > 0 set enghud[hdspot+1] to md2.
        if p1:CONTAINS("Main") {
            enghud:remove(hdspot). enghud:insert(0,eg).
            if md2 > 1 {enghud:remove(hdspot+1). enghud:insert(1,md2).set ins to ins+1.}
            set ins to ins+1.
        }else{
            for fndt in findtags{
                if p1:CONTAINS(fndt){
                    enghud:remove(hdspot). enghud:insert(ins,eg).
                    if md2 > 1 {enghud:remove(hdspot+1). enghud:insert(ins+1,md2).set ins to ins+1.}
                    set ins to ins+1.
                    break.
                }
            }
        }
        set hdspot to hdspot+1.
        if md2 > 0 set hdspot to hdspot+1.
    }
    FOR I IN RANGE(1, 10) {hsel:add(list(0,1,1,1)). }
    FOR i IN RANGE(0, 10) {hudopts:add(list(" "," "," "," ")).}
    FOR i IN RANGE(2, 10,2) {
      set HudOpts[I][1] to itemlist.
      set HudOpts[I][2] to prttaglist[1].
      set HSEL[I][1] to 1.
    }
    set eng to list(EMPTYHUD,EMPTYHUD,EMPTYHUD,EMPTYHUD,EMPTYHUD,EMPTYHUD,EMPTYHUD,EMPTYHUD).
    set PrvITM to EmptyHud.
    set ItmTrg to EmptyHud.
    set nxtITM to EmptyHud.
    set BTHD10 to EmptyHud.
    set BTHD11 to EmptyHud.
    set BTHD12 to EmptyHud.
    global trglst to getRTVesselTargets().
    global ItemNumPrv to 0.
    global tagNumPrv to 0.
    if loadattempts < 3 {
        if AutoDspList[0][0][0] > 0 set hsel[2][1] to AutoDspList[0][0][0].
        if AutoDspList[0][0][1] > 0 set hsel[2][2] to AutoDspList[0][0][1].
    }
      if hsel[2][2] >  HudOpts[2][2]:length set hsel[2][2] to 1.
      if hsel[2][1] >  HudOpts[2][1]:length set hsel[2][1] to 1.
      set checktime to time:seconds.
  }
  function HudFuctionMain{
    //#region update screen
    Set LastInput to time:seconds.
    CLEARSCREEN.
    speedboost("off").
    local isDone to 0.
    local refreshTimer to TIME:SECONDS.
    local refreshTimer2 to TIME:SECONDS.
    local buttonRefresh to 1.
    UPDATEHUDOPTS().
    set tagnumprv to 0.
    set ItemNumPrv to 0.
    updatehudFast().
    updatehudSlow().
    set RowSel to 2.
    UPDATEHUDOPTS().
   function updatehudSlow{
    if LastIn(-5) speedboost().
    IF dbglog > 2 log2file("UPDATEHUDSLOW").
      if hudop = 5{
        local enb to "".
        printline("",0,1).
        if AutoRscList[0][EnabSel]       = 1 set enb  to " VISIBLE  ". else set enb  to "SKIP OVER ".  
        if AutoValList[0][0][3][modesel] = 2 set enb2 to "SKIP OVER ".
        if AutoValList[0][0][3][modesel] = 1 set enb2 to " VISIBLE  ".
        if AutoValList[0][0][3][modesel] = 3 set enb2 to "SNSR ONLY ".
        set enb3 to MODElong[modesel].
        if modesel = 1 set enb2 to "          ".
        set eng[0] to EMPTYHUD. 
        set eng[1] to "AUTO MODE ".
        set eng[2] to " MODE VIS ".
        set eng[3] to "   MODE   ". 
        if h5mode <> 1 set eng[4] to "  DELAY   ". else set eng[4] to "**DELAY** ".
        set eng[5] to "VISIBILITY".
        set eng[7] to "   ITEM   ".
        local dctprint to "  NORMAL  ".
        if dctnmode > 0 {
          set dctprint to "WAIT 4 OTH".
          if dctnmode = 2 set dctprint to "LOCK 2 OTH".
          set eng[2]   to "   ITEM   ".
          set eng[3]   to "    TAG   ".
          set enb2 to ItemListHUD[HdItm].
          set enb3 to Prttaglist[HdItm][hdtag].
          set enb3 to makehud(enb3).
        }
        print " |"+dctprint+"|"+enb2+"|"+enb3+"|" at (0,1).
        print "|"+enb+"|"+HudOpts[2][1][EnabSel] at (45,1).
        print setdelay at (39,1).}
      else{
      set eng[0] to EmptyHud.
      set eng[1] to EmptyHud.
      set eng[2] to EmptyHud.
      set eng[3] to EmptyHud.
      set eng[4] to EmptyHud.
      set eng[5] to EmptyHud.
      set eng[7] to EmptyHud.
      local k to 0.
        for i in range(1,prtTagList[engtag][0]*2){
          local EngCur to enghud[i-1].
            if EngCur < 100 and EngCur > 0 {
                set k to k+1.
            LOCAL TG TO prtTagList[engtag][EngCur].
            LOCAL PT TO prtlist[engtag][EngCur][1].
            local j to i+1.//*2.
            set engsfx to makehud(Prttaglist[engtag][EngCur],5).
            if TG:CONTAINS("Main")     set engsfx to " MAIN ". else{
            if TG:CONTAINS("Scramjet") set engsfx to "SCRMJT". else{
            if TG:CONTAINS("Booster")  set engsfx to "BOOSTR". else{
            if TG:CONTAINS("Nuclear" ) set engsfx to "NUKENG". else{
            if TG:CONTAINS("rotor" )   set engsfx to " ROTOR". else{
            if TG:CONTAINS("prop" )    set engsfx to " PROP ". else{
            if TG:CONTAINS("vtol" )    set engsfx to " VTOL ". else{
            }}}}}}}
            local engact to 0.
            if pt:hasmodule("FSengineBladed"){if getEvAct(pt,"FSengineBladed","Status",30,-1,2):contains("inactive") set engact to 2. else set engact to 1.}
            else{
              if pt:hassuffix("ignition"){if pt:ignition = false set engact to 2. else set engact to 1.}
              else{
                  local lon to list("on", "activate").
                  local loff to list("off","shutdown").
                  local Elst to engmods.
                  //if Pt:hassuffix("modes") if Pt:modes:length > 1 if not Pt:primarymode set Elst to list("MultiModeEngine").
                  set engact to getactions("OnOff",Elst,engtag, EngCur,1,1,lon,loff,3).
              }
            }
            IF PT <> CORE:part {
            if engact = 1{SET eng[j-1] TO engsfx+" ON ".}ELSE{if engact = 2{SET eng[j-1] TO engsfx+" OFF".}else{SET eng[j-1] TO EmptyHud.}}
            IF PT:hasmodule("MultiModeEngine"){
                local Md to PT:getmodule("MultiModeEngine"):getfield("mode").
                if md = "Wet" set md to " AFTERBRN ". else if md = "ClosedCycle" set md to "CLOSED CYC". 
                if Pt:hassuffix("modes") if Pt:modes:length > 1 if PT:primarymode {SET eng[J] TO "  NORMAL  ".} ELSE  {SET eng[J] TO md.}
            }else{
                if pt:hasmodule("FSengineBladed") SET eng[J] TO " HOVER TGL".
                if pt:hasmodule("FSswitchEngineThrustTransform"){
                    local ccc to  getactions("OnOff",list("FSswitchEngineThrustTransform"),engtag, EngCur,1,1,list("reverse"), list("normal"),3).
                    if ccc > 0{
                    if ccc= 1 set eng[J] to " FWD THRST".
                    if ccc= 2 set eng[J] to "RVRS THRST". 
                    }else{SET eng[j] TO EmptyHud.}
                }
            }
            }else{SET eng[j] TO EmptyHud.}
            }
            if rowval = 0 {IF INTAKES {SET Eng[7] TO "INTAKES ON".} ELSE  {SET Eng[7] TO "INTAKE OFF".} }
             ELSE{IF MtrOps[hsel[2][1]][0] = 0 {SET Eng[7] TO "MTR ON BOT".} else {SET Eng[7] TO "MTR ON ALL".}}
        }
    }
      PRINT "|"+Eng[1]+"|"+Eng[2]+"|"+Eng[3]+"|"+Eng[4]+"|"+Eng[5]+"|"+Eng[7]+"|LEAVE PRGM|" at (0,0).
      if hudop <> 5 {if FuelUpdRate = "Slow" UpdateFuel().}
      if ship:hassuffix("CREWCAPACITY"){
        if ship:crewcapacity > 0{
          set crewcap to ship:crewcapacity.
          if ship:hassuffix("CREW") if ship:crew:length > 0 set CrewAct to ship:crew.}
      }
      SpeedBoost("off").
    }
   function updatehudFast {// top lists and warnings 
      if LastIn(-5) {SpeedBoost().}
      if hudop <> 5{
        set HUDTOP to GetHudTop().
        ListToSpace(HUDTOP[1],ploc2,4).
        ListToSpace(HUDTOP[0],ploc ,2).
        ListToSpace(HUDTOP[2],ploc3,3).
        if GrpDspList3[FLYTAG][1] = 6 and LinkLock = 0{
          LOCAL PR TO "                   ".
          IF FlState = "Flight" {SET  ss to "      SIDESLIP:"+round(bearing_between(ship,srfprograde,ship:facing),1). if colorprint = 1 {set pr to "    ".}}
          else{ set ss to "                ". if colorprint = 1 {set ss to "    ". set pr to "                ".}}
          PRINTLINE(pr+"HEADING:"+ ROUND(compass_and_pitch_for()[0],0)+"         PITCH:"  + ROUND(compass_and_pitch_for()[1],0)+"         ROLL:"   + ROUND(roll_for(),0)+ss,"WHT",13).
          set ln14 to 2.
        }
        if FuelUpdRate = "Fast" AND BtnActn = 0 UpdateFuel().
        SpeedBoost("off").
      }
      function ListToSpace{
        local parameter lin, loc, SKP IS 1.
        local st to 0.
        LOCAL SK IS 0.
        if hudop=5 set st to 1.
        for i in range(st,lin:length){
          PRINT lin[I] AT (loc,I+1). 
          if lin[I]:contains("            ") SET SK TO SK+1.
          IF SK = SKP break.
         }
      }
      function GetHudTop {
        set listout1 to list().
        set listout2 to list().
        set listout3 to list().
        local thrst is 0.
        list engines in eng_list.
        for engs in eng_list {
          if engs:flameout = false and engs:ignition = true {
            set thrst to thrst + engs:thrust.
          }
        }
        local gravity is ship:body:mu / (ship:altitude + ship:body:radius)^2.
        set twr to round(thrst / (ship:mass * gravity),2).
        set thrst to round(thrst, 0).
        if ship:hassuffix("deltav") listout1:add("|DltV:"+round(SHIP:DELTAV:CURRENT,0)+"      ").
        listout1:add("|THR: "+thrst+"      ").
        listout1:add("|TWR: "+TWR+"      ").
        IF FlState <> "Land"{ 
          listout1:add( "|PER: "+formatTime(eta:periapsis)+"  ").
          LOCAL AP TO formatTime(ETA:apoapsis).
          IF AP <> "passed" and AP <> 0 listout1:add( "|APO: "+AP+"  ").
        }
        IF steeringmanager:enabled = TRUE{
          IF HdngSet[3][4] > 0 and HdngSet[0][4] > 0{listout1:add("|SPDLOCK:"+HdngSet[0][4]+"("+round(SHIP:VELOCITY:SURFACE:MAG,0)+")"+glt(HdngSet[0][4],round(SHIP:VELOCITY:SURFACE:MAG,0))+"  ").}
          IF HdngSet[3][5] > 0 and HdngSet[0][5] > 0{listout1:add("|ALTLOCK:"+HdngSet[0][5]+"("+round(SHIP:ALTITUDE,0)+")"+glt(HdngSet[0][5],round(SHIP:ALTITUDE,0))+"  ").}
          IF HdngSet[3][6] > 0 and HdngSet[0][6] > 0{listout1:add("|VSPDLOK:"+HdngSet[0][6]+"("+round(SHIP:VERTICALSPEED,0)+")"+glt(HdngSet[0][6],round(SHIP:VERTICALSPEED,0))+"  ").}
        }
      //hudtop middle
       listout2:add(PADMID(SHIP:status,pwdt2)).
       listout2:add(PADMID(ItemList[hsel[2][1]]+":"+prtTagList[hsel[2][1]][hsel[2][2]],pwdt2)).
          if senselist[5] = 1{
            set biomecur to BSensor:getmodule("ModuleGPS" ):getfield("biome").
            If biomecur = "???" set biomecur to "UNKNOWN".
            listout2:add(PADMID(body:name+":"+BiomeCur,pwdt2)).
          }
      if body:atm:exists {
        set HdngSet[1][5] to body:atm:height.
        if FlState = "SpaceATM"  {listout2:add(PADMID("ATM HEIGHT:"+body:atm:height+" M",pwdt2)).} 
      }
        set foblink to foblink+1.
        if runauto = 3 {
          if foblink = 1      {listout2:add(PADMID("***AUTO ACTNS DISABLED***",pwdt2)). listout2:add(PADMID("******SET IN AG1******",pwdt2)). }else{listout2:add(PADMID("    ",pwdt2)). listout2:add(PADMID("******SET IN AG1******",pwdt2)).}
        }
      if fo = 1{if foblink = 1{listout2:add(PADMID("FLAMEOUT!",pwdt2)).}else{listout2:add(PADMID("    ",pwdt2)).}}
        if foblink = 2 set foblink to 0. 
        IF BRAKES = TRUE        listout2:add(PADMID("**BRAKE**",pwdt2)).
      if Radartag > 0 {if prtlist[radartag][1][1]:hasmodule("ModuleRadar"){
          LOCAL rdrmod to GetMultiModule(prtlist[radartag][1][1],"lock","ModuleRadar")[1].
          if wordcheck(rdrmod[0],"current locks") = 1 and rdrmod[1] > 0{listout2:add(PADMID("**LOCK**",pwdt2)).}
      }}
      if BDPtag > 0 {
        if getEvAct(prtlist[BDPtag][1][1],"BDModulePilotAI","deactivate pilot",1,3) = true {
            local ptmp to CheckTrue(30,prtlist[BDPtag][1][1],"BDModulePilotAI","standby mode","** AI PILOT STDBY **","** AI PILOT ON **",0,3).
            listout2:add(PADMID(ptmp,pwdt2)).
        }
      }
      if steeringmanager:enabled = false {IF MJB > 1{
        IF MJB = 2 listout2:add(PADMID("SAS: MECHJEB",pwdt2)).
        IF MJB = 3 listout2:add(PADMID("SAS: LANDING",pwdt2)).
        IF MJB = 4 listout2:add(PADMID("SAS: TRANSLATRON",pwdt2)).
        IF MJB = 5 listout2:add(PADMID("SAS: ASCENT",pwdt2)).
        }ELSE{if sas = true listout2:add(PADMID("SAS:"+SASMODE,pwdt2)). else listout2:add(PADMID("SAS OFF",pwdt2)).}}
      else{
        if HdngSet[3][4]+HdngSet[3][5]+HdngSet[3][6] = 0 listout2:add(PADMID("HEADING LOCK"+"-HD:"+HdngSet[0][1]+"("+round(compass_and_pitch_for()[0],0)+")"+glt(HdngSet[0][1],ROUND(compass_and_pitch_for()[0],0),1),pwdt2)).
         else {listout2:add(PADMID("AUTOPILOT"+"-HD:"+HdngSet[0][1]+"("+round(compass_and_pitch_for()[0],0)+")"+glt(HdngSet[0][1],ROUND(compass_and_pitch_for()[0],0),1),pwdt2)).
         IF steeringmanager:enabled = TRUE if abs(SteeringManager:ANGLEERROR) < 5 listout2:add(PADMID("MOVING TO HEADING")).
         }
        }
        IF MtrOps[hsel[2][1]][0] = 1 listout2:add(PADMID("***METER DISPLAY LOCKED***",pwdt2)).
        IF HLON = 1 listout2:add(PADMID("***HIGHLIGHTING ENABLED***",pwdt2)).
      //hudtop right
      //listout3:add("|THR"+SetGauge(round(throttle*100,0), 1, pwdt3-1)).
      LOCAL ECC TO ROUND(ship:electriccharge/ecmax*100,0).
      listout3:add("|ECG("+ECC+")"+SetGauge(ECC, 1, pwdt3-6)). 
      IF FlState = "Flight" listout3:add("|AOA: "+round(vertical_aoa(),1)+"   ").
      listout3:add("|Speed: "+round(SHIP:VELOCITY:SURFACE:MAG,0)+" M/S   ").
      LOCAL VSP TO round(SHIP:VERTICALSPEED  ,0).
      IF VSP > 0 SET VSP TO " "+VSP.
      IF STATUSFLY:CONTAINS(SHIP:status) listout3:add("|V-SPD:"+VSP+" M/S   ").
      listout3:add("|RDALT: "+round(ALT:RADAR-Height,0)+"  ").
      local lng to listout2:length+1.
      until listout2:length > 7 listout2:add("                          ").
      until listout3:length > 7 listout3:add("             ").
      until listout1:length > 7 listout1:add("             ").   
      return list(LISTOUT1,listout2,listout3).
    }
  }
   FUNCTION UPDATEHUDOPTS{//options, sidelist and bototm buttons
    if LastIn(-5) SpeedBoost().
    IF dbglog > 1 log2file("UPDATEHUDOPTS").
        if ship:resources:tostring:contains("liquidfuel"){if ROUND(ship:resources[RscNum["liquidfuel"]]:amount/ship:resources[RscNum["liquidfuel"]]:capacity*100,0) < 10 SET forcerefresh TO 1.}
        IF ship:resources:tostring:contains("ELECTRICCHARGE"){if ROUND(ship:resources[RscNum["ELECTRICCHARGE"]]:amount/ship:resources[RscNum["ELECTRICCHARGE"]]:capacity*100,0) < 10 SET forcerefresh TO 1.}
      //#region set hud vars
      if buttonRefresh > 0 and forcerefresh = 0 set forcerefresh to 1. 
      global itemnumcur to hsel[2][1].
      if itemnumcur <> ItemNumPrv and GrpDspList[itemnumcur][0] < prttaglist[itemnumcur][0]+1 {set hsel[2][2] to GrpDspList[itemnumcur][0].}
      global TagNumCur to hsel[2][2].
      local AutoCurMode to abs(AutoDspList[itemnumcur][TagNumCur]).
      set Curdelay to AutoTRGList[0][itemnumcur][TagNumCur].
      global tagnamecur to prttaglist[itemnumcur][TagNumCur].
      local npskp to 1.
      if itemnumcur <> AGTag and itemnumcur <> flytag and (itemnumcur <>CMDTag and TagNumCur < cmdln+1) set NpSkp to 0.
      set rowval to 0.
      if RowSel=1 set rowval to 1.
      IF NEWHUD = 1 set newhud to 0.
      IF itemnumcur <> ItemNumPrv or TagNumCur <> tagNumPrv {SET newhud TO 1. IF dbglog > 1 log2file("   NEWHUD").}
      if NEWHUD = 1 or forcerefresh > 0 or (hudop <> 5 and HUDOPPREV = 5) {
        SET WarnLst to "".
        if forcerefresh > 0 {SET BOTPREV TO "zz". SET STPREV TO "zz".}
        set hsel[2][3] to max(getgoodpart(itemnumcur,TagNumCur,1),1).
        global partnumcur to hsel[2][3].
        global currentPart to prtlist[itemnumcur][TagNumCur][partnumcur].
        if HlOn = 1 and hlparts <> 0 {if HLPARTS:enabled set hlParts:enabled to False.}
        if NpSkp = 0 {
        global CleanParts to CleanList(prtList[itemnumcur][TagNumCur], tagnamecur).
          if CleanParts:length > 0 {
            set hlParts to HIGHLIGHT(CleanParts, rgb(0,0,1)).
            IF hlparts <> 0 {
              if HlOn = 1 set hlParts:enabled to True. ELSE set hlParts:enabled to fALSE. 
            }
          }
        }
        SET DCPRes TO 0.
      global alttag to 0.
        if hudop <> 5 AND HUDOPPREV = 5 { PRINTLINE("",0,1).  PRINTLINE("",0,14).}
          set ItmTrg to grpopslist[itemnumcur][TagNumCur][GrpDspList[itemnumcur][TagNumCur]]. 
          set BTHD10 to grpopslist[itemnumcur][TagNumCur][GrpDspList2[itemnumcur][TagNumCur]]. 
          set BTHD11 to grpopslist[itemnumcur][TagNumCur][GrpDspList3[itemnumcur][TagNumCur]].
          set PrvITM TO CHECKOPT(ITEMLIST[0],itemnumcur,"-",6,1,1).
          set nxtITM TO CHECKOPT(ITEMLIST[0],itemnumcur,"+",6,1,1).
          if newhud = 1 printbothud().
      }

      if BtnActn = 1 {updatehudSlow(). return.}
          IF BtnActn = 0 {
            IF ROWVAL = 0 {
              set PrvGRP TO CHECKOPT(prtTagList[itemnumcur][0], TagNumCur,"-",7,1,1).
              set nxtGRP TO CHECKOPT(prtTagList[itemnumcur][0], TagNumCur,"+",7,1,1).
              PRINT "                               " AT (0,3).
              PRINT "                               " AT (0,7).
              PRINT PrvGRP AT (0,3).
              PRINT nxtGRP AT (0,7).
            }else{
              set PrvGRP TO "                               ".
              set nxtGRP TO "                               ".
            }
          }
      if AutoCurMode = 14 set StsSelection to abs(AutoValList[itemnumcur][TagNumCur]).
      if StsSelection > STATUSOPTS[0] set StsSelection to STATUSOPTS[0]. 
      if StsSelection = 0 set StsSelection to 1.
      if hudop =5 and HUDOPPREV <> 5 {
        set EnabSel to itemnumcur.
      }
      if hudop < 6 set HudOptsR[6] to AutoValList[itemnumcur][TagNumCur].
      //#endregion
      //#region check missing part
      SET  missingpart to 0.
      if alltagged:length <> ship:ALLTAGGEDPARTS():length partcheck().
      local pl to prtList[itemnumcur][TagNumCur].
      set pl to pl:sublist(1, pl:length).
      if NpSkp = 0{for p in pl{if not PrtListcur:contains(p) or BadPart(p , tagnamecur) set MissingPart to MissingPart+1.}}
      local dcpg to 0.
      if itemnumcur = dcptag{for p in pl{if p <> "" {IF p <> CORE:PART{set dcpg to 0.}}}}
      //#endregion
      //#region run on change
      if missingpart < prtlist[itemnumcur][TagNumCur]:length-1 and dcpg <> 1{
        if NEWHUD > 0 or forcerefresh > 0 {
        if MeterList[2][itemnumcur][0] <> 0 and hsel[2][3] <> partnumprv SetCurrentMeter().
        set partnumprv to partnumcur.
          if NEWHUD = 1 {
            set AutoSetAct to AutoTRGList[itemnumcur][TagNumCur].
            set autosetmode to autocurmode.
            set setdelay to curdelay.
            set AutoRstMode to autoRstList[itemnumcur][TagNumCur].
            if itemnumcur <> dcptag SET AutoValList[0][0][3][15] TO 0.
            SET LOADBKP TO 0. SET SAVEBKP TO 0. 
            LOCAL CLSKP TO 0.
            IF (itemnumcur = flytag AND TagNumCur = 1) or itemnumcur = agtag SET CLSKP TO 1.
            if (GrpDspList3[FLYTAG][1] <> 6 and RunAuto = 1 and itemnumcur <> scitag and CLSKP = 0) OR (forcerefresh > 0 and clskp = 0) PRINTLINE("",0,13).
            set botrow to bigempty2. 
            set BaySel to 1. 
            set fuelmon to 0. 
            if itemnumcur = FlyTag set AUTOHUD[1] to 1. 
            set axsel to 1. 
            set scipart to 1.
            if TagNumCur <> tagNumPrv {set GrpDspList[itemnumcur][0] to TagNumCur.}
            if AutoCurMode = 6 and autoRscList[itemnumcur][TagNumCur]:istype("string") set RscSelection to safekey(RscNum,autoRscList[itemnumcur][TagNumCur]). 
            set meterpart to 0.
          set hudopts[1][1] to "".
          set hudopts[1][2] to "".
          set hudopts[1][3] to "".
          }
          set MtrCur[5] to ActiveMeter[itemnumcur].
          if MeterList[2][itemnumcur][0] <> 0 {set DispInfo to 11. SetCurrentMeter().}else{
            set DispInfo to 1.
            set MtrCur[0] to 0.
            set MtrCur[1] to 100.
            set MtrCur[2] to 5.
            if MtrCur[5] < MtrCur[3] set MtrCur[5] to MtrCur[3].
            if MtrCur[5] > MtrCur[4] set MtrCur[5] to MtrCur[4].
          }
          set rowT1 to "".
          set rowT2 to "".
          set statusdispnum to GrpDspList[itemnumcur][TagNumCur].
          if GrpDspList[itemnumcur][TagNumCur]= 1 set statusdispnum to 3.
          if GrpDspList[itemnumcur][TagNumCur]= 5 set statusdispnum to 7.
          IF HUDOP <> 5{
          set ln14 to 0.
          if itemnumcur = lighttag { 
          if getactions("OnOff",MeterList[0][1],itemnumcur, TagNumCur,2,6,list("blink"),list("blink")) = 0 set bthd10 to EmptyHud.
          if currentPart:hasmodule("ModuleNavLight") and rowval = 1{
            set BTHD10 to SetButtonContent(meterlist[0][1],"activate flash","dectivate flash"," FLASH OFF"," FLASH ON ").
            set BTHD11 to SetButtonContent(meterlist[0][1],"activate double flash","dectivate double flash","DBFLSH OFF","DBFLSH ON ").
          }
          if TagNumCur = 1 AND ROWVAL = 0 {set BTHD11 to " SAVE BKP ". IF file_exists(autofileBAK) set BTHD10 to " LOAD BKP ". else set BTHD10 to EmptyHud. }
          }
          ELSE{
          if itemnumcur = AGtag {
            set DispInfo to 1.
           if TagNumCur = 11 AND THROTTLE > 0 {set GrpDspList[itemnumcur][TagNumCur] to 2. SET ItmTrg TO " TURN OFF ".}ELSE{ set GrpDspList[itemnumcur][TagNumCur] to 1. SET ItmTrg TO " TURN ON  ".}
            if TagNumCur = 1{
              if RunAuto = 1 set BTHD10 to " AUTO ON  ". ELSE IF RUNAUTO = 3 set BTHD10 to " AUTO OFF ". ELSE IF RunAuto = 2 OR RunAuto = 0 set BTHD10 to " AUTO WAIT".
              set bthd11 to " LIST AUTO".
            }
                if TagNumCur = 2 {set BTHD11 to " SAVE BKP ". IF file_exists(autofileBAK) set BTHD10 to " LOAD BKP ". }
                if tagNumcur = 3 {
                if HLon = 1 set BTHD10 to "HGHLGT ON ". else set BTHD10 to "HGHLGT OFF".
              }
                if tagNumcur = 4 {
                  LOCAL PLC TO 35.
                  IF ROWVAL = 0{
                    PRINTLINE(" Processing Speed: "+Removespecial(speeds[0][SPEEDSET[0]],"  ")+":EST EC per Second:"+round((speeds[1][SPEEDSET[0]]*0.000004*25),2),mtrcolor((SPEEDSET[0]/(speeds[0]:length-1))*100),13).
                    PRINTLINE(" BOOST Speed     : "+Removespecial(speeds[0][SPEEDSET[1]],"  ")+":EST EC per Second:"+round((speeds[1][SPEEDSET[1]]*0.000004*25),2),mtrcolor((SPEEDSET[1]/(speeds[0]:length-1))*100),14).
                    set ln14 to 2.
                    set BTHD10 to speeds[0][SPEEDSET[0]].
                    set BTHD11 to speeds[0][SPEEDSET[1]].
                    PRINT "                       " at (35,heightlim-3).
                  }
                  ELSE{
                    PRINTLINE(" Power save Processing Speed: "+Removespecial(speeds[0][SPEEDSET[2]],"  ")+":EST EC per Second:"+round((speeds[1][SPEEDSET[2]]*0.000004*25),2),mtrcolor((SPEEDSET[2]/(speeds[0]:length-1))*100),13).
                    PRINTLINE(" Power save BOOST Speed     : "+Removespecial(speeds[0][SPEEDSET[3]],"  ")+":EST EC per Second:"+round((speeds[1][SPEEDSET[3]]*0.000004*25),2),mtrcolor((SPEEDSET[3]/(speeds[0]:length-1))*100),14).
                    set ln14 to 2.
                    set BTHD10 to speeds[0][SPEEDSET[2]].
                    set BTHD11 to speeds[0][SPEEDSET[3]].
                    PRINT "| PWR SAVE |          |" at (35,heightlim-3).
                  }
                  if printpause = 0 {
                    PRINT "|PROCESSING|   BOOST  |" at (34,heightlim-2).
                    PRINT "|   SPEED  |   SPEED  |" at (34,heightlim-1).
                  }
              }
            if rowsel = 1{
              //if tagNumcur = 2{
             //   set BTHD10 to "RFRSH HUD ". set BTHD11 to "RFRSH INFO".
            //        PRINTLINE(" HUD refreshRate: "+refreshRateSlow+" SECONDS"+" INFO refreshRate: "+refreshRateFast+" SECONDS","WHT",14).  set ln14 to 1.
             // }
              if tagNumcur = 10{
                if dbglog = 0 set BTHD10 to "  LOG OFF ". else if dbglog = 1 set BTHD10 to "  LOG ON  ".if dbglog = 2 set BTHD10 to "LOG VRBOSE".  if dbglog = 3 set BTHD10 to "LOG OVRKLL".
                if debug  = 0 set BTHD11 to " DEBUG OFF". else set BTHD11 to " DEBUG ON ".
                PRINTLINE(" ONLY ENABLE LOGGING IF YOU ARE HAVING A PROBLEM","RED",14).
                set ln14 to 1.
              }
              }
          }
          ELSE{
          if itemnumcur = Flytag {
            set DispInfo to 52.
            if TagNumCur = 1 {
              set ln14 to 2.
               set trglst to getRTVesselTargets(2).
              if rowval = 1 {
                set BTHD11 to "NEXT OPTN ". 
                if apsel = 3 set zop to 2. 
                if zop = 1 set BTHD10 to "ONE 2 CRNT". else set BTHD10 to "ONE 2 ZERO".
              if hdngset[3][axsel] = 1 set ItmTrg to " MODE ON  ". else set ItmTrg to " MODE OFF ".
              if apsel = 1 or axsel = 7 or axsel = 9 if AUTOHUD[1] > 3 set AUTOHUD[1] to 3.
               }
              else{set BTHD10 to "ALL 2 CRNT".}
            }
            else{
              set BTHD10 to EmptyHud.
              set BTHD11 to emptyhud.
            }
          }
          ELSE{ 
          if itemnumcur = CMDtag {
            if getactions("OnOff",list("ModuleScienceContainer"),itemnumcur, TagNumCur,2,6,list("collect all"),list("collect all")) = 0 set bthd10 to EmptyHud.
            if TagNumCur > cmdln {set ItmTrg to "  TOGGLE  ". set bthd10 to "DSBL MCHJB".}
          }
          ELSE{
          if itemnumcur = geartag  {
            if AutoBrake = 0 set BTHD10 to " BRAKE OFF". ELSE
            if AutoBrake = 1 set BTHD10 to " BRAKE ON ". ELSE
            if AutoBrake = 2 set BTHD10 to "AUTO BRAKE". 
              if rowval = 1 {
                IF CurrentPart:hasmodule("ModuleWheelSuspension") set ItmTrg to CheckTrue(3,currentPart, "ModuleWheelSuspension","spring strength"  ,"SPRNG MAN ","SPRNG AUTO"). ELSE{set ItmTrg to EmptyHud.}
                IF CurrentPart:hasmodule("ModuleWheelBase")       set BTHD10 to CheckTrue(3,currentPart, "ModuleWheelBase"      ,"friction control" ,"FRCTN MAN ","FRCTN AUTO"). ELSE{set BTHD10 to EmptyHud.}
                IF CurrentPart:hasmodule("ModuleWheelSteering")   set BTHD11 to CheckTrue(3,currentPart, "ModuleWheelSteering"  ,"steering response","STEER MAN ","STEER AUTO"). ELSE{set BTHD11 to EmptyHud.}
              }
          }
          ELSE{
          if itemnumcur = baytag{SET DISPINFO TO 33.}
          ELSE{
          if itemnumcur = FRNGtag {set ItmTrg to CheckTrue(3,currentPart, "ModuleProceduralFairing","deploy"  ,"  DEPLOY  "," DEPLOYED ").}
          ELSE{
          if itemnumcur = anttag {
            set DispInfo to 21. 
          if rtech <> 0{
            set ln14 to 1.
            set trglst to getRTVesselTargets().
            if rowval=1 and meterlist[0][0]:contains("target"){
              set PrvGRP TO CHECKOPT(trglst[0], anttrgsel,"-",trglst,1,1).
              set nxtGRP TO CHECKOPT(trglst[0], anttrgsel,"+",trglst,1,1).
              if trglst[anttrgsel] = getEvAct(CurrentPart,"ModuleRTAntenna","target",30) set ItmTrg to " CRNT TRG ". else set ItmTrg to "SET TARGET".}
            }
               if GetActions("ONOFF",MeterList[1][itemnumcur],itemnumcur, TagNumCur,1,6,list("extend","deploy","Activate"),list("retract","close")) = 0 set itmtrg to EmptyHud.
               if GetActions("ONOFF",MeterList[1][itemnumcur],itemnumcur, TagNumCur,3,6,list("transmit")) = 0 set BTHD11 to EmptyHud.
              }
          ELSE{
          if itemnumcur = Docktag {
            set dispinfo to 21.
          if getactions("OnOff",list("ModuleToggleCrossfeed"),itemnumcur, TagNumCur,1,6,list("enable"),list("disable")) = 0 set bthd11 to EmptyHud.
          if getactions("OnOff",MeterList[1][itemnumcur] ,itemnumcur, TagNumCur,1,6,list("OPEN","TOGGLE","CLOSE")) = 0 set bthd10 to EmptyHud.
          if currentPart:hassuffix("HASPARTNER") IF currentPart:HASPARTNER = TRUE  set GrpDspList[itemnumcur][TagNumCur] to 2. ELSE set GrpDspList[itemnumcur][TagNumCur] to 1.
          if currentPart:hassuffix("STATE") IF currentPart:STATE ="DISABLED" set GrpDspList2[itemnumcur][TagNumCur] to 3.
          if rowval = 1{if getEvAct(CurrentPart,"ModuleDockingNode","control from here",3) set ItmTrg to "CNTRL FROM".}
          }
          ELSE{
            if itemnumcur = CntrlTag {
            local cnt to 0.
              for Cfld in CntrlFldList{
                local Ctag to MeterList[0][2][0]:find(Cfld).
                IF Ctag > -1 set MeterList[0][2][1][Ctag] to 0-CNTRLLimLst[TagNumCur][cnt]+"/"+CNTRLLimLst[TagNumCur][cnt]+"/1".
                set cnt to cnt+1.
                SET REMETER TO 1.
              }
            }
          ELSE{
          if itemnumcur = ISRUTag {set DispInfo to 41.SET HDXT TO "RSRC".}
          ELSE{
          if itemnumcur = RBTTag {
            if currentPart:hasmodule("ModuleRoboticController"){
              for i in RANGE(1,10,3){
                SET modulelist[0][itemnumcur][i] TO "ModuleRoboticController". 
              }
              set ItmTrg to "PLAY/PAUSE".
              set BTHD10 to "LOOP MODE ".
              set BTHD11 to "DIRECTION ".
              IF ROWVAL = 1 set BTHD11 to "ENAB/DISAB".
            }
              else{ 
              if autoRstList[0][0][tagnumcur] = 0 set BTHD11 to "  NO LOCK ".       
              ELSE if autoRstList[0][0][tagnumcur] > 0 set BTHD11 to "AUTO:"+autoRstList[0][0][tagnumcur]+" SEC".
              local count to 0.
              for MD in MeterList[0][1]{
                if CurrentPart:modules:contains(MD){
                  for i in RANGE(1,11,3){
                    SET modulelist[0][RBTTag][i] TO MD. 
                  }
                  if MD = "ModuleRoboticServoPiston" and fieldlist[1] = "target extension"{                               
                    if CurrentPart:title:contains("1p2") set mtrcur[7][1] to "0.8".
                    if CurrentPart:title:contains("1p4") set mtrcur[7][1] to "2.4".
                    if CurrentPart:title:contains("3p6") set mtrcur[7][1] to "1.6".
                    if CurrentPart:title:contains("3pt") set mtrcur[7][1] to "4.8".
                  }
                  if MD = "ModuleRoboticServoHinge" and fieldlist[1] = "target angle"{
                    if CurrentPart:title:contains("G-00") {set mtrcur[7][0] to "-90". set mtrcur[7][1] to "90".}
                    if CurrentPart:title:contains("G-11") {set mtrcur[7][0] to "-90". set mtrcur[7][1] to "90".}
                  }                            
                  break.
                }set count to count+1.
              }
            }
          }
          else{
          if itemnumcur = SMRTtag {
                if currentpart:hasmodule("Timer"){
                    local ccc to  getactions("OnOff",list("Timer"),itemnumcur, TagNumCur,1,1,list("use minutes"), list("use seconds")).
                    if ccc > 0{
                    if ccc= 1 set BTHD10 to "  SECONDS ".
                    if ccc= 2 set BTHD10 to "  MINUTES ". 
                    }
                    set ItmTrg to SetButtonContent(list("Timer"),"Start countdown","","   START  ","  RUNNING ").
                }
                set BTHD11 to SetButtonContent(MeterList[0][1],"Reset","Reset","   RESET  ","   RESET  ").
                if currentpart:hasmodule("smartsrb") set ItmTrg to EmptyHud.
          }else{
          if itemnumcur = scitag {
            SET STPREV TO "zzz".
            set meterpart to 0.
            set scanlist to list().
            if currentpart:hasmodule("ModuleResourceScanner"){
              for i in range (0,currentpart:modules:length-1){
                if currentpart:modules[i] = "ModuleResourceScanner" scanlist:add(currentpart:getmodulebyindex(i):allfieldnames[0]+":"+currentpart:getmodulebyindex(i):getfield(currentpart:getmodulebyindex(i):allfieldnames[0]):tostring).
              }
              local scl to max(0,scanlist:length-1).
              set Lscroll to list(min(Lscroll[0],scl),scl).
            }
            set DispInfo to 12.
            local ccc to  getactions("OnOff",list("scansat"),itemnumcur, TagNumCur,2,1,list("start"), list("stop")).
            if ccc > 0{
              if ccc= 1 set bthd11 to "START SCAN".
              if ccc= 2 set bthd11 to "STOP  SCAN". 
            }
              for md in sciModData{
              if currentpart:hasmodule(md){
                local PM to currentpart:GetModule(md).
                if pm:hassuffix("data"){
                  if pm:Hasdata {
                    local test to Removespecial(pm:data[0]:title," while").
                    set test to Removespecial(test," just").
                    local Xdata to round(pm:data[0]:transmitvalue,2).
                    local Sdata to round(pm:data[0]:sciencevalue,2).
                    local lmt to 13+Sdata:tostring:length+Xdata:tostring:length.
                    if test:tostring:length > WidthLim-lmt set test to test:substring(0,WidthLim-lmt).
                    local brp to test+"-(RTN:"+Sdata+" XMIT:"+Xdata+")".
                    local brpc to "GRN".
                    if colorprint = 1 and brp:length < widthlim-8 set brpc to "WHT".
                    set botrow to GetColor(test+"-(RTN:"+Sdata+" XMIT:"+Xdata+")",brpc).
                    set BTHD10 to " TRANSMIT ".
                  }
                }
                if currentpart:hasmodule("scansat"){
                  local mdl to currentpart:getmodule("scansat").
                  set SciDsp to mdl:allfieldnames.
                  if SciDsp:contains("scan altitude"){
                    local scalt to mdl:getfield("scan altitude").
                    set scalt to scalt:split(">").
                    local IdealAlt to scalt[1].
                    set scalt to scalt[0]:split("-").
                    set scalt[0] to scalt[0]+"000".
                    set scalt[1] to scalt[1]:REPLACE("km", "000"). 
                    set IdealAlt to IdealAlt:REPLACE("km Ideal", "000"). 
                    SET scalt[0] to removeletters(SCALT[0],", :").
                    SET scalt[1] to removeletters(SCALT[1],", :").
                    SET IdealAlt to removeletters(IdealAlt,", :").
                    local altmin to scalt[0]:tonumber.
                    local altmax to scalt[1]:tonumber.
                    local altidl to idealalt:tonumber.
                    local po to bigempty2.
                    if SHIP:ALTITUDE < altmin set po to " TOO LOW! INCREASE ALT BY "+ (ALTMIN-ROUND(SHIP:altitude,0))+"M TO RUN. MIN:("+ALTMIN+")             ".
                    if SHIP:ALTITUDE > altmax set po to " TOO HIGH! DECREASE ALT BY "+((ROUND(SHIP:altitude,0))-altmax)+"M TO RUN. MAX("+ALTMAX+")             ".
                    if SHIP:ALTITUDE > altmin      and SHIP:ALTITUDE < altmax      { set po to " WITHIN SCAN ALT.".
                      if SHIP:ALTITUDE < altidl*.9 set po to PO+"INCREASE BY "+ (altidl*.9-ROUND(SHIP:altitude,0)) +"M TO REACH IDEAL RANGE:("+altidl*.9+"-"+altidl*1.1+")             ".
                      if SHIP:ALTITUDE > altidl*1.1 set po to PO+"DECREASE BY "+(ROUND(SHIP:altitude,0)-altidl*1.1)+"M TO REACH IDEAL RANGE:("+altidl*1.1+"-"+altidl*.9+")             ".
                    }
                    if SHIP:ALTITUDE > altidl*.9 and SHIP:ALTITUDE < altidl*1.1 set po to " WITHIN IDEAL RANGE:("+altidl*.9+"-"+altidl*1.1+")                            ".
                    LOCAL PO3 TO "                     ".
                    if bthd11 = "STOP  SCAN" set po3 to " SCANNER DEPLOYED                      ". ELSE SET PO3 TO " SCANNER RETRACTED                      ".
                    if SciDsp:contains("scan type") SET PO3 TO " SCAN:"+mdl:getfield("scan type")+":"+po3.
                    if po3:length > WidthLim set po3 to po3:substring(0,(WidthLim-2)).
                    printline(po3,0,13). 
                    printline(po,0,14).
                    set ln14 to 2.
                  }
                  if SciDsp:length > 0{
                  set hudopts[1][1] to "Scan Info:"+scipart.  
                  set hudopts[1][2] to ":"+SciDsp[scipart-1].
                  set hudopts[1][3] to ":"+mdl:getfield(SciDsp[scipart-1]).
                }else{set hudopts[1][1] to "No scan info".}
                set ln14 to 2.
                }else{
                   PRINTLINE("",0,14). if GrpDspList3[FLYTAG][1] <> 6 PRINTLINE("",0,13).
                  set SciDsp to pm:alleventnames.
                  if SciDsp:length = 0 set SciDsp to pm:allactionnames.
                  if SciDsp:length > 0{
                  set hudopts[1][2] to scipart.  
                  set hudopts[1][3] to ":"+SciDsp[scipart-1].
                  set hudopts[1][1] to "Experiment:".
                }else{set hudopts[1][1] to "No experiment or data full".}
                break.
              }}
            }
          if getactions("OnOff",SciModAlt,itemnumcur, TagNumCur,1,6,list("review")) <> 0 set itmtrg to "  DELETE  ".
          if getactions("OnOff",list("SCANexperiment"),itemnumcur, TagNumCur,0,6,list("analyze")) <> 0 set itmtrg to "  ANALYZE ".
          if getactions("OnOff",SciModAlt,itemnumcur, TagNumCur,3,6,list("transmit")) = 0 and BTHD10 <> " TRANSMIT "{
            local actn to GetActions(1,AnimModAlt,itemnumcur, TagNumCur,2,1,list("deploy","extend"),list("retract","close")).
            if actn = 0 {set BTHD10 to EmptyHud.} else{ if actn = 3 set actn to 1.
              if actn < 3 {
                set GrpDspList2[itemnumcur][TagNumCur] to actn+2. 
                set BTHD10 to grpopslist[itemnumcur][TagNumCur][GrpDspList2[itemnumcur][TagNumCur]]. 
              }
            }
          }
          if getactions("OnOff",list("ModuleScienceContainer"),itemnumcur, TagNumCur,3,6,list("collect")) <> 0 {
            local amt to list(0,0,0).
            set cnt to 0.
            local spc to "     ".
            if colorprint = 1 set spc to "   ".
            if  currentpart:hasmodule("ModuleScienceContainer"){
            set BTHD11 to " CLCT SCI ".
              for dt in currentpart:getmodule("ModuleScienceContainer"):data {
                set cnt to cnt+1.
                set amt[0] to round(amt[0]+dt:sciencevalue,2).
                set amt[1] to round(amt[1]+dt:transmitvalue,2).
                set amt[2] to round(amt[2]+dt:DATAAMOUNT,2).
              }
            set botrow to GetColor(cnt+" Experiments"+SPC+"Data:"+amt[2]+spc+"Science Val:"+amt[0]+spc+"Xmit Val:"+amt[1]+spc,"WHT").
            }
          }else{
            if GetActions(1,SciModAlt,itemnumcur, TagNumCur,3,6,list("reset"), list("reset")) <> 0 {set BTHD11 to "  RESET   ".}
          }
            }
          else{
          if itemnumcur = EngTag  {
            getEvAct(CurrentPart,"ModuleGimbal","show actuation toggles",10).
            if currentpart:hassuffix("ignition"){if currentpart:ignition = false set GrpDspList[itemnumcur][TagNumCur] to 1. else set GrpDspList[itemnumcur][TagNumCur] to 2.}
            IF currentpart:hasmodule("MultiModeEngine"){}else{
                set BTHD10 to emptyhud.
                IF currentpart:hasmodule("FSengineBladed"){
                    if rowval = 1 {
                        SET HDXT TO "OPTN".
                        set BTHD10 to CheckTrue(30, currentpart, "FSengineBladed","thr keys" ,"*THR KEYS*"," THR KEYS ").
                        set BTHD11 to CheckTrue(30, currentpart, "FSengineBladed","thr state","*THR STAT*"," THR STAT ").
                    }ELSE{
                        set BTHD10 to " HOVER TGL".
                        set BTHD11 to CheckTrue(30, currentpart, "FSengineBladed","steering" ," STEER ON "," STEER OFF").
                    }
                }
                if currentpart:hasmodule("FSswitchEngineThrustTransform"){
                    local ccc to  getactions("OnOff",list("FSswitchEngineThrustTransform"),itemnumcur, TagNumCur,1,1,list("reverse"), list("normal")).
                    if ccc > 0{
                    if ccc= 1 set BTHD10 to " FWD THRST".
                    if ccc= 2 set BTHD10 to "RVRS THRST". 
                    }
                }
                
            }
          }
          ELSE{
          IF itemnumcur = Inttag {
            //local ccc to  getactions("OnOff",list("ModuleResourceIntake"),itemnumcur, TagNumCur,1,1,list("open"), list("close")).
            //if ccc > 0  set GrpDspList[itemnumcur][TagNumCur] to ccc.
          }
          ELSE{
          IF itemnumcur = labtag {
            if getactions("OnOff",list("ModuleScienceContainer"),itemnumcur, TagNumCur,3,6,list("collect")) <> 0 set BTHD11 to " CLCT SCI ".
          }
          ELSE{
          IF itemnumcur = slrtag {
            if getactions("OnOff",list("ModuleAnimateGeneric"),itemnumcur, TagNumCur,1,6,list("extend","toggle"),list("retract","toggle")) = 0 set bthd10 to EmptyHud.
          }
          ELSE{
          if itemnumcur = WMGRtag   {if rowval = 0 {set BTHD11 to "NEXT TEAM ".} if rowval = 1 and Radartag > 0{ set BTHD10 to "NEXT TRGT ".}}
          ELSE{
          if itemnumcur = BDPtag   {
            set ItmTrg to CheckTrue(1,currentPart,"BDModulePilotAI","deactivate pilot"," TURN OFF "," TURN ON  ").
          }
          ELSE{
          if itemnumcur = dcptag   {
            SET AutoValList[0][0][3][15] TO 1.
          if DcpPrtList[TagNumCur][1]:hassuffix("resources") {
          if DcpPrtList[TagNumCur][1]:typename = "string" {set fuelmon to 0.}
            else{
              IF DCPRes = 0 {
                local rscl to getRSCList(DcpPrtList[TagNumCur][1]:resources).
                set prsclist to rscl[0].
                set prsclist2 to rscl[2].
                set pRscNum to rscl[1].
                SET DCPRes TO 1.
              }
              if newhud = 1 {
                if autoRscList[itemnumcur][TagNumCur]:istype("string") {
                      set RscSelection to safekey(pRscNum,autoRscList[itemnumcur][TagNumCur]). } 
                else {set RscSelection to autoRscList[itemnumcur][TagNumCur].}
              }
              if HudOpts[2][2][TagNumCur]:contains("Payload") or prsclist:length=0 {set fuelmon to 0.}else{set fuelmon to 1.}
              if rowval=1{SET HDXT TO " RSC".
              if prsclist2:length > 0 {
                if prsclist2[0] <> "" and fuelmon = 1 and rowval = 1{
                  set PrvGRP TO CHECKOPT(prsclist2:length-1, RscSelection,"-",prsclist2,0,1).
                  set nxtGRP TO CHECKOPT(prsclist2:length-1, RscSelection,"+",prsclist2,0,1).
                }}
              }
            }
          }else set fuelmon to 0.
            set dispinfo to 0.
            if getactions("OnOff",list("ModuleToggleCrossfeed"),itemnumcur, TagNumCur,1,6,list("enable"),list("disable")) = 0 set bthd10 to EmptyHud.
            if currentpart:hasmodule("ModuleAnimateGeneric"){
              local pm to currentpart:getmodule("ModuleAnimateGeneric"):allactionnames.
              set pm2 to currentpart:getmodule("ModuleAnimateGeneric"):ALLEVENTNAMES.
              set pm3 to list().
              for itm in pm pm3:add(itm).
              for itm in pm2 pm3:add(itm).
              for k in range (0,pm3:length){
                  SET BTHD11 TO EmptyHud.
                  if pm3[k]:contains("inflate") set BTHD11 to " INFLATE  ".
                  if pm3[k]:contains("deflate") set BTHD11 to " DEFLATE  ".
                  if pm3[k]:contains("deploy")  set BTHD11 to "  DEPLOY  ".
              }
            }   
          }
          ELSE{
          if mks = 1 {
            if itemnumcur = DEPOtag   {set DispInfo to 21.}
            ELSE{
            if itemnumcur = PWRTag {set DispInfo to 41.
            if currentPart:hasmodule("USI_InertialDampener"){
              local OnOff to CurrentPart:Getmodule("USI_InertialDampener"):alleventnames[0].
              if OnOff = "ground tether: off" set BTHD11 to " TETHR OFF".
              if OnOff = "ground tether: on" set BTHD11 to  " TETHR ON ".
            }
            SET HDXT TO "    ".
            set BayLst to GetMultiModule(CurrentPart,"recipe").
            if currentpart:hasmodule("USI_Converter"){ set BayTrg to GetMultiModule(CurrentPart,"","USI_Converter").}
            }
            else{
            if itemnumcur = MksDrlTag {
              set DispInfo to 41.
              }
              else{
              if itemnumcur = CnstTag {}
              else{
              if itemnumcur = DcnstTag {}
              else{
              if itemnumcur = habTag {
                if currentpart:hasmodule("USI_BasicDeployableModule"){
                if currentpart:getmodule("USI_BasicDeployableModule"):hasfield("paid"){ 
                  set PaidMeter to currentpart:getmodule("USI_BasicDeployableModule"):getfield("paid")*100.
                  set DispInfo to 61. set alttag to 1.
                  set hudopts[1][2] to ":".
                  set hudopts[1][1] to "Paid".
                  set hudopts[1][3] to SetGauge(PaidMeter/100*100,1,widthlim-7).
                }}
              }
              else{}}}}}}
          }
          else{}}}}}}}}}}}}}}}}}}}}}}
           if DispInfo = 11 AND REMETER = 1 SetCurrentMeter().
            if MtrCur[5] < MtrCur[3] set MtrCur[5] to MtrCur[3].
            if MtrCur[5] > MtrCur[4] set MtrCur[5] to MtrCur[4].
          if hudop <> 5 set actnlist to list(1,ItmTrg,BTHD10,BTHD11,EmptyHud).
          }
          IF HUDOP = 5{ //set auto section
            set HudOptsR[5] to"AUTO"+MODESHRT[AutoSetMode].
            set PrvITM to actnlist[AutoSetAct].
            set ItmTrg to MODELONG[AutoSetMode].
            local topprint to bigempty.
            set BTHD10 TO HudRstMdLst[AutoRstMode].
            set BTHD11 TO "   CLEAR  ".
            if h5mode <> 1 set eng[4] to "  DELAY   ". else set eng[4] to "**DELAY** ".
            PRINTLINE("|  ACTION  |   MODE   |").
            print " AFTER TRIGGER" at (32,17).
            PRINT HudOpts[2][1][itemnumcur]+ ":" + HudOpts[2][2][TagNumCur] + ":" + HudOpts[2][3] at (2,hudstart-2).
            LOCAL MODEPRINT TO Removespecial(ItmTrg,"   ").
            set   MODEPRINT TO Removespecial(MODEPRINT,"  ").
            IF MODEPRINT = "ALTAGL" SET MODEPRINT TO "ALT AGL".
            if AutoSetAct > actnlist:length-1 set AutoSetAct to 1.
            LOCAL ActionPrint TO actnlist[AutoSetAct].
            if ActionPrint:LENGTH > 0 {IF ActionPrint[ActionPrint:LENGTH-1] <> " " SET ActionPrint TO ActionPrint+" ".}
            IF ActionPrint[0] <> " " SET ActionPrint TO " "+ActionPrint.
            LOCAL AftTrgPrint TO "".
            local ValuePrint to "".
            LOCAL DelayPrint TO "".
            local infoprint to bigempty2.
            print "                              " at (50,10).
            if AutoSetMode = 6 {
              set nxtITM TO "  SEl RSC ".
              local RscNme to RscList[RscSelection][0].
              LOCAL RSNM TO RscList[RscNum[RscNme]][1].
              print  RSNM AT (WidthLim-RSNM:length,10).
              if ship:resources:tostring:contains(RscNum[RscNme]:tostring){ 
                LOCAL RESPCT TO ROUND(ship:resources[RscNum[RscNme]]:amount/ship:resources[RscNum[RscNme]]:capacity*100,0).
                  local lm to 66-RSNM:length-ClrMin. 
                  local lcl to MtrColor(RESPCT).
                  local prf to RSNM+"("+RESPCT+"%)".
                  SET InfoPrint to prf+GETCOLOR(SetGauge(RESPCT,0,widthlim-prf:length-9),lcl).
                }
                  set ValuePrint to AUTOHUD[0]+" %".
            }
            else{
                set nxtITM TO EmptyHud.   
                if AutoSetMode = 2{ set ValuePrint to  AUTOHUD[0]+      " M/S".  set infoprint to "CURRENT SPEED:"+round(SHIP:VELOCITY:SURFACE:MAG,0)+" M/S".}else{
                if AutoSetMode = 3{ set ValuePrint to  AUTOHUD[0]+      " M".    set infoprint to "CURRENT ALTITUDE:"+round(SHIP:ALTITUDE,0)+" M".
                if body:atm:exists  set topprint to " ATMOSPHERE HEIGHT:"+body:atm:height+" M".   
                }else{
                if AutoSetMode = 4{ set ValuePrint to  AUTOHUD[0]+      " M AGL".set infoprint to "CURRENT RADAR ALTITUDE:"+round(ALT:RADAR-Height,0)+" M AGL".
                if body:atm:exists  set topprint to " ATMOSPHERE HEIGHT:"+body:atm:height+" M". 
                }else{
                if AutoSetMode = 5{ set ValuePrint to  AUTOHUD[0]+      " %".    set infoprint to "CURRENT ELECTRIC CHARGE:"+round(ship:electriccharge/ecmax*100,0)+" %".}else{
                if AutoSetMode = 7{ set ValuePrint to  AUTOHUD[0]+      " %".    set infoprint to "CURRENT THROTTLE:"+round(THROTTLE,0)+" THRTL".}else{
                if AutoSetMode = 8{ set ValuePrint to  AUTOHUD[0]+      " kPa".  set infoprint to "CURRENT PRESSURE:"+round(SHIP:SENSORS:PRES,0)+" kPa".}else{
                if AutoSetMode = 9{ set ValuePrint to  AUTOHUD[0]*0.01+ " EXP".  set infoprint to "CURRENT SUN EXPOSURE:"+round(SHIP:SENSORS:LIGHT,0)+" EXP".}else{
                if AutoSetMode = 10{set ValuePrint to  AUTOHUD[0]+      " K".    set infoprint to "CURRENT TEMPERATURE:"+round(SHIP:SENSORS:TEMP,1)+" K".}else{
                if AutoSetMode = 11{set ValuePrint to  AUTOHUD[0]*0.01+ " M/S2". set infoprint to "CURRENT GRAVITY:"+round(ship:sensors:grav:mag,1)+" M/S2".}else{
                if AutoSetMode = 12{set ValuePrint to  AUTOHUD[0]*0.01+ " G".    set infoprint to "CURRENT ACCELERATION:"+round(ship:sensors:acc:mag,1)+" G".}else{
                if AutoSetMode = 13{set ValuePrint to  AUTOHUD[0]*0.01      .    set infoprint to "CURRENT THRUST TO WEIGHT:"+TWR.}else{
                if AutoSetMode = 14 {
                  set nxtITM TO " SEL MODE ".
                  if StsSelection = 0 set StsSelection to 1. 
                  if StsSelection > STATUSOPTS[0] set StsSelection to STATUSOPTS[0]. 

                  print STATUSOPTS[StsSelection] AT (WidthLim-STATUSOPTS[StsSelection]:length,10).
                  set ValuePrint to  AUTOHUD[0].    
                  set infoprint to "TRIGGER ON STATUS:"+STATUSOPTS[StsSelection]+"             CURRENT STATUS:"+SHIP:status. 
                  IF AutoRstMode = 2 or AutoRstMode = 3 set AutoRstMode to 4.  
                }
                else{
                if AutoSetMode = 15{
                  set nxtITM TO "  SEl RSC ".
                  LOCAL RSNM TO prsclist[RscSelection][1].
                  print  RSNM AT (WidthLim-RSNM:length,10).
                  local lm to 56-ClrMin-RSNM:length.
                  local fmtr to GetFuelLeft(DcpPrtList[TagNumCur],3,0,RscSelection).
                  local lcl to MtrColor(fmtr).
                  set ValuePrint to  AUTOHUD[0]+      " FUEL". set infoprint to "CURRENT "+RSNM+" IN PART:"+ "("+fmtr+"%)"+GETCOLOR(SetGauge(fmtr,0,lm),lcl).
                }
                }}}}}}}}}}}
              }
            }
            IF  AutoRstMode = 1 SET AftTrgPrint TO "DISABLE".
            IF  AutoRstMode = 2 if AUTOHUD[2] = " UNDER " { SET AftTrgPrint TO "SWITCH TO OVER".}ELSE{SET AftTrgPrint TO "SWITCH TO UNDER".}.
            IF AUTOHUD[2] = " UNDER " { SET ValuePrint TO "UNDER "+ValuePrint.
              IF AutoRstMode = 4 {SET AftTrgPrint TO "WAIT FOR UNDER".}
              IF AutoRstMode = 3 {SET ActionPrint TO "RESET ". SET AftTrgPrint TO "WAIT FOR OVER".}
            }
            IF AUTOHUD[2] = "  OVER " {SET ValuePrint TO "OVER "+ValuePrint.
              IF AutoRstMode = 3 {SET AftTrgPrint TO "WAIT FOR OVER".}
              IF AutoRstMode = 4 {SET ActionPrint TO "RESET ".  SET AftTrgPrint TO "WAIT FOR UNDER".}
            }
            if setdelay > 0{SET DelayPrint TO "WAIT "+setdelay+" SEC".} ELSE SET DelayPrint TO "".
            LOCAL LCL TO "WHT".
            if dctnmode = 1 {      
              set topprint to "WONT START DETECTION UNTIL AFTER "+REMOVESPECIAL(ItemListHUD[HdItm]," ")+":"+Prttaglist[HdItm][hdtag]+" IS TRIGGERED".
              SET LCL TO "ORN".
            }
            if dctnmode = 2 {      
              set topprint to "WILL TRIGGER WHEN "+REMOVESPECIAL(ItemListHUD[HdItm]," ")+":"+Prttaglist[HdItm][hdtag]+" IS TRIGGERED.".
              SET LCL TO "YLW".
            }
            if h5mode = 1 {      
              set topprint to "CURRENTLY SETTING DELAY TIME. PRESS DELAY TO SET".
              SET LCL TO "YLW".
            }
            PRINTLINE(" "+topprint,LCL,13).
            PRINTLINE(" "+InfoPrint,0,14). 
            set ln14 to 2.
            PRINTLINE("",0,16). 
            IF AutoSetMode <> 1{
              if AutoSetMode = 14 { set valueprint to STATUSOPTS[StsSelection]. IF AUTOHUD[0] = 0 set autohud[0] to 1.}
                IF AUTOHUD[0] <> 0 {
                  PRINTLINE( DelayPrint+ActionPrint+"when "+MODEPRINT+" is "+ValuePrint+" then "+AftTrgPrint,0,16).
                   print ActionPrint AT (WidthLim-ActionPrint:length,ACP).
                  }
                ELSE{PRINT "VALUE NOT SET" at (1,16).}
            }ELSE{    PRINT "MODE NOT SET" at (1,16). PRINT "               " AT (widthlim-15,ACP).}
          }
          ELSE{ //hudop <> 5
           set HudOptsR[5] to"AUTO"+MODESHRT[AutoCurMode].
              SETHUD().
              if DispInfo = 1 AND NEWHUD = 0{
                local lcl to "GRN".
                if GrpDspList[itemnumcur][TagNumCur] = 1 set lcl to "RED".
                if GrpDspList[itemnumcur][TagNumCur] = 2 set lcl to "CYN".
                set HudOpts[1][1] to getcolor(modulelist[2][itemnumcur][statusdispnum],lcl).
                printline(" "+HudOpts[1][1]+ HudOpts[1][2]+ HudOpts[1][3],0,hudstart-1).
              }
              IF DispInfo > 1{UPDATESTATUSROW().}
                //#region hudset high
                  PRINTLINE(" "+HudOpts[2][1][itemnumcur]+ ":" + HudOpts[2][2][TagNumCur] + ":" + HudOpts[2][3],0,hudstart-2).
                  printbothud().
                //#endregion
            IF HudOptsR[6] = 0 {SET OVUN TO "     ".}else{
              IF HudOptsR[6] < 0 {IF AutoRstMode = 3 set ovun to "RESET ". ELSE SET OVUN TO "UNDER ". set AUTOHUD[2] to " UNDER ". }
              IF HudOptsR[6] > 0 {IF AutoRstMode = 4 set ovun to "RESET ". ELSE SET OVUN TO " OVER ". set AUTOHUD[2] to "  OVER ". } 
            }
            if h5mode = 1  set ovun to "DELAY ".
            SET numloc1 to widthlim-6-HudOptsR[6]:tostring:length.
            local valprint to HudOptsR[6].
            if AutoCurMode = 9 or AutoCurMode = 11 or AutoCurMode = 12  or AutoCurMode = 13 {set valprint to valprint*.01. set NUMLOC1 to NUMLOC1-2.}
            PRINT "                         " AT (55,acp+2).
            if AutoCurMode <> 1 PRINT OVUN+ABS(valprint) AT (NUMLOC1,acp+2).
            set TrgLim to 1.
            if bthd10 <> emptyhud set TrgLim to 2.
            if bthd11 <> emptyhud set TrgLim to 3.
            set actnlist[0] to TrgLim.
            if AutoTRGList[itemnumcur][TagNumCur] > trglim set AutoTRGList[itemnumcur][TagNumCur] to trglim.
            
          }
        }
      }
      else{//if no part
      if dbglog > 1 log2file("    NO PART"+ItemList[itemnumcur]+":"+prtTagList[itemnumcur][TagNumCur]).
            set hudopts[1][1] to "NO PART".
            set hudopts[1][2] to "".
            set hudopts[1][3] to "".
            set DispInfo to 10.
            set BTHD10 to EmptyHud. 
            set BTHD11 to EmptyHud.
            set ITMTRG to EmptyHud.
            PRINTLINE().
            PRINTLINE(HudOpts[2][1][itemnumcur]+ ":" + HudOpts[2][2][TagNumCur] + ":" + HudOpts[2][3],0,hudstart-2). 
            PRINTLINE(HudOpts[1][1]+ HudOpts[1][2]+ HudOpts[1][3],0,hudstart-3).
            SET autoTRGList[0][itemnumcur][tagnumcur] TO 0-abs(AutoCurMode)-1.
      }
            set ItemNumPrv to itemnumcur.
            set tagNumPrv to TagNumCur.
      //#endregion
      //#region MainPrint
          //#region print if change
          local acpadd to 0.
          IF HUDOP <> HUDOPPREV or forcerefresh > 0{
          PRINT HudOptsR[5] AT (widthlim-8,acp+1).
              PRINT "            " AT (0,3).
              PRINT "            " AT (0,7).
            print "                         " at (55,acp+3).
             IF HUDOP <> 5 PRINT HudOptsL[1][HUDOP] AT (0,1). PRINT HudOptsR[1][HUDOP] AT (widthlim-11,1).
              PRINT HudOptsL[2][HUDOP] AT (0,2). PRINT HudOptsR[2][HUDOP] AT (widthlim-6,2).
              PRINT HudOptsL[3][HUDOP] AT (0,5). PRINT HudOptsR[3][HUDOP] AT (widthlim-8,5).
              PRINT HudOptsL[4][HUDOP] AT (0,6). PRINT HudOptsR[4][HUDOP] AT (widthlim-8,6).
               if hudop < 6 {                    PRINT HudOptsR[7][HUDOP] AT (widthlim-11,12).
                                                 PRINT HudOptsR[8][HUDOP] AT (widthlim-4,13).}
              if hudop=5 {
                local numloc1 to widthlim-12-AUTOHUD[0]:tostring:length.
                local valprint to AUTOHUD[0].
                local adjprint to AutoAdjByLst[AUTOHUD[1]].
                if AutoSetMode = 9 or AutoSetMode = 11 or AutoSetMode = 12 or AutoSetMode = 13 {set valprint to valprint*.01. set NUMLOC1 to NUMLOC1-2. set adjprint to adjprint*.01.}
                print "NOT SAVED" AT (61,acp+1).
                ///print "          " AT (70,acp+2).
                PRINT "              "+AUTOHUD[2]+ABS(valprint) AT (NUMLOC1-9,acp+2).
                if AutoSetMode = 14 PRINT "   ON STATUS" AT (widthlim-12,acp+2).
                PRINT adjprint AT (0,6).
                PRINT AUTOHUD[2] AT (0,3).}
              else{//hudop <> 5
              PRINT PrvGRP AT (0,3).
              PRINT nxtGRP AT (0,7).
                if hudop < 6 and AutoCurMode <> 1{
                  if AutoSetAct > actnlist:length-1 set AutoSetAct to 1.  
                    print actnlist[AutoSetAct] AT (WidthLim-actnlist[AutoSetAct]:length,ACP).
                    if AutoCurMode = 14 AND AutoValList[itemnumcur][TagNumCur] > 0 {print STATUSOPTS[StsSelection] AT (WidthLim-STATUSOPTS[StsSelection]:length,acp+3). set acpadd to 1.}
                    else{
                      if AutoCurMode = 6 {
                        local rscnm to autoRscList[itemnumcur][TagNumCur].
                        if rscnm:istype("string") set rscnm to RscNum[rscnm].
                        local arsc to RscList[rscnm].
                        print  arsc[1]+"("+ROUND(ship:resources[arsc[3]]:amount/arsc[2]*100,0)+"%)" AT (widthlim-5-arsc[1]:length,acp+3). set acpadd to 1.}
                      else{
                        if AutoCurMode = 15 AND PRscList:LENGTH > 0 and prsclist[0] <> ""{
                          local ARSC to PRscList[autoRscList[itemnumcur][TagNumCur]][0].
                          if itemnumcur = dcptag {print  arsc AT (widthlim-arsc:length,acp+3). set acpadd to 1.}
                        }
                      }
                    }
                }else{print "               " AT (65,acp).PRINT "                    " AT (60,9).PRINT "                    " AT (60,10).PRINT "                    " AT (60,11).}// print "                         " at (55,acp+2). print "                         " at (55,acp+3).}
              }
              
          IF HUDOP > 6 {
            print "       Set" at (widthlim-10,8).
            print "           "+HDXT at (65,9). 
            IF ROWVAL = 1 and meterpart = 2 and MtrCur[4] > 0{ //HDXT = "OPTN" AND
              local po1 to meterlist[0][0].
              LOCAL po2 TO MtrCur[5]+" OF "+MtrCur[4].
              local po3 to "        ".
              if meterlist[0][0] = "Option Not Available" {
                IF MtrCur[5] < MtrCur[4]{local cnt to 0. 
                  until meterlist[0][0] <> "Option Not Available" or (MtrCur[5] = MtrCur[4] and cnt > MtrCur[4]) {
                    set MtrCur[5] TO CHANGESEL(MtrCur[4],MtrCur[5],"+",MtrCur[3]). 
                    set ActiveMeter[itemnumcur] to MtrCur[5]. 
                    SetCurrentMeter().
                    set cnt to cnt+1.
                  }
                }set forcerefresh to 2. set newhud to 2.
              }else{if adjmode = "num" set po3 to "Adj By: "+mtrcur[2].}
              print "          "+po1 at (WIDTHLIM-po1:LENGTH-10,10).
              print "          "+po2  at (WIDTHLIM-po2:LENGTH -10,11).
              print "          "+po3 at (WIDTHLIM-po3:LENGTH-10,12).
            }
            if itemnumcur = FlyTag{
               print "   "+AutoAdjByLst[AUTOHUD[1]] at (widthlim-AutoAdjByLst[AUTOHUD[1]]:TOSTRING:length-3,10).
               print " NXT ROW" at (widthlim-8,12).
            }
          }else{ IF AutoCurMode <> 1 {
            if AutoCurMode = 14 PRINT "   ON STATUS" AT (widthlim-12,acp+2).
            if autoTRGList[0][itemnumcur][TagNumCur] > 0{print "DELAY "+autoTRGList[0][itemnumcur][TagNumCur] AT (widthlim-6-autoTRGList[0][itemnumcur][TagNumCur]:tostring:length,acp+4).}else{print "            " at (widthlim-12,acp+4).}
          }
            if hudop = 6{
              print "       RUN" at (widthlim-10,8).
              print "     EXPERIMENT" at (widthlim-15,9).
            }
          }
          printbothud().
          }
          SET HUDOPPREV TO HUDOP.
          if forcerefresh = 1 set forcerefresh to 0.
          //#endregion
          //#region alwaysprint
          //#region warnings and notiifications
          set LinkLock to 0.
          if AutoDspList[0][itemnumcur][TagNumCur][0] <> 0 {
            if AutoDspList[0][itemnumcur][TagNumCur][0]:tostring <> "0" {
              set ln14 to 2.
              local TrgPrint to "".
              local splt to AutoDspList[0][itemnumcur][TagNumCur][0]:split("-").
              if splt:length = 3 {PRINTLINE("WONT START DETECTION UNTIL AFTER "+REMOVESPECIAL(ItemListHUD[splt[0]:tonumber]," ")+":"+Prttaglist[splt[0]:tonumber][splt[1]:tonumber]+" IS TRIGGERED","ORN",13). set TrgPrint to "WAIT 4 OTHER".set LinkLock to 1.}
              if splt:length = 4 {PRINTLINE("WILL TRIGGER WHEN "+REMOVESPECIAL(ItemListHUD[splt[0]:tonumber]," ")+":"+Prttaglist[splt[0]:tonumber][splt[1]:tonumber]+" IS TRIGGERED","YLW",13). set TrgPrint to "LOCK 2 OTHER". set LinkLock to 2.}
              print  TrgPrint AT (widthlim-TrgPrint:length,acp+4-linklock+acpadd).
            }
          }
          if loadbkp = 2 {set line to 1. set isdone to 1.}
          if SAVEbkp = 2 {SaveAutoSettings(2). printline(" BACKUP FILE SAVED","CYN").  PRINTLINE("",0,13).  PRINTLINE("",0,14).  SET SAVEBKP TO 0. }
          if SHIP:status <> ShipStatPREV{
            IF STATUSSPACE:CONTAINS(SHIP:status){SET FlState to "Space". if body:atm:exists SET FlState to "SpaceATM".}
            IF STATUSLAND:CONTAINS(SHIP:status) SET FlState to "Land".
            if ship:status = "FLYING" SET FlState to "Flight".
            set ShipStatPREV to ship:status.
          }
          for i in range(1,prtTagList[engtag][0]+1){
            set fo to 0.
            if prtlist[engtag][I][1]:HASSUFFIX("FLAMEOUT"){
              if prtlist[engtag][I][1]:FLAMEOUT and PrtListcur:contains(prtlist[engtag][I][1]){set fo to 1. BREAK.}
            }
          }

          LOCAL PRLCL TO 14.
          IF RUNAUTO <> 1 SET PRLCL TO 13.
          if (itemnumcur = LIGHTTAG AND TagNumCur = 1) or (itemnumcur = AGTAG AND TagNumCur = 2 and rowval <> 1){
            if loadbkp = 1  {IF file_exists(autofileBAK) print " CLICK ONE MORE TIME TO LOAD FROM BACKUP " at (1,PRLCL). ELSE print " NO BACKUP FILE TO LOAD FROM " at (1,PRLCL).}
            if SAVEbkp = 1  {print " CLICK ONE MORE TIME TO SAVE TO BACKUP " at (1,PRLCL).}
          }
          if LastIn(60) and pscnt < 3{set pscnt to pscnt+1.
             PRINTQ:PUSH(" POWER SAVE MODE ACTIVATED NON-BOOST CPU SPEED REDUCED"+"<sp>"+"WHT"). 
             set CPUSPD to SPEEDSET[2].
          }
          //#endregion
          FOR clearPips IN RANGE(0, 4){PRINT " " at (0,hudstart-clearPips).}
          PRINT ">" at (0,hudstart-RowSel).
          //#endregion
          //#endregion
            function SetCurrentMeter{
              local parameter Nin is 4, mtrmin is 1.
              set ActionWait to 1.
            local Modulesin  to MeterList[1][itemnumcur]:copy.
            local InfoListin to MeterList[2][itemnumcur]:copy.
            LOCAL infolistOUT TO infolistIN:COPY.
            SET LCP TO prtlist[itemnumcur][TagNumCur][partnumcur].
            local po1 to "Option Not Available".
            if ModulesIn:LENGTH = 1 set modulesin to splitlist(ModulesIn[0]).
            set Nin to (Nin*3)-2.
            local mdmax to 0.
            local mdout to 0.
            local mtrskp to 0.
            LOCAL CT TO 1-NEWHUD.
            IF REMETER = 1 SET CT TO 0.
            if MtrCur[5] < MtrCur[3] set MtrCur[5] to MtrCur[3].
            if MtrCur[5] > MtrCur[4] set MtrCur[5] to MtrCur[4].
            if InfoListin[0]:typename = "Scalar" set mdmax to InfoListin:length-1.
            if dbglog > 2 log2file("    SetCurrentMeter:"+LISTTOSTRING(Modulesin)+" NumIn:"+Nin+" mdmax:"+mdmax+" NEWHUD:"+NEWHUD).  
            local cnt1 to 0.
            FOR MD IN Modulesin{
              if LCP:hasmodule(MD){set cnt1 to cnt1+1.
                if mdmax > 0 and cnt1 = 1{
                  for mdcur in range(1,mdmax+1){if mdcur = mdmax+1 break.
                  set mdtmp to splitlist(infolistin[mdcur][0][0],1)[0].
                    if dbglog > 2 log2file("      SetListCur:("+mdcur+"):"+LISTTOSTRING(mdtmp)).
                      if mdtmp:contains(MD) {set infolistOUT to infolistin[mdcur]. set  MeterList[2][itemnumcur][0] to mdcur. set mdout to mdcur. break.}
                    }
                  }
                  IF CT = 0 set FieldList to SplitDisplayList(Modulesin:copy, infolistOUT:copy,1, 2):copy.
                  SET CT TO CT+1.
                  if FieldList[3]:length > 1 set mtrcur[7] to FieldList[3][MtrCur[5]]:split("/").
                  if FieldList[4]:length > 1 set mtrcur[8] to FieldList[4][MtrCur[5]]:split("/").
                  if mtrcur[7]:length > 0{
                  local mtrlast to mtrcur[7][mtrcur[7]:length-1].
                    if mtrcur[7]:length = 3{//set min max normal mode
                    set dbgtrk to "1a".
                      set MtrCur[0] to BoolNum(mtrcur[7][0]).
                      set MtrCur[1] to BoolNum(mtrcur[7][1]). 
                      if newhud > 0 OR mtrcur[7][2] = 0 {set MtrCur[2] to BoolNum(mtrcur[7][2]). set newhud to 0.}
                    }else{
                      if mtrlast = -1{//match # to name in next row mode
                        set MtrCur[0] to 1.
                        set MtrCur[1] to mtrcur[7]:length-1.
                        set MtrCur[2] to 1.
                      }
                      if mtrlast = -2{.//Dont use meter mode. 
                        set MtrCur[0] to 0.
                        set MtrCur[1] to 0.
                        set MtrCur[2] to 0.
                        set mtrskp to 1.
                      }
                    }
                    if mtrlast = -1 { 
                      set NextGoodField to 0.
                      if mtrcur[8]:length > 0 AND mtrcur[6]> -1{
                        IF mtrcur[8][mtrcur[6]] = "NoAct"{
                          IF lastdir = "+"    {FOR I IN RANGE (mtrcur[6],MTRCUR[1]+1)  IF mtrcur[8][i] <> "NoAct" {SET NextGoodField to i. break.}
                          if NextGoodField = 0 FOR I IN RANGE (0,MTRCUR[1]+1)    iF mtrcur[8][i] <> "NoAct" {SET NextGoodField to i. break.}
                        }
                        else{                  FOR I IN RANGE (mtrcur[6],-1)          IF mtrcur[8][i] <> "NoAct" {SET NextGoodField to i. break.}
                          if NextGoodField = 0 FOR I IN RANGE (MTRCUR[1],-1)    IF mtrcur[8][i] <> "NoAct" {SET NextGoodField to i. break.}}
                                          log2file("                  NOACT:"+MTRCUR[5]+" NextGood:"+NextGoodField+" dir ="+lastdir).
                        }
                      }
                    }
                  }
                  SET modulelist[0][itemnumcur][Nin] TO "". 
                  set modulelist[2][itemnumcur][Nin] to "".
                  if getEvAct(LCP,MD,MeterList[0][2][0][MtrCur[5]],3,0,3) or mtrskp = 1{
                    SET modulelist[0][itemnumcur][Nin] TO MD.
                    set modulelist[2][itemnumcur][Nin] to MeterList[0][2][0][MtrCur[5]].
                    if dbglog > 2 log2file("                Option set to:"+modulelist[2][itemnumcur][Nin]).
                    set po1 to MeterList[0][2][0][MtrCur[5]].
                    set mtrcur[6] to mtrcur[7]:find(FieldList[2][MtrCur[5]]:TOSTRING).
                    BREAK.
                  }
              }
            }

            if fieldlist[2]:length > 0 IF METERPART = 0 set MeterPart to 1.
            set MeterList[0][0] to po1. 
            set MeterList[0][1] to Modulesin:copy. 
              if MtrCur[5] < MtrCur[3] set MtrCur[5] to MtrCur[3].
              if MtrCur[5] > MtrCur[4] set MtrCur[5] to MtrCur[4].
            if dbglog > 2 log2file("                MTROUT:"+LISTTOSTRING(MeterList[0][1])+"  optout:"+MeterList[0][0]).
            set actionwait to 0.            
            return list(InfoListin,mdout).
          }
            FUNCTION SetButtonContent{
                local parameter MDL is meterlist[0][1], fldon is "zz", fldoff is "zz", RtnOn is " TURN ON  ", RtnOff is " TURN OFF ".
                local rtn to EmptyHud.
                if not MDL:typename:contains("list")  set MDL to list(MDL).
                    local ccc to  getactions("OnOff",mdl,itemnumcur, TagNumCur,1,1,list(FldOn), list(fldoff)).
                    if ccc > 0{
                    if ccc= 1 set rtn to RtnOn.
                    if ccc= 2 set rtn to RtnOff. 
                    }
                    return rtn.
              }
            function printbothud{
            local parameter 
            ItemNum is hsel[2][1],
            TAGNUM IS HSEL[2][2].
              if colorprint > 0{
                local itmtrg2 to itmtrg.
                local PrvITM2 to PrvITM.
                PRINT "|          |          |          |          |          |" at (17,heightlim).
                if hudop <> 5{
                  if findcl2:HASKEY(itmtrg){set itmtrg2 to  getcolor(itmtrg,FindCl2[itmtrg]).}
                  else{
                    if GrpDspList[ItemNum][TAGNUM]  = 1 set itmtrg2 to "[#00FFFF]"+itmtrg+"{COLOR}".
                    if GrpDspList[ItemNum][TAGNUM]  = 2 set itmtrg2 to "[#ff0000]"+itmtrg+"{COLOR}".
                  }
                }
                else{
                  if GrpDspList[itemnumcur][TagNumCur] = 1 set PrvITM2 to "[#00FFFF]"+PrvITM+"{COLOR}".
                  if GrpDspList[itemnumcur][TagNumCur] = 2 set PrvITM2 to "[#ff0000]"+PrvITM+"{COLOR}".
                }
                PRINT " |"+PrvITM2+"|"+ItmTrg2+"|"+nxtITM+"|"+BTHD10+"|" at (0,heightlim). 
                PRINT BTHD11+"|" at (62,heightlim).
              }else{PRINT " |"+PrvITM+"|"+ItmTrg+"|"+nxtITM+"|"+BTHD10+"|"+BTHD11+"|"+BTHD12+"|          |" at (0,heightlim).}
            }
          SpeedBoost("off").
   }
   FUNCTION UPDATESTATUSROW{//bottom row
    LOCAL br TO 0.
    local lcl to 0.
    IF dbglog > 2 log2file("UPDATESTATUSROW:"+newhud+" DispINfo:"+DispInfo).
                LOCAL LF TO 0.
                if newhud = 1 and DispInfo > 1 PRINTLINE("",0,14). 
                if ship:resources:tostring:contains("liquidfuel"){//if ship resources has resource
                  LOCAL FuelLeft TO ROUND(ship:resources[RscNum["liquidfuel"]]:amount/ship:resources[RscNum["liquidfuel"]]:capacity*100,0).
                  if FuelLeft < 1                                                         {set WarnOut to " WARNING FUEL EMPTY                                                   ". set lcl to "RED".}.else
                  if FuelLeft < 5                                                         {set WarnOut to " WARNING FUEL CRITICALLY LOW                                          ". set lcl to "ORN".}.else
                  if FuelLeft < 10                                                        {set WarnOut to " WARNING FUEL LOW                                                     ". set lcl to "YLW".}
                  if FuelLeft < 10 {SET LF TO 1.}
                }
                IF LF <> 1 AND itemnumcur <> SCITAG{
                  if runauto = 2 {
                    if SHIP:status = "PRELAUNCH" {                                        set WarnOut to " PRELAUNCH. AUTO TRIGGERS DISABLED UNTIL AFTER LAUNCH.                 ". set lcl to "YLW".}
                      else {if IsPayload[0] = 1 {set RunAuto to 0. SET refreshRateSlow TO 10. set refreshRateFast to 10. set RFSBAak to refreshRateSlow.}else set runauto to 1. 
                                                                                          set WarnOut to "".}}
                    ELSE{
                      if runauto = 3                               {                      set WarnOut to " AUTO TRIGGERS DISABLED. CHANGE SETTING IN ACTION GROUP ITEM.          ". set lcl to "ORN".}
                    else{
                      if runauto = 0                               {                      set WarnOut to " PAYLOAD PART. AUTO TRIGGERS DISABLED UNTIL 10 SECONDS AFTER DECOUPLE.". set lcl to "YLW".}
                    ELSE{
                      if AutoDspList[itemnumcur][TagNumCur] > 0 and runauto <> runautobak{set WarnOut to "".}
                    }}}
                    if ship:electriccharge < 10                                          {set WarnOut to " WARNING LOW ELECTRIC CHARGE. CPU SPEEDBOOST DISABLED                ". set lcl to "RED".}
                }
                if WarnLst <> WarnOut {
                  if WarnOut <> "" set ln14 to 1.
                  printline(WarnOut,lcl,14).
                }
                  set WarnLst to WarnOut.
                set runautobak to runauto.
              if hudop = 5 or itemnumcur = dcptag return.
              if newhud = 0{
              //set ActionWait to 1.
              if LastIn(-5) SpeedBoost().
              set lcl to 0.
                local HudItem to hsel[2][1].
                local hudtag to hsel[2][2].
                local HudPrt to hsel[2][3].//getgoodpart(HudItem,hudtag,1).
                 local fl to "".
                 local halfmtr to "". 
                 set br TO rowsel.
                  if  HudItem <> sciTag and printpause = 0 set botrow to bigempty2.
                 if DispInfo > 10 {
                    local pl to prtList[HudItem][hudtag].
                    set pl to pl:sublist(1, pl:length).
                    local p to prtList[HudItem][hudtag][HudPrt].
                      IF HudItem = SMRTTAG{ //update rate override section
                              if p:hasmodule("Timer") {
                                local j to getEvAct(P,"Timer","remaining time",30).
                                if not j:istype("boolean") and j <> 0 lastin().
                              }
                      }
                  if DispInfo = 11 {IF meterpart > 0 {Multimeter().}ELSE{QuickField(p).}}
                  else{
                  if DispInfo <30 {
                    if DispInfo = 21 {
                      if HudItem = anttag {
                        quickfield(p).
                        if rtech <> 0 {
                          if rtech:hasKSCconnection(ship) = True {printline("CONNECTED TO KSC WITH DELAY OF:"+rtech:kscdelay(ship)+"          ","WHT",14). set ln14 to 1.}
                          IF getEvAct(P,"ModuleRTAntenna","target",3)  and meterlist[0][0]:contains("target"){
                            local ct to getEvAct(P,"ModuleRTAntenna","target",30).
                            if ct:contains("VESSEL(") set ct to ct:substring(8,ct:length-10).
                            if ct:contains("BODY(") set ct to ct:substring(5,ct:length-7).
                            IF BR=1{
                            local lcl2 to "orn".
                            if trglst[anttrgsel] <> ct {set HudOpts[1][1] to getcolor("set target to:"+trglst[anttrgsel],"ORN").}else{set HudOpts[1][1] to getcolor("current target:"+trglst[anttrgsel],"WHT").}
                            //printline(" "+HudOpts[1][1]+ HudOpts[1][2]+ HudOpts[1][3],0,hudstart-1).
                            }
                          }
                        }
                      }
                      IF HudItem = DOCKTAG{
                        if P:hassuffix("STATE") SET HudOpts[1][1] TO P:STATE.
                        if P:hassuffix("DOCKEDSHIPNAME") SET HudOpts[1][3] TO P:DOCKEDSHIPNAME.
                        Set HudOpts[1][2] TO "               ".
                       set  botrow to FormatFields(p,MeterList[0][1],MeterList[0][2],1,0)[0].
                      }
                    }
                    if DispInfo = 22 {set HudOpts[1][3] to getstatus(HudItem,hudtag,2,1).}
                    else{
                    if DispInfo = 23 {
                      if HudItem = RBTTag{ // off
                        if P:hasmodule("ModuleRoboticController"){
                          LOCAL PLP TO getstatus(HudItem,hudtag,1,1,-1).
                          IF PLP = 0 SET PLP TO "Playing". else set PLP to "Paused".
                          set PLP to "Status:"+PLP.
                          LOCAL LPM TO getstatus(HudItem,hudtag,2,1,-1).
                          IF LPM = 0 SET LPM TO "None". 
                          IF LPM = 1 set LPM to "Repeat".
                          IF LPM = 2 set LPM to "Ping Pong".
                          IF LPM = 3 set LPM to "None-Restart".
                          set LPM to "Loop Mode:"+LPM.
                          LOCAL TDR TO getstatus(HudItem,hudtag,3,1,-1).
                          IF TDR = 0 SET TDR TO "Foward". else set TDR to "Reverse".
                          set TDR to "Play Direction:"+TDR.
                          set HudOpts[1][3] to getstatus(HudItem,hudtag,4,1,-1)+" | "+PLP+" | "+LPM+" | "+TDR.
                          set plspd to getEvAct(P,"ModuleRoboticController","Play Speed",30,-1,2).
                          if plspd:istype("string") set plspd to plspd:tonumber.
                          set botrow to "Play Speed:"+SetGauge(Removespecial(plspd/mtrcur[1])*100,1,widthlim-16).
                        }
                        else{
                          local aaa to getstatus(HudItem,hudtag,MtrCur[5],1,2).
                          if BR >0{
                              LOCAL MDPRINT TO modulelist[2][RBTTag][MtrCur[5]*3-2]. 
                              if MDPRINT:tostring:contains("(%)") set mtrcur[1] to 100.
                            IF AAA <> "                                    " {
                              local localguage to Removespecial(aaa:tonumber/mtrcur[1])*100. 
                              if br > 0  set botrow to MDPRINT+SetGauge(localguage,1,widthlim-4-MDPRINT:length).
                              SET BOTPREV TO "000".
                            }
                            print MDPRINT at (WidthLim-MDPRINT:length,10).
                          }
                            QuickField(p).
                        }
                      }
                    }}
                  }
                  else{
                  if DispInfo <40 {
                    if DispInfo = 33 {
                      local LCL2 to "GRN".
                      if GrpDspList[itemnumcur][TagNumCur] = 1 set LCL2 to "RED".
                      if GrpDspList[itemnumcur][TagNumCur] = 2 set LCL2 to "CYN".
                      set HudOpts[1][1] to getcolor(modulelist[2][itemnumcur][statusdispnum],LCL2).
                      printline(" "+HudOpts[1][1]+ HudOpts[1][2]+ HudOpts[1][3],0,hudstart-1).
                      set  botrow to FormatFields(p,MeterList[0][1],MeterList[0][2],1,0)[0].
                    }ELSE{
                    }
                  }
                  else{
                  if DispInfo <50 {
                    if DispInfo = 41 {
                      local op to 2.
                      IF HudItem = DrillTag set op to 3.
                      IF HudItem = MksDrlTag set op to 4.
                      IF BR=1 {
                      local aaa to getstatus(HudItem,hudtag,op,1).
                      IF AAA = "                                    " {set halfmtr to "". }ELSE{
                      local bbb to removeletters(aaa).
                      local ccc to bbb:split("/").
                      local localguage to (ccc[0]:tonumber / ccc[1]:tonumber)*100.
                      set FullMtr to "core temp"+SetGauge(localguage,1,widthlim-11).
                      if br > 0 set botrow to FullMtr.
                      set HalfMtr to "core temp"+SetGauge(localguage,1,30).
                      }}
                      if mks > 0{
                        IF HudItem = PWRTag{
                          if p:hasmodule("usi_converter"){
                            local t1 to p:getmodule("usi_converter").
                            set fl to t1:allfieldnames[0].
                            if baylst[0] > 0{  
                              set fl to baytrg[baysel][0].                   
                              set t1 to prtlist[pwrtag][hudtag][1]:getmodulebyindex(baytrg[baysel][2]).
                            }
                            set hudopts[1][2] to "".
                            set hudopts[1][1] to fl.
                            if GrpDspList[HudItem][hudtag] = 2 set hudopts[1][3] to GetColor(":ACTIVE:","CYN"). 
                            if GrpDspList[HudItem][hudtag] = 1 set hudopts[1][3] to GetColor(":NOT ACTIVE:","RED").
                            if rowval = 1{
                              IF BR=1 {
                                local aaa to getstatus(HudItem,hudtag,3,1).
                                IF AAA <> "                                    " {
                                  local localguage to (aaa:tonumber / 1)*100. 
                                  if halfmtr = "" {set botrow to "Governor"+SetGauge(localguage,1,widthlim-11).}else{
                                  if br > 0 set botrow to "Governor"+SetGauge(localguage,1,30)+" "+halfmtr.
                                }}
                                  set hudopts[1][2] to "".
                                  set hudopts[1][1] to fl.
                                  if baylst[0] > 0 {
                                  set hudopts[1][3] to ":"+BayLst[BaySel][0]+":"+BayLst[BaySel][1]. 
                                  SET HDXT TO "BAY ".
                                  }
                              }
                            }else{ MKSConvCheck(fl,1,HudItem, hudtag).}.
                          }
                        }
                        IF HudItem = MksDrlTag{
                          if p:hasmodule("usi_harvester"){
                            local t1 to p:getmodule("usi_harvester").
                            set fl to t1:allfieldnames[1].
                            set hudopts[1][2] to "".
                            set hudopts[1][1] to "".
                            if GrpDspList2[HudItem][hudtag] = 4 set hudopts[1][3] to ":ACTIVE:".
                            if GrpDspList2[HudItem][hudtag] = 3 set hudopts[1][3] to ":NOT ACTIVE:".
                            MKSDrillCheck(fl,1,HudItem, hudtag).
                              IF BR=1 {
                                local aaa to getstatus(HudItem,hudtag,3,1).
                                IF AAA <> "                                    " {
                                  local localguage to (aaa:tonumber / 1)*100.
                                  if halfmtr = ""{ if br > 0 set botrow to "Governor"+SetGauge(localguage,1,widthlim-11).}
                                  else{
                                  IF ROWVAL = 1 { if br > 0 set botrow to "Governor"+SetGauge(localguage,1,30)+" "+halfmtr.}
                                }}
                                set hudopts[1][2] to "".
                                set hudopts[1][1] to "".
                              }
                          }
                        }
                      }
                      IF HudItem = ISRUTag{
                        set hudopts[1][2] to isruoptlst[ConvRSC]+":". 
                        set hudopts[1][3] to ToggleResConv(p,isruoptlst[ConvRSC],ConvRSC,2). 
                        set hudopts[1][1] to "Converter:"+ConvRSC+":".
                      }else{
                      IF HudItem = DrillTag{
                        set hudopts[1][1] to "Ore Rate".
                        set hudopts[1][2] to ":".
                        set HudOpts[1][3] to getstatus(HudItem,hudtag,2,1)+"        ".}}
                    }
                  }
                  else{
                  if DispInfo <70 {
                    if DispInfo = 51 {
                      set HudOpts[1][1] to "".
                      set HudOpts[1][2] to "".
                      set HudOpts[1][3] to GetFuelLeft(prtList[HudItem][hudtag],2).
                    }
                    else{
                    if DispInfo = 52 {
                      set HudOpts[1][1] to "".
                      set HudOpts[1][2] to "".
                      if sas = false {set HudOpts[1][3] to getcolor(" SAS MDOE:OFF","RED").}else{set HudOpts[1][3] to getcolor(" SAS MODE:"+sasMode,"CYN").}
                      if steeringmanager:enabled = True set HudOpts[1][3] to getcolor("HEADING LOCKED","CYN"). 
                        if hudtag = 1 {
                        if apsel = 1 and axsel > 3 set axsel to 1.
                        if apsel = 2 IF axsel < 4 or axsel > 6 set axsel to 4.
                        if apsel = 3 and axsel < 7 set axsel to 7.
                          local l1 to " ".
                          local l2 to "               ".
                          local prfx to list(" ").
                          local sffx to list(" ").
                          for i in range(0,APaxis[0]) prfx:add(l1).
                          for i in range(0,APaxis[0]) sffx:add(l2).
                            for i in range (1,APaxis[0]){
                              if HdngSet[3][i] = 1 {
                                set prfx[i] to "*".
                                set sffx[i] to "*"+l2:substring(1,l2:length-1).
                              }
                            }
                          if br = 1{
                            if not prfx[axsel]:contains("*") {
                              set prfx[axsel] to ">".
                              set sffx[axsel] to "<"+l2:substring(1,l2:length-1).
                              set ItmTrg to " MODE OFF ".
                            }
                            else{
                              set prfx[axsel] to "<".
                              set sffx[axsel] to ">"+l2:substring(1,l2:length-1).
                              set ItmTrg to " MODE ON  ".
                            }
                            SET HudOpts[1][1] TO "".
                            SET HudOpts[1][3] TO "        ".
                            if apsel = 1{
                              IF AXSEL = 1 SET HudOpts[1][2] TO "HEADING:"+ HdngSet[0][1].
                              IF AXSEL = 2 SET HudOpts[1][2] TO "PITCH:"  + HdngSet[0][2].
                              IF AXSEL = 3 SET HudOpts[1][2] TO "ROLL:"   + HdngSet[0][3].
                            }
                            if apsel = 2{
                              IF AXSEL = 4 SET HudOpts[1][2] TO "SPEED:"  + HdngSet[0][4].
                              IF AXSEL = 5 SET HudOpts[1][2] TO "ALT:"    + HdngSet[0][5].
                              IF AXSEL = 6 SET HudOpts[1][2] TO "V-SPD:"  + HdngSet[0][6].
                            }
                            if apsel = 3{
                              IF AXSEL = 7 SET HudOpts[1][2] TO "PITCH LIM:"+ HdngSet[0][7].
                              IF AXSEL = 8 SET HudOpts[1][2] TO "SPEED MIN:"+ HdngSet[0][8].
                              IF AXSEL = 9 SET HudOpts[1][2] TO "AOA LIM:"  + HdngSet[0][9].
                            }
                          }
                          if apsel = 1{
                            set botrow to " "+prfx[1]+       "HEADING:"+ HdngSet[0][1]+sffx[1].
                            set botrow to     botrow+prfx[2]+"PITCH:"  + HdngSet[0][2]+sffx[2].
                            set botrow to     botrow+prfx[3]+"ROLL:"   + HdngSet[0][3]+sffx[3].
                          }
                          if apsel = 2{
                            set botrow to  " "+prfx[4]+       "SPEED:"  + HdngSet[0][4]+sffx[4].
                            set botrow to      botrow+prfx[5]+"ALT:"    + HdngSet[0][5]+sffx[5].
                            set botrow to      botrow+prfx[6]+"V-SPD:"  + HdngSet[0][6]+sffx[6].
                          }
                           if apsel = 3{
                            set botrow to  " "+prfx[7]+       "PITCH LIM:"+ HdngSet[0][7]+sffx[7].
                            set botrow to      botrow+prfx[8]+"SPEED MIN:"+ HdngSet[0][8]+sffx[8].
                            set botrow to      botrow+prfx[9]+"AOA LIM:"  + HdngSet[0][9]+sffx[9].
                          }
                          if GrpDspList3[FLYTAG][1] <> 6{
                          LOCAL PR TO "                   ".
                          IF FlState = "Flight" {SET  ss to "      SIDESLIP:"+round(bearing_between(ship,srfprograde,ship:facing),1). if colorprint = 1 {set pr to "    ".}}
                          else{ set ss to "                ". if colorprint = 1 {set ss to "    ". set pr to "                ".}}
                          PRINTLINE(pr+"HEADING:"+ ROUND(compass_and_pitch_for()[0],0)+"         PITCH:"  + ROUND(compass_and_pitch_for()[1],0)+"         ROLL:"   + ROUND(roll_for(),0)+ss,0,13).
                          set ln14 to 2.
                          }
                        }ELSE{
                          if prttagList[HudItem][hudtag]:contains("TARGET") {
                            IF BR=1 {set botrow to "set target to:"+trglst[anttrgsel]+"           ". set ItmTrg to " SET TRGT ".set lcl to "CYN".}
                            else{if hastarget = True {set botrow to "Current target:"+target+"           ". set lcl to "WHT".}
                            else {set botrow to "WARNING: NO TARGET SET. SET A TARGET TO USE THIS MODE".set lcl to "RED". set ItmTrg to EmptyHud.}}
                          }
                        }
                    }
                    else{
                    if DispInfo = 61 {
                      if HudItem = habtag{
                        if alttag=1{set ItmTrg to " DPST RSC ".
                          IF BR=1{
                            if ship:resources[RscNum["MaterialKits"]]:capacity > 0 {
                            if rowval = 1 set botrow to RscList[RscNum["MaterialKits"]][1]+SetGauge(ship:resources[RscNum["MaterialKits"]]:amount/ship:resources[RscNum["MaterialKits"]]:capacity*100,1,widthlim-4-RscList[RscNum["MaterialKits"]][1]:length).
                            }else{if rowval = 1 set botrow to "No Material Kits Storage". set lcl to "RED".}
                          } 
                        }
                      }
                    }
                    }}
                  }
                  else{}}}}}
                 }
                  if meterpart > 0 {
                    if mtrcur[8]:length > 0 and NextGoodField <> 0 and mtrcur[6] <>  mtrcur[1] and mtrcur[6] <>  mtrcur[0]{
                      if mtrcur[8][mtrcur[6]]:contains("NoAct"){
                        local amt to 0.
                        local lcldir to "+".
                        if NextGoodField >  mtrcur[6] set amt to NextGoodField- mtrcur[6].
                        if NextGoodField <  mtrcur[6] {set amt to  mtrcur[6]-NextGoodField. set lcldir to "-".}
                        adjust_Meter(prtlist[HudItem][hudtag], max(abs(amt)-1,1), lcldir, 4, HudItem,  MtrCur[0], MtrCur[1]).  set forcerefresh to 2.
                      }else{ set MeterGoodLast to  mtrcur[6].}
                    }
                  }
              }else set forcerefresh to 1.
                  if botrow = bigempty2 set lcl to 0.      
                  if botrow:length > WidthLim set botrow to botrow:substring(0,WidthLim).
                  if printpause = 0 and hsel[2][1] <> agtag{
                    LOCAL STPRINT TO " "+HudOpts[1][1]+ HudOpts[1][2]+ HudOpts[1][3].
                    IF STPREV <> STPRINT {
                      printline(STPRINT,0,hudstart-1).
                      SET STPREV TO STPRINT.
                    }
                    if BOTPREV <> BOTROW{
                      PRINTLINE(botrow,lcl).
                      SET BOTPREV TO BOTROW.
                    }
                  }else{SET BOTPREV TO "zz". SET STPREV TO "zz".}
                  IF NEWHUD = 2 SET NEWHUD TO 0.
                  //set ActionWait to 0.
                  SpeedBoost("off").
   }

   //#endregion 
    function ToggleGroup{//togglegroup(item number, tag number, option, auto).
      local parameter Inum, tagnum, optnin, auto is 0.
      SpeedBoost().
      if auto = 0 LastIn().
      set forcerefresh to 2.
      LOCAL FLT TO 0.
      IF INUM > ItemList[0] SET FLT TO 1.
      LOCAL INAME TO "".
      IF FLT = 0 {IF TAGNUM > PRTTAGLIST[INUM][0] SET FLT TO 2. IF FLT < 2 SET INAME TO ":"+itemlist[Inum].}
      IF dbglog > 0{
        local nd to " MANUAL".
        if auto = 1 set nd to ":AUTO".
        if auto = 2 set nd to ":FROM QUEUE".
        if auto = 3 set nd to ":TOP HUD BUTTON".
        log2file("TOGGLEGROUP:I:"+inum+" - T:"+tagnum+" - Opt:"+optnin+" - AUTO:"+auto). 
        IF FLT = 0 log2file("           :"+itemlist[Inum]+":"+prttaglist[Inum][tagnum]+nd). ELSE {log2file("           :BAD VALUE!!!!!!"+INAME).return.}
      }
        IF OPTNIN = 0{
          set AutoDspList[Inum][TagNum] to abs(AutoDspList[Inum][TagNum]).
          set AutoDspList[0][Inum][TagNum][0] to 0.
          local udo to 1. 
          if AutoValList[Inum][tagnum] < 0 SET UDO TO 2.
          PRINTQ:PUSH(REMOVESPECIAL(ItemListHUD[Inum]," ")+":"+Prttaglist[Inum][TagNum]+" DETECTION NOW ACTIVE"+"<sp>"+"GRN"). 
          if DbgLog > 1 log2file("       UpdateAutoTriggers (UDO("+UDO+"),AutoDspList[Inum][TagNum]("+AutoDspList[Inum][TagNum]+"),Inum("+inum+"),TagNum("+tagnum+"))." ).
          UpdateAutoTriggers(UDO,AutoDspList[Inum][TagNum],Inum,TagNum).
          SpeedBoost("off").
          set ShipStatPREV2 to "ForceRenew".
          RETURN.
        }
        IF OPTNIN = -1{
          set OPTNIN to AutoTRGList[Inum][tagnum].
        }
        IF OPTNIN = -2{
          IF AutoDspList[0][INUM][TAGNUM]:LENGTH > 1 LINKCHECK(inum, tagnum).
          PRINTQ:PUSH( prttaglist[inum][tagnum]+ " "+" TRIGGERED EXTERNALLY"+"<sp>"+"WHT"). 
          SpeedBoost("off").
          Return.
        }
      //#region toggle group settings
      set checktime to time:seconds.
      local MDL to modulelist[0][inum].
      local MDL2 to modulelist[1][inum].
      local MDL3 to modulelist[2][inum].
      local tagname to prttaglist[inum][tagnum].
      local pl to prtList[inum][tagnum].
      set pl to pl:sublist(1, pl:length).
      local opset to optnin.
      if opset > 3 set opset to 3. 
      local optn3 to opset*3.
      local optn2 to optn3-1.
      local optn1 to optn3-2.
      local lightcheck to 0.
      local cmd to true.
      local evact to 0.
      if MDL[0] = "Event" or MDL2[0] = "Event"  set evact to 1.
      if MDL[0] = "Action" or MDL2[0] = "Action"  set evact to 2.
      //local ea1 to MDL[0].
      //local ea2 to MDL2[0]. 
      local fld to mdl3[0]. //field to get
      local op to mdl3[4]. //option for off
      global Module1 to MDL[optn1].
      global Event1On to MDL[optn2].
      global Event1Off to MDL[optn3].
      global Module2 to MDL2[optn1].
      global Event2On to MDL2[optn2].
      global Event2Off to MDL2[optn3].
      global COMMAND TO "".
      local PrintOverride to 0.
      local opout to 0.
      local fl to "".
      local t to "".
      local printout to "".
      LOCAL PRFX TO "".
      set cnt to 0.
      local SymCheck to 0.
      local lco to 0.
      local modov to "".
      LOCAL MODULE TO "".
      local AltTrg to 0.
      local ccc to list().
      local OnOffAdd to list(meterlist[4][inum][0],meterlist[4][inum][1]).
      if optnin > 0 and meterlist[4][inum]:length > 2 set OnOffAdd to list(meterlist[4][inum][optnin*2-2],meterlist[4][inum][optnin*2-1]).
      LOCAL Pnum TO  getgoodpart(Inum,tagnum,2).
      set p to  prtlist[Inum][tagnum][PNUM].
      if MeterList[1][inum][0] <> 0 set modov to TrimModules2(MeterList[1][inum],inum,tagnum).
      //#endregion
      if inum <> agtag and inum <> flyTag and (inum <>CMDTag and tagnum < cmdln+1){
        LOCAL PL2 TO PL:COPY.
        for pt in pl2{
          if not pt:tostring:contains("tag="+tagname){
            if pt <> core:part {if DbgLog > 0 log2file("         "+PT:TOSTRING+" REMOVED FOR TAG MISMATCH(tag="+tagname+")" ).} else{if DbgLog > 0 log2file("         PART GONE").}
            set cnt to cnt+1.
            PL:REMOVE(PL:FIND(pt)).
          }else{if DbgLog > 2 log2file("         PART GOOD(tag="+tagname+")" +PT:TOSTRING).}
        }
      if cnt > pl2:length-1 OR PL:LENGTH = 0{
        if DbgLog > 0 log2file("          TAG REMOVED FOR TAG MISMATCH(tag="+tagname+")" ).
        SpeedBoost("off").
       return.
      }
      if DbgLog > 1 log2file("          PartsIn:"+LISTTOSTRING(PL)).
      }
      if autoTRGList[0][inum][tagnum] < 0 {SpeedBoost("off"). return.}
      if autoTRGList[0][inum][tagnum] > 0 and auto = 1 set evact to 4.
      //#region TOGGLE CHECK
      if inum > 0{
        local localmods to MeterList[1][inum].
        if auto = 0 and inum <> engtag set localmods to MeterList[0][1].
        SET PRFX TO MeterList[3][inum]+" ".
        if debug > 0 and optnin < 4 PRINTLINE(optnin+"-"+Module1+"-"+Event1On+"-"+Event1Off,0,13).
        if DbgLog > 1 and optnin < 4 log2file("           MOD IN: Module1:"+optnin+"-Module1:"+Module1+"-Event1On:"+Event1On+"-Event1Off:"+Event1Off+" FLD:"+fld ).
        if auto > -2 set ItemLastRun to INUM.
        if inum = lighttag{
          SET PRFX TO "LIGHT ".
          IF P:hasmodule("modulecommand") AND AUTO <> 0 {SpeedBoost("off").RETURN.}
          if optnin = 1{
            set ccc to checkActions(5,1,localmods, list("lights on","light on"),list("lights off", "light off")).
            if  ccc[3] = 0 or ccc[0] = "moduleanimategeneric" {set ccc to checkActions("OnOff",5,localmods, "toggle light","toggle light").}
            if  ccc[3] > 0 {
              ClearCHK(ccc,-1,0,3,"<>","PO/ TOGGLED  ", "moduleanimategeneric"). 
              if ccc[0] = "modulecolorchanger" {set PRINTOUT to " TOGGLED  ".  set PrintOverride to 3.}
            }
            IF AUTO = 2 SET PrintOverride TO -1.
          }
          if optnin = 2 {
              set fld to " ".
            if tagnum = 1 and auto = 0 AND ROWVAL = 0{
              SET LOADBKP TO LOADBKP+1.
              set forcerefresh to 1.
              SpeedBoost("off").RETURN.
            }
          }
          if optnin = 3 {
            if tagnum = 1 and auto = 0 AND ROWVAL = 0{
              SET SAVEBKP TO SAVEBKP+1.
              set forcerefresh to 1.
              SpeedBoost("off").RETURN.
            }
          }
        }
          else{
          if mks =1 {
          if inum = PWRTag {
            if optnin = 1 {
              if p:hasmodule("usi_converter"){
                set PrintOverride to 1.
                set forcerefresh to 1.
                set t to p:getmodule("usi_converter").
                set fl to t:allfieldnames[0]. 
                if baytrg[0] > 1{ 
                  set t to p:getmodulebyindex(baytrg[baysel][2]).
                  set fl to baytrg[baysel][0].
                  set evact to 3.
                }
                set module to module1.
                set ccc to getactions("Actions"+Pnum,localmods,inum, tagnum,optnin,1,list("start", "activate"),list("stop", "deactivate")).          
                if ccc[3] = 3 or ccc[3] = 0{
                  if GrpDspList[Inum][tagnum] = 1{ 
                  PRINTQ:PUSH(" "+prtTagList[INUM][tagnum]+" TURNED ON"+"<sp>"+"CYN").  
                    set ccc to getactions("Actions"+Pnum,localmods,inum, tagnum,optnin,2,list("toggle"),list("zz")).
                    set GrpDspList[Inum][tagnum] to 2.
                    }
                  else{
                  if GrpDspList[Inum][tagnum] = 2{
                    PRINTQ:PUSH(" "+prtTagList[INUM][tagnum]+" TURNED OFF"+"<sp>"+"RED"). 
                  set ccc to getactions("Actions"+Pnum,localmods,inum, tagnum,optnin,2,list("zz"),list("toggle")).
                  }}
                }else{
                    if ccc[3] = 1  PRINTQ:PUSH(" "+prtTagList[INUM][tagnum]+" TURNED ON"+"<sp>"+"CYN").                   
                    if ccc[3] = 2  PRINTQ:PUSH(" "+prtTagList[INUM][tagnum]+" TURNED OFF"+"<sp>"+"RED"). 
                }
                set PrintOverride to -1.
               if  ccc[3] > 0 SetTrgVars(CCC,-1).
              }
            }else{
              if optnin = 3 and BTHD11:contains("TETHR"){
                set ccc to getactions("Actions"+Pnum,list("USI_InertialDampener"),inum, tagnum, optnin, 1,list("ground tether: on"),list("ground tether: off")).
                ClearCHK(ccc,0,0,0,"="). 
              }
            }
          }
          else{
            if inum = MksDrlTag {
              IF OPTNIN = 1{
                set GrpDspList2[Inum][tagnum] to 3.
              }
              if optnin = 2 {
                  if getactions("OnOff"+Pnum,AnimModAlt,inum, tagnum,1,6,list("retract")) <> 0 {
                  if prtlist[MksDrlTag][tagnum][1]:hasmodule("usi_harvester"){
                    set forcerefresh to 1.
                    set t to prtlist[MksDrlTag][tagnum][1]:getmodule("usi_harvester").
                    set fl to t:allfieldnames[1].
                    //set fl2 to getEvAct(P,"usi_harvester",t:getfield(fl+" rate"),30).
                        set ccc to getactions("Actions"+Pnum,list("usi_harvester"),inum, tagnum, optnin, 0,list("start","activate"),list("stop","deactivate")).
                        if ccc[3] <> 3 {
                        if ccc[3] = 1  PRINTQ:PUSH(" "+prtTagList[INUM][tagnum]+" TURNED ON"+"<sp>"+"CYN").                   
                        if ccc[3] = 2  PRINTQ:PUSH(" "+prtTagList[INUM][tagnum]+" TURNED OFF"+"<sp>"+"RED"). 
                        }else{
                      if GrpDspList2[Inum][tagnum] = 3{
                        set ccc to getactions("Actions"+Pnum,localmods,inum, tagnum,optnin,2,list("activate","toggle"),list("ZZ")).
                        set GrpDspList2[Inum][tagnum] to 4.
                        }
                      else{
                      if GrpDspList2[Inum][tagnum] = 4{
                        set ccc to getactions("Actions"+Pnum,localmods,inum, tagnum,optnin,2,list("zz"),list("deactivate","toggle")).
                        set GrpDspList2[Inum][tagnum] to 3.
                      }}
                    }
                  ClearCHK(ccc,-1).
                  }
                }else{                  
                   PRINTQ:PUSH(" DRILL NOT DEPLOYED! DEPLOYING AND STARTING"+"<sp>"+"ORN").
                      ActionQNew:ADD(List(TIME:SECONDS,inum,tagnum,1)). 
                      ActionQNew:ADD(List(TIME:SECONDS+5,inum,tagnum,2)). 
                }
                set PrintOverride to -1.
              }
            }
            else{if inum = habtag {set forcerefresh to 1.}}
          }
        }// stop putting else line here.
          if inum = ENGtag { 
            IF optnin = 1 {
              set localmods to engmods.
              local lon to list(" on", "activate").
              local loff to list(" off","shutdown").
              if p:hassuffix("modes") if P:modes:length > 1 {if not P:primarymode set AltTrg to 1.}
              if p:hassuffix("ignition"){if p:ignition = false set loff to list(""). else set lon to list("").}  
              if p:hasmodule("FSengineBladed"){if getEvAct(P,"FSengineBladed","Status",30):contains("inactive") set loff to list(""). else set lon to list("").}
              set ccc to getactions("Actions"+Pnum,localmods,inum, tagnum,optnin,3,lon,loff).
             ClearCHK(ccc,-1).
            }
            if optnin = 2 {
                if p:hasmodule("FSengineBladed"){
                    IF ROWVAL = 1{ set PrintOverride to -1.
                    PRINTQ:PUSH(CheckTrue(40,pl,"FSengineBladed","thr keys"," "+prtTagList[INUM][tagnum]+" THROTTLE KEY RESPONSE SET TO ON   "+"<sp>"+"CYN"," "+prtTagList[INUM][tagnum]+" THROTTLE KEY RESPONSE SET TO Off  "+"<sp>"+"RED")).                     
                    }ELSE{
                        set ccc to getactions("Actions"+Pnum,list("FSengineBladed"),inum, tagnum,optnin,3,"hover").
                        ClearCHK(ccc,-1).
                }
                }
                if p:hasmodule("FSswitchEngineThrustTransform"){
                        set ccc to getactions("Actions"+Pnum,list("FSswitchEngineThrustTransform"),inum, tagnum,OPTNIN,3,list("reverse"),list("normal")).
                        if  ccc[3] > 0 SetTrgVars(CCC,-1).
                        if ccc[3] = 2  PRINTQ:PUSH(" "+prtTagList[INUM][tagnum]+" THRUST SET TO NORMAL  "+"<sp>"+"CYN").
                        if ccc[3] = 1  PRINTQ:PUSH(" "+prtTagList[INUM][tagnum]+" THRUST SET TO REVERSE "+"<sp>"+"RED"). 
                        set PrintOverride to -1.
                }
            }
            IF optnin = 3 {
                    if p:hasmodule("FSengineBladed"){
                      set PrintOverride to -1.
                        IF rowval = 1 {PRINTQ:PUSH(CheckTrue(40,pl,"FSengineBladed","thr state"," "+prtTagList[INUM][tagnum]+" THROTTLE STATE RESPONSE SET TO ON   "+"<sp>"+"CYN"," "+prtTagList[INUM][tagnum]+" THROTTLE STATE RESPONSE SET TO Off  "+"<sp>"+"RED")).
                        }else{PRINTQ:PUSH(CheckTrue(40,pl,"FSengineBladed","steering"," "+prtTagList[INUM][tagnum]+" ROTOR STEERING SET TO ON   "+"<sp>"+"CYN"," "+prtTagList[INUM][tagnum]+" ROTOR STEERING SET TO Off  "+"<sp>"+"RED")).}
                    }
                    else{set fld to "GIMBAL". set op to "False".}
            }
          }//}
          else{
          if inum = dcptag { 
            IF optnin = 1{
              local ct to 0.
              for pt in pl {
                for md in DcpModAlt{
                  if pt:hasmodule(md){set ct to ct+1.
                    if ct = 1 set module1 to md. 
                    if ct = 2 set module2 to md.
                  }
                }
              }
               if p:hasmodule(Module1){
                if p:getmodule(Module1):hasEVENT("jettison heat shield"){set t to p:getmodulebyindex(0). set evact to 3.}
              }
          }
          if P:hasmodule("moduledecouple") or P:hasmodule("ModuleAnchoredDecoupler") if P:hassuffix("ISDECOUPLED")  if P:ISDECOUPLED = True { PRINTQ:PUSH("ALREADY DECOUPLED      "+"<sp>"+"RED"). SpeedBoost("off").return.}.
          }
          else{
          if inum = WMGRtag {
                if optnin = 1 {
                  if P:hasmodule("MissileFire"){
                    getEvAct(P,"MissileFire","fire missile",20). set PrintOverride to -1.  PRINTLINE(tagname+ " FIRING" ,"RED"). SpeedBoost("off").return.
                  }
                }
                if optnin = 2 and Radartag > 0 and BTHD10 = "NEXT TRGT "{
                  if getEvAct(P,"ModuleRadar","target next",20) PRINTQ:PUSH("RADAR TARGET CYCLED    "+"<sp>"+2). 
                  SpeedBoost("off").return.
                }
                if optnin = 3 {
                  if CMtag > 0 and BTHD11 <> "NEXT TEAM " for cm in cmlist {if getEvAct(cm,"CMDropper","fire countermeasure",20) PRINTLINE("COUNTERMEASURES FIRED " ,"RED").} 
                  if BTHD11 = "NEXT TEAM " and auto = 0  if getEvAct(P,"MissileFire","next team",20)PRINTQ:PUSH("Team changed to "+P:getmodule("MissileFire"):getfield("team")+"<sp>"+2). set PrintOverride to -1.
                  RETURN.
                }
              }
          else{
          if inum = BDPtag {
              IF P:hasmodule("BDModulePilotAI"){ 
                set fl to P:getmodule("BDModulePilotAI").
                if getEvAct(p,"BDModulePilotAI","deactivate pilot",1,3) = true set event1on to "".
                if optnin = 2 AND P:getmodule("BDModulePilotAI"):hasFIELD("standby mode"){ 
                  SET forcerefresh TO 1.
                  IF fl:GETFIELD("standby mode") = False {
                    fl:SETFIELD("standby mode", True). PRINTQ:PUSH("STANDBY MODE ON "+"<sp>"+2).  
                    SET GrpDspList2[Inum][tagnum] TO 4. SpeedBoost("off").return.}
                  ELSE{
                    fl:SETFIELD("standby mode", False). PRINTQ:PUSH("STANDBY MODE OFF "+"<sp>"+1).  
                    SET GrpDspList2[Inum][tagnum] TO 3. SpeedBoost("off").return.}
                }
                if optnin = 3 AND fl:hasFIELD("unclamp tuning "){ SET forcerefresh TO 1.
                  IF fl:GETFIELD("unclamp tuning ") = False {
                    fl:SETFIELD("unclamp tuning ", True).  PRINTQ:PUSH( "TUNING UNCLAMPED "+"<sp>"+1). SET ALTVAL TO 1. SET GrpDspList3[Inum][tagnum] TO 6. set remeter to 1. SpeedBoost("off"). return.}
                  ELSE{
                    fl:SETFIELD("unclamp tuning ", False). PRINTQ:PUSH( "TUNING CLAMPED "+"<sp>"+2).   SET ALTVAL TO 0. SET GrpDspList3[Inum][tagnum] TO 5. set remeter to 1. SpeedBoost("off"). return.}
                }
              }
            }
          else{
          if inum = SMRTtag {
              if currentpart:hasmodule("Timer"){
                if optnin = 1 {
                set ccc to  getactions("Actions"+Pnum,list("Timer"),inum, tagnum,2,1,list("Start Countdown"),list("zzz")).
                ClearCHK(ccc,0,0,0,">","po/ TOGGLED").
                }
                if optnin = 3 {
                set fld to " ".
                }
              }
            }
          else{
          if inum = AGTag {
            if evact <> 4{
              IF optnin = 1 {
                set opout to 1.
                if tagnum = 1 {  toggle ag1 . if ag1  = false SET opout TO 2.}else{
                if tagnum = 2 {  toggle ag2 . if ag2  = false SET opout TO 2.}else{
                if tagnum = 3 {  toggle ag3 . if ag3  = false SET opout TO 2.}else{
                if tagnum = 4 {  toggle ag4 . if ag4  = false SET opout TO 2.}else{
                if tagnum = 5 {  toggle ag5 . if ag5  = false SET opout TO 2.}else{
                if tagnum = 6 {  toggle ag6 . if ag6  = false SET opout TO 2.}else{
                if tagnum = 7 {  toggle ag7 . if ag7  = false SET opout TO 2.}else{
                if tagnum = 8 {  toggle ag8 . if ag8  = false SET opout TO 2.}else{
                if tagnum = 9 {  toggle ag9 . if ag9  = false SET opout TO 2.}else{
                if tagnum = 10 { toggle ag10. if ag10 = false SET opout TO 2.}else{
                if tagnum = 11 {
                  IF throttle < 1 SET ship:control:pilotmainthrottle TO 1. ELSE SET ship:control:pilotmainthrottle TO 0.
                  if THROTTLE < 0 SET opout TO 2.}else{
                if tagnum = 12 { 
                  IF RCS = False RCS ON. ELSE RCS OFF.
                  if RCS = False SET opout TO 2.}else{
                if tagnum = 13 {toggle ABORT.  if ABORT = false set opout to 2.}else{
                if tagnum = 14 {toggle GEAR.   if GEAR  = false set opout to 2.}else{
                if tagnum = 15 {toggle LIGHTS. if LIGHTS= false set opout to 2.}else{
                if tagnum = 16 {toggle BRAKES. if BRAKES= false set opout to 2.}else{
                }}}}}}}}}}}}}}}}
                SET GrpDspList[Inum][tagnum] TO opout.
                PRINTQ:PUSH( tagname+ " "+" TRIGGERED "+"<sp>"+opout). 
                IF AutoDspList[0][INUM][TAGNUM]:LENGTH > 1 LINKCHECK(inum, tagnum).
                IF PRINTQ:LENGTH > 0 and printpause = 0 PrintTheQ().
                set AgSPrev to AgState:copy.
                SpeedBoost("off").return.
              }
              IF OPTNIN = 2 and auto = 0{
                  if rowsel = 1{
                    if tagnum = 2 {
                      set refreshRateSlow to CHANGESEL(10,refreshRateSlow ,"+").
                      PRINTQ:PUSH(" HUD REFRESH RATE SET TO "+refreshRateSlow+"<sp>"+"WHT"). set PrintOverride to -1.
                      set RFSBAak to refreshRateSlow.
                    }
                    if tagnum = 4 {
                      set SPEEDSET[2] to CHANGESEL(speeds[1]:length-1,SPEEDSET[2],"+"). 
                      if SPEEDSET[2] > SPEEDSET[3] set SPEEDSET[3] to SPEEDSET[2].
                      SET CPUSPD TO SPEEDSET[2].
                      PRINTQ:PUSH(" Power Save Processing Speed Set to "+Removespecial(speeds[0][SPEEDSET[2]]," ")+"<sp>"+"PRP").
                      set PrintOverride to -1.
                    }                    
                    if tagnum = 10 {
                      set dbglog to CHANGESEL(4,dbglog ,"+").
                      IF dbglog > 3 SET dbglog TO 0.
                      LOCAL ZZ TO " ON". IF dbglog = 0 SET ZZ TO " OFF". if dbglog = 2 set ZZ to " VERBOSE".  if dbglog = 3 set ZZ to " OVERKLL".
                      PRINTQ:PUSH(" LOGGING SET TO "+ZZ+"<sp>"+"WHT"). set PrintOverride to -1.
                    }
                    IF PRINTQ:LENGTH > 0 and printpause = 0 PrintTheQ().
                    SpeedBoost("off"). RETURN.
                  }else{
                  if tagnum = 1 {
                    if RunAuto = 1 OR RUNAUTO = 2 {set RunAuto to 3. PRINTQ:PUSH(" AUTO TRIGGERS DISABLED "+"<sp>"+"RED"). set PrintOverride to -1.}
                      ELSE IF RUNAUTO = 3 {
                        IF SHIP:status = "PRELAUNCH" {SET RUNAUTO TO 2.  PRINTQ:PUSH(" AUTO TRIGGERS SET TO PRELAUNCH "+"<sp>"+"YLW"). set PrintOverride to -1.}
                        ELSE IF IsPayload[0] = 1 AND IsPayload[1] <> core:part {SET RunAuto TO 0. PRINTQ:PUSH(" AUTO TRIGGERS SET TO PAYLOAD PART "+"<sp>"+"YLW"). set PrintOverride to -1.}
                        ELSE {set RunAuto to 1. PRINTQ:PUSH(" AUTO TRIGGERS ENABLED "+"<sp>"+"CYN"). set PrintOverride to -1.}
                      }
                    }
                  if tagnum = 2{
                     SET LOADBKP TO LOADBKP+1.
                      set forcerefresh to 1.
                      SpeedBoost("off").RETURN.
                    }
                    if tagnum = 3 {
                      set HLon to CHANGESEL(1,HLon ,"+",0).
                      if hlon = 1 PRINTQ:PUSH(" PART HIGHLIGHTING ENABLED"+"<sp>"+"CYN"). ELSE PRINTQ:PUSH(" PART HIGHLIGHTING DISABLED"+"<sp>"+"ORN"). 
                      set PrintOverride to -1.
                    }
                    if tagnum = 4 {
                      set SPEEDSET[0] to CHANGESEL(speeds[1]:length-1,SPEEDSET[0],"+"). 
                      if SPEEDSET[0] > SPEEDSET[1] set SPEEDSET[1] to SPEEDSET[0].
                      SET CPUSPD TO SPEEDSET[0].
                      PRINTQ:PUSH(" Processing Speed Set to "+Removespecial(speeds[0][SPEEDSET[0]]," ")+"<sp>"+"WHT").
                    }
                    IF PRINTQ:LENGTH > 0 and printpause = 0 PrintTheQ().
                    SpeedBoost("off"). RETURN.
                  }
              }
              if optnin = 3 and auto = 0{
                if TAGNUM = 1{
                  PRINTQ:PUSH(" LISTING AUTO SETTINGS"+"<sp>"+"CYN"). set PrintOverride to -1.
                  listautosettings().
                }
                if rowsel = 1{
                  if tagnum = 2{
                      set refreshRateFast to CHANGESEL(10,refreshRateFast ,"+").
                      PRINTQ:PUSH(" INFO REFRESH RATE SET TO "+refreshRateFast+"<sp>"+"WHT"). set PrintOverride to -1.
                    }
                  if tagNumcur = 4 {
                    set SPEEDSET[3] to CHANGESEL(speeds[1]:length-1,SPEEDSET[3],"+",SPEEDSET[2]).
                    PRINTQ:PUSH(" Power Save BOOST Processing Speed Set to "+Removespecial(speeds[0][SPEEDSET[3]]," ")+"<sp>"+"prp").
                  }
                }else{
                    if tagnum = 2 {
                     SET SAVEBKP TO SAVEBKP+1.
                      set forcerefresh to 1.
                      SpeedBoost("off").RETURN.
                    }
                  if tagNumcur = 4 {
                    set SPEEDSET[1] to CHANGESEL(speeds[1]:length-1,SPEEDSET[1],"+",SPEEDSET[0]).
                    PRINTQ:PUSH(" BOOST Processing Speed Set to "+Removespecial(speeds[0][SPEEDSET[1]]," ")+"<sp>"+"WHT").
                  }
                if tagnum = 10 {
                  set DEBUG to CHANGESEL(2,DEBUG ,"+").
                  if debug> 1 SET DEBUG TO 0.
                  LOCAL ZZ TO " ON". IF DEBUG = 0 SET ZZ TO " OFF".
                  PRINTQ:PUSH(" DEBUG SET TO "+ZZ+"<sp>"+"WHT"). set PrintOverride to -1.
                }
              }
            }
            }
          }
          else{
          if inum = FlyTag {
            if evact <> 4{
              set opout to 2.
              local strst to StrLock.
              local trgsas to 1.
              if tagnum > 1{
                if optnin = 1 AND MJB <> 2 {
                  if SHIP:VELOCITY:SURFACE:MAG<1 and tagnum < 4 {set trgsas to 0.}
                  unlock steering.
                  if sasmode =  Removespecial(prtTagList[Flytag][tagnum]," ") AND SAS = True set opout to 1.
                  if opout = 1 {
                  sas off. 
                  PRINTQ:PUSH(" SAS SET TO:OFF"+"<sp>"+"GRN"). set PrintOverride to -1.
                    set StrLock to 0.
                  }
                  else{
                    LOCAL SSKP TO 0.
                    if trgsas = 1{
                      if prttagList[INUM][TAGNUM]:contains("TARGET") {
                        if hastarget <> True {PRINTQ:PUSH("NO TARGET SET. SET A TARGET TO USE THIS MODE"+"<sp>"+"RED"). SET SSKP TO 1.}
                      }
                      IF SSKP = 0{
                        SAS ON. wait 0.1. 
                        set sasmode to Removespecial(prtTagList[Flytag][tagnum]," ").
                        PRINTQ:PUSH(" SAS SET TO:"+sasMode+"<sp>"+"CYN").  set PrintOverride to -1.
                        set StrLock to tagnum.
                      }
                    }
                  }
                }ELSE{IF MJB > 1 {PRINTQ:PUSH(" CAN'T ENABLE SAS MODE, MECHJEB ACTIVE<sp>"+"RED").  set PrintOverride to -1.}}
              }
              else{
                if rowval = 1 {
                  if optnin = 1 {
                    set HdngSet[3][axsel] TO CHANGESEL(1,HdngSet[3][axsel] ,"+",0).
                  }
                  if optnin = 2 {
                    if zop = 1{
                      if axsel = 1 set HdngSet[0][1] to ROUND(compass_and_pitch_for()[0],0).
                      if axsel = 2 set HdngSet[0][2] to ROUND(compass_and_pitch_for()[1],0). 
                      if axsel = 3 set HdngSet[0][3] to ROUND(roll_for(),0).
                      if axsel = 4 set HdngSet[0][4] to ROUND(SHIP:VELOCITY:SURFACE:MAG,0).
                      if axsel = 5 set HdngSet[0][5] to ROUND(ship:altitude,0).
                      if axsel = 6 set HdngSet[0][6] to ROUND(ship:VERTICALSPEED,0).
                    set zop to 2.
                    RETURN.
                    }
                    else{
                      if axsel = 1 set HdngSet[0][1] to 0.
                      if axsel = 2 set HdngSet[0][2] to 0.
                      if axsel = 3 set HdngSet[0][3] to 0.
                      if axsel = 4 set HdngSet[0][4] to 0.
                      if axsel = 5 set HdngSet[0][5] to 0.
                      if axsel = 6 set HdngSet[0][6] to 0.
                      if axsel = 7 set HdngSet[0][7] to 0.
                      if axsel = 8 set HdngSet[0][8] to 0.
                      if axsel = 9 set HdngSet[0][9] to 0.
                      set zop to 1.
                      RETURN.
                    }
                  }
                }else{
                  if optnin = 1 AND MJB <> 2{
                    if GrpDspList[Inum][tagnum] = 1 {
                      set opout to 2.
                      sas off.
                      //LOCK STEERING TO HEADING(HdngSet[0][1]+flyadj[1],HdngSet[0][2]+flyadj[2]+plimadj,HdngSet[0][3]+flyadj[3]).
                      LOCK STEERING TO HEADING(HdngSet[0][1]+flyadj[1],HdngSet[0][2]+flyadj[2],HdngSet[0][3]+flyadj[3]).
                      set StrLock to 1.
                      PRINTQ:PUSH(" HEADING LOCKED"+"<sp>"+"CYN"). set PrintOverride to -1.
                    }
                    else{
                      set opout to 1.
                      unlock steering. set strlock to 0.
                      PRINTQ:PUSH(" STEERING UNLOCKED"+"<sp>"+"ORN"). set PrintOverride to -1.
                    } 
                  }ELSE{IF MJB > 1 {PRINTQ:PUSH(" CAN'T ENABLE SAS MODE, MECHJEB ACTIVE<sp>"+"RED").  set PrintOverride to -1.}}
                  if optnin = 2 {
                    set HdngSet[0][1] to ROUND(compass_and_pitch_for()[0],0).
                    set HdngSet[0][2] to ROUND(compass_and_pitch_for()[1],0). 
                    set HdngSet[0][3] to ROUND(roll_for(),0).
                    set HdngSet[0][4] to ROUND(SHIP:VELOCITY:SURFACE:MAG,0).
                    set HdngSet[0][5] to ROUND(ship:altitude,0).
                    //set HdngSet[0][6] to ROUND(ship:VERTICALSPEED,0).
                    PRINTQ:PUSH(" ALL SET TO CURRENT"+"<sp>"+"WHT").
                    return.
                  }
                  if optnin = 3{
                    if GrpDspList3[Inum][tagnum] = 5 {set GrpDspList3[Inum][tagnum] to 6. PRINTQ:PUSH(" HEADING WILL ALWAYS SHOW"+"<sp>"+"WHT"). set PrintOverride to -1.}
                    else{                             set GrpDspList3[Inum][tagnum] to 5. PRINTQ:PUSH(" HEADING WILL SHOW ON THIS PAGE"+"<sp>"+"GRN"). set PrintOverride to -1.}
                    SET forcerefresh TO 1.
                    SpeedBoost("off").return.
                  }
                }
              }
              SET GrpDspList[Inum][tagnum] TO opout. 
              if strst > 0 {if steeringmanager:enabled = false set GrpDspList[Inum][strst] to 1. else set GrpDspList[Inum][strst] to 2.}
              SpeedBoost("off").return.
            }
          }
          else{
            if inum = CMDTag{
              if optnin = 1 {
                if tagnum > cmdln{
                  PRINTQ:PUSH(" MECHJEB: "+prtTagList[CMDTag][tagnum]+" ACTIVATED <sp>"+"CYN").  set PrintOverride to -1.
                  set Event1On to mjeb[1][mjeb[0]:find(prtTagList[CMDTag][tagnum])]. set module1 to "mechjebcore".
                  set Event1Off to "".
                  ClearOOA().
                  SET MJB TO 2.
                  IF TAGNUM > 8 SET MJB TO 3.
                  IF TAGNUM > 10 SET MJB TO 4.
                  IF TAGNUM > 18 SET MJB TO 5.
                  IF Event1On = "deactivate smartacs" SET MJB TO 1.
                }
              }
              if optnin = 2 {
                if tagnum > cmdln{
                  PRINTQ:PUSH(" MECHJEB SAS: TURNED OFF <sp>"+"ORN").  set PrintOverride to -1.
                  clearev().
                  IF TAGNUM > 10 set Event1On to "translatron off". ELSE set Event1On to "deactivate smartacs".
                  set module1 to "mechjebcore".
                  SET MJB TO 1.
                  }
              }
              if optnin = 3{
                if P:hasmodule("ModuleScienceContainer"){
                  set ccc to getactions("Actions"+Pnum,list("ModuleScienceContainer"),inum, tagnum,optnin,3,list("collect")).
                  if  ccc[3] <> 0{
                    ClearCHK(ccc,0,0,4,"<>","po/ SCIENCE COLLECTED","NA").
                  }
                }
              }
            }else{
          if inum = sciTag {
            if not p:hasmodule("modulecommand"){
              set localmods to TrimModules(listadd(scimodalt,p:modules:sublist(0,max(p:modules:length-1,3)),1),p,1).
            } else set localmods to scimodalt.
            if localmods = 0 {PRINTQ:PUSH(" NO MODULES FOUND:<sp>ORN"). return.}
            SET LCO TO 1.
            if optnin = 1{
              if getactions("OnOff"+Pnum,localmods,inum, tagnum,1,1,list("review","reset")) <> 0  and auto = 0{
                set printout to " DELETEDa               ".
                set evact to 2.
                IF P:HASMODULE("SCANexperiment") set ccc to getactions("Actions"+Pnum,list("SCANexperiment"), inum, tagnum,optnin,1, list("review", "analyze","delete","discard")).  
                else set ccc to getactions("Actions"+Pnum,localmods, inum, tagnum,optnin,evact, list("delete","discard", "reset")). 
                SetTrgVars(CCC).
                set forcerefresh to 2.
              }else{
                local wt to 0.
                set evact to 1.
                if auto < 2 {
                  local DDD to getactions("Actions"+Pnum,localmods, inum, tagnum,optnin,EVACT, list("deploy","extend","open"),list("crew report")). //l1 = check to make sure deployed optns, l2 = if has sci action and unrelated deploy optn
                  if DDD[3] <> 0 {
                    set module1 to DDD[0].
                    if ddd[1] <> "" set Event1On to DDD[1]. else set Event1On to DDD[2].
                    set fld to " ".
                    if ddd[3] = 1{
                      set wt to 1.
                      ActionQNew:ADD(List(TIME:SECONDS+5,inum,tagnum,optnin)). 
                      ActionQNew:ADD(List(TIME:SECONDS+9,inum,tagnum,2)). 
                      PRINTQ:PUSH("Deploying! Experiment will run in 5 seconds then retract."+"<sp>"+"WHT").
                      set PrintOverride to -1.
                    }
                  }
                  }
                  if wt = 0{

                      set ccc to getactions("Actions"+Pnum,localmods,inum, tagnum, optnin, 3,SciRun).
                      ClearCHK(ccc,-2).
                  }
              }
              set scipart to 1.
              }
            if optnin = 2{
              set evact to 1.
                set ccc to getactions("Actions"+Pnum,localmods, inum, tagnum,optnin,2, list("transmit")).
                if auto = 2 set ccc[3] to 0.
                if  ccc[3] <> 0{
                  if P:getmodule(ccc[0]):Hasdata{
                    P:getmodule(ccc[0]):transmit. 
                    LOCAL CNN TO 1.
                    if rtech <> 0 {if not rtech:hasKSCconnection(ship) set cnn to 0.} ELSE {IF HOMECONNECTION = "" SET CNN TO 0.}
                    if cnn = 1 PRINTQ:PUSH(" TRANSMITTING SCIENCE"+"<sp>"+"WHT"). else PRINTQ:PUSH(" NO CONNECTION"+"<sp>"+"ORN"). 
                    set PrintOverride to -1.
                  } 
                }else{
                  set ccc to getactions("Actions"+Pnum,localmods,inum, tagnum,optnin,evact,list("deploy","extend","open"),list("retract","close")). 
                  ClearCHK(ccc,0,0,0,"=").
                }
            }
            if optnin = 3{
              set evact to 2. 
              if P:hasmodule("ModuleScienceContainer"){
                set ccc to getactions("Actions"+Pnum,list("ModuleScienceContainer"),inum, tagnum,optnin,3,list("collect")).
                if  ccc[3] <> 0{
                  ClearCHK(ccc,0,0,4,"<>","po/ SCIENCE COLLECTED","NA").
                }
              }
              if GetActions(1,localmods,inum, tagnum,3,1,list("reset")) <> 0{
                set ccc to getactions("Actions"+Pnum,localmods, inum, tagnum, 3, 1, list("reset")).
                if  ccc[3] <> 0{
                  set botrow to bigempty2.
                  ClearCHK(ccc,0,0,4,"<>","po/ RESET","NA"). //chkin, strg is 0, chlc is 0, chpo is 0, CHGEQ is ">", CHANS is "", CHMod is "".
                }
              }
              if P:hasmodule("scansat"){
                set ccc to  getactions("Actions"+Pnum,list("scansat"),inum, tagnum,2,1,list("start"),list("stop")).
                if ccc[3]= 1 set printout to "SCAN STARTED".
                if ccc[3]= 2 set printout to "SCAN STOPPED". 
                SetTrgVars(CCC).
              }
            }
            if optnin = 4{
              for md in sciModAlt{
                if P:hasmodule(md){
                  local pm to P:GetModule(md).
                  local sc to pm:alleventnames.
                  if sc:length = 0 {set sc to pm:allactionnames. set evact to 2.}
                  if sc:length > 0{
                    set event1on to sc[scipart-1]. set event2on to "".
                    set event1off to sc[scipart-1]. set event2off to "".
                    set module1 to md. set module2 to "".
                    PRINTQ:PUSH("EXPERIMENT "+event1on+" RUN"+"<sp>"+"CYN").
                    set PrintOverride to -1.
                    break.
                  }else{SpeedBoost("off").return.}
                }
              } set scipart to 1.
            }
          }
          else{
          if inum = baytag{if P:hasmodule("Hangar") set module to module2.}
          else{
          if inum = geartag{
            set SymCheck to 1.
            set evact to 1.
            IF P:hasmodule(module1) set evact to 2.
            IF P:hasmodule(module2) AND NOT P:hasmodule(module1) {set fld to " ". set SymCheck to 0.
              if getactions("OnOff"+Pnum,AnimModAlt ,inum, tagnum,1,1,list("extend"),list("retract")) <> 0{
                LOCAL DDD TO TOGCHECK(PL,list("extend"),list("retract"),list("toggle"),AnimModAlt).
                IF DDD[0]:CONTAINS("TOGGLE") SET evact TO 2.
                set ccc to getactions("Actions"+Pnum,localmods,inum, tagnum,optnin,evact,DDD[0],DDD[1]).
                ClearCHK(ccc).
                ClearOOA().
              }
            }
            if rowval = 1 {
              set ccc to list(0,0,0,0,0).
              if optnin = 1 {set ccc to checkActions("HasField",1,list("ModuleWheelSuspension"), "spring/damper: override"   , "spring/damper: auto"   , "spring strength"  ,"", " spring/damper set to manual"   , " spring/damper set to auto").   }
              if optnin = 2 {set ccc to checkActions("HasField",1,list("ModuleWheelBase")      , "friction control: override", "friction control: auto", "friction control" ,"", " friction control set to manual", " friction control set to auto").}
              if optnin = 3 {set ccc to checkActions("HasField",1,list("ModuleWheelSteering")  , "steering adjust: override" , "steering adjust: auto" , "steering response",""," steering adjust set to manual" , " steering adjust set to auto" ).}
              ClearCHK(ccc,0,0,0,"<>").
            }
          }
          else{
          if inum = anttag{
            if optnin = 1{
              if rowval = 0 {
                if P:hasmodule("ModuleAnimateGeneric") and not P:hasmodule("ModuleDeployableAntenna"){
                  set ccc to getactions("Actions"+Pnum,list("ModuleAnimateGeneric"),inum, tagnum,optnin,1,list("extend"),list("retract")). 
                  if  ccc[3] <> 0{SetTrgVars(CCC). SET OPTNIN TO 2.}
                }
              }else{
                if rowval = 1 AND ITMTRG = "SET TARGET"{
                  getEvAct(P,"ModuleRTAntenna","target",40, trglst[anttrgsel]).
                  PRINTQ:PUSH("target set to:"+ trglst[anttrgsel]+"<sp>"+"CYN"). 
                  set PrintOverride to -1.
                }
              }
            }
          }
          ELSE{
          if inum = RBTTag{
            if P:hasmodule("ModuleRoboticController"){
              set ccc to "".
              set fld to " ".
              if optnin = 1 {set ccc to getactions("Actions"+Pnum,list("ModuleRoboticController"),inum, tagnum,optnin,2,list("toggle play")). set PRINTOUT to " PLAY TOGGLED".}
              if optnin = 2 {set ccc to getactions("Actions"+Pnum,list("ModuleRoboticController"),inum, tagnum,optnin,2,list("toggle loop mode")). set PRINTOUT to "LOOP MODE TOGGLED".}
              if optnin = 3 {
                IF BTHD11 <> "ENAB/DISAB" {set ccc to getactions("Actions"+Pnum,list("ModuleRoboticController"),inum, tagnum,optnin,2,list("toggle direction")). set PRINTOUT to "DIRECTION TOGGLED".}
                ELSE                      {set ccc to getactions("Actions"+Pnum,list("ModuleRoboticController"),inum, tagnum,optnin,2,list("toggle controller enabled")). set PRINTOUT to "ENABLE TOGGLED".}
              }
              ClearCHK(ccc,-1,1). 
            }
              else{
              IF OPTNIN = 1{
              local count to 0.
              for MD in localmods{
                if P:modules:contains(MD) {
                  set module1 to MD. set module2 to "".
                  IF OPTNIN = 1 {
                    set fld to " ".
                    set ccc to getactions("Actions"+Pnum,list(MD),inum, tagnum,optnin,2,list("toggle")).
                    ClearCHK(ccc,-1,1).
                  }
                  break.
                }
                set count to count+1.
              }
                for pt in pl {getEvAct(pt,module1,"disengage servo lock",20).}
                }
              IF OPTNIN = 2{
                local swp to SwapBool(getEvAct(p,module1,"locked",30,-1,2)).
                for pt in pl {PRINTQ:PUSH(CheckTrue(40,pl,module1,"locked"," "+prtTagList[INUM][tagnum]+" LOCK ENABLED   "+"<sp>"+"CYN"," "+prtTagList[INUM][tagnum]+" LOCK DISABLED  "+"<sp>"+"RED")).}
                SET FORCEREFRESH TO 2.
                SpeedBoost("off").RETURN.
              }
            }
          }
          else{
            if inum = labtag{
              if optnin = 3{set evact to 2. 
                set ccc to GetActions(5,list("ModuleScienceContainer"),inum, tagnum,optnin,3,list("collect")).
                ClearCHK(ccc,0,0,4,"<>","po/ SCIENCE COLLECTED","NA"). //chkin, strg is 0, chlc is 0, chpo is 0, CHGEQ is ">", CHANS is "", CHMod is "".
              }
            }           
            else{
              IF INUM = DockTAG {
                IF optnin = 1{
                   if P:hassuffix("STATE") IF P:STATE ="DISABLED" {
                    if getactions("OnOff"+Pnum,AnimModAlt ,inum, tagnum,1,1,list("OPEN"),list("CLOSE")) <> 0 {
                      ActionQNew:ADD(List(TIME:SECONDS,inum,tagnum,2)).
                      PRINTQ:PUSH(tagname+ " NOT DEPLOYED. DEPLOYING"+"<sp>"+"YLW").
                      SpeedBoost("off").RETURN.
                    }
                     }
                  if P:hassuffix("HASPARTNER") IF P:HASPARTNER <> TRUE {PRINTQ:PUSH(tagname+ " NOT DOCKED"+"<sp>"+"ORN"). SpeedBoost("off").RETURN.}
                }
                if optnin = 2{
                  local l1 to list("open","close","toggle"). local l2 to list("open","close","toggle").
                  if P:hassuffix("STATE") IF P:STATE ="DISABLED" set l2 to list(""). else set l1 to list(""). 
                  set ccc to getactions("Actions"+Pnum,AnimModAlt,inum, tagnum,optnin,3,l1,l2).
                ClearCHK(ccc,0,0,0,"<>"). 
                }
                if optnin = 3 and BTHD11 = "CNTRL FROM" {
                  set ccc to getactions("Actions"+Pnum,localmods,inum, tagnum,optnin,3,list("control from here"),list("control from here")).
                  ClearCHK(ccc,0,0,0,"<>"). 
                }
              }ELSE{
                         
              if DbgLog > 0 log2file("    "+P:TOSTRING+"    NO TAG MATCH!!!!" ).}}}}}}}}}}}}}}}}
          //#endregion 
          //#region TRIGGER
           IF DBGLOG > 2 log2file("           TRIGGERSECTION:").
          if module2   = module1   set module2  to "". 
          if Event2On  = Event1On  set Event2On  to "". 
          if Event2Off = Event1Off set Event2Off to "".
          if evact <> 3 and fld = " "{
            if Event1On  = Event1Off set Event1Off  to "". 
            if Event2Off = Event2On  set Event2Off to "".
          }
          if fld = "" set fld to " ".
          if modov = "" set modsout to list(module1,module2). else set modsout to modov.
          if modsout = "" set modsout to list(module1,module2).
          local EvOnOut to listadd(list(Event1On,Event2On),OnOffAdd[0]).
          local EvOffOut to listadd(list(Event1Off,Event2Off),OnOffAdd[1]).
          if  ccc:length <  4 set ccc to               getactions("Actions"+Pnum,modsout,inum, tagnum,optnin,0,EvOnOut,EvOffOut).
          else if  ccc[3] = 0 set ccc to               getactions("Actions"+Pnum,modsout,inum, tagnum,optnin,1,EvOnOut,EvOffOut).
          if  ccc[3] = 0 or ccc[3] = 3{
            if fld = " "  set ccc to  getactions("Actions"+Pnum,modsout,inum, tagnum,optnin,2,EvOnOut,EvOffOut).
            else          set ccc to  getactions("Actions"+Pnum,modsout,inum, tagnum,optnin,0,EvOnOut,EvOffOut).
            }
          if ccc[3] <> 0 {
            set evact to ccc[4].
            SetTrgVars(CCC,-1,evact).
            set module to ccc[0].
            if fld <>" " AND CCC[2] = op{set lightcheck to 1.}ELSE{set lightcheck to ccc[3].}
            if lightcheck = 1 or lightcheck = 3{set OPout to optn2. set command to ccc[1].}
            if lightcheck = 2                  {set OPout to optn3. set command to ccc[2].}
          }
          if fld <>" " and (evact <> 1 or ccc[3] = 3){
            local yn to 0. 
            local ddd to getactions("Actions"+Pnum,modsout,inum, tagnum,optnin,4,list(fld)).
            set lightcheck to ddd[3].
            set module to ddd[0]. 
            //set fld to ddd[1]. 
            LOCAL FldVal to ddd[2]. 
            if FldVal = op{set command to Event1On.  set OPout to optn2. set lightcheck to 1.}
              else{        set command to Event1Off. set OPout to optn3. set lightcheck to 2.}
              if DbgLog > 0 log2file("     FIELD CHECK: "+module+"-"+command+"-"+fld+":"+fldval+"-"+op).
          }
          if REMOVESPECIAL(printout," ") = "" set printout to modulelist[2][inum][OPout].
          IF dbglog > 0{
            log2file("              module:"+LISTTOSTRING(module)).
            log2file("              EVACT:"+LISTTOSTRING(evact)).
            log2file("              EvOnOut:"+LISTTOSTRING(EvOnOut)).
            log2file("              EvOffOut:"+LISTTOSTRING(EvOffOut)).
            log2file("              command:"+LISTTOSTRING(command)).
            log2file("              FLD:"+FLD).
            log2file("              fldoff:"+OP)..
            log2file("              OPout:"+OPout).
            log2file("              Symcheck:"+LISTTOSTRING(symcheck)).
            log2file("              PRINTOUT:"+PRINTOUT).
          }
          if OPout > 0 {
              if lightcheck = 1 or lightcheck = 3 set cmd to True.
              if lightcheck = 2 set cmd to False.
            set dbgtrk to "0".
            local lc to 0.
                if autoTRGList[0][inum][tagnum] > 0 and auto = 1 set evact to 4.
                if module <> "" set modsout to list(module). //if modov = "" set modsout to list(module).
                if evact < 4 and evact > 0{local cnt to 0. local PUIDPrev to list().
                for md in modsout {if dbglog > 2 log2file("            TriggerMOD:"+MD).
                  for pt in pl {local pev to evact.
                    if symcheck = 1 {if  pt:symmetrycount > 1{if dbglog > 2 log2file("                  Symcheck:"+pt:uid).
                      for sym in range (1,pt:symmetrycount+1){
                        //if sym = pt:symmetrycount+1 break. 
                        local inbt to " =/= ".
                        if PUIDPrev:contains(pt:SYMMETRYPARTNER(sym):uid) {set pev to 5. set inbt to "  =  ".}
                        if dbglog > 2 log2file("                      part("+sym+"):"+pt:SYMMETRYPARTNER(sym):uid+inbt+listtostring(PUIDPrev)).
                        }
                      }
                    }
                      if PrtListcur:contains(pt) AND SHIP:PARTS:contains(pt) and pev < 5 {if dbglog > 2 log2file("            TriggerPart("+cnt+"):"+pt). set cnt to cnt+1.
                        if pev < 3{
                            if getEvAct(PT,md,command,pev){
                              if INUM = RBTTag and autoRstList[0][0][tagnum] > 0 and optnin =1 and not P:hasmodule("ModuleRoboticController"){ActionQNew:ADD(List(TIME:SECONDS+autoRstList[0][0][tagnum],inum,tagnum,2)).}   //QUEUE FOR ROBOT LOCK
                              if inum = dcptag and optnin = 1 {if not tagname:contains("Payload") AND not tagname[0]:contains("Z0"){DcpPrtXtra(pt).}} //decoupler xtra
                              if pev = 1 {
                                if AltTrg = 1 {if dbglog > 2 log2file("                    ALT Triggered:"+MD+"-"+command+"-"+AltTrg). local zz to AlternateTrigger(pt,AltTrg,LIGHTCHECK). if zz = false set AltTrg to 0.}
                                if AltTrg = 0{if dbglog > 2 log2file("                    Event Triggered:"+MD+"-"+command).            if pt:getmodule(md):hasevent(command) pt:GETMODULE(md):doevent(command).                   }}
                              if pev = 2 {    if dbglog > 2 log2file("                    Action Triggered:"+MD+"-"+command+"-"+cmd).   if pt:getmodule(md):hasaction(command) pt:GETMODULE(md):doaction(command,cmd).              }
                            }
                          }
                        if pev = 3 {getEvAct(PT,md,command,10).set dbgtrk to "3".}
                        wait 0.001.
                      } if pev < 4 PUIDPrev:add(pt:uid).
                    }
                  }
                  if rowval = 1 and auto = 0 set lco to 1.
                if inum <> lighttag and P <> ship:rootpart and lco = 0 set lc to LGHTCHECK(tagname,p).
                }
                IF evact = 4 SET PrintOverride TO -1.
                if lc = 1 and P <> ship:rootpart and lco = 0 set printout to printout+" AND LIGHTS TOGGLED".
                local lcl to lightcheck.
                set lout to PRFX+tagname+ " "+ printout.
                if PrintOverride > 0  set lcl to PrintOverride.
                IF PrintOverride > -1 PRINTQ:PUSH(lout:tostring+"<sp>"+LCL:tostring).  
                if debug > 0 PRINTLINE(module+"-"+command+"-"+opout+"-"+evact+"-"+cmd+"-"+fld+"-"+op,0,14).
                if DbgLog > 0{
                  local EVTXT TO "      ACTION OUT:".
                  IF evact = 1 SET EVTXT TO "     EVENT  OUT:".
                  log2file(EVTXT+module+":"+command+" - "+modulelist[2][inum][OPout]+" - FIELD:"+fld+" - FIELDOFF:"+op+" lout:"+lout+" prfx:"+prfx+" PRINTOVERRIDE:"+PRINTOVERRIDE).
                }
                IF AutoDspList[0][INUM][TAGNUM]:LENGTH > 1 LINKCHECK(inum, tagnum).
                SetHudOptn(lightcheck, optnin, inum, tagnum).
          }
          ELSE{
            if debug > 0 PRINTLINE(module1+"-"+module2+"-"+command+"-"+evact+"-"+LIGHTCHECK+"-"+fld+"-"+op+" NOTRG ",0,14).
            if DbgLog > 0 and evact <> 4 log2file("     MOD OUT: "+module1+"-"+module2+"-"+command+"-"+evact+"-"+LIGHTCHECK+"-"+fld+"-"+op+" NOTRG " ).
            IF PrintOverride > -1 and evact <> 4 and auto <> 1 {
            PRINTQ:PUSH(PRFX+tagname+ " "+ printout+" TRIGGER FAILED"+"<sp>"+"ORN").
            if DbgLog > 0 log2file(PRFX+tagname+ " "+ printout+" TRIGGER FAILED" ).
            }
          }
          //#endregion 
          }
            IF evact = 4 and auto = 1 {
              ActionQNew:ADD(List(TIME:SECONDS+AutoTRGList[0][inum][tagnum],inum,tagnum,optnin)). //ActionQueue2[AutoTRGList[0][inum][tagnum]]:ADD(List(inum,tagnum,optnin)). 
              PRINTQ:PUSH(tagname+" "+autoTRGList[0][inum][tagnum]+" SECOND DELAY"+"<sp>"+"YLW").
              if DbgLog > 0 log2file("     "+tagname+" "+autoTRGList[0][inum][tagnum]+" SECOND DELAY").
              IF PRINTQ:LENGTH > 0 and printpause = 0 PrintTheQ().
              SpeedBoost("off").Return.
            }
          IF PRINTQ:LENGTH > 0 {IF printpause = 0 PrintTheQ().}
          //#region TRG FUNCTIONS
          function ClearCHK{ //ClearCHK(ccc,0,0,0,">","po/TOGGLED").
            local parameter chkin, strg is 0, chlc is 0, chpo is 0, CHGEQ is ">", CHANS is "", CHMod is "".
            if DbgLog > 2 log2file("                ClearCHK:"+" chkin:"+LISTTOSTRING(chkin)+" strg:"+strg+" chlc:"+chlc+" chpo:"+chpo+" CHGEQ:"+CHGEQ+" CHANS:"+CHANS+" CHMod:"+CHMod).
              if (chkin[3] > 0 and CHGEQ = ">") or (chkin[3] < 0 and CHGEQ = "<") or (chkin[3] <> 0 and CHGEQ = "<>") or CHGEQ = "=" or strg = -2{
              clearev().
              if strg = -2 { SetTrgVars(chkin). return.}
              SetTrgVars(chkin,strg).
              if (CHmod <> "" and chkin[0] = CHMod) or chmod = "NA"{
                if chmod <> "NA" clearev(chkin[3]).
                if CHANS <> "" {
                  set chans to chans:split("/").
                  if chans[0]:contains("po") set printout to CHANS[1].
                }
              }
              if chlc <> 0 set lightcheck to chlc.
              if chpo <> 0 {SET PrintOverride TO chpo.}
            } 
          }
          function AlternateTrigger{
            local parameter ATpart, ATopt, ATlchk.
            local ATres to 0.
            if atopt = 1 {if ATlchk = 1{if ATpart:hassuffix("activate"){ATpart:activate. set ATres to 1.}}else{if ATlchk = 2{if ATpart:hassuffix("shutdown") {ATpart:shutdown. set ATres to 1.}}}}
            if ATres = 1 return true. else return false.
          }
          function TogCheck{
            local parameter TCPin, TCL1,TCL2, TCL3, TCMdls.
            LOCAL TCnt TO LIST(0,0).
            FOR PTS IN TCPIN{
              LOCAL CMP TO LIST().
              if getactions("OnOff",TCMdls,0,PTS,1,1,TCL1) <> 0 SET TCnt[0] TO TCnt[0]+1.
              if getactions("OnOff",TCMdls,0,PTS,1,1,TCL2) <> 0 SET TCnt[1] TO TCnt[1]+1.
            }
            IF TCNT[0] > 0 {IF TCNT[1] > 0 RETURN LIST(TCL3,TCL3). ELSE RETURN LIST(TCL1,"").}ELSE{IF TCNT[1] > 0 RETURN LIST("",TCL2).}
          }
          function checkActions{
            local parameter mode, evac, mods, opt1, opt2 is "", field1 is "", FldOffAns is "", ans1 is "", ans2 is "".
            if not opt1:istype("List") set opt1 to list(opt1).
            if not opt2:istype("List") set opt2 to list(opt2).
            if not field1:istype("List") set field1 to list(field1).
            local TmpMDX to StrginAct(mode:tostring).
            set mode to TmpMDX[0].
            local mdx to TmpMDX[1].
            if not mdx:istype("scalar") set mdx to 0.
            IF DBGLOG > 2 log2file("        checkactions: MODE:"+MODE+" EVAC:"+EVAC+"MODS:"+LISTTOSTRING(MODS)+"opt1:"+LISTTOSTRING(opt1)+"opt2:"+LISTTOSTRING(opt2)+" FldOffAns:"+FldOffAns+" ans1:"+ans1+" ans2:"+ans2+" MDX:"+MDX).
            local FFF to getactions("Actions"+Pnum,mods,inum, tagnum,optnin,evac,opt1,opt2). //standard check to evac
            if mdx > 0 and FFF[3] = 0 set FFF to getactions("Actions"+Pnum,mods,inum, tagnum,optnin,mdx,opt1,opt2).//add number to mode or use number only to use alt event call on fail of 1st
            if mode = "OnOff"{//overwrite on/off with different value
              local skp to 0.
              if field1 <> ""  if FFF[0] <> field1 set skp to 1. 
              if FFF[3] > 0 and skp = 0 {set FFF[3] to getactions("OnOff"+Pnum,mods,inum, tagnum,optnin,3,opt1,opt2).}
              }
            if mode = "HasField" {//check if field exists to verify on/off            
              set FFF[3] to getactions("OnOff"+Pnum,mods,inum, tagnum,optnin,4,field1).
              if FFF[3] = 0 set FFF[3] to 2.
              if FFF[3] = 2 set PRINTOUT to ans1.
              if FFF[3] = 1 set PRINTOUT to ans2.
              set PrintOverride to 1.
            }
            IF DBGLOG > 2 log2file("        checkactionsANS:"+LISTTOSTRING(FFF)).
            return FFF.
          }
          function SetTrgVars{
            local parameter inlst, fldin is 0, evactin is 0.
            if DbgLog > 1 log2file("                SETTRGVARS: inlst:"+LISTTOSTRING(inlst)+" fldin:"+fldin+" evactin:"+evactin+" FLDin:"+fld).
            if evactin = 0 set evact to inlst[4].
              if inlst[0] <> "" and inlst[0] <> module2 set module1 to inlst[0]. 
              if inlst[1] <> "" and inlst[1] <> Event2On  set Event1On  to inlst[1].
              if inlst[2] <> "" and inlst[2] <> Event2Off set Event1Off to inlst[2]. 
              if inlst[3] <> "" set lightcheck to inlst[3].
            if fldin <> -1{
              if fldin = 0 set fld to " ". else set fld to fldin.
            }
            if DbgLog > 1 log2file("                  MODULEout:"+INLST[0]+" EVENT1ONout:"+EVENT1ON+" EVENT1OFFout:"+EVENT1OFF+" EVENT2ONout:"+EVENT2ON+" EVENT2OFFout:"+EVENT2OFF+" LIGHTCHECKout:"+LIGHTCHECK+" FLDout:"+fld).
          }
          FUNCTION LINKCHECK{
            local parameter inm, tnm.
            if DbgLog > 0 log2file("   LINKCHECK:"+ITEMLIST[Inm]+":"+PRTTAGLIST[INUM][TNM]+"("+LISTTOSTRING(AutoDspList[0][inm][tnm])+")").
            local itm2 to "0".
            SET AutoDspList[0][inm][tnm] TO DEDUP(AutoDspList[0][inm][tnm]).
            FOR I IN RANGE(AutoDspList[0][inm][tnm]:LENGTH-1,0){
              local itm1 to AutoDspList[0][inm][tnm][I].
              if itm2 <> itm1 {
                local aa to 0.
                local splt to itm1:split("-").
                if splt:length > 2 {if splt:length = 4{set aa to 0-splt[3]:tonumber. set splt[2] to aa:tostring.}
                local pnt to List(TIME:SECONDS+AutoTRGList[0][splt[0]:tonumber][splt[1]:tonumber],splt[0]:tonumber,splt[1]:tonumber,splt[2]:tonumber).
                if not ActionQNew:contains(pnt) ActionQNew:ADD(pnt).
                if aa = 0 AutoDspList[0][inm][tnm]:REMOVE(I).
                }
              }
              set itm2 to itm1.
            }
          }
          FUNCTION LGHTCHECK{
                LOCAL parameter  tn, LCPin.
                local rtn is 0.
                if lighttag = 0 return rtn.
                LOCAL SKP TO 1.
                if prttaglist[lighttag]:contains(tn) set skp to 0.
                for md in lightChkskp{ if p:hasmodule(md) SET SKP TO 1. break.}
                 IF SKP = 0{set rtn to 1. ActionQNew:ADD(List(TIME:SECONDS+1,1,prttaglist[lighttag]:find(tn),1)).}
              if DbgLog > 0 log2file("      LIGHTCHECK:"+TN+"("+rtn+")").
                return rtn.
          }
          function SetHudOptn{
            local parameter lchk, opchk, in, tn.
            if DbgLog > 1 log2file("      SETHUDOPTN-LCHK:"+LCHK+" opchk:"+opchk+" IN:"+IN+" TN:"+TN).
              if lchk = 1 {
                if opchk =1  SET GrpDspList[in][tn] TO 2.
                IF opchk =2 SET GrpDspList2[in][tn] TO 4.
                IF opchk =3 SET GrpDspList3[in][tn] TO 6.
              }
              if lchk = 2 {                  
                if opchk =1 SET  GrpDspList[in][tn] TO 1.
                IF opchk =2 SET GrpDspList2[in][tn] TO 3.
                IF opchk =3 SET GrpDspList3[in][tn] TO 5.
              }
              if forcerefresh = 0 set forcerefresh to 1.
              return.
          }
          function DcpPrtXtra{
            local parameter prt.
            local wtx to 0.
            if DbgLog > 0 log2file("   DCP PART EXTRA:"+prt).
              for chl in prt:children {
                for chl2 in chl:children {
                  for chl3 in chl2:children {
                    actions(chl3).}
                  actions(chl2).}
                actions(chl).
              }
                  local function actions{
                  local parameter prt2, m is "", evnt is "", dcpxev is 1.
                  local cont to 0.
                  local DCPmods to TrimModules(DcpXtraMod,prt2,1).
                  if dcpmods[0] = 0 return.
                    for it in DCPmods{if prt2:modules:contains(it){set cont to 1. break.}}
                    if cont = 0 return.
                      local lll to GetActions("Actions",DCPmods,0, prt2,0,3,list("on", "activate","deploy","arm","toggle")).
                      if DbgLog > 0 log2file("   DCP PART EXTRATRG:"+LISTTOSTRING(LLL)).
                      if  lll[3] > 0 and (prt2:tag = "" or prt2:tag = prt:tag){
                        set m to lll[0]. set evnt to lll[1]. set dcpxev to lll[4]. set fnd to 1.
                        if dcpxev = 1 {if prt2:getmodule(m):hasevent(evnt) prt2:getmodule(m):doevent(evnt).}else getEvAct(prt2,m,evnt,10).
                        if dcpxev = 2 {if prt2:getmodule(m):hasAction(evnt) prt2:getmodule(m):doAction(evnt, True).}
                        wait .001.
                        if evnt:contains("chute") or evnt:contains("deploy") set wtx to .25.
                      }
                }
                wait wtx.
              }
          function clearooa{
                SET OnOffAdd TO LIST("","").
              }
          function clearev{
            local parameter op is 0.
            IF dbglog > 2 log2file("              clearev("+OP+")").
            if op = 0 {
              set event1on to "". set event1off to "". set module1 to "".
              set event2on to "". set event2off to "". set module2 to "".
            }else{
              set Event1Off to Event1On. set fld to " ".
              if op = 1 {set Event1Off to "". set Event2Off to "".}
              if op = 2 {set Event1On to "". set Event2On to "".}
            }
          }
          //#endregion 
          RETURN.
      }
    function TopHugTrig{//translate top buttons to appropriate triggers
        local parameter HudNum.
        local trgnum to enghud[hudnum].
        local ActNum to 1.
        if trgnum > 100 {set actnum to trgnum - 100. set trgnum to enghud[hudnum-1].}
        togglegroup(engtag,TrgNum,ActNum,3).
    }

    //#region meter set
   function UpdateMeterLeft{//left meter
    local parameter 
    ItemNum is hsel[2][1],
    TagNum  is hsel[2][2].
         local lim to 7-ln14.
         local sensordisp to list().
          if hudop <> 5{
            IF FlState = "Space" OR FlState = "SpaceATM"{
              if hasnode = True{
                LOCAL TM TO formatTime(ETA:NEXTNODE).
                IF TM <> "PASSED" sensordisp:add("NODE:"+TM+"   ").
              }
              if orbit:hasnextpatch = True{
                LOCAL TM TO formatTime(ETA:TRANSITION).
                IF TM <> "PASSED" sensordisp:add("XSTN:"+TM+"   ").
              }
            }
            local skp to 0.
            if ItemNum = engtag or (crewact:length > 1 and (ItemNum = CMDTag or ItemNum = labtag)) or (itemnum = scitag and scanlist:length > 0) set skp to 1.
            if skp = 0 {
              if senseskp = 0 {
                if senselist[3] = 1 and AutoValList[0][0][3][8]  <> 2 {sensordisp:add("PSR :"+round(SHIP:SENSORS:PRES,0)+" kPa").}
                if senselist[1] = 1 and AutoValList[0][0][3][11] <> 2 {sensordisp:add("GRAV:"+round(ship:sensors:grav:mag,1)+" M/S2").}
                if senselist[4] = 1 and AutoValList[0][0][3][10] <> 2 {sensordisp:add("TEMP:"+round(SHIP:SENSORS:TEMP,1)+" K").}
                if senselist[0] = 1 and AutoValList[0][0][3][12] <> 2 {sensordisp:add("ACCL:"+round(ship:sensors:acc:mag,1)+" G").}
                if senselist[2] = 1 and AutoValList[0][0][3][9]  <> 2 {sensordisp:add("SUN :"+round(SHIP:SENSORS:LIGHT,2)+" EXP").}
              }
            }
            else{
            if ItemNum = ENGTag{
              local eng_list to prtlist[engtag][TagNum].
              local ltg to prtTagList[engtag][TagNum].
              local enout to list().
              local cnt to 0.
              local thr to 0.
              for engs in eng_list {
                if engs:hassuffix("thrust"){
                  local thrs to engs:thrust.
                  if thrs > 10 set thrs to round(thrs,0). else set thrs to round(thrs,1).
                  local enout1 to ltg+":("+cnt+"):"+thrs.
                  if engs:hassuffix("flameout") if engs:flameout = TRUE set enout1 to ltg+"("+cnt+"):"+"FLAMEOUT".
                  if engs:hassuffix("ignition") if engs:ignition = FALSE set enout1 to ltg+"("+cnt+"):"+"OFF".
                    set thr to thr + thrs.
                    set cnt to cnt+1.
                    LOCAL LSFX TO "kN".
                    IF ENOUT1:TOSTRING:CONTAINS("OFF") SET LSFX TO "".
                    enout:add(enout1+LSFX).
                  }
                }
                if thr > 0 enout:insert(0,ltg+" THRUST:"+thr+"kN").
                for ac in enout sensordisp:add(ac).
              }
              else{
                if ItemNum = LabTag or ItemNum = CMDTag or ItemNum = ACDTag or ItemNum = habtag{
                  sensordisp:add("CREW:"+MeterList[3][ItemNum]+":"+prtTagList[ItemNum][TagNum]). 
                  for ac in CrewAct {for pts in prtList[ItemNum][TagNum]{if ac:part = pts and ac:part:tag = prtTagList[ItemNum][TagNum] and not sensordisp:contains(ac) sensordisp:add(ac).}}
                }else{
                if ItemNum = scitag AND scanlist:LENGTH > 0{
                  sensordisp:add("Surface Scanner:").
                  for i in range(Lscroll[0],MAX(Lscroll[1]+1,MIN(7,scanlist:length-1))){ IF I = LSCROLL[1]+1 BREAK. sensordisp:add(scanlist[i]).} 
                  if scanlist:length > lim-1 set lscroll[0] to ADDMAX(Lscroll[0],1,0,Lscroll[1]-6).
                  } 
                }
              }
            }
          }else{
                  sensordisp:add("ACTIONS AVAILABLE:").
                  for i in actnlist:sublist(1,actnlist:length-1){sensordisp:add(" "+i).} 
                  set lim to actnlist:length.
          }
        IF sensordisp:LENGTH < lim {sensordisp:INSERT(0,"                                        ").}
        until sensordisp:length > lim-1 sensordisp:add("                                        ").
        local spc to " ".
        for ln in range (0, lim-1){if ln < sensordisp:length print sensordisp[ln]:tostring:padright(widthlim/2) at (1,ln+8).  else {if ln+9 < lim+8 print spc:padright(widthlim/2) at (1,ln+8). break.}}
        if hudop = 5 print ">"at (1,AutoSetAct+8).
    }
   function UpdateFuel{
    local parameter 
    ItemNum is hsel[2][1],
    TagNum  is hsel[2][2].
        if dcptag <> 0 and ItemNum = dcptag and fuelmon = 1 {
          IF DCPRes = 0 {
            local rscl to getRSCList(DcpPrtList[TagNum][1]:resources).
            set prsclist to rscl[0].
            set prsclist2 to rscl[2].
            set pRscNum to rscl[1].
            SET DCPRes TO 1.
          }
            if newhud = 1 {
              if autoRscList[ItemNum][TagNum]:istype("string") {
                    set RscSelection to safekey(pRscNum,autoRscList[ItemNum][TagNum]). } 
              else {set RscSelection to autoRscList[ItemNum][TagNum].}
            }
            local lm to widthlim-5-ClrMin. 
            local fmtr to GetFuelLeft(DcpPrtList[TagNum],3,0,RscSelection).
            local lcl to MtrColor(fmtr).
            printline (" "+HudOpts[1][1],0,16).
            if lcl:istype("string") and HudOpts[1][1] <> "No Part"{
              PRINTLINE("("+fmtr+"%)"+GetFuelLeft(DcpPrtList[TagNum],0,lm,RscSelection),lcl).
              }
        }
    }  
   function MtrColor{//returns color based on percentage
  local parameter pctin.
  local lcl to "WHT".
  if pctin < 10 set lcl to "RED".else{
  if pctin < 25 set lcl to "RRN".else{
  if pctin < 40 set lcl to "ORN".else{
  if pctin < 55 set lcl to "YRN".else{
  if pctin < 70 set lcl to "YLW".else{
  if pctin < 85 set lcl to "YGR".else{
  if pctin < 95 set lcl to "GRN".else{
  }}}}}}}
  return lcl.
}
   FUNCTION SETHUD{//set some button content, almost totally depreciated
    local parameter ItemNum is hsel[2][1].
          if rowval = 0 {
            SET HUDOP TO 1.
            if itemnum = scitag{} SET HUDOP TO 2.
          }
          if rowval = 1 {
              SET HUDOP TO 4.
              if itemnum = DCPtag{SET HUDOP TO 10. set hudoptsl[1][10] to "RSRC   ". set hudoptsl[3][10] to "RSRC   ".SET HDXT TO "    ".}
              else{
              if   MeterPart > 0 {
                set hudop to 10. set hudoptsl[1][10] to "LIMIT  ". set hudoptsl[3][10] to "LIMIT  ".SET HDXT TO "OPTN".
                }
              else{
              if itemnum = Flytag{set hudop to 10.
                if ItmTrg = " SET TRGT "{set hudoptsl[1][10] to "TARGET ". set hudoptsl[3][10] to "TARGET ".SET HDXT TO "    ".}
                else{set hudoptsl[1][10] to "LIMIT  ". set hudoptsl[3][10] to "LIMIT  ".SET HDXT TO "AMNT".}}
              else{
              if mks = 1 {
                if itemnum = pwrtag or itemnum = MksDrlTag {set hudop to 10. set hudoptsl[1][10] to "GOV    ". set hudoptsl[3][10] to "GOV    ".}
              }else{}}}}//}}}
          }
          print "         " AT (61,8).
          if hudop <> 5 and hudopprev = 5 {PRINTLINE(). PRINTLINE("",0,16). }
    }
   function GetFuelLeft{
     local parameter prts, opt is 1, GMAX IS 0, resnum is 0,
    ItemNum is hsel[2][1],
    TagNum  is hsel[2][2].
    local GFLDlvl to 2.
    if Tagnum = dcptag set GFLDlvl to 6. 
     if dbglog > GFLDlvl log2file("    GETFUELLEFT:"+ItemList[itemnum]+":"+prtTagList[itemnum][Tagnum]+" resnum:"+resnum).
     local prtf to prts:copy.
     if resnum:istype("string"){
      if hudop <> 5 {
        if Tagnum = dcptag {
             set resnum to safekey(pRscNum,resnum).}
        else{set resnum to safekey(RscNum ,resnum).}
      }
     }
      local PctTot to 0.
      set cnt to 0.
      if prtf:length = 0 return.
         prtf:add("").
      local pl4 to prtf:sublist(1, prtf:length).
      if pl4:length = 0 return.
      if dbglog > GFLDlvl log2file("               :"+LISTTOSTRING(pl4)+" OPT:"+opt+" gmax:"+gmax+" resnum:"+resnum + " AUTOTRG:"+autoTRGList[0][itemnum][Tagnum]).
      local gauge to ":".
      local DCPGone to 1.
      if autoTRGList[0][itemnum][Tagnum] > -1 {
          for pt IN pl4{
              if pt <> "" {
                if dbglog > GFLDlvl log2file("    PRT:"+pt).
                IF pt <> CORE:PART{
                  set DCPGone to 0.
                  if resnum > pt:resources:length set resnum to pt:resources:length-1.
                  if pt:resources:length > max(resnum-1,0) {
                    IF  pt:resources[resnum]:capacity > 0 {
                      if Ship:parts:contains(pt){
                        set resource to pt:resources[resnum].
                        set ResCur to resource:name+":".
                        set percentage to resource:amount / resource:capacity * 100.
                        set cnt to cnt+1.
                        set PctTot to PctTot+percentage.
                      }
                    }else{set HudOpts[1][1] to pt:resources[resnum]:name+":". if opt < 3 set gauge to ":No res. storage". else set gauge to 0.}
                  }else{if opt < 3{set HudOpts[1][1] to "". set HudOpts[1][2] to "".} set gauge to ":No resources".}

                }
              }
            }
          }
              if DCPGone = 1 {set HudOpts[1][1] to "No Part". set HudOpts[1][2] to " ". set gauge to "                                                                       ". set DcpPrtList[Tagnum] to list(0,"").}
              else{
                if gauge = ":No resources" or cnt = 0 or gauge = 0{}else{
                  set percentage to PctTot/cnt.
                  if opt > 4 {
                    if opt = 5 set rescur to "".
                    set rescur to rescur+"("+round(percentage,0)+"%)".
                    if gmax = 0 set GMAX to widthlim-3-rescur:length.
                    if colorprint = 1 set gauge to GETCOLOR(SetGauge(percentage, 1, GMAX-9),mtrcolor(percentage)).
                    else  set gauge to SetGauge(percentage, 1, GMAX).
                    if gauge = ":" set gauge to ":EMPTY                       ".
                    return rescur+gauge.
                  }
                  if opt =3 {set gauge to round(percentage).}
                  if opt =4 {set gauge to round(percentage,3).}
                  IF OPT < 3{
                    if opt =1 set ResCur to rescur + " ".
                    set HudOpts[1][1] to rescur.
                    set gauge to SetGauge(percentage, 1, GMAX).
                    if gauge = ":" set gauge to ":EMPTY                       ".
                  }
                }
              }
              if dbglog > 2 log2file("      "+" AMT:"+gauge+" DCPGONE:"+DCPGone). 
              return gauge.
    }
   function adjust_thrust{//adjust some meters, almost totally depreciated
     LOCAL parameter PrtsIN, amount, direction, op is 1.
      LOCAL PrtsIN2 to PrtsIN:sublist(1, PrtsIN:length).
     if op =1{
        for engine in PrtsIN2 {
            if engine:hassuffix("thrustlimit"){
            set CurLim to engine:thrustlimit.
            if direction = "+" {set NewLim to CurLim + amount.
            } else {set NewLim to CurLim - amount.}
            set NewLim to max(0, min(100, NewLim)).
            set engine:thrustlimit to NewLim.
            }
        }
      }
     if op =2{
        for GOV in PrtsIN2 {
          set CurLim to GOV:getmodule("mksmodule"):getfield("governor").
          if direction = "+" {set NewLim to CurLim + amount.
          } else {set NewLim to CurLim - amount.}
          if newlim > 1 set NewLim to 1. if newlim < 0 set NewLim to 0.
          GOV:getmodule("mksmodule"):setfield("governor", NewLim).
        }
      }
    }
   function adjust_Meter{
      LOCAL parameter PrtsIN, amount, direction, op is 1, inum is 1, limitlow is 0, limit is 100, fldin is 0, mdl is 0.
      IF dbglog > 1{
        log2file("    ADJUST_METER:"+" amount:"+amount+" direction:"+direction+" op:"+op+" inum:"+inum+" limitlow:"+limitlow+" limit:"+limit).
        log2file("        "+LISTTOSTRING(PrtsIN)).
      }
      SET BOTPREV TO "zz". SET STPREV TO "zz". 
      set lastdir to direction.
      LOCAL PrtsIN2 to PrtsIN:sublist(1, PrtsIN:length).
      local opset to op.
      local optn1 to opset*3-2.
      local mdn to 0.
      local rnd is 0.
      IF amount:TOSTRING:CONTAINS(".") {//auto set round
        LOCAL AA TO amount:TOSTRING:split(".").
        SET rnd TO min(AA[1]:LENGTH,2).
      }
      if fldin = 0 set FldIn to modulelist[2][inum][optn1].
      if mdl = 0 {if meterlist[0][2][0][0] <> "" set mdl to splitlist(meterlist[0][2][0][0]). ELSE set mdl to modulelist[0][inum][optn1].}
       IF NOT MDL:istype("list") SET MDL TO LIST(MDL).
        for Pt in PrtsIN2 {
          FOR MDL2 IN MDL {
            if getEvAct(pt,MDL2,FldIn,3,2){
              set CurLim to BoolNum(getEvAct(pt,MDL2,FldIn,30,-1,2)).
              if curlim:istype("list"){
                if mtrcur[7]:length > 1 {
                  set curlim to curlim[0].
                  chklim().
                } else break.
              }
                else{
              if NOT CurLim:istype("Scalar") set CurLim to CurLim:tonumber.
                if mtrcur[7]:length > 1 {if mtrcur[7][mtrcur[7]:length-1] = "-1" and limitlow = 1 set limitlow to 0.} 
              if amount <> 0 {
                if mdn = 0 {
                  if direction = "+" {set NewLim to CurLim + amount.} else {set NewLim to CurLim - amount.}
                  if newlim > limit set NewLim to limit. 
                  if newlim < limitlow set NewLim to limitlow.
                  set mdn to 1.
                }
                if mtrcur[7]:length > 1 {
                  if mtrcur[7][mtrcur[7]:length-1] = "-1" chklim().
                  }
              }
              else{set newlim to SwapBool(getEvAct(pt,MDL2,FldIn,30,-1,2)).}
            }
            if curlim:istype("Scalar") and NOT newlim:istype("Scalar") and NOT newlim:istype("Boolean") set NewLim to BoolNum(newlim,1).
            if newlim:istype("Scalar") Pt:getmodule(MDL2):setfield(FldIn, round(NewLim, rnd)). else Pt:getmodule(MDL2):setfield(FldIn, NewLim).
              IF dbglog > 1{
                log2file("        PART:"+pT+" FIELD:"+FldIn+" SET "+CurLim+" TO:"+NewLim).
              }BREAK.
            }
          }
        }
        function chklim{
          local tmplim to mtrcur[7]:find(curlim:tostring).
          if direction = "+" {
            if mtrcur[7]:length-1 > tmplim set newlim to mtrcur[7][tmplim+1].
            else set newlim to mtrcur[7][0].
            IF NEWLIM:TOSTRING = "-1" set newlim to mtrcur[7][0].
          }else{
            if tmplim > 0 set newlim to mtrcur[7][tmplim-1].
            else set newlim to mtrcur[7][mtrcur[7]:length-2].
            IF NEWLIM:TOSTRING = "-1" set newlim to mtrcur[7][mtrcur[7]:length-2].
          }
        }
    }
   function CheckDcpFuel{//decoupler fuel check
    //if dbglog > 2 log2file(" CHECKDCPFUEL").
  for t in Range(1,prttagList[dcptag][0]+1){
    if AutoDspList[dcptag][T] = modeshrt:find("FUEL") {
      if not prttaglist[dcptag][T]:contains("Payload"){
      local trg to 0. 
      local vl to abs(AutoValList[dcptag][T]).
      if vl = 1 set vl to 0.01.
      local fllft to GetFuelLeft(DcpPrtList[T],4,0,AutoRscList[dcptag][T],dcptag, t).
        if not fllft:tostring:contains("                                                                       ") {
          if AutoValList[dcptag][T] > -0.0001 AND fllft > vl set trg to 1.
          if AutoValList[dcptag][T] <  0.0001 AND fllft < vl set trg to 2.
          //if dbglog > 2 log2file("     T("+T+")trg("+trg+") - TargetVal:"+vl+" - ActVal:"+fllft).
          if trg > 0{ToggleGroup(dcptag,t,1,1). ClearAuto(dcptag,t,trg,modeshrt:find("FUEL")).}
        } 
      }
    }
  }
}
   function SetGauge{ //returns gauge of 0-100 percent set to fit after row items 1 and 2. 
      local parameter pct, row, Gmax is 0.
      set pct to round(pct, 0).
      if dbglog > 2 log2file("              SetGauge: pct:"+pct+" GMAX:"+gmax).
      local gauge to ":".
      if pct <> "                                    "{
      if pct:typename <> "Scalar"{
        set pct to removeletters(pct).
        set pct to pct:tonumber.
      }
      if pct < 100.001 {if pct > 100 set pct to 100.
       if Gmax = 0{set GaugeLim to widthlim-3-HudOpts[row][1]:length-HudOpts[row][2]:tostring:length.}else {set GaugeLim to Gmax.}
        FOR i IN RANGE(1, round(pct/(100/GaugeLim),0)) {set gauge to gauge+"=".}
        FOR i IN RANGE(round(pct/(100/GaugeLim),0),100/(100/GaugeLim)) {set gauge to gauge+"_".}
      }else{set gauge to ":OVER LIMIT!!!".}
      return gauge.} else{return pct.}
    }   
   function CheckAGs{//check for external changes in action groups
          if ItemLastRun <> agtag {
          if dbglog > 2 log2file("        CHECKAGs"+" ItemLastRun:"+ItemLastRun).
            for agi in range (0,AgState:length-1) {
              if AgState[agi] <> AgSPrev[agi] {
              if dbglog > 2 log2file("          TOGGROUP:"+(agi+1)+" CRNT:"+AgState[agi]+" PREV:"+AgSPrev[agi]).
                togglegroup(agtag,agi+1,-2,2). 
              }
            }
          }
          set ItemLastRun to 0.
          set AgSPrev to AgState:copy.
      }   
   function MultiMeter{//sets up new meter disaplays
    local itemnum is hsel[2][1].
    local Tagnum is hsel[2][2].
    SET meterpart TO 2.
    local parameter prtin is currentpart, 
    ModIn is MeterList[0][1], 
    MtrList is MeterList[0][2], 
    opt is 0, RND IS -1, rws is 2,  DBGLVL IS 1 .
    local dbglvlH to min(DBGLVL+1,2).
    local rvl to rowval.
    local NoMTR to True.
    if not ModIn:typename:contains("list")  set ModIn to list(modin).
    if opt = 1 or MtrCur[4] = 0 or meterlist[0][0] = "Option Not Available" set rvl to 0.
    if MtrOps[itemnum][0] = 1 set rvl to 1.
    if dbglog > DBGLVL log2file("      MultiMeter:"+prtin+" Mod:"+LISTTOSTRING(modin)+" RowVal:"+rvl).
    if MtrList[0][0] <> "" {
      if MtrList[0][0] <> "" set ModIn to splitlist(MtrList[0][0]).
      if dbglog > dbglvlH log2file("        MtrList[0][0]:"+MtrList[0][0]).}
    if MtrList[1][0] <> "" {if dbglog > dbglvlH log2file("        MtrList[1][0]:"+MtrList[1][0]).}
    if MtrList:length > 2 {if dbglog > dbglvlH log2file("       MtrList[2]:"+LISTTOSTRING(MtrList[2])). 
    }
    local dbgtrk to "0-".
    if FieldList[2]:length = 1 and fieldlist[2][0] ="" set rvl to 0.
    if rvl = 1 {
      set dbgtrk to dbgtrk+"1-".
      FOR Md IN ModIn{
          local MidEnd to "".
        IF prtin:HASMODULE(md){
          if dbglog > dbglvlH log2file("          MOD:"+MD). 
          SET BOTPREV TO "000".
          LOCAL fldV TO FieldList[2][MtrCur[5]].
          local FISAdjBy to mtrcur[7][mtrcur[7]:length-1].
          if rnd = -1 {
            IF mtrcur[7][0]:TOSTRING:CONTAINS(".") {//auto set round
              LOCAL AA TO mtrcur[7][0]:TOSTRING:split(".").
              SET RND TO AA[1]:LENGTH.
            }ELSE SET RND TO 0.
          }
          if prtin:getmodule(MD):hasfield(fldV){
            if dbglog > dbglvlH log2file("          FIELD:"+FLDV).
            local ValRes to getEvAct(prtin,MD,fldV,30,RND,dbglvlH).
            set HudOpts[1][3] TO "". set HudOpts[1][2] TO "".
            set MeterList[0][0] to fldv.
            if mtrcur[7]:length = 3 and mtrcur[7][mtrcur[7]:length-1] <> -1{
              set dbgtrk to dbgtrk+"mtrcur[7] = 3-".
              if ValRes:istype("Boolean") {Set MidEnd to ValRes:tostring. set dbgtrk to dbgtrk+"Bool-". set adjmode to "bool".}
              else{
                if ValRes:istype("Scalar") and MtrCur[1]:istype("Scalar"){ set dbgtrk to dbgtrk+"Scalar-". set adjmode to "num".
                set dbgtrk to dbgtrk+"mtrcur[7] = guage-".                  
                  LOCAL pct TO (ValRes/MtrCur[1])*100.
                  if  mtrcur[0] > 0 set pct to (ValRes-mtrcur[0])/(MtrCur[1]-mtrcur[0])*100.
                  set BOTROW TO " "+fldV+SetGauge(pct,1,widthlim-4-fldV:length-1).//dde
                  set NoMTR to False.
                  set MidEnd to ROUND(ValRes,RND).
                  if fldv:contains("%") set MidEnd to MidEnd+"%".
                  if dbglog > dbglvlH {
                    log2file("                    LineOut1a:"+BOTROW).
                    log2file("                    LineOut2a:"+MidEnd).
                  }
                }
              }
            }
            if NoMTR {
              if FISAdjBy < 1 {
                set dbgtrk to dbgtrk+" < 1-".  set adjmode to "name".
                if FieldList[4]:length > 0 and mtrcur[7]:length > 0{set dbgtrk to dbgtrk+"> than 0-".
                  local fvl to mtrcur[7]:find(ValRes:TOSTRING).
                  if mtrcur[7]:contains(ValRes:tostring){set dbgtrk to dbgtrk+"Contains valres:-".
                  IF mtrcur[8]:LENGTH < mtrcur[7]:LENGTH {until mtrcur[8]:length = mtrcur[7]:LENGTH mtrcur[8]:add("").}
                    if dbglog > DBGLVL {log2file("         SetandReplStr:"+ValRes+"("+fvl+")"). 
                                        log2file("         FieldINName ("+fvl+"):"+LISTTOSTRING(mtrcur[7][fvl])).
                                        log2file("        FieldOUTName ("+fvl+"):"+LISTTOSTRING(mtrcur[8][fvl])).}
                    IF mtrcur[8][fvl] <> "" set ValRes to ReplaceWords(ValRes,FieldList[3][MtrCur[5]],FieldList[4][MtrCur[5]]).
                    set MidEnd to ValRes.
                  }
                }
              }
            }
            if  mtrcur[7][mtrcur[7]:length-1] <> -1
            if dbglog > dbglvlH log2file("                   debugtrack:"+dbgtrk+" NoMtr:"+NoMtr+"  FIELDV:"+fldv+" val:"+MidEnd+" FISAdjBy:"+FISAdjBy).
            set fldv to ReplaceWords(fldV). 
            set HudOpts[1][1] to fldV+":"+MidEnd.
            if dbglog > dbglvlH log2file("                    LineTopOut:"+HudOpts[1][1]).
              if FieldList[5]:length > 1 and FieldList[5][MtrCur[5]] <> "" {set HudOpts[1][1] to HudOpts[1][1]+FieldList[5][MtrCur[5]].}
              else{
              local hout to HudOpts[1][1]:split(":").
              if FindCl3:HASKEY(hout[1]) and hout[1] <> ""{
                set hout[1] to  getcolor(hout[1],FindCl3[hout[1]],2).
                set HudOpts[1][1] to hout[0]+":"+hout[1].
                }
              }
              if dbglog > dbglvlH log2file("                    LineTopOutCLR:"+HudOpts[1][1]).
              break.
          }
        }
      } 
    }
    ELSE {set dbgtrk to dbgtrk+"0a". 
      if FieldList[6][0] <> 0 {set rws to 1. set dbgtrk to dbgtrk+"0b".}
      local pout to FormatFields(prtin,ModIn, MtrList,rws,2,DBGLVL).
      if REMOVESPECIAL(pout[0]," ") = "" or not pout[0]:contains(":") {
      local optn to GrpDspList[itemnum][hsel[2][2]].
        set pout[0] to modulelist[2][itemnum][1]+modulelist[2][itemnum][4-optn]. 
        IF FIELDLIST[1]:LENGTH > 0 SET FORCEREFRESH TO 2.
        if dispinfo > 1 set newhud to 2.
        //set pout[1] to modulelist[2][itemnum][1+optn].
        }
      if FieldList[6][0] <> 0 {
        local nm to 0.
        if  FieldList[6][0]:contains("auto") {
          set pout[1] to GetFuelLeft(prtlist[itemnum][hsel[2][2]],6).
          set nm to GetFuelLeft(prtlist[itemnum][hsel[2][2]],3).
        }else{
          set pout[1] to FieldList[6][0]+GetFuelLeft(prtlist[itemnum][hsel[2][2]],5,widthlim-3-FieldList[6][0]:length).
          set nm to  GetFuelLeft(prtlist[itemnum][hsel[2][2]],3).
        }
        if  FieldList[6][0]:contains("/"){
          local splt to FieldList[6][0]:split("/").
          if nm > 0 set pout[0] to splt[2]. else set pout[0] to splt[1]. 
        }
      }
            set HudOpts[1][3] TO "". 
            set HudOpts[1][2] TO "". 
            set HudOpts[1][1] to pout[0].
            set botrow to " "+pout[1].
            if dbglog > DBGLVL{ log2file("                   MLineOut1:"+pout[0]). 
                                log2file("                   MLineOut2:"+pout[1]).}
      }
      if nomtr = 1 and rvl = 1 {
        set dbgtrk to dbgtrk+"1a".
        set botrow to " "+FormatFields(prtin,ModIn, MtrList,1,2,DBGLVL)[0].
        if dbglog > DBGLVL log2file("                   bRLineOut2:"+botrow).
      }
      if dbglog > dbglvlH log2file("                    DBGTRK:"+DBGTRK).
      return NoMTR.
  }
   function FormatFields{//sets up new text displays
    local parameter prtin, MdIn, MtrList, rws is 2,  RND IS -1, DBGLVL IS 1.
    if FieldList[1]:length = 0 return list("","").
    local dbglvlH to min(DBGLVL+1,2).
    if not MdIn:typename:contains("list") set MdIn to list(MdIn).
    if dbglog > DBGLVL log2file("         FormatFieldsIN :"+" RWS:"+rws+" RND:"+rnd+" "+prtin+" Mod:"+LISTTOSTRING(MdIn)).  
    if MtrList[0][0]:istype("scalar") set MtrList[0] to MtrList[0][MtrList[0][0]].
    if not MtrList:typename:contains("list")set MtrList to list(MtrList).
    if dbglog > DBGLVL log2file("         FormatFieldsADJ:"+prtin+" Mod:"+LISTTOSTRING(MdIn)).                        
        local pout to "".
        local pout2 to "".
        local PrintValOut to list("","","","","","","").
        local styl to FieldList[7].   
        local vn to FieldList[8].
        local addedlines to list().
        local fields to FieldList[1]:COPY.
        //if dbglog > dbglvlH log2file("          fields:"+LISTTOSTRING(fields)). 
        if fieldlist:length > 9 and rowval = 1{
          if fieldlist[9]:length > 0{
            for j in fieldlist[9]{LOCAL CNTJ TO FIELDLIST[2]:FIND(MeterList[2][itemnumcur][0][J[0]:TONUMBER]).
              if CNTJ < mtrcur[5]+1 AND CNTJ > -1 {set fields to J:copy.}}
          }
        }
        if fieldlist:length > 10 and rowval = 0{
          local xt to 0.
          if fieldlist[10]:length > 0{
            for j in fieldlist[10]{
              if j[0]:contains("STATE-") {
                  local ste to j[0]:split("-"). 
                  if dbglog > dbglvlH log2file("          ste:"+LISTTOSTRING(ste)).
                  for k in ste:sublist(1,ste:length-1){if FlState = k {set fields to j:sublist(1,j:length-1):copy. set xt to 1. break.}}
              }if xt = 1 break.
            }
          }
        }
        //if dbglog > dbglvlH log2file("          fields2:"+LISTTOSTRING(fields)). 
        LOCAL FIELDS2 TO FIELDS:copy.
        FOR Md IN mdin{
          if dbglog > dbglvlH log2file("          MOD:"+LISTTOSTRING(md)). 
          IF prtin:HASMODULE(md){
            for i in range(0,fields2:length+1) {
              PrintValOut:add("").
              LOCAL FFAns to "".
              if i < fields2:length {set FFAns to getEvAct(prtin,md,fields2[i]:tostring:REPLACE("\","/"),30,RND,dbglvlH).}
                //if dbglog > dbglvlH log2file("          fields("+i+"):"+fields2[i]+" FFAns:"+FFAns).} 

              if REMOVESPECIAL(FFAns," ") <> ""{
                if FFAns:istype("scalar"){if abs(FFAns) > 10 set FFAns to round(FFAns,0).}.
                local tmp to fields2[i]:tostring:REPLACE("\","/").
                //if dbglog > dbglvlH log2file("          tmp:"+tmp). 
                if FieldList[4]:length > 0 and FieldList[2]:length > 0{
                  if FieldList[2]:contains(tmp:TOSTRING){
                    local fvl to FieldList[2]:find(tmp:TOSTRING).
                    if dbglog > dbglvlH {log2file("           FieldINNames("+fvl+"):"+LISTTOSTRING(FieldList[3][fvl])). 
                                        log2file("          FieldOUTNames("+fvl+"):"+LISTTOSTRING(FieldList[4][fvl])).}
                    IF FieldList[4][fvl] <> "" set FFAns to ReplaceWords(FFAns,FieldList[3][fvl],FieldList[4][fvl]).
                  }
                }
                
                if not addedlines:contains(tmp:tostring){
                  FIELDS:REMOVE(FIELDS:FIND(fields2[i]:tostring)).
                  addedlines:add(tmp).
                  set PrintValOut[i] to tmp+":"+FFAns.
                  if FFAns = "NA" or FFAns = "N/A" {set PrintValOut[i] to "".}
                  //if dbglog > dbglvlH log2file("          PrintValOut("+i+"):"+PrintValOut[i]). 
                }
              }
            }
          }
        }
            for i in range (PrintValOut:length-1,0) if PrintValOut[i] = "" PrintValOut:remove(i).
            if PrintValOut[0] = "" PrintValOut:remove(0).
            if PrintValOut:contains("") PrintValOut:remove(PrintValOut:find("")).
            if dbglog > dbglvlH log2file("          PrintValOut:"+LISTTOSTRING(PrintValOut)).
            local lngth to 0.
            local brk to min(PrintValOut:length,3).
            local brkadd to 0.
            if rws = 1 set brk to PrintValOut:length. 
            if brk > 2 {
              for ln in range(0,PrintValOut:length){
                set lngth to PrintValOut[ln]:length.
                if lngth > widthlim-5 {set brk to ln. break.}
              }
            }
            if rws > 1{
              if PrintValOut:length > 4 set brk to 3. else
              if PrintValOut:length = 4 set brk to 2. 
              if PrintValOut:length > 4 {
                local lng to widthlim.
                for i in PrintValOut:sublist(brk-1,PrintValOut:length-1) set lng to -i:length.
                if lng > 7 set brk to brk-1.
              }else
              if PrintValOut:length > 1 AND PrintValOut:length < 4 set brk to 1.
            }
            local polngth to list(PrintValOut:length-brk,PrintValOut:length-(PrintValOut:length-brk)).
            for i in range (0,PrintValOut:length){
              local hout to PrintValOut[i]:split(":").
              global tsth to hout:copy.
              local mdl to ":".
              if hout[0] <> "" {
                local h0Raw to hout[0].
                set hout[0] to ReplaceWords(hout[0]).
                local fnd to fieldlist[1]:find(h0Raw).
                if fnd > -1 {
                  if fieldList[7][0] <> 0 {
                    if styl:length > 1 if styl[fnd] <> "" {
                      if styl[fnd]:contains("M-") OR styl[fnd]:contains("Mn-") OR styl[fnd]:contains("Mp-"){
                        local lms to styl[fnd]:split("-").
                        local liml to lms[1].
                        local limh to lms[2].
                        local tmp1 to "".
                        LOCAL ANS1 TO  hout[1].
                        if ans1:contains("K /") {
                          set tmp1 to ans1:split("/").
                          set ans1 to tmp1[0].
                          set limh to round(RemoveLetters(RemoveLetters(tmp1[1]),"/ "):tonumber,0).
                          set liml to 0.
                        }
                        set ANS1 TO  RemoveLetters(RemoveLetters(ANS1),"/ ").
                        if ans1:length > 9 set ans1 to ans1:substring(0,9).
                        if ans1 <> "" {
                          if not ans1:istype("string") set ans1 to ans1:tostring.
                          if ans1:contains("."){
                            local ddd to ans1:split(".").
                            if ddd[1]:length < 3{set ans1 to round(ans1:tonumber,0).}else{set ans1 to removeletters(ans1,".").}}
                          set ans1 to BoolNum(ans1,1).
                          set liml to BoolNum(liml,1).
                          set limh to BoolNum(limh,1).
                          if liml+limh = 0 {
                            local aaa to "".
                            for mdls in MtrSpecList {local bbb to getEvAct(prtin,mdls,h0Raw,30). if bbb <> false and bbb <> "" {set aaa to bbb. break.}}
                            IF AAA <> "" {
                              set aaa to removeletters(aaa).
                              set aaa to aaa:split("/").
                              set liml to 0.
                              set ans1 to aaa[0]:tonumber.
                              set limh  to aaa[1]:tonumber.
                            }
                          }
                          local pct to ans1/limh*100.
                          if  liml > 0 set pct to ((ans1-liml)/(limh-liml)*100).
                          local submore to 0.
                          IF PrintValOut:length = 5 AND BRK = 2 SET BRKADD TO 1.
                          //if i > 0 and brk = 1 set brkadd to PrintValOut):length/4. 
                          local lnlngth to polngth[0].
                          if i > brk set lnlngth to polngth[1].
                          //if PrintValOut:length-1 > i+1 and PrintValOut:length > 3 set lnlngth to 2.
                          if lnlngth > 1 {
                            if PrintValOut:length-1 > i set submore to PrintValOut[i+1]:length.
                            if PrintValOut:length-1 > i+1  set submore to submore+PrintValOut[i+2]:length.
                            if PrintValOut:length-1 > i+1 set submore to submore+PrintValOut[i+2]:length.
                          }
                          IF styl[fnd]:contains("Mp-") set hout[0] to hout[0]+"("+round(PCT,0)+"%)".
                          IF styl[fnd]:contains("Mn-") set hout[0] to HOUT[0]+"("+ans1+")".
                          local gl to (widthlim/(max(1,lnlngth)))-hout[0]:length.
                          if gl+hout[0]:length > widthlim-5 set gl to (widthlim/(max(1,lnlngth)))-hout[0]:length-5.
                          if colorprint = 1 and lnlngth = 1 set hout[1] to GETCOLOR(SetGauge(pct, 1, gl-4),mtrcolor(pct)).
                          else set hout[1] to SetGauge(pct, 1, gl).//finish meter fix
                          if hout[1]:contains(":") or  hout[0]:contains(":") set mdL to "".
                        }
                      }
                    }
                  }
                }
                set hout[1] to ReplaceWords(hout[1]).
                if rws > 1 and brk < 2 and i < 1{if FindCl3:HASKEY(hout[1]){set hout[1] to getcolor(hout[1],FindCl3[hout[1]],2).}}
                if VN:length > 1 and fnd > -1 if vn[fnd] <> "" set hout[1] to hout[1]+vn[fnd].
                set PrintValOut[i] to hout[0]+mdl+hout[1].
              }
            }
            local Pbrk to brk+brkadd.
            if PrintValOut:length > 6 set PrintValOut to PrintValOut:sublist(0,6).
            until PrintValOut:length > brk+2 PrintValOut:add("").
            global tstbrk to brk.
            global tstpo to PrintValOut.
            local addxtra to 0.
            if brk = 2 or lngth < widthlim*0.8 set addxtra to 2.
            local l3max to 0.
            local l1max to                  max(PrintValOut[0]:length+1,PrintValOut[brk]:length+2+addxtra).
            local l2max to                  max(PrintValOut[1]:length+1,PrintValOut[brk+1]:length+2+addxtra).
                  if Pbrk > 2  set l3max to max(PrintValOut[2]:length+1,PrintValOut[brk+2]:length+2+addxtra).
            local inb to max(0,(widthlim-2-l1max-l2max-l3max)/max(brk-1,1)). 
            IF (l1max+inb+l2max+inb+l3max) < widthlim-3 {UNTIL (l1max+inb+l2max+inb+l3max) > WIDTHLIM-4 SET INB TO INB+1.}
            local inb2 to inb.
            //if brk > 2 {LOCAL INB2 TO INB+(l2max/2). SET INB TO INB-(l2max/2).}
            set pout  to PrintValOut[0]:padright(l1max+inb).
            if brk >1 set pout to pout+PrintValOut[1]:padright(l2max+INB2).
            if brk >2 set pout to pout+PrintValOut[2].
            set pout2 to PrintValOut[brk]:padright(max(0,l1max+inb))+PrintValOut[brk+1]:padright(max(0,l2max+INB2))+PrintValOut[brk+2].
            if dbglog > DBGLVL{ log2file("                   LineOut1:"+pout). 
                                log2file("                   LineOut2:"+pout2). 
                                log2file("                   List:"+LISTTOSTRING(PrintValOut)).
                                log2file("                    BRK:"+brk).}
        return list(pout, pout2).
  }
   Function SplitDisplayList{//split list to usable format
    local parameter  MdInDl, MtrList, OPT IS 0, DBGLVL IS 1. //MeterList[1][itemnumcur], MeterList[2][itemnumcur]
    if dbglog > DBGLVL log2file("     SplitDisplayList ModIn:"+LISTTOSTRING(MdInDl)). 
    local PrintFieldVals to list().
    local FieldReplaceNames to list().
    local FieldGoodNames to list().
    local ValueNames   to list().
    local FieldAllVals   to list().
    local GetFuel   to list(0).
    local SetStyle  to list(0).
    local MValueNames  to list().
    local BotRowNames to list().
    local ALTRowNames to list().
    set MeterList[0][1] to list().
    set MeterList[0][2] to list().
        if MtrList:length > 0 {
          for i in range (0,MtrList:length+1){if i = MtrList:length break.
            meterlist[0][2]:add(MtrList[i]:copy).
          }
          set MtrList to meterlist[0][2]:copy.
        }
    if meterlist[0][2]:typename:contains("list"){
      if meterlist[0][2]:length > 1 set FieldReplaceNames to meterlist[0][2][1].
      if meterlist[0][2][0]:typename:contains("list") {
        if meterlist[0][2][0][0] <> "" set MdInDl to splitlist(meterlist[0][2][0][0]).
        if meterlist[0][2][1][0] <> "" {
          if dbglog > DBGLVL log2file("         meterlist[0][2][1]:"+LISTTOSTRING(meterlist[0][2][1])). 
          set PrintFieldVals to meterlist[0][2][1][0]:split("/").
        }
        IF OPT = 1 and MtrOps[hsel[2][1]][0] = 0{
          set mdindl to TrimModules2(mdindl).
          if MeterList[0][2][0]:length > 1{
            set MeterList[0][2] to trimfields(MeterList[0][2]:copy, MdInDl).
          }
        }
        set MtrCur[4] to MeterList[0][2][1]:length-1.
        set MtrCur[3] to 1.
        if MtrCur[5] < MtrCur[3] set MtrCur[5] to MtrCur[3].
        if MtrCur[5] > MtrCur[4] set MtrCur[5] to MtrCur[4].
        if meterlist[0][2]:length > 2 {
          local cnt2 to 0.
          for i in range (2,meterlist[0][2]:length+1){if i = meterlist[0][2]:length break.
            if dbglog > DBGLVL log2file("         meterlist[0][2]["+i+"]:"+LISTTOSTRING(meterlist[0][2][i])). 
            if meterlist[0][2][i][0] <> "" and i > 1{
              if meterlist[0][2][i][0] = "Names"set FieldGoodNames to meterlist[0][2][i]:copy.
              if meterlist[0][2][i][0]:contains("Values"){
                set ValueNames to meterlist[0][2][i]:copy.
                local vn to ValueNames.
                if meterlist[0][2][i]:length > 0 {set vn to splitlist(meterlist[0][2][i][0]).
                  //if meterlist[0][2][i][0]:contains("/") set vn to meterlist[0][2][i][0]:split("/"). 
                  for k in range (0,vn:length){set vn[k] to REMOVESPECIAL(VN[K]:TOSTRING:REPLACE("\","/")," ").}
                  SET VN TO VN:SUBLIST(1,VN:LENGTH).
                  if vn:length < PrintFieldVals:length {until vn:length > PrintFieldVals:length-1 vn:add("").}
                  set MValueNames to vn.
                }
              }
              if meterlist[0][2][i][0]:contains("BotRow"){
                local Pfv to meterlist[0][2][i][0]:split("/").
                local brv to pfv[0]:REPLACE("botrow",""). 
                if brv = "" set brv to "0". 
                set pfv[0] to brv:tostring.
                BotRowNames:add(Pfv).
                set cnt2 to cnt2+1.
              }
              if meterlist[0][2][i][0]:contains("Style")  {
                set SetStyle to meterlist[0][2][i][0]:split("/"). 
                set SetStyle to SetStyle:sublist(1,SetStyle:length-1).
                    for k in range (0,SetStyle:length){set SetStyle[k] to REMOVESPECIAL(SetStyle[K]:TOSTRING:REPLACE("\","/")," ").}
              }
              else
              if meterlist[0][2][i][0]:contains("Fuelleft") set getfuel to list(meterlist[0][2][i][1]).
              else
              if meterlist[0][2][i][0]:contains("AltVal") {
                local splt to meterlist[0][2][i][0]:split("/").
                if ALTVAL = splt[1]:tonumber {set FieldReplaceNames to meterlist[0][2][i].}
              }else
              if meterlist[0][2][i][0]:contains("STATE-")  ALTRowNames:add(meterlist[0][2][i][0]:split("/")).
            }
          }
        }
        set FieldAllVals to meterlist[0][2][0]:copy. //MeterList[2][itemnumcur][0]  
        if dbglog > DBGLVL log2file("         meterlist[0][2][0]:"+LISTTOSTRING(meterlist[0][2][0])).
        if meterlist[0][2][0][0] <> "" {set MdInDl to list(meterlist[0][2][0][0]).}
        if meterlist[0][2][1][0] <> "" {
          if dbglog > DBGLVL log2file("         meterlist[0][2][1]:"+LISTTOSTRING(meterlist[0][2][1])). 
          set PrintFieldVals to meterlist[0][2][1][0]:split("/").
        }
      }
    }else{set meterlist[0][2] to list(meterlist[0][2]).}
    LOCAL TMPTRM TO LIST(PrintFieldVals:COPY).
    LOCAL L2 TO 0.  LOCAL SS TO 0. LOCAL VNM TO 0.
    IF NOT SetStyle[0]:typename:contains("SCALAR") {TMPTRM:ADD(SetStyle). SET L2 TO L2+1. SET SS TO L2.}
    IF MValueNames:LENGTH > 0 {TMPTRM:ADD(MValueNames). SET L2 TO L2+1. SET VNM TO L2.}
    //IF TMPTRM:LENGTH > 1 {
      set TMPTRM to trimfields(TMPTRM, MdInDl,-1).
      
    //}
    //ELSE set TMPTRM to LIST(trimfields(PrintFieldVals, MdInDl,hsel[2][1],hsel[2][2],BotRowNames:copy)).
    set PrintFieldVals to TMPTRM[0].
    IF SS > 0 set SetStyle to TMPTRM[SS].
    IF VNM > 0 set MValueNames to TMPTRM[VNM].
    if dbglog > DBGLVL {log2file("            PrintFieldVals:"+LISTTOSTRING(PrintFieldVals)). 
                        log2file("            FieldAllVals:"+LISTTOSTRING(FieldAllVals)).
                        log2file("            FieldReplaceNames:"+LISTTOSTRING(FieldReplaceNames)).
                        log2file("            FieldGoodNames:"+LISTTOSTRING(FieldGoodNames)).
                        log2file("            ValueNames:"+LISTTOSTRING(ValueNames)).
                        log2file("            MValueNames:"+LISTTOSTRING(MValueNames)).
                        log2file("            getfuel:"+LISTTOSTRING(getfuel)).
                        log2file("            SetStyle:"+LISTTOSTRING(SetStyle)).
                        }
    if not meterlist[0][2][0]:typename:contains("list") {set PrintFieldVals to splitlist(meterlist[0][2][0]).
      //if meterlist[0][2][0]:contains("/")  set PrintFieldVals to meterlist[0][2][0]:split("/").
    }
    //if PrintFieldVals:length = 0 set PrintFieldVals to meterlist[0][2].
    set REMETER TO 0.
    return list(mdinDl, PrintFieldVals:copy,FieldAllVals:copy,FieldReplaceNames:copy,FieldGoodNames:copy,ValueNames:copy,Getfuel:copy,SetStyle:copy,MValueNames:COPY, BotRowNames:copy,ALTRowNames:copy).
  }
   function QuickField{//old method for fallover
    local parameter pt is p, hdi is hsel[2][1], mx is 4, mn is 1.
    if dbglog > 1 log2file("         QuickField:"+pt+"("+hdi+")").
    if MeterList[0][2] <> 0 {
      multimeter().
    }
    else{
      set mx to mx*3-2.
      set mn to mn*3-2.
      local lo1 to list().
      local lo2 to list().
      for i in range(1,13,3){
        if i > mn-1 and i < mx+1 {
          lo1:add(modulelist[0][hdi][i]).
          lo1:add(modulelist[1][hdi][i]).                    
          lo2:add(modulelist[2][hdi][i]).
        }
      }
      set hudopts[1][1] to FormatFields(pt,lo1,lo2,1,0)[0].
    }
  }
   function CycleAjdBy{//change amount to adjust by
    local adjL to list(1,5,10,25,50,100,1000).
    if dbglog > 2 log2file("       CycleAdjBy:").
    IF mtrcur[7][0]:TOSTRING:CONTAINS(".") {
      LOCAL AA TO mtrcur[7][0]:TOSTRING:split(".").
      local bb TO AA[1]:LENGTH.
      if bb= 1 set adjL to list(0.1,0.25,0.5,1,5,10,25).
      if bb= 2 set adjL to list(0.01,0.05,0.1,0.5,1,5,10,25).
    }
    local crnt to mtrcur[2].
    if adjL:contains(crnt){
      set cr to  adjL:find(crnt).
      if cr < adjL:length-1 set cr to cr+1. else set cr to 0.
      set crnt to adjL[cr].
        if mtrcur[1] < crnt+.0001 set crnt to adjL[0].
        if dbglog > 2 log2file("              SET "+mtrcur[2]+" TO:"+crnt).
        set mtrcur[2] to crnt.
    }
  }
   //#region MKS
   Function MKSConvCheck{
    local parameter fl,J,huditem, hudtag.
    local err1 to "". local err2 to "".
      if fl = "reactor"{ 
          if ship:resources[RscNum["EnrichedUranium"]]:capacity = 0 set err1 to ": No Enriched Uranium Storage". else if ship:resources[RscNum["EnrichedUranium"]]:amount < 0.01 set err1 to ": No Enriched Uranium".
          if ship:resources[RscNum["DepletedFuel"]]:capacity = 0 set err2 to ": No Depleted Fuel Storage". else if ship:resources[RscNum["DepletedFuel"]]:amount > ship:resources[RscNum["DepletedFuel"]]:capacity-0.5 set err2 to ": Depleted Fuel Full". 
          if err1+err2 = "" {
              set hudopts[J][2] to hudopts[J][3]+":Enriched Uranium".
              set hudopts[J][3] to SetGauge(ship:resources[RscNum["EnrichedUranium"]]:amount/ship:resources[RscNum["EnrichedUranium"]]:capacity*100,J).
          }else{
              set hudopts[J][3] to err1+err2. 
              set GrpDspList[HudItem][hudtag] to 1. set forcerefresh to 1.
          }
      }else{   
        if fl = "agroponics" or fl = "[greenhouse]" { ResourceCheck(j, huditem, hudtag, "Mulch", "", "Fertilizer", "", ""). }else{                                                       
        if fl = "chemicals"                  { ResourceCheck(j, huditem, hudtag,"Minerals"        , ""                , ""           , ""                  , "Chemicals"        ). }else{
        if fl = "[smelter]"                  { ResourceCheck(j, huditem, hudtag,"Machinery"       , ""                , ""           , ""                  , ""                 ). }else{
        if fl = "[crushser]"                 { ResourceCheck(j, huditem, hudtag,"Machinery"       , ""                , ""           , ""                  , ""                 ). }else{
        if fl = "Sifter"                     { ResourceCheck(j, huditem, hudtag,"Dirt"            , ""                , ""           , ""                  , "Machinery"        ). }else{
        if fl = "Silicon"                    { ResourceCheck(j, huditem, hudtag,"Silicates"       , "Machinery"       , ""           , ""                  , "Silicon"          ). }else{
        if fl = "Polymers"                   { ResourceCheck(j, huditem, hudtag,"Substrate"       , ""                , ""           , ""                  , "Polymers"         ). }else{
        if fl = "RefinedExotics"             { ResourceCheck(j, huditem, hudtag,"ExoticMinerals"  , "RareMetals"      , "Chemicals"  , ""                  , "RefinedExotics"   ). }else{
        if fl = "h2o (Hyd)"                  { ResourceCheck(j, huditem, hudtag,"Hydrates"        , ""                , ""           , ""                  , "Water"            ). }else{
        if fl = "h2o (Kar)"                  { ResourceCheck(j, huditem, hudtag,"Karbonite"       , ""                , ""           , ""                  , "Water"            ). }else{
        if fl = "h2o (Ore)"                  { ResourceCheck(j, huditem, hudtag,"Ore"             , ""                , ""           , ""                  , "Water"            ). }else{
        if fl = "Chemicals"                  { ResourceCheck(j, huditem, hudtag,"Minerals"        , ""                , ""           , ""                  , "Chemicals"        ). }else{
        if fl = "Fertilizer(G)"              { ResourceCheck(j, huditem, hudtag,"Gypsum"          , ""                , ""           , ""                  , "Fertilizer"       ). }else{
        if fl = "Fertilizer(M)"              { ResourceCheck(j, huditem, hudtag,"Minerals"        , ""                , ""           , ""                  , "Fertilizer"       ). }else{
        if fl = "Metals"                     { ResourceCheck(j, huditem, hudtag,"MetallicOre"     , ""                , ""           , ""                  , "Metals"           ). }else{
        if fl = "LFO"                        { ResourceCheck(j, huditem, hudtag,"Ore"             , ""                , ""           , ""                  , "LiquidFuel"       , "Oxidizer"). }else{//not sure always full
        if fl = "LiquidFuel"                 { ResourceCheck(j, huditem, hudtag,"Ore"             , ""                , ""           , ""                  , "LiquidFuel"       ). }else{//not sure always full
        if fl = "Monopropellant"             { ResourceCheck(j, huditem, hudtag,"Ore"             , ""                , ""           , ""                  , "Monopropellant"   ). }else{
        if fl = "Recycling"                  { ResourceCheck(j, huditem, hudtag,"Recyclables"     , ""                , ""           , ""                  , "Metals"           ,"Chemicals", "Polymers"). }else{
        if fl = "RocketParts"                { ResourceCheck(j, huditem, hudtag,"SpecializedParts", "MaterialKits"    , ""           , ""                  , "RocketParts"      ). }else{
        if fl = "DepletedFuel"               { ResourceCheck(j, huditem, hudtag,"DepletedFuel"    , ""                , ""           , ""                  , "EnrichedUranium"  ). }else{
        if fl = "SpecializedParts"           { ResourceCheck(j, huditem, hudtag,"RefinedExotics"  , ""                , "Silicon"    , ""                  , "SpecializedParts" ). }else{
        if fl = "MaterialKits"               { ResourceCheck(j, huditem, hudtag,"Metals"          , "Polymers"        , "Chemicals"  , ""                  , "MaterialKits"     ). }else{
        if fl = "agriculture(s)"             { ResourceCheck(j, huditem, hudtag,"Substrate"       , "Water"           , "Fertilizer" , "Organics"          , ""                 ). }else{
        if fl = "agriculture(d)"             { ResourceCheck(j, huditem, hudtag,"Dirt"            , "Water"           , "Organics"   , "Fertilizer"        , ""                 ). }else{
        if fl = "ColonySupplies"             { ResourceCheck(j, huditem, hudtag,"Organics"        , "SpecializedParts", "MaterialKits", ""                 , "ColonySupplies"   ). }else{
        if fl = "Machinery"                  { ResourceCheck(j, huditem, hudtag,"SpecializedParts", ""                , "MaterialKits", ""                 , "Machinery"        ). }else{
        if fl = "EnrichedUranium"            { ResourceCheck(j, huditem, hudtag,"Uraninite"       , ""                , ""           , ""                  , "EnrichedUranium"  ). }else{
        if fl = "Deuterium"                  { ResourceCheck(j, huditem, hudtag,"Deuterium"       , "Helium3"         , ""           , ""                  , "D2"               ). }else{
        if fl = "FusionPellets"              { ResourceCheck(j, huditem, hudtag,"FusionPellets"   , ""                , "Helium3"    , ""                  , ""                 ). }else{
        if fl = "Silicates"                  { ResourceCheck(j, huditem, hudtag,"Silicates"       , ""                , ""           , ""                  , "Silicates"        ). }else{
        if fl = "Minerals"                   { ResourceCheck(j, huditem, hudtag,""                , ""                , ""           , ""                  , "Minerals"         ). }else{
        if fl = "MetallicOre"                { ResourceCheck(j, huditem, hudtag,""                , ""                , ""           , ""                  , "MetallicOre"      ). }else{
        if fl = "cultivate(s)"               { ResourceCheck(j, huditem, hudtag,"Substrate"       , "Water"           , "Fertilizer" , ""                  , ""                 ). }else{
        if fl = "cultivate(d)"               { ResourceCheck(j, huditem, hudtag,"Dirt"            , "Water"           , "Fertilizer" , ""                  , ""                 ). }else{
        if fl = "centrifuge"                 { ResourceCheck(j, huditem, hudtag,"Uraninite"       , ""                , ""           , ""                  , "EnrichedUranium"  ). }else{
        if fl = "breeder"                    { ResourceCheck(j, huditem, hudtag,"depletedfuel"    , ""                , ""           , ""                  , "EnrichedUranium"  ). }else{
        if fl = "electronics"                { ResourceCheck(j, huditem, hudtag,"MaterialKits"    , "Synthetics"      , ""           , ""                  , "electronics"      ). }else{
        if fl = "Alloys"                     { ResourceCheck(j, huditem, hudtag,"Metals"          , "RareMetals"      , ""           , ""                  , "Alloys"           ). }else{
        if fl = "Prototypes"                 { ResourceCheck(j, huditem, hudtag,"Electronics"     , "Robotics"        , "Machinery"  , "SpecializedParts"  , ""                 ). }else{
        if fl = "Robotics"                   { ResourceCheck(j, huditem, hudtag,"Alloys"          , "MaterialKits"    , "Machinery"  , ""                  , "Robotics"         ). }else{      
        if fl = "Synthetics"                 { ResourceCheck(j, huditem, hudtag,"Machinery"       , "ExoticMinerals"  , "Polymers"   , ""                  , "Synthetics"       ). }else{     
        if fl = "Dirt"                       { ResourceCheck(j, huditem, hudtag,""                , ""                , ""           , ""                  , "Dirt"       ). }else{  
        if fl = "transportCredits"           { ResourceCheck(j, huditem, hudtag,"MaterialKits"    , "liquidfuel"      , ""           , ""                  , "transportCredits"). }else{  
        //if fl = "Lodeharvester"            { ResourceCheck(j, huditem, hudtag,""                , ""                , ""           , ""                  , "ResourceNode"  ). }else{



          
        }}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}
  }
   Function MKSDrillCheck{
      local parameter fl,j,huditem, hudtag.
        if fl = "Dirt"                      { ResourceCheck(j, huditem, hudtag, ""       , ""                , ""           , ""                  , "Dirt"             ). }else{//working      
        if fl = "Minerals"                  { ResourceCheck(j, huditem, hudtag, ""       , ""                , ""           , ""                  , "Minerals"         ). }else{
        if fl = "Silicates"                 { ResourceCheck(j, huditem, hudtag, ""       , ""                , ""           , ""                  , "Silicates"        ). }else{
        if fl = "Ore"                       { ResourceCheck(j, huditem, hudtag, ""       , ""                , ""           , ""                  , "Ore"              ). }else{
        if fl = "Exotic Minerals"           { ResourceCheck(j, huditem, hudtag, ""       , ""                , ""           , ""                  , "ExoticMinerals"   ). }else{
        if fl = "Karbonite"                 { ResourceCheck(j, huditem, hudtag, ""       , ""                , ""           , ""                  , "Karbonite"        ). }else{
        if fl = "Uraninite"                 { ResourceCheck(j, huditem, hudtag, ""       , ""                , ""           , ""                  , "Uraninite"        ). }else{
        if fl = "Gypsum"                    { ResourceCheck(j, huditem, hudtag, ""       , ""                , ""           , ""                  , "Gypsum"           ). }else{
        if fl = "Substrate"                 { ResourceCheck(j, huditem, hudtag, ""       , ""                , ""           , ""                  , "Substrate"        ). }else{
        if fl = "MetallicOre"               { ResourceCheck(j, huditem, hudtag, ""       , ""                , ""           , ""                  , "MetallicOre"      ). }else{
        if fl = "Water"                     { ResourceCheck(j, huditem, hudtag, ""       , ""                , ""           , ""                  , "Water"            ). }else{
        if fl = "Hydrates"                  { ResourceCheck(j, huditem, hudtag, ""       , ""                , ""           , ""                  , "Hydrates"         ). }else{
        if fl = "Uraninite"                 { ResourceCheck(j, huditem, hudtag, ""       , ""                , ""           , ""                  , "Uraninite"        ). }else{
        if fl = "RareMetals"                { ResourceCheck(j, huditem, hudtag, ""       , ""                , ""           , ""                  , "RareMetals"       ). }else{
        if fl = "Rock"                      { ResourceCheck(j, huditem, hudtag, ""       , ""                , ""           , ""                  , "Rock"             ). }else{
        }}}}}}}}}}}}}}}
   
  }
   function ResourceCheck {
      local parameter j, huditem, hudtag, RsIn1, RsIn2, RsIn3, RsIn4 is "", RsOt1 is "", RsOt2 is "", RsOt3 is "".
      local err1 to "". local err2 to "". local err3 to "". local err4 to "". local GgL to 0. local ggl2 to 0.
      local p1 to 0. local p2 to 0. local p3 to 0. local p4 to 0. LOCAL P5 TO 0. local p6 to 0. local p7 to 0.
      if RsIn1 <> ""{set p1 to 1. 
        if RscNum:HASKEY(RsIn1){
          set ggl to ggl+ RscList[RscNum[RsIn1]][1]:length+1.
          if ship:resources[RscNum[RsIn1]]:capacity = 0 set err1 to ": No " +RscList[RscNum[RsIn1]][1] + " Storage". 
          else if ship:resources[RscNum[RsIn1]]:amount < 0.01 set err1 to ": No " +RscList[RscNum[RsIn1]][1].
        }else{Set err1 to ": No " +RsIn1+ " Storage".} 
      }
      if RsIn2 <> ""{set p2 to 1. 
        if RscNum:HASKEY(RsIn2){
          set ggl to ggl+RscList[RscNum[RsIn2]][1]:length+2.
          if ship:resources[RscNum[RsIn2]]:capacity = 0 set err2 to ": No " +RscList[RscNum[RsIn2]][1] + " Storage". 
          else if ship:resources[RscNum[RsIn2]]:amount < 0.01 set err2 to ": No " +RscList[RscNum[RsIn2]][1].
        }else{Set err2 to ": No " +RsIn2+ " Storage". }
      }
      if RsIn3 <> ""{set p3 to 1. set p6 to 1.
        if RscNum:HASKEY(RsIn3){
          set ggl2 to ggl2+RscList[RscNum[RsIn3]][1]:length.
          if ship:resources[RscNum[RsIn3]]:capacity = 0 set err3 to ": No " +RscList[RscNum[RsIn3]][1] + " Storage". 
          else if ship:resources[RscNum[RsIn3]]:amount < 0.01 set err3 to ": No " +RscList[RscNum[RsIn3]][1].
        }else{set err3 to ": No " +RsIn3+ " Storage". }
      }
      if RsIn4 <> ""{set p4 to 1. 
        if RscNum:HASKEY(RsIn4){
          set ggl2 to ggl2+RscList[RscNum[RsIn4]][1]:length+1.
          if ship:resources[RscNum[RsIn4]]:capacity = 0 set err4 to ": No " +RscList[RscNum[RsIn4]][1] + " Storage". 
          else if ship:resources[RscNum[RsIn4]]:amount < 0.01 set err4 to ": No " +RscList[RscNum[RsIn4]][1].
        }else{set err4 to ": No " +RsIn4+ " Storage". }
      }
      if RsOt1 <> ""{set p4 to 1. SET P5 TO 1. 
        if RscNum:HASKEY(RsOt1){
          set ggl2 to ggl2+RscList[RscNum[RsOt1]][1]:length+1.
          if ship:resources[RscNum[RsOt1]]:capacity = 0 set err4 to ": No " +RscList[RscNum[RsOt1]][1] + " Storage". 
          else if ship:resources[RscNum[RsOt1]]:amount > ship:resources[RscNum[RsOt1]]:capacity-0.5 set err4 to ": "+RscList[RscNum[RsOt1]][1]+" Full".
        }else{set err4 to ": No " +RsOt1+ " Storage". }
      }
      if RsOt2 <> ""{set p6 to 1. SET P4 TO 1. set p5 to 2. 
        if RscNum:HASKEY(RsOt2) {
        if  RscNum:HASKEY(RsOt1){
        set ggl2 to ggl2+RscList[RscNum[RsOt2]][1]:length+1.
        if ship:resources[RscNum[RsOt1]]:capacity = 0 set err3 to ": No " +RscList[RscNum[RsOt1]][1] + " Storage". 
          else if ship:resources[RscNum[RsOt1]]:amount > ship:resources[RscNum[RsOt1]]:capacity-0.5 set err3 to ": "+RscList[RscNum[RsOt1]][1]+" Full".
        set err4 to"".
        if ship:resources[RscNum[RsOt2]]:capacity = 0 set err4 to ": No " +RscList[RscNum[RsOt2]][1] + " Storage". 
          else if ship:resources[RscNum[RsOt2]]:amount > ship:resources[RscNum[RsOt2]]:capacity-0.5 set err4 to ": "+RscList[RscNum[RsOt2]][1]+" Full".
      }else{}
        }else{set err3 to ": No " +RsOt2+ " Storage". }
      }
      if RsOt3 <> ""{set p7 to 1. 
        if RscNum:HASKEY(RsOt3){
        set ggl to ggl+RscList[RscNum[RsOt3]][1]:length+2.
          if ship:resources[RscNum[RsOt3]]:capacity = 0 set err2 to ": No " +RscList[RscNum[RsOt3]][1] + " Storage". 
            else if ship:resources[RscNum[RsOt3]]:amount > ship:resources[RscNum[RsOt3]]:capacity-0.5 set err2 to ": "+RscList[RscNum[RsOt3]][1]+" Full".
        }else{set err4 to ": No " +RsOt3+ " Storage".}       
      }
            if err1+err2+err3+err4 = "" {
              set ggl  to (widthlim-3-ggl-hudopts[J][3]:length-hudopts[J][2]:length-hudopts[J][1]:length)/2*(2-p2-p7)-1.
              set ggl2 to (widthlim-3-ggl2)/2*(2-p6).
                if p1 = 1             set err1 to RscList[RscNum[RsIn1]][1]+SetGauge(ship:resources[RscNum[RsIn1]]:amount/ship:resources[RscNum[RsIn1]]:capacity*100,J,GgL).
                if p2 = 1             set err2 to RscList[RscNum[RsIn2]][1]+SetGauge(ship:resources[RscNum[RsIn2]]:amount/ship:resources[RscNum[RsIn2]]:capacity*100,J,GgL).
                if p7 = 1             set err2 to RscList[RscNum[RsOt3]][1]+SetGauge(ship:resources[RscNum[RsOt3]]:amount/ship:resources[RscNum[RsOt3]]:capacity*100,J,GgL).
                if p3 = 1             set err3 to RscList[RscNum[RsIn3]][1]+SetGauge(ship:resources[RscNum[RsIn3]]:amount/ship:resources[RscNum[RsIn3]]:capacity*100,J,(GgL2)).
                if p4 = 1 AND P5 = 0  set err4 to RscList[RscNum[RsIn4]][1]+SetGauge(ship:resources[RscNum[RsIn4]]:amount/ship:resources[RscNum[RsIn4]]:capacity*100,J,(GgL2)).
                if p4 = 1 AND P5 = 1  {
                  if p1+p2>0{set err4 to RscList[RscNum[RsOt1]][1]+SetGauge(ship:resources[RscNum[RsOt1]]:amount/ship:resources[RscNum[RsOt1]]:capacity*100,J,(GgL2)).}
                  else{      set err2 to RscList[RscNum[RsOt1]][1]+SetGauge(ship:resources[RscNum[RsOt1]]:amount/ship:resources[RscNum[RsOt1]]:capacity*100,J,(GgL-5)).}
                }
                if p4 = 1 AND P5 = 2  set err3 to RscList[RscNum[RsOt1]][1]+SetGauge(ship:resources[RscNum[RsOt1]]:amount/ship:resources[RscNum[RsOt1]]:capacity*100,J,(GgL2)).
                if p5 = 2             set err4 to RscList[RscNum[RsOt2]][1]+SetGauge(ship:resources[RscNum[RsOt2]]:amount/ship:resources[RscNum[RsOt2]]:capacity*100,J,(GgL2)).
                set hudopts[J][3] to hudopts[J][3]+err1+" "+err2.
                set botrow to err3+" "+err4.
            }else{
              if huditem = pwrtag{
                set hudopts[J][3] to ":not converting:".
                set botrow to err1+err2+err3+err4.
                set GrpDspList[HudItem][hudtag] to 1.
                set forcerefresh to 1.
              }
              if huditem = MksDrlTag{
                set hudopts[J][3] to ":not Active:"+err1+err2+err3+err4.
                set GrpDspList2[HudItem][hudtag] to 4.
                set forcerefresh to 1.
              }

            }
    }
    //#endregion
    //#endregion
    //#region get text info
   FUNCTION CHANGESEL{
    local parameter OMAX, CSCURRENT, DIR, OMIN is 1.
        IF dbglog > 1 log2file("    CHANGESEL:"+" CSCURRENT:"+ CSCURRENT+" DIR:"+ DIR+" OMIN:"+ OMIN+" OMAX:"+ OMAX).
        IF DIR = "+" {IF CSCURRENT < OMAX {SET CSCURRENT TO CSCURRENT + 1.}ELSE{SET CSCURRENT TO OMIN.}}else{
        IF DIR = "-" {IF CSCURRENT > OMIN {SET CSCURRENT TO CSCURRENT - 1.}ELSE{SET CSCURRENT TO OMAX.}}}
        IF dbglog > 1 log2file("         OUT:"+CSCURRENT).
        RETURN CSCURRENT.
    }
   function ToggleResConv{
    local parameter prt, rsrc, rscnumL, mode is 1.
    local TRCAns to "".
    if rsrc = "liquidfuel" set rsrc to "lqdfuel".
    if rsrc = "oxidizer" set rsrc to "ox".
      local t to prt:getmodulebyindex(rscnumL).
      if prt:hasmodule("ModuleResourceConverter"){
        if t:HASEVENT("start isru ["+rsrc+"]"){set TRCAns to "not converting      ".
          if mode = 1 {t:DOEVENT("start isru ["+rsrc+"]"). set TRCAns to "converting            ".}}
        else{
        if t:HASEVENT("stop isru ["+rsrc+"]"){set TRCAns to "converting            ".
          if mode = 1 {t:DOEVENT("stop isru ["+rsrc+"]"). set TRCAns to "not converting      ".}}
        }}
      return TRCAns.
    }
   FUNCTION ADDMAX{
    LOCAL PARAMETER NmIn, NmAdd, NmMin, NmMax, opt is 1.
    if dbglog > 2 log2file("    ADDMAX:"+" NmIn:"+NmIn+" NmAdd:"+NmAdd+" NmMin:"+NmMin+" NmMax:"+NmMax+" opt:"+opt).
    set nmcalc to NmIn+NmAdd.
    if opt = 1{
      IF nmcalc > NmMax SET nmcalc TO(nmcalc- NmMax)-NmMin-1.
      IF nmcalc < NmMin SET nmcalc TO NmMax-abs(nmcalc+ NmMin)+1.
      RETURN nmcalc.
    }
    if opt = 2{
      IF nmcalc > NmMax SET nmcalc to NmMin.
      IF nmcalc < NmMin SET nmcalc TO NmMax.
      RETURN nmcalc.
    }
    if opt = 3{
      IF nmcalc > NmMax SET nmcalc to NmMax.
      IF nmcalc < NmMin SET nmcalc TO NmMin.
      RETURN nmcalc.
    }
   }
   function wordcheck{
      local parameter input, wordchk.
      local WCAns to 0.
      for w in wordchk{if input:contains(w){set WCAns to 1. BREAK.}}
      return WCAns.
    }
   FUNCTION CHECKOPT{
      local parameter OMAX, CoCURRENT, DIR, LstIn1 IS LIST(""), omin is 1, opt is 0.
      LOCAL PLMT IS 13.
      if DbgLog > 2 log2file("      CheckOPT-:"+CoCURRENT+":"+DIR+" mode:"+LstIn1+" min:"+omin+" MAX:"+OMAX).
      IF DIR = "+" {IF CoCURRENT < OMAX {SET CoCURRENT TO CoCURRENT + 1.}ELSE{SET CoCURRENT TO omin.}}
      IF DIR = "-" {IF CoCURRENT > omin {SET CoCURRENT TO CoCURRENT - 1.}ELSE{SET CoCURRENT TO OMAX.}}
      if LstIn1 = 6 {
        until AutoRscList[0][Cocurrent] = 1 {
          IF DIR = "+" {IF CoCURRENT < OMAX {SET CoCURRENT TO CoCURRENT + 1.}ELSE{SET CoCURRENT TO omin.}}
          IF DIR = "-" {IF CoCURRENT > omin {SET CoCURRENT TO CoCURRENT - 1.}ELSE{SET CoCURRENT TO OMAX.}}
        }
        RETURN ItemListHUD[CoCURRENT].
      }
      if LstIn1 = 7 {
        SET OMAX TO prtTagList[itemnumcur][0].
        IF CoCURRENT > OMAX set Cocurrent to omax.
        local selprv to CoCURRENT.
        until autoTRGList[0][ITEMNUMCUR][CoCURRENT] > -1 {
          IF DIR = "+" {IF CoCURRENT < OMAX {SET CoCURRENT TO CoCURRENT + 1.}ELSE{SET CoCURRENT TO omin.}}
          IF DIR = "-" {IF CoCURRENT > omin {SET CoCURRENT TO CoCURRENT - 1.}ELSE{SET CoCURRENT TO OMAX.}}
          if Cocurrent = selprv break.
        }
      if DbgLog > 2 log2file("      CheckTAG-:"+CoCURRENT).
        LOCAL ANSOUT TO  PRTTAGLIST[ITEMNUMCUR][MIN(CoCURRENT,PRTTAGLIST[ITEMNUMCUR]:LENGTH-1)].
        if opt = 0 return ANSOUT. else return ANSOUT:substring(0,(min(ANSOUT:length, PLMT))).
      }
      if LSTIN1:typename = "string" return.
      IF LSTIN1[0]= "" RETURN.
      if opt = 0 return LstIn1[CoCURRENT]. else return LstIn1[CoCURRENT]:substring(0,(min(LstIn1[CoCURRENT]:length, PLMT))).
    }
   Function SwapBool{
    local parameter Boolin is "".
    if boolin = false set boolin to true. else if boolin = true set boolin to false. 
    return boolin.
  }
   //#endregion
    //#region auto
   function clearauto{
    local parameter item, tag, updn, opt, RSM IS autoRstList[item][tag].
    LOCAL UPDN2 TO 0.
    set opt to abs(opt).
    IF dbglog > 0{
      log2file("      CLEAR AUTO-:"+itemlist[item]+":"+prttaglist[item][tag]).
      IF dbglog > 1{
        log2file("        "+item+" tag:"+tag+" updn:"+updn+" opt:"+opt ).
        log2file("        autoRstList[item][tag](RSMD):"+RSM ).
        log2file("        AutoValList[item][tag]("+AutoValList[item][tag]+"):"). 
        local lud to "OVER".
        if updn = 2 set lud to "UNDER".
        if updn = 3 set lud to "OVER-OFF".
        if updn = 4 set lud to "UNDER-OFF".
        log2file("        AutoLst["+MODELONG[opt]+"("+opt+")]["+lud+"("+updn+")]["+itemlist[item]+"("+item+")]    :"+LISTTOSTRING(AutoLst[opt][updn][item]) ).
        if AutotagLstUP[item]:length > 1 log2file("         AutotagLstUP["+item+"]:"+LISTTOSTRING(AutotagLstUP[item]) ).
        if AutotagLstDN[item]:length > 1 log2file("         AutotagLstDN["+item+"]:"+LISTTOSTRING(AutotagLstDN[item]) ).
        if  AutotagLstNAup[item]:length > 1 log2file("        AutotagLstNAup["+item+"]:"+LISTTOSTRING(AutotagLstNAup[item]) ).
        if  AutotagLstNADN[item]:length > 1 log2file("        AutotagLstNADN["+item+"]:"+LISTTOSTRING(AutotagLstNADN[item]) ).
      }
    }
    set cnt to 0.
    local trm to 0.
    local lst1 to AutoLst[opt][updn][item]:sublist(0, AutoLst[opt][updn][item]:length).
    for i in lst1{
      if RSM = 1 {
        local trg1 to 0.
        if updn = 1 and i = AutoValList[item][tag] set trg1 to 1.
        if updn = 2 and 0-i = AutoValList[item][tag] set trg1 to 2. 
          if trg1 > 0{
            set trm to 1.
            set AutoLst[opt][updn][item][cnt] to 0.
            if   AutotagLstDN[item]:contains(tag)   AutotagLstDN[item]:remove(AutotagLstDN[item]:find(tag)).
            if   AutotagLstUP[item]:contains(tag)   AutotagLstUP[item]:remove(AutotagLstUP[item]:find(tag)).
            if AutotagLstNADN[item]:contains(tag) AutotagLstNADN[item]:remove(AutotagLstNADN[item]:find(tag)).
            if AutotagLstNAup[item]:contains(tag) AutotagLstNAup[item]:remove(AutotagLstNAup[item]:find(tag)).
            break.
          }
          set cnt to cnt+1.
      }
      else{
        if RSM > 1 {
            if updn = 1 and i = AutoValList[item][tag]{
              if DbgLog > 0 log2file("      "+itemlist[item]+":"+prttaglist[item][tag]+" switched to UNDER" ).
              SET UPDN2 TO 2.
              set AutoValList[item][tag] to 0-ABS(AutoValList[item][tag]).
            }
            if updn = 2 and 0-i = AutoValList[item][tag]{
              if DbgLog > 0 log2file("      "+itemlist[item]+":"+prttaglist[item][tag]+" switched to OVER" ).
              SET UPDN2 TO 1.
              set AutoValList[item][tag] to ABS(AutoValList[item][tag]).
            }
            if updn2 > 0 {
              if not AutoLst[opt][UPDN2][item]:contains(AutoLst[opt][UPDN][item][cnt]) AutoLst[opt][UPDN2][item]:ADD(AutoLst[opt][UPDN][item][cnt]).
              set AutoLst[opt][UPDN][item][cnt] to 0. 
              break.
            }
            set cnt to cnt+1.
        }
      }
    }

     if trm = 1{
            if AutoItemLst[opt][1]:contains(item) {IF AutotagLstUP[item]:length   = 0 AutoItemLst[opt][1]:remove(AutoItemLst[opt][1]:find(item)).}
            if AutoItemLst[opt][2]:contains(item) {IF   AutotagLstDN[item]:length = 0 AutoItemLst[opt][2]:remove(AutoItemLst[opt][2]:find(item)).}
            if AutoItemLst[opt][3]:contains(item) {IF AutotagLstNAUP[item]:length = 0 AutoItemLst[opt][3]:remove(AutoItemLst[opt][3]:find(item)).}
            if AutoItemLst[opt][4]:contains(item) {IF AutotagLstNADN[item]:length = 0 AutoItemLst[opt][4]:remove(AutoItemLst[opt][4]:find(item)).}
     }
      IF AutoLst[opt][updn][item]:LENGTH > 1 AND AutoLst[opt][updn][item]:CONTAINS(0) AutoLst[opt][updn][item]:REMOVE(AutoLst[opt][updn][item]:SUBLIST(1,AutoLst[opt][updn][item]:LENGTH):FIND(0)+1).
    if RSM = 1 {set AutoDspList[item][tag] to 1.} else 
    if RSM > 1 AND UPDN2 > 0 UpdateAutoTriggers(updn2,OPT,item,tag).
    //if item = dcptag set DcpPrtList[tag] to list(0,"").
    set SaveFlag to 1. 
    UpdateAutoMinMax(opt).
      IF dbglog > 1{
        log2file("        post update triggers").
        log2file("          AutoLst["+opt+"]["+updn+"]["+item+"]    :"+LISTTOSTRING(AutoLst[opt][updn][item]) ).
        if AutotagLstUP[ITEM]:length > 1 log2file("         AutotagLstUP["+ITEM+"]:"+LISTTOSTRING(AutotagLstUP[ITEM]) ).
        if AutotagLstDN[ITEM]:length > 1 log2file("         AutotagLstDN["+ITEM+"]:"+LISTTOSTRING(AutotagLstDN[ITEM]) ).
        if  AutotagLstNAup[ITEM]:length > 1 log2file("        AutotagLstNAup["+ITEM+"]:"+LISTTOSTRING(AutotagLstNAup[ITEM]) ).
        if  AutotagLstNADN[ITEM]:length > 1 log2file("        AutotagLstNADN["+ITEM+"]:"+LISTTOSTRING(AutotagLstNADN[ITEM]) ).
      }
  }
   function TriggerAuto{ //and check auto state
      local parameter LstIN, md, ThrVal, opt is 1, opt2 is 1.
      //lastin().
      SpeedBoost().
      IF dbglog > 0{
        if opt2 < 2 log2file("TRIGGERAUTO md:"+modelong[md]+"("+md+") ThrVal:"+ThrVal+" opt:"+opt+" opt2:"+opt2 ). else
        if opt2 = 2 and dbglog > 2 log2file("CHECK-RSC   md:"+modelong[md]+"("+md+") ThrVal:"+ThrVal+" opt:"+opt+" opt2:"+opt2 ). else
        if opt2 = 3 and dbglog > 2 log2file("CHECKSTATE  md:"+modelong[md]+"("+md+") status:"+STATUSOPTS[ThrVal]+"("+thrval+")"+" opt:"+opt+" opt2:"+opt2 ).
        if dbglog > 2 and opt2 < 2 log2file("    LstIN:"+LISTTOSTRING(Lstin)).
      }
      local AbsThr to abs(ThrVal).
      set cnt to 0.   
      local lst2 to list().
      for i in Lstin:sublist(1, Lstin:length) {
          if opt = 1 and AutotagLstUP[i]:length > 0 set lst2 to AutotagLstUP[I]:sublist(0, AutotagLstUP[I]:length).
          if opt = 2 and AutotagLstDN[i]:length > 0 set lst2 to AutotagLstDN[I]:sublist(0, AutotagLstDN[I]:length).
          if lst2:length > 0 for t in lst2 {
            Local savedVal TO AutoValList[I][T].
            local trg to 0. local act to 0. 
            local AbsVal to abs(savedVal).
            if DbgLog > 1 and opt2 < 2{
              log2file("      "+itemlist[I]+"("+I+") "+prtTagList[i][t]+"("+T+")").
              log2file("        AbsVal:"+AbsVal+" "+" savedVal:"+savedVal+" AbsThr:"+AbsThr).
              log2file("        autoRstList[I][T]:"+autoRstList[I][T]).
              log2file("        AutoRscList[I][T]:"+AutoRscList[I][T]).
              log2file("        AutoDspList[I][T]:"+AutoDspList[I][T]).
            }
            if autoRstList[I][T] > 2 and autoRstList[I][T] - opt = 2 set act to 1.
            if autoRstList[I][T] < 3 set act to 1.
            if AutoDspList[I][T] = md{
              if opt2 = 2{
                if AutoRscList[I][T]<>0{
                  local RscAmt to ship:resources[RscNum[AutoRscList[I][T]]]:amount/ship:resources[RscNum[AutoRscList[I][T]]]:capacity*100.
                  local ZAdj to 0. if savedval = 0 set zadj to 0.0001.
                  if RscAmt > 1 set RscAmt to round(RscAmt,0).
                  if savedVal > -0.0001 {if RscAmt > AbsVal-zadj set trg to 1. set dpr to " > ".}
                  if savedVal <  0.0001 {if RscAmt < AbsVal+zadj set trg to 2. set dpr to " < ".}
                  IF DbgLog > 1 and TRG = 1 and md <> 14 log2file("       if SavedVal ("+savedval+") >  -0.0001 and "+" rsc:"+AutoRscList[I][T]+"("+RscAmt+")  > AbsVal-"+zadj+"("+(AbsVal-zadj)+") trg:"+TRG+"="+OPT+"--ACT:"+ACT).
                  IF DbgLog > 1 and TRG = 2 and md <> 14 log2file("       if SavedVal ("+savedval+") <   0.0001 and "+" rsc:"+AutoRscList[I][T]+"("+RscAmt+")  < AbsVal+"+zadj+"("+(AbsVal+zadj)+") trg:"+TRG+"="+OPT+"--ACT:"+ACT).
                  IF DbgLog > 1 and TRG = 0 and md <> 14 log2file("       ITEM:"+itemlist[i]+" TAG:"+prttagList[i][t]+" rsc:"+AutoRscList[I][T]+"("+RscAmt+")"+dpr+absval).
                }}
                else{
              If opt2 = 3{
                    LOCAL TIMETO TO 999.
                    IF AbsVal < 9{if AbsVal = statusopts:find(ship:status) {set act to 1. set trg to 1. }}
                    ELSE{
                           IF AbsVal = 9  set timeto to eta:apoapsis. 
                      else IF AbsVal = 10 set timeto to ETA:periapsis. 
                      else IF AbsVal = 11 set timeto to ETA:NEXTNODE. 
                      else IF AbsVal = 12 set timeto to ETA:TRANSITION.
                      if timeto < 10 { set act to 1. set trg to 1. IF WARPMODE = "RAILS" AND WARP > 0 SET WARP TO 0. UNTIL kuniverse:timewarp:issettled = TRUE WAIT 0.5.}
                    }
                  }
              else{
                if AbsVal = AbsThr and savedVal > -0.0001 and savedVal > AbsThr-.0001 set trg to 1.
                if AbsVal = AbsThr and savedVal <  0.0001 and savedVal < 0-AbsThr+.0001 set trg to 2.
                if DbgLog > 1 and md <> 14 log2file("       if AbsVal("+AbsVal+") = AbsThr("+AbsThr+") and savedVal("+savedVal+") trg:"+TRG+"="+OPT+"--ACT:"+ACT).}
            }}
              if trg = opt {if act = 1 ToggleGroup(i,t,AutoTRGList[I][T],1). ClearAuto(i,t,opt,AutoDspList[I][T]). UPDATEHUDOPTS().}
          }
      }
      SpeedBoost("off").
    }
   function listautosettings{
    SpeedBoost().
    if dbglog > 0 log2file("LISTING AUTO SETTINGS").
    set loading to 0.
      set BtnActn to 1.
      desktop().
      local Plst2 is list().
      for i in range(1,itemlist[0]+2){plst2:add(list(0)).}
      for md in range (1,MODESHRT:LENGTH){
        for u in range(1,5){
          if u = 5 {
          }
          else{
          if u = 1 {set ud to "  OVER ". SET LS TO autotaglstup.}
          if u = 2 {set ud to " UNDER ". SET LS TO autotaglstdn.}
          if u = 3 {set ud to "  OVER ". SET LS TO AutotagLstNAUP.}
          if u = 4 {set ud to " UNDER ". SET LS TO AutotagLstNADN.}
            for i in range(1,autoitemlst[md][u]:length){
              local icnt to 1.
              set itm to autoitemlst[md][u][i].
                if dbglog > 0 log2file("    "+LISTTOSTRING(LS[MD])).
                if ls[md]:length > 0{
                  for t in range(0,ls[itm]:length){
                    local tg to ls[itm][t].
                    IF T <> 0 pout(itm,tg).
                    loadbar().                    
                    set icnt to icnt+1.
                  }
                }
            }
          }
        }
      }
      PRINTLINE("",0,16).
      set LNstp to 1.
     // PRINT "|          | CONTINUE |          |" at (0,heightlim).
      PRINT "|          |          |          |" at (0,heightlim).
        for i in range(1,plst2:length-1){
          if plst2[i]:length > 1{
            for j in range(1,plst2[i]:length){
              local po to printrow(plst2[i][j],0). 
              wait.02.
              if i > plst2:length-2 set po to 1.
              if po = 1 WaitFor(15,1).
            }
          }
        }
        if plst2:length > 0 WaitFor(15,1).
            local function pout{
              local parameter itmP,tgP.
              if dbglog > 0 log2file("    "+ItemList[itmp]+":"+prttaglist[itmp][tgp]).
              local automode to abs(AutoDspList[itmP][tgP]).
              LOCAL MODEPRINT TO Removespecial(MODELONG[automode]," "). 
              local wt4 to "".
                local vlprint to abs(AutovalList[ItmP][TgP]).
                local ACTLST to list(4,grpopslist[itmP][tgP][GrpDspList[itmP][tgP]],grpopslist[itmP][tgP][GrpDspList2[itmP][tgP]],grpopslist[itmP][tgP][GrpDspList3[itmP][tgP]], EmptyHud).
                for l in range(1,4){
                  if actlst[l] = EmptyHud set ACTLST[l] to "ACTION"+L.
                }
                LOCAL ActionPrint TO ACTLST[AutoTRGList[itmP][TgP]].
                if ActionPrint:LENGTH > 0 {IF ActionPrint[ActionPrint:LENGTH-1] <> " " SET ActionPrint TO ActionPrint.}
                IF ActionPrint[0] <> " " SET ActionPrint TO " "+ActionPrint.
                set ActionPrint TO " "+Removespecial(ActionPrint," ")+" ".
                SET ActionPrint TO ActionPrint:REPLACE("TURN","TURN ").
                SET ActionPrint TO ActionPrint:REPLACE("RUN","RUN ").
                SET ActionPrint TO ActionPrint:REPLACE("XMIT","XMIT ").
                SET ActionPrint TO ActionPrint:REPLACE("ACTION","ACTION ").
                local afttrgprint to "".
                if autoTRGList[0][itmP][tgP] > 0 {SET DelayPrint TO " WAIT "+autoTRGList[0][itmP][tgP]+" THEN".} ELSE SET DelayPrint TO "".
                if AutoDspList[itmP][tgP] < 0 and AutoDspList[0][itmP][tgP][0]:tostring <> "0"{
                  local splt to AutoDspList[0][itmP][tgP][0]:split("-").
                  if splt:length = 3 set  wt4 to "HOLD4 ".
                  if splt:length = 4 set  wt4 to "LOCK2 ".
                }
                if AutoDspList[itmp][TgP] < 0 and AutoDspList[0][itmp][TgP][0] <> 0{
                  local splt to AutoDspList[0][itmp][TgP][0]:split("-").                  
                  set DelayPrint to wt4+REMOVESPECIAL(ItemListHUD[splt[0]:tonumber]," ")+":"+Prttaglist[splt[0]:tonumber][splt[1]:tonumber]+" "+DelayPrint.}
                IF  autoRstList[itmP][tgP] = 1 SET AftTrgPrint TO "DISABLE".
                IF  autoRstList[itmP][tgP] = 2 if UD = " UNDER " { SET AftTrgPrint TO "SWITCH TO OVER".}ELSE{SET AftTrgPrint TO "SWITCH TO UNDER".}.
                IF UD = " UNDER " { SET vlprint TO "UNDER "+vlprint.
                  IF autoRstList[itmP][tgP] = 4 {SET AftTrgPrint TO "WAIT FOR UNDER".}
                  IF autoRstList[itmP][tgP] = 3 {SET ActionPrint TO "RESET ". SET AftTrgPrint TO "WAIT FOR OVER".}
                }
                IF UD = "  OVER " {SET vlprint TO "OVER "+vlprint.
                  IF autoRstList[itmP][tgP] = 3 {SET AftTrgPrint TO "WAIT FOR OVER".}
                  IF autoRstList[itmP][tgP] = 4 {SET ActionPrint TO "RESET ".  SET AftTrgPrint TO "WAIT FOR UNDER".}
                }
                IF MODEPRINT = "ALTAGL" SET MODEPRINT TO "ALT AGL".
                IF MODEPRINT = "STATUS" set vlprint to "is "+ STATUSOPTS[abs(AutoValList[ItmP][TgP])].
                local itmprint to prttaglist[itmP][tgP].
                if itmprint:length > 15 {
                  for wd in trimwords{
                    set itmprint to Removespecial(itmprint,wd).
                  }
                }
                set AftTrgPrint to " THEN "+AftTrgPrint.
                if AftTrgPrint = " THEN DISABLE" set AftTrgPrint to "".
                if Plst2[itmP]:length = 1  and automode <> 1{
                  Plst2[itmP]:add(getcolor(itemlist[itmP],"WHT")).
                }
                local pof to "  "+itmprint+":"+DelayPrint+ActionPrint+"WHEN "+MODEPRINT+" "+vlprint+AftTrgPrint.
                if automode <> 1 and not Plst2[itmP]:contains(pof){Plst2[itmP]:add(pof).
                if dbglog > 0 log2file("    "+pof).
                }
            }
            function WaitFor{
                local parameter wt is 10, opt is 0.
                local wt2 to wt.
                local ch to "".
                //until k2 > wt2-1
                for k2 in range (1,wt2-2){
                  //print "continuing in "+(wt2-k2)+" seconds, or press continue." at (1,16).
                  print "continuing in "+(wt2-k2)+" seconds." at (1,16).
                  //set k2 to k2 +1.
                  ///figure this out
                  if terminal:input:haschar {set ch to terminal:input:getchar().}
                  if ch = "5" {button8a().set ch to "".}
                  wait 1.
                  if k2 > wt2-1 break.
                function button8a{SET k2 to wt2.}buttons:setdelegate(8,button8a@).
                }
              if opt = 1{
                for z in range(1,LNstp+1) print "|"+Bigempty2+"|" at(0,z). 
                set LNstp to 1.
              }     
              //buttons:setdelegate(8,button8@).

              set forcerefresh to 1.
            }
      set BtnActn to 1.
      buttons:setdelegate(8,button8@).
    clearscreen.
    SpeedBoost("off").
    return.
    }
    //#endregion
    //MAINLOOP
    //#region buttons 
    function button0{lastin(). if BtnActn=0{set BtnActn to 1. if ENG[1] <> EmptyHud{
      if hudop = 5{
      set dctnmode to ADDMAX(dctnmode,1,0,2).}
    else{TopHugTrig(0).}}
    set buttonRefresh to 2.}set BtnActn to 0. }  buttons:setdelegate(0,button0@).

    function button1{lastin(). if BtnActn=0{set BtnActn to 1. if ENG[2] <> EmptyHud{
      if hudop = 5{
        if dctnmode = 0{
          local lmt to 2. 
          if ModeSel > 7 and modesel < 13 set lmt to 3.
          if modesel > 1 SET AutoValList[0][0][3][modesel] TO CHANGESEL(lmt, AutoValList[0][0][3][modesel] ,"+").
        }
        else{
          SET HDItm TO CHANGESEL(ItemList[0], HDItm ,"+").
          SET HDTag TO 1.
        }
      }
      else{TopHugTrig(1).}}
      set buttonRefresh to 2.}set BtnActn to 0. }  buttons:setdelegate(1,button1@).
    
    function button2{if BtnActn=0{lastin(). set BtnActn to 1. if ENG[3] <> EmptyHud{
      if hudop = 5{
        if dctnmode = 0{
        SET modesel TO CHANGESEL(MODELONG[0], modesel,"+"). 
        until AutoValList[0][0][3][modesel] > -1 {SET modesel TO CHANGESEL(MODELONG[0], modesel,"+").}
        }
        else{
          SET HDTag TO CHANGESEL(prtTagList[HDItm][0], HDTag ,"+").//AAAA
        }
        //UPDATEHUDOPTS().
      }
      else{TopHugTrig(2).}}
      set buttonRefresh to 2.}set BtnActn to 0. 
    }buttons:setdelegate(2,button2@).
    
    function button3{if BtnActn=0{lastin(). set BtnActn to 1. if ENG[4] <> EmptyHud{
      if hudop = 5{if h5mode = 1 set h5mode to 0. else set h5mode to 1.} 
      else{TopHugTrig(3).}}set buttonRefresh to 2.}set BtnActn to 0. }  buttons:setdelegate(3,button3@).
    
    function button4{if BtnActn=0{lastin(). set BtnActn to 1. if ENG[5] <> EmptyHud{
      if hudop = 5{SET AutoRscList[0][EnabSel] TO CHANGESEL(2, AutoRscList[0][EnabSel] ,"+"). 
    }else{TopHugTrig(4).}}set buttonRefresh to 2.}set BtnActn to 0. }  buttons:setdelegate(4,button4@).
    
    function button5{if BtnActn=0{lastin(). set BtnActn to 1. if ENG[7] <> EmptyHud{
      if hudop = 5{SET EnabSel TO CHANGESEL(HudOpts[2][1][0], EnabSel,"+"). PRINT EmptyHud+EmptyHud AT (52,1).set buttonRefresh to 2.}
    else{
    if rowval = 0 {TOGGLE INTAKES.}else{SET MtrOps[hsel[2][1]][0] TO CHANGESEL(1, MtrOps[hsel[2][1]][0],"+",0).}
    }}}set BtnActn to 0. set buttonRefresh to 3.}  buttons:setdelegate(5,button5@).
    
    function button6{if BtnActn=0{lastin(). set BtnActn to 1. set buttonRefresh to 2.}set BtnActn to 0. }  buttons:setdelegate(6,button6@).
    
    function button7{if BtnActn=0{lastin(). if PrvITM <> EmptyHud or hudop = 5{
      set BtnActn to 1.set buttonRefresh to 3. set seldir to "-". 
      IF HUDOP = 5{
        if TrgLim > 1 SET AutoSetAct TO CHANGESEL(TrgLim, AutoSetAct,"+"). 
      }else{
         clearall(). clearto(2,14).
         //if hsel[2][1] = CMDTag clearto(9,14).
       SET HSEL[2][1] TO CHANGESEL(HudOpts[2][1][0], hsel[2][1],seldir).
        until AutoRscList[0][HSEL[2][1]] = 1 {SET HSEL[2][1] TO CHANGESEL(HudOpts[2][1][0], hsel[2][1],seldir).}
        SET HSEL[2][2] TO 1. 
        SET HSEL[2][3] TO 1.
        set HudOpts[2][2] to prttaglist[hsel[2][1]].
        set HudOpts[2][3] to " ".
        set MtrPrtSel[1] to 0.}
        set forcerefresh to 2.
        UPDATEHUDOPTS().
        set forcerefresh to 2.
        }}set BtnActn to 0.}  buttons:setdelegate(7,button7@).
    
    function button8{
      lastin().
      if BtnActn=0{
        set BtnActn to 1. 
        set buttonRefresh to 1.
        IF HUDOP = 5{
          SET AutoSetMode TO CHANGESEL(MODELONG[0], AutoSetMode,"+").
          until AutoValList[0][0][3][AutoSetMode] = 1 {SET AutoSetMode TO CHANGESEL(MODELONG[0], AutoSetMode,"+").}
        }else{
        if hsel[2][1] = ISRUTag {set hudopts[1][3] to ToggleResConv(prtlist[hsel[2][1]][hsel[2][2]][hsel[2][3]],isruoptlst[ConvRSC],ConvRSC).
        //UPDATEHUDOPTS().
        }
        else{
          if hsel[2][1] = flytag and ItmTrg = " SET TRGT " {
            IF trglst[anttrgsel] = "no-target" or trglst[anttrgsel] = "active-vessel" return. 
            SET TARGET TO trglst[anttrgsel]. PRINTLINE("target set to:"+ trglst[anttrgsel],"CYN").}
          ELSE{
          if hsel[2][1] = flytag {if hasTarget = FALSE and ItmTrg = " SET TRGT " RETURN.}
          togglegroup(hsel[2][1],hsel[2][2],1).  
        }}}set forcerefresh to 1. 
      }set BtnActn to 0.}  buttons:setdelegate(8,button8@).
    
    function button9{lastin(). if BtnActn=0{if NXTITM <> EmptyHud{
      set BtnActn to 1. set buttonRefresh to 3. set seldir to "+". 
    IF HUDOP = 5{
      if  abs(AutoSetMode) = 6 {
        if RscSelection =RscList:length-1 {set RscSelection to 0.}
        else{set RscSelection TO CHANGESEL(RscList:length-1,RscSelection,seldir).}
      }
      if abs(AutoSetMode) = 14  set StsSelection TO CHANGESEL(STATUSOPTS[0],StsSelection,"+").
      if  abs(AutoSetMode) = 15 {
        if RscSelection =PRscList:length-1 {set RscSelection to 0.}else{
        set RscSelection TO CHANGESEL(PRscList:length-1,RscSelection,seldir).}
      }
      SET HUDOPPREV TO 0.
    }
    else{
         clearall(). clearto(2,14).
         //if hsel[2][1] = CMDTag clearto(9,14).
        SET HSEL[2][1] TO CHANGESEL(HudOpts[2][1][0], hsel[2][1],seldir).
       until AutoRscList[0][HSEL[2][1]] = 1 {SET HSEL[2][1] TO CHANGESEL(HudOpts[2][1][0], hsel[2][1],seldir).}
        SET HSEL[2][2] TO 1. 
        SET HSEL[2][3] TO 1.
        set HudOpts[2][2] to prttaglist[hsel[2][1]].
        set HudOpts[2][3] to " ".
        set MtrPrtSel[1] to 0.}
        set forcerefresh to 2.
        UPDATEHUDOPTS().
        set forcerefresh to 2.
    }}set BtnActn to 0.}  buttons:setdelegate(9,button9@).
    
    function button10{lastin(). if BtnActn=0{set BtnActn to 1. if BTHD10 <> EmptyHud{
      IF HUDOP = 5{
       set AutoRstMode to CHANGESEL(HudRstMdLst[0],AutoRstMode,"+"). 
       IF  abs(AutoSetMode) = 14 and AutoRstMode > 1 set AutoRstMode to 1.
      }else{
        IF hsel[2][1] = GEARTAG and rowval = 0{SET AUTOBRAKE TO AUTOBRAKE+1. IF AUTOBRAKE = 3 SET AUTOBRAKE TO 0.}
        ELSE{
          togglegroup(hsel[2][1],hsel[2][2],2).}
        set buttonRefresh to 1.}set forcerefresh to 2. 
        //UPDATEHUDOPTS().
        }
    }set BtnActn to 0.}  buttons:setdelegate(10,button10@).
    
    function button11{lastin(). if BtnActn=0{set BtnActn to 1. if BTHD11 <> EmptyHud{
        IF HUDOP = 5{
          set AutoDspList[hsel[2][1]][hsel[2][2]] to 1.
          SET AutoValList[hsel[2][1]][hsel[2][2]] TO 0.
          SaveAutoSettings(). PRINTQ:PUSH(" AUTO FILE SAVED"+"<sp>"+"WHT"). SETHUD().  
          //UPDATEHUDOPTS().
        }else{
          if hsel[2][1] = RBTTag and not prtlist[hsel[2][1]][hsel[2][2]][hsel[2][3]]:hasmodule("ModuleRoboticController"){
            SET autoRstList[0][0][tagnumcur] TO autoRstList[0][0][tagnumcur]+1. IF autoRstList[0][0][tagnumcur] = 10 SET autoRstList[0][0][tagnumcur] TO 0. set forcerefresh to 1.}
        ELSE{
        if hsel[2][1] = FlyTag and ROWVAL = 1 and HSEL[2][2] = 1{
          set axsel to changesel(APaxis[0], axsel,"+").
          if apsel = 1 and axsel > 3 set axsel to 1.
          if apsel = 2 IF axsel < 4 or axsel > 6 set axsel to 4.
          if apsel = 3 and axsel < 7 set axsel to 7.
          set forcerefresh to 1.
        }
        else{togglegroup(hsel[2][1],hsel[2][2],3).}}
        set buttonRefresh to 1. set forcerefresh to 2. 
        //UPDATEHUDOPTS().
        }}
    }set BtnActn to 0.}  buttons:setdelegate(11,button11@).
    
    function button12{lastin(). if BtnActn=0{}}  buttons:setdelegate(12,button12@).
    
    function button13{lastin(). if BtnActn=0{}}  buttons:setdelegate(13,button13@).
    
    function button14{lastin(). if BtnActn=0{}}  buttons:setdelegate(14,button14@).
    
    function button15{lastin(). if BtnActn=0{}}  buttons:setdelegate(15,button15@).
    
    function buttonUp{lastin(). if BtnActn=0{set BtnActn to 1. 
      IF HUDOP = 5{
        if abs(AutoSetMode) = 14 {set StsSelection TO CHANGESEL(STATUSOPTS[0],StsSelection,"+").}
        else{
          if h5mode = 1 {SET setdelay to ADDMAX(setdelay,AutoAdjByLst[AUTOHUD[1]],0,100000,3).}
          else{
          SET AUTOHUD[0] to ADDMAX(AUTOHUD[0],AutoAdjByLst[AUTOHUD[1]],0,1000000000,3).
          }}
      }
      else{if RowSel < 2 {set RowSel to RowSel + 1 - rowval+1. set buttonRefresh to 2.}}
      UPDATEHUDOPTS().
      }.set BtnActn to 0. set forcerefresh to 2.}  buttons:setdelegate(-3,buttonUp@).
    
    function buttonDown{lastin(). if BtnActn=0{set BtnActn to 1. 
      IF HUDOP = 5{
        if abs(AutoSetMode) = 14 {set StsSelection TO CHANGESEL(STATUSOPTS[0],StsSelection,"-").}
        else{
            if h5mode = 1 {SET setdelay to ADDMAX(setdelay,0-AutoAdjByLst[AUTOHUD[1]],0,100000,3).}
        else{
          SET AUTOHUD[0] to ADDMAX(AUTOHUD[0],0-AutoAdjByLst[AUTOHUD[1]],0,1000000000,3).
          SET HUDOPPREV TO 0.
          }}
      }
      else{if RowSel > 1 {set RowSel to RowSel - 1. set buttonRefresh to 2.}}
      UPDATEHUDOPTS().
      }.set BtnActn to 0. set forcerefresh to 2.}  buttons:setdelegate(-4,buttonDown@).
    
    function buttonLeft{lastin(). if BtnActn=0{set BtnActn to 1.  set buttonRefresh to 1. set seldir to "-".
            IF HUDOP = 5{
              SET HUDOPPREV TO 0.
              IF AUTOHUD[2] = "  OVER "{ SET AUTOHUD[2] TO " UNDER ".}ELSE{
              IF AUTOHUD[2] = " UNDER " SET AUTOHUD[2] TO "  OVER ".}
            }
      else{ clearall(). set forcerefresh to 2. if hsel[2][1] = CMDTag clearto(9,14).
      if rowval = 0{
        if hsel[2][1] = scitag set scipart to 1.
        local selprv to HSEL[2][2].
        SET HSEL[2][2] TO CHANGESEL(HudOpts[2][2][0], hsel[2][2],seldir). 
        if autoTRGList[0][HSEL[2][1]][hsel[2][2]] < 0{
          until autoTRGList[0][HSEL[2][1]][HSEL[2][2]] > -1 or HSEL[2][2] = selprv{
          SET HSEL[2][2] TO CHANGESEL(HudOpts[2][2][0], hsel[2][2],seldir). 
          }
        }
        SET HSEL[2][3] TO 1.
        set MtrPrtSel[1] to 0.
      }
      if rowval = 1 {
        local ys to 0.
        if mtrcur[7]:length > 0 {if mtrcur[7][mtrcur[7]:length-1] = -2 set ys to 1.}
        IF hsel[2][1] = flytag AND hsel[2][2] = 1 set ys to 1.
          if ys = 1 or meterpart = 0{
            if hsel[2][1] = WMGRtag and meterlist[0][0] = "weapon"{getEvAct(prtlist[hsel[2][1]][hsel[2][2]][hsel[2][3]],"MissileFire","previous weapon",20).}else{
            if hsel[2][1] = anttag and meterlist[0][0]:contains("target"){set anttrgsel to changesel(trglst[0], anttrgsel,seldir).}else{


            if hsel[2][1] = ISRUTag {set ConvRSC to changesel(isruoptlst[0], ConvRSC,seldir).
              set hudopts[1][3] to ToggleResConv(prtlist[hsel[2][1]][hsel[2][2]][hsel[2][3]],isruoptlst[ConvRSC],ConvRSC,2).}else{
            if hsel[2][1] = scitag {set scipart to changesel(SciDsp:length,scipart,seldir).}else{
            if hsel[2][1] = DcpTag  {set RscSelection TO CHANGESEL(PRscList:length-1, RscSelection,seldir,0).
            }else{
            if hsel[2][1] = BDPTag  {adjust_Meter(prtlist[hsel[2][1]][hsel[2][2]], MtrCur[2], seldir, 1, hsel[2][1],  MtrCur[0], MtrCur[1]).}else{
            if hsel[2][1] = FlyTag  {
              set HdngSet[0][(axsel)] to ADDMAX(HdngSet[0][(axsel)],-AutoAdjByLst[AUTOHUD[1]], HdngSet[2][(axsel)], HdngSet[1][(axsel)]).
              if ItmTrg = " SET TRGT " set anttrgsel to changesel(trglst[0], anttrgsel,seldir).
            }else{
            if mks =1{ 
              if hsel[2][1] = pwrTag    {adjust_thrust(prtlist[hsel[2][1]][hsel[2][2]],0.1,seldir,2).}else{
              if hsel[2][1] = MksDrlTag {adjust_thrust(prtlist[hsel[2][1]][hsel[2][2]],0.1,seldir,2).}
            }
            }}}}}}}}
          }else{if MeterPart > 0 {adjust_Meter(prtlist[hsel[2][1]][hsel[2][2]], MtrCur[2], seldir, 4, hsel[2][1],  MtrCur[0], MtrCur[1]).}}
      }
      } 
      UPDATEHUDOPTS().
      }.set BtnActn to 0. set forcerefresh to 2.}  buttons:setdelegate(-5,buttonLeft@).
    
    function buttonRight{lastin(). if BtnActn=0{set BtnActn to 1. set buttonRefresh to 1. set seldir to "+".
      IF HUDOP = 5{SET AUTOHUD[1] TO CHANGESEL(AutoAdjByLst[0],AUTOHUD[1],seldir). SET HUDOPPREV TO 0. SET forcerefresh TO 2.}
      else{ clearall(). set forcerefresh to 2.
      if rowval = 0 {
        if hsel[2][1] = scitag set scipart to 1.
        local selprv to HSEL[2][2].
        SET HSEL[2][2] TO CHANGESEL(HudOpts[2][2][0], hsel[2][2],seldir). 
        if autoTRGList[0][HSEL[2][1]][hsel[2][2]] < 0{
          until autoTRGList[0][HSEL[2][1]][HSEL[2][2]] > -1 or HSEL[2][2] = selprv{
          SET HSEL[2][2] TO CHANGESEL(HudOpts[2][2][0], hsel[2][2],seldir). 
          }
        }
        SET HSEL[2][3] TO 1.
        set MtrPrtSel[1] to 0.
      }
      if rowval = 1 {
        local ys to 0.
        if mtrcur[7]:length > 0 {if mtrcur[7][mtrcur[7]:length-1] = -2 set ys to 1.}
        IF hsel[2][1] = flytag AND hsel[2][2] = 1 set ys to 1.
          if ys = 1 or meterpart = 0{
        if hsel[2][1] = WMGRtag  and meterlist[0][0] = "weapon"{if prtlist[hsel[2][1]][hsel[2][2]][hsel[2][3]]:hasmodule("MissileFire") if prtlist[hsel[2][1]][hsel[2][2]][hsel[2][3]]:getmodule("MissileFire"):hasaction("next weapon") prtlist[hsel[2][1]][hsel[2][2]][hsel[2][3]]:GETMODULE("MissileFire"):doaction("next weapon", True).}else{
        if hsel[2][1] = anttag and meterlist[0][0]:contains("target"){set anttrgsel to changesel(trglst[0], anttrgsel,seldir).}else{
        if hsel[2][1] = ISRUTag {set ConvRSC to changesel(isruoptlst[0], ConvRSC,seldir).set hudopts[1][3] to ToggleResConv(prtlist[hsel[2][1]][hsel[2][2]][hsel[2][3]],isruoptlst[ConvRSC],ConvRSC,2).
        }else{
        if hsel[2][1] = scitag {set scipart to changesel(SciDsp:length,scipart,seldir).}else{
        if hsel[2][1] = DcpTag  {set RscSelection TO CHANGESEL(PRscList:length-1, RscSelection,seldir,0).
        }else{
        if hsel[2][1] = BDPTag  {adjust_Meter(prtlist[hsel[2][1]][hsel[2][2]], MtrCur[2], seldir, 1, hsel[2][1],  MtrCur[0], MtrCur[1]).}else{
        if hsel[2][1] = FlyTag  {
          set HdngSet[0][(axsel)] to ADDMAX(HdngSet[0][(axsel)],AutoAdjByLst[AUTOHUD[1]], HdngSet[2][(axsel)], HdngSet[1][(axsel)]).
          if ItmTrg = " SET TRGT " set anttrgsel to changesel(trglst[0], anttrgsel,seldir).
          }else{
        if mks =1{set forcerefresh to 2. if hsel[2][1] = pwrTag  {adjust_thrust(prtlist[hsel[2][1]][hsel[2][2]],0.1,seldir,2).}else{
            if hsel[2][1] = MksDrlTag  {adjust_thrust(prtlist[hsel[2][1]][hsel[2][2]],0.1,seldir,2).}else{
            }}
        }}}}}}}}//}
        }else{if MeterPart > 0 {adjust_Meter(prtlist[hsel[2][1]][hsel[2][2]], MtrCur[2], seldir, 4, hsel[2][1],  MtrCur[0], MtrCur[1]).}}
      }} 
      UPDATEHUDOPTS().
      }.set forcerefresh to 2. set BtnActn to 0.}  buttons:setdelegate(-6,buttonRight@).
    
    function buttonEnter{lastin(). if BtnActn=0{set BtnActn to 1. 
        IF HUDOP = 5{
          local adl to  abs(AutoSetMode).
          if adl > 4 and adl < 8  if AUTOHUD[0] > 100 set autohud[0] to 100.
          if adl = 6 {set autoRscList[hsel[2][1]][hsel[2][2]] to  RscList[RscSelection][0].} 
          if adl = 14 {SET AUTOHUD[0] to StsSelection. SET AUTOHUD[2] TO "  OVER ". }
          if adl = 15 {if PRscList:length > 0 set autoRscList[hsel[2][1]][hsel[2][2]] to  RscSelection.}
            SET AutoValList[hsel[2][1]][hsel[2][2]] to  AUTOHUD[0].
            set AutoTRGList[hsel[2][1]][hsel[2][2]] to AutoSetAct.
            set autoRstList[hsel[2][1]][hsel[2][2]] TO AutoRstMode.
            set AutoTRGList[0][hsel[2][1]][hsel[2][2]] to setdelay.
            local rmstring to hsel[2][1]+"-"+hsel[2][2]+"-"+0.
            LOCAL rmstring2 to hsel[2][1]+"-"+hsel[2][2]+"-"+-1.
            for rmstring3 in list(rmstring,rmstring2){
              if AutoDspList[0][HDItmB][HDTagB]:contains (rmstring3) AutoDspList[0][HDItmB][HDTagB]:remove  (AutoDspList[0][HDItmB][HDTagB]:find(rmstring3)).
              if AutoDspList[0][HDItm][HDTag]:contains   (rmstring3) AutoDspList[0][HDItm][HDTag]:remove     (AutoDspList[0][HDItm][HDTag]:find(rmstring3)).
            }
            if dctnmode > 0 {
              set AutoDspList[hsel[2][1]][hsel[2][2]] to 0-abs(AutoSetMode).
              if dctnmode = 2 {if not AutoDspList[0][HDItm][HDTag]:contains(rmstring2) {AutoDspList[0][HDItm][HDTag]:add(rmstring2).} set AutoDspList[hsel[2][1]][hsel[2][2]] TO 1.}
                ELSE{          if not AutoDspList[0][HDItm][HDTag]:contains(rmstring)  {AutoDspList[0][HDItm][HDTag]:add(rmstring).}}
              local mde to 1-dctnmode.
                set AutoDspList[0][hsel[2][1]][hsel[2][2]][0] to HDItm+"-"+HDtag+"-"+mde.
            }
            else{
                set AutoDspList[hsel[2][1]][hsel[2][2]] to abs(AutoSetMode).
                set AutoDspList[0][hsel[2][1]][hsel[2][2]][0] to 0.
              }
               set h5mode to 0.
              SET AutoDspList[0][HDItm][HDTag] TO DEDUP(AutoDspList[0][HDItm][HDTag]).
              SET AutoDspList[0][HDItmB][HDTagB] TO DEDUP(AutoDspList[0][HDItmB][HDTagB]).
            
          IF AUTOHUD[2] = " UNDER " {SET UpDnOut to 2. SET AutoValList[hsel[2][1]][hsel[2][2]] TO 0-AUTOHUD[0].}else{SET UpDnOut to 1.  SET AutoValList[hsel[2][1]][hsel[2][2]] TO AUTOHUD[0].}
          IF dbglog > 0{
              log2file("SAVE AUTO TRIGGER:"+ItemList[hsel[2][1]]+":"+prtTagList[hsel[2][1]][hsel[2][2]]).
              logauto(1).
          }
          SaveAutoSettings().
          SETHUD(). 
          UpdateAutoTriggers(UpDnOut,abs(AutoDspList[hsel[2][1]][hsel[2][2]]),hsel[2][1],hsel[2][2],1).
          set buttonRefresh to 1. 
          UPDATEHUDOPTS().
        }
        else{
     if rowval = 1 {
        if  hsel[2][1] = SciTag{togglegroup(hsel[2][1],hsel[2][2],4).
        }else{
        if  hsel[2][1] = Flytag{
          IF hsel[2][2] = 1 {
            local lmt to 3.
            if axsel > 3 set lmt to AutoAdjByLst[0].
            SET AUTOHUD[1] TO CHANGESEL(lmt,AUTOHUD[1],"+").
          }
        }else{
      if  MeterPart > 0  {set MtrCur[5] TO CHANGESEL(MtrCur[4],MtrCur[5],"+",MtrCur[3]). set ActiveMeter[hsel[2][1]] to MtrCur[5]. set newhud to 2.
        }else{
        if mks = 1 {
          if hsel[2][1] = PWRtag {if HDXT = "BAY " {set BaySel TO CHANGESEL(BayLst[0],BaySel,"+"). }}
        }}}}
        SET forcerefresh TO 1. 
        UPDATEHUDOPTS().
        }
    }
    }. set BtnActn to 0.}  buttons:setdelegate(-1,buttonEnter@).
    
    function buttonCancel{lastin(). if BtnActn=0{set BtnActn to 1. 
    IF HUDOP = 5{
      SET AUTOHUD TO AUTOHUDBK. SETHUD().
        IF dbglog > 0{
            log2file("CANCEL EDIT AUTO TRIGGER "+ItemList[hsel[2][1]]+":"+prtTagList[hsel[2][1]][hsel[2][2]]).
            logauto().
            clearto(1,16). 
        }
      }
      ELSE{
        if hudop < 7 {
          SET HUDOP TO 5.
          set h5mode to 0.
          set RscSelection to 0.
          SET AUTOHUDBK TO AUTOHUD. clearto(1,14).  clearall().
          SET AUTOHUD[0] TO ABS(AutoValList[hsel[2][1]][hsel[2][2]]).
          if autoRscList[hsel[2][1]][hsel[2][2]]<>0{set RscSelection to safekey(RscNum,autoRscList[hsel[2][1]][hsel[2][2]]) .}
          set setdelay to AutoTRGList[0][hsel[2][1]][hsel[2][2]].
          set AutoSetMode to abs(AutoDspList[hsel[2][1]][hsel[2][2]]).
          if AutoDspList[hsel[2][1]][hsel[2][2]] > 0  set dctnmode to 0. else  {set dctnmode to 1.}
          if AutoDspList[0][hsel[2][1]][hsel[2][2]][0] <> 0 {
            local splt to AutoDspList[0][hsel[2][1]][hsel[2][2]][0]:split("-").
            set HDItm to splt[0]:tonumber. set HDItmB to HDItm.
            set HDTag to splt[1]:tonumber. set HDTagB to HDTag.
            if splt:length = 3 set dctnmode to 1.
            if splt:length = 4 set dctnmode to 2.
          }
          set AutoSetAct to AutoTRGList[hsel[2][1]][hsel[2][2]].
          set AutoRstMode to autoRstList[hsel[2][1]][hsel[2][2]].
          if AutoValList[hsel[2][1]][hsel[2][2]] > 0 SET UDO TO 1. ELSE SET UDO TO 2.
          ClearAuto(hsel[2][1],hsel[2][2],UDO,AutoSetMode,1).
            IF dbglog > 0{
                log2file("EDIT AUTO TRIGGER "+ItemList[hsel[2][1]]+":"+prtTagList[hsel[2][1]][hsel[2][2]]).
              logauto().
          }
        }else{set forcerefresh to 1.
          if meterpart = 2 {CycleAjdBy(). set forcerefresh to 2.}
          if  hsel[2][1]= Flytag {set apsel TO CHANGESEL(aplim,apsel,"+"). set forcerefresh to 1.}
        }
      }
    set buttonRefresh to 1.
    UPDATEHUDOPTS().
    }.set BtnActn to 0.}  buttons:setdelegate(-2,buttonCancel@).
    
    function button16{lastin(). if BtnActn=0{set BtnActn to 1. SET isDone to 1.}.set BtnActn to 0.}  buttons:setdelegate(13,button16@).
    //#endregion buttons
    local ch to "".
    until isDone > 0 {
      IF kuniverse:timewarp:issettled = TRUE {
        IF WARP > 0 AND WARPMODE = "RAILS" AND ship:control:pilotmainthrottle > 0 SET THRTFIX TO 1.
        IF THRTFIX = 1 {
          IF WARP < 1{
            UNTIL ship:control:pilotmainthrottle = THRTPREV {SET ship:control:pilotmainthrottle TO THRTPREV.}
            SET THRTFIX TO 0.
            if dbglog > 0 log2file("POST WARP THROTTLE SET TO "+THRTPREV).
            PRINTLINE("PRE-WARP THROTTLE LEVEL RESTORED "+THRTPREV,"WHT").
          }
        }
        ELSE{if warp = 0 SET THRTPREV TO ship:control:pilotmainthrottle.}
      }
      IF PRINTQ:LENGTH > 0 {if printpause = 0  IF PRINTQ:LENGTH > 1 set refreshRateSlow to 2. PrintTheQ().}
      if LastIn(-5) set refreshRateSlow to 1.
      if TIME:SECONDS - refreshTimer2 > refreshRateSlow-.01{
        UpdateMeterLeft().
        if saveflag = 1 {
          if alltagged:length <> ship:ALLTAGGEDPARTS():length partcheck(). 
          if STATUSSAVE:CONTAINS(SHIP:STATUS) or time:seconds-checktime > 90 SaveAutoSettings().
          }
        //UPDATEHUDSLOW().
        UPDATESTATUSROW(). 
        SET refreshTimer2 to TIME:SECONDS.
        set printpause to 0.
        IF PRINTQ:LENGTH = 0 set refreshRateSlow to RFSBAak.
      }
      local hdchk to  HdngSet[3][4]+ HdngSet[3][5]+ HdngSet[3][6].
      IF steeringmanager:enabled = TRUE if hdchk <> 0 if abs(SteeringManager:ANGLEERROR) < 5 ap().
      SET VSPDPRV TO SHIP:verticalspeed.
      SET SPDPRV TO SHIP:VELOCITY:SURFACE:MAG.
      set ALTPRV to ship:altitude.
    //#region check auto
    if steeringmanager:enabled = True and sas = true unlock steering.
    IF AUTOBRAKE = 0 SET BRAKES TO FALSE. ELSE
    IF AUTOBRAKE = 1 SET BRAKES TO TRUE. ELSE
    IF AUTOBRAKE = 2 {
      IF  SHIP:status = "LANDED" or SHIP:status = "PRELAUNCH"{IF THROTTLE > 0.4999{SET BRAKES TO FALSE.}ELSE{SET BRAKES TO TRUE.}}else{SET BRAKES TO FALSE.}
    }
    if RunAuto = 0{
      LOCAL SWAP TO 0.
      if IsPayload[1] = core:part{SET SWAP TO 1.}
      else{if IsPayload[1]:isdecoupled = True SET SWAP TO 1.}
      if SWAP = 1 {
        SET RunAuto TO 1.
        set refreshRateSlow to autovallist[0][0][4][0].
        set refreshRateFast to autovallist[0][0][4][1].        
        for i in range(1,10){PRINTLINE("CONTROL ENABLING IN "+10-I+" SECONDS   ","WHT"). WAIT 1.}
        ISRUcheck().
         PRINTLINE("",0,14).
      }
    }
    else{
      if HUDOP <> 5 AND RUNAUTO = 1{
        SpeedBoost("on",1).
        local trg to 0. 
        //check auto spd.
        if checkautotrigger(SpdTrgsUP)  <> 0{set trg to min(SpdTrgsUP[0],SpdTrgsUP[1]).       if trg = 0 set trg to SpdTrgsUP[1]. if trg <> 0 and SHIP:VELOCITY:SURFACE:MAG > trg TriggerAuto(AutoitemLst[2][1],2,trg,1,1).}
        if checkautotrigger(SpdTrgsDN)  <> 0{set trg to max(SpdTrgsDN[0],SpdTrgsDN[1]).       if trg = 0 set trg to SpdTrgsDN[0]. if trg <> 0 and SHIP:VELOCITY:SURFACE:MAG < trg TriggerAuto(AutoitemLst[2][2],2,trg,2,1).}
        //check auto ALT.
        if checkautotrigger(ALTTrgsUP)  <> 0{set trg to min(ALTTrgsUP[0],ALTTrgsUP[1]).       if trg = 0 set trg to ALTTrgsUP[1]. if ship:altitude > trg  TriggerAuto(AutoitemLst[3][1],3,trg,1,1).}
        if checkautotrigger(ALTTrgsDN)  <> 0{set trg to max(ALTTrgsDN[0],ALTTrgsDN[1]).       if trg = 0 set trg to ALTTrgsDN[0]. if ship:altitude < trg TriggerAuto(AutoitemLst[3][2],3,trg,2,1).}
        //check auto AGL.
        if checkautotrigger(AGLTrgsUP)  <> 0{set trg to min(AGLTrgsUP[0],AGLTrgsUP[1]).       if trg = 0 set trg to AGLTrgsUP[1]. if ALT:RADAR > trg  TriggerAuto(AutoitemLst[4][1],4,trg,1,1).}
        if checkautotrigger(AGLTrgsDN)  <> 0{set trg to max(AGLTrgsDN[0],AGLTrgsDN[1]).       if trg = 0 set trg to AGLTrgsDN[0]. if ALT:RADAR < trg TriggerAuto(AutoitemLst[4][2],4,trg,2,1).}
        //check auto EC.
        if checkautotrigger(ECTrgsUP)   <> 0{set trg to min(ECTrgsUP[0],ECTrgsUP[1]).         if trg = 0 set trg to ECTrgsUP[1].  if round(ship:electriccharge/ecmax*100,0) > trg  TriggerAuto(AutoitemLst[5][1],5,trg,1,1).}
        if checkautotrigger(ECTrgsDN)   <> 0{set trg to max(ECTrgsDN[0],ECTrgsDN[1]).         if trg = 0 set trg to ECTrgsDN[0].  if round(ship:electriccharge/ecmax*100,0) < trg  TriggerAuto(AutoitemLst[5][2],5,trg,2,1).}
        //check auto Rsc.
        if  checkautotrigger(RscTrgsUP) <> 0{set trg to min(RscTrgsUP[0],RscTrgsUP[1]).       if trg = 0 set trg to RscTrgsUP[1]. TriggerAuto(AutoitemLst[6][1],6,trg,1,2).}
        if  checkautotrigger(RscTrgsDN) <> 0{set trg to max(RscTrgsDN[0],RscTrgsDN[1]).       if trg = 0 set trg to RscTrgsDN[0]. TriggerAuto(AutoitemLst[6][2],6,trg,2,2).}
        //check auto throttle.
        if  checkautotrigger(ThrtTrgsUP) <>0 {set trg to min(ThrtTrgsUP[0],ThrtTrgsUP[1]).    if trg = 0 set trg to ThrtTrgsUP[1]. IF THROTTLE > (TRG*.01) TriggerAuto(AutoitemLst[7][1],7,trg,1,1).}
        if  checkautotrigger(ThrtTrgsDN) <>0 {set trg to max(ThrtTrgsDN[0],ThrtTrgsDN[1]).    if trg = 0 set trg to ThrtTrgsDN[0]. IF THROTTLE < (TRG*.01) TriggerAuto(AutoitemLst[7][2],7,trg,2,1).}
        //check auto Pressure.
        if senselist[3] = 1{
          if  checkautotrigger(PresTrgsUP) <> 0 {set trg to min(PresTrgsUP[0],PresTrgsUP[1]). if trg = 0 set trg to PresTrgsUP[1]. IF SHIP:SENSORS:PRES > TRG TriggerAuto(AutoitemLst[8][1],8,trg,1,1).  }
          if  checkautotrigger(PresTrgsDN) <> 0 {set trg to max(PresTrgsDN[0],PresTrgsDN[1]). if trg = 0 set trg to PresTrgsDN[0]. IF SHIP:SENSORS:PRES < TRG TriggerAuto(AutoitemLst[8][2],8,trg,2,1).  }
        }
        //check auto Sun.
        if senselist[2] = 1{
          if  checkautotrigger(SunTrgsUP) <> 0 {set trg to min(SunTrgsUP[0],SunTrgsUP[1]).    if trg = 0 set trg to SunTrgsUP[1].  IF SHIP:SENSORS:LIGHT > (TRG*.01) TriggerAuto(AutoitemLst[9][1],9,TRG,1,1).  }
          if  checkautotrigger(SunTrgsDN) <> 0 {set trg to max(SunTrgsDN[0],SunTrgsDN[1]).    if trg = 0 set trg to SunTrgsDN[0].  IF SHIP:SENSORS:LIGHT < (TRG*.01) TriggerAuto(AutoitemLst[9][2],9,TRG,2,1).  }
        }
        //check auto Temp.
        if senselist[4] = 1{
          if checkautotrigger(TempTrgsUP) <> 0 {set trg to min(TempTrgsUP[0],TempTrgsUP[1]).  if trg = 0 set trg to TempTrgsUP[1]. IF SHIP:SENSORS:TEMP > TRG TriggerAuto(AutoitemLst[10][1],10,trg,1,1).}
          if checkautotrigger(TempTrgsDN) <> 0 {set trg to max(TempTrgsDN[0],TempTrgsDN[1]).  if trg = 0 set trg to TempTrgsDN[0]. IF SHIP:SENSORS:TEMP < TRG TriggerAuto(AutoitemLst[10][2],10,trg,2,1).}
        }
        //check auto Grav.
        if senselist[1] = 1{
          if checkautotrigger(GravTrgsUP) <> 0 {set trg to min(GravTrgsUP[0],GravTrgsUP[1]).  if trg = 0 set trg to GravTrgsUP[1]. IF round(ship:sensors:grav:mag,1) > (TRG*.01) TriggerAuto(AutoitemLst[11][1],11,TRG,1,1).}
          if checkautotrigger(GravTrgsDN) <> 0 {set trg to max(GravTrgsDN[0],GravTrgsDN[1]).  if trg = 0 set trg to GravTrgsDN[0]. IF round(ship:sensors:grav:mag,1) < (TRG*.01) TriggerAuto(AutoitemLst[11][2],11,TRG,2,1).}
        }
        //check auto ACC.
        if senselist[0] = 1{
          if checkautotrigger(ACCTrgsUP) <> 0  {set trg to min(ACCTrgsUP[0],ACCTrgsUP[1]).    if trg = 0 set trg to ACCTrgsUP[1].  IF round(ship:sensors:acc:mag,1) > (TRG*.01) TriggerAuto(AutoitemLst[12][1],12,TRG,1,1).}
          if checkautotrigger(ACCTrgsDN) <> 0  {set trg to max(ACCTrgsDN[0],ACCTrgsDN[1]).    if trg = 0 set trg to ACCTrgsDN[0].  IF round(ship:sensors:acc:mag,1) < (TRG*.01) TriggerAuto(AutoitemLst[12][2],12,TRG,2,1).}
        }
        //check auto TWR.
          if checkautotrigger(TWRTrgsUP) <> 0  {set trg to min(TWRTrgsUP[0],TWRTrgsUP[1]).    if trg = 0 set trg to TWRTrgsUP[1].  IF twr > (TRG*.01) TriggerAuto(AutoitemLst[13][1],13,TRG,1,1).}
          if checkautotrigger(TWRTrgsDN) <> 0  {set trg to max(TWRTrgsDN[0],TWRTrgsDN[1]).    if trg = 0 set trg to TWRTrgsDN[0].  IF twr < (TRG*.01) TriggerAuto(AutoitemLst[13][2],13,TRG,2,1).}
        //check auto Status. 
          if SHIP:status <> ShipStatPREV2  OR MAX(StsTrgsUP[0],StsTrgsUP[1])>8{
            if checkautotrigger(StsTrgsUP) <> 0 {set trg to min(StsTrgsUP[0],StsTrgsUP[1]).
              if trg = 0 set trg to StsTrgsUP[1].  if AutoitemLst[14][1]:length > 1 {
                IF StsTrgs:contains(statusopts:find(ship:status)) OR MAX(StsTrgsUP[0],StsTrgsUP[1])>8{
                  TriggerAuto(AutoitemLst[14][1],14,TRG,1,3).
                } else{set ShipStatPREV2 to SHIP:status.}
              }
            }
          }
        //check Auto fuel 
        if dcptag <> 0 {if checkautotrigger(FuelTrgsDN) <> 0 OR checkautotrigger(FuelTrgsUP) <> 0 CheckDcpFuel().}
        SpeedBoost("off").
      } 
      //#endregion
      }
      //#region refresh 
      if BtnActn = 0 {
      IF loadattempts > 0 and buttonRefresh > 0 and TIME:SECONDS-boottime > 30{set loadattempts to -1.  sendboot().}
      if buttonRefresh > 0 updatehudSlow().
      IF BUTTONREFRESH > 1 {if forcerefresh = 0 SET FORCEREFRESH TO 1.}
      //IF BUTTONREFRESH > 2 {updatehudSlow(). UPDATEHUDOPTS(). SET FORCEREFRESH TO 2. SET refreshTimer2 to TIME:SECONDS.}
      IF BUTTONREFRESH > 2 {updatehudSlow(). SET FORCEREFRESH TO 2. SET refreshTimer2 to TIME:SECONDS.}
      if SHIP:status <> ShipStatPREV UPDATEHUDOPTS().
      //if  forcerefresh > 1 {UPDATEHUDOPTS().}
      if  (forcerefresh > 0 or newhud > 0) and ActionWait = 0 {UPDATEHUDOPTS().}
      set forcerefresh to 0.
      
}

      if TIME:SECONDS - refreshTimer > refreshRateFast-.01 or buttonRefresh > 0 {
        updatehudFast(). 
        if prtcount <> SHIP:PARTS:LENGTH {set saveflag to 1.}.
        SET refreshTimer to TIME:SECONDS.
        set buttonRefresh to 0.
        set AgState to list(AG1,ag2,ag3,ag4,ag5,ag6,ag7,ag8,ag9,ag10,0,RCS,ABORT,GEAR,lights,BRAKES).
        CheckAGs().
      }   
      if ActionQNew:length > 0 {
        local acqrm to list().
        LOCAL AACQ TO ActionQNew:COPY.
        local np to list(99,99,99,99).
        for n in AACQ {
          if n[3] = 0 and np[3] = 0 and n[1] = np[1] and n[2] = np[2] {acqrm:add(n).}
          else{
            if n[0] < time:seconds{
              set BtnActn to 1. 
              ToggleGroup(n[1],n[2],n[3],2).
              acqrm:add(n).
              set BtnActn to 0. 
            }
          }
          set np to n.
        }
        for n in acqrm {if ActionQNew:contains(n) ActionQNew:remove(ActionQNew:find(n)).}
        UPDATESTATUSROW().
      }
      //#endregion
      //#region terminal
      if terminal:input:haschar {if BtnActn = 0 set ch to terminal:input:getchar().}
      if ch = "6"  {buttonRight().set ch to "".}
      if ch = "4"  {buttonLeft().set ch to "".}
      if ch = "8"  {buttonUp().set ch to "".}
      if ch = "2"  {buttonDown().set ch to "".}
      if ch = "7"  {button7().set ch to "".}
      if ch = "1" and  BtnActn = 0 {button10().set ch to "".}
      if ch = "9"  {button9().set ch to "".}
      if ch = "3" and  BtnActn = 0 {button11().set ch to "".}
      if ch = "5" and  BtnActn = 0 {button8().set ch to "".}
      if ch = "+"  {set ch to "".}      
      if ch = "-"  {set ch to "".}
      //#endregion terminal
    WAIT 0.001.
    }
    //clearscreen.
	}
}
function logauto{
  LOCAL parameter OPT IS 0.
  local dl to "".
  local av to "".
  local at to "".
  local ar to "".
  local MD to "".
  IF OPT = 1{
    SET av to " SET TO "+AUTOHUD[0].
    set at to " SET TO "+AutoSetAct.
    set ar TO " SET TO "+AutoRstMode.
    set DL TO " SET TO "+ setdelay.
    set MD to " SET TO "+abs(AutoSetMode).
  }
  LOCAL RSCSL to safekey(RscNum,autoRscList[hsel[2][1]][hsel[2][2]]).
  log2file("    AutoValList[hsel[2][1]][hsel[2][2]](TRG VALUE  ):"+AutoValList[hsel[2][1]][hsel[2][2]]+AV).
  log2file("    AutoTRGList[hsel[2][1]][hsel[2][2]](ACTION     ):"+AutoTRGList[hsel[2][1]][hsel[2][2]]+" - "+actnlist[AutoTRGList[hsel[2][1]][hsel[2][2]]]+AT).
  log2file("    autoRstList[hsel[2][1]][hsel[2][2]](RESET MODE ):"+autoRstList[hsel[2][1]][hsel[2][2]]+" - "+HudRstMdLst[autoRstList[hsel[2][1]][hsel[2][2]]]+AR).
  log2file("    AutoDspList[hsel[2][1]][hsel[2][2]](AUTO MODE  ):"+AutoDspList[hsel[2][1]][hsel[2][2]]+" - "+MODELONG[abs(AutoDspList[hsel[2][1]][hsel[2][2]])]+MD).
  log2file("    AutoTRGList[0][hsel[2][1]][hsel[2][2]](DELAY   ):"+AutoTRGList[0][hsel[2][1]][hsel[2][2]]+dl).
  if AutoDspList[0][hsel[2][1]][hsel[2][2]][0] <> 0 log2file("    AutoDspList[0][hsel[2][1]][hsel[2][2]][0](WAIT4):"+AutoDspList[0][hsel[2][1]][hsel[2][2]][0]).
  if AutoDspList[hsel[2][1]][hsel[2][2]] = 6 {
    log2file("    autoRscList[hsel[2][1]][hsel[2][2]](RSC SEL    ):"+autoRscList[hsel[2][1]][hsel[2][2]]+" - "+RscList[RSCSL][0]).
  }
  if AutoDspList[hsel[2][1]][hsel[2][2]] = 15 AND PRscList:LENGTH > 0{
    log2file("    autoRscList[hsel[2][1]][hsel[2][2]](RSC SEL    ):"+autoRscList[hsel[2][1]][hsel[2][2]]+" - "+PRscList[RSCSL][0]).
  }
  if AutoDspList[hsel[2][1]][hsel[2][2]] < 0 and AutoDspList[0][hsel[2][1]][hsel[2][2]][0]:tostring <> "0"{
    if HDItm <> HDItmB or HDTag <> HDTagB {
      log2file("    AutoDspList[0][HDItmB][HDTagB](WAIT 4 GRP OUT  ):"+AutoDspList[0][HDItmB][HDTagB]+" - "+REMOVESPECIAL(ItemListHUD[HdItmb]," ")+":"+Prttaglist[HdItmb][hdtagb]).
      log2file("    AutoDspList[0][HDItm][HDTag]( WAIT 4 GROUP IN  ):"+AutoDspList[0][HDItm][HDTag]+ " - "+ REMOVESPECIAL(ItemListHUD[HdItm]," ")+":"+Prttaglist[HdItm][hdtag]).
    }if AutoDspList[0][hsel[2][1]][hsel[2][2]][0] <> 0 {
    local splt to AutoDspList[0][hsel[2][1]][hsel[2][2]][0]:split("-").
    if splt:length = 3 log2file( "WONT START DETECTION UNTIL AFTER "+REMOVESPECIAL(ItemListHUD[HdItm]," ")+":"+Prttaglist[HdItm][hdtag]+" IS TRIGGERED").
    if splt:length = 4 log2file( "WILL TRIGGER WHEN "+REMOVESPECIAL(ItemListHUD[HdItm]," ")+":"+Prttaglist[HdItm][hdtag]+" IS TRIGGERED").
    }
  }
}
//#region AP
function AP{// if up 2 fast not turning dn
        local spd to SHIP:VELOCITY:SURFACE:MAG.
        IF SHIP:verticalspeed > VSPDPRV SET VrtDIR TO 1. ELSE SET VrtDIR TO -1.
        IF spd                >  SPDPRV SET SpdDIR TO 1. ELSE SET SpdDIR TO -1.
        IF ship:altitude      >  ALTPRV SET AltDIR TO 1. ELSE SET AltDIR TO -1.
        IF HdngSet[0][4] > 0 set HLIM to HdngSet[0][4]. ELSE set HLIM to HLIMSTRT.
        local altprob to 0.
        set AltSet to HdngSet[0][5].
        IF SHIP:altitude > AltSet set altprob to 1.
        IF SHIP:altitude < AltSet set altprob to -1.
        IF HdngSet[0][6] > 0 SET VLIM TO HdngSet[0][6]. ELSE SET VLIM TO VLIMSTRT.
        IF HdngSet[0][7] > 0 set plim to HdngSet[0][7]. ELSE set plim to PLIMSTRT.
        IF HdngSet[0][8] > 0 set LLIM to HdngSet[0][8]. ELSE set LLIM to LLIMSTRT.
        //LOCAL MLT TO min(ABS(SHIP:verticalspeed)/VLIM,1).
        local mlt to 1.
        local PitchCur to ROUND(compass_and_pitch_for()[1],0).
        LOCAL PitchTrg TO HdngSet[0][2].
        local plimcur to plim.//+plimadj.
        local ptset to abs(PitchCur)+ABS(flyadj[2]).//+plimadj.
        local vprob to 0. if abs(SHIP:verticalspeed) > VLIM*MLT set vprob to 1.
        local ndir to 1.     if PitchCur < 0 set ndir to -1.
        local spdprob to 0.
        if ship:control:pilotmainthrottle < .05 and spd > Hlim and PitchCur < 0 set spdprob to 1.
        if ship:control:pilotmainthrottle > .95 and spd < llim*1.05 and SpdDIR=-1 set spdprob to -1.
        local plimprob to 0. if plimcur < PitchCur set plimprob to 1.
        IF HdngSet[3][4] > 0 { //speed
          local thradj to 3*(1-(min(spd,HLIM)/max(spd,HLIM))).
          local spdclose to 0.
          if GetRange(spd, HdngSet[0][4],10) {set spdclose to 1. set thradj to thradj * 2.}
          IF SpdDIR = 1 {
            IF spd > HLIM Throtadj(ship:control:pilotmainthrottle-thradj).
            if ship:control:pilotmainthrottle = 1 and not spdclose = 1 and PitchCur < plimcur+1 and spdprob > 0 pitchadj(01).//set plimadj to min(plimadj+1,0).
          }
          ELSE{
            if ship:control:pilotmainthrottle = 1 {if PitchCur > 0 and not spdclose = 1 and spdprob <  0 pitchadj(-01).}// set plimadj to plimadj-1.}
            else{ if spd < HLIM Throtadj(ship:control:pilotmainthrottle+thradj).}
          }
        }
        IF HdngSet[3][5] > 0 {//alt          
            local adj to 3.
            if GetRange(SHIP:altitude, AltSet,2)  {set adj to 1. set plimcur to plim/10.}else{
            if GetRange(SHIP:altitude, AltSet,5)  {set adj to 1. set plimcur to plim/6.}else{
            if GetRange(SHIP:altitude, AltSet,10) {set adj to 1. set plimcur to plim/3.}else{
            if GetRange(SHIP:altitude, AltSet,15) {set adj to 2. set plimcur to plim/2.}}}}
            set plim to ceiling(plim).
            if plimcur < PitchCur set plimprob to 1.
            local Vprob2 to 0.
            if vprob = 1 and PitchCur > 3 set Vprob2 to 1.
            IF altprob = 1 {IF plimprob = 0 and vprob = 0                     {IF DBGLOG > 1  log2file(" ALT CHK 1 DN"). pitchadj(0-adj).} else {IF DBGLOG > 1  log2file(" ALT CHK 1 UP"). pitchadj(adj).  }}
            IF altprob =-1 {IF plimprob = 0 and spdprob > -1 and  Vprob2 = 0 {IF DBGLOG > 1  log2file(" ALT CHK 2 UP"). pitchadj(adj).}   else {IF DBGLOG > 1  log2file(" ALT CHK 2 DN"). pitchadj(0-adj).}}
          }
        IF HdngSet[3][6] > 0 {if abs(SHIP:verticalspeed) > VLIM pitchadj(-AltDIR).}

        function pitchadj{
          local parameter amt is 1.
          SET flyadj[2] TO flyadj[2]+amt.
          if ndir > 0 if flyadj[2]+PitchTrg > plimcur {  set flyadj[2] to plimcur-PitchTrg.   IF DBGLOG > 0  log2file(" LIM ADJ UP").}
          if ndir < 0 if flyadj[2]+PitchTrg < 0-plimcur {set flyadj[2] to 0-plimcur-PitchTrg. IF DBGLOG > 0  log2file(" LIM ADJ DN").}
          IF DBGLOG > 1 if amt > 0 LogAP("    PITCH ADJ UP: "+amt). else LogAP("    PITCH ADJ DN:"+amt).
        }
        function Throtadj{
          local parameter st.
          SET ship:control:pilotmainthrottle TO st.
          IF DBGLOG > 0 log2file("   THRTL SET TO: "+st).
        }
        function LogAP{
          local parameter str is "".
          if str <> "" log2file(str).
          log2file("      THROTTLE:"+ship:control:pilotmainthrottle).
          log2file("      SPEED:"+round(spd,0)+" spdlim:"+Hlim+" spdmin:"+LLIM).
          log2file("      ALTITUDE:"+round(ship:altitude,0)+" ALTSET:"+ HdngSet[0][5]).
          log2file("      VERTICAL SPEED:"+round(ship:VERTICALSPEED,0)+" VLIM:"+vlim+" MLT:"+round(mlt,2)+" VLIM*MLT:"+round(VLIM*MLT,2)).
          log2file("      VrtDIR:"+VrtDIR+"  SpdDIR:"+SpdDIR+"  AltDIR:"+AltDIR).
          log2file("      PITCH:"+PitchCur+" PLimCur:"+plimcur+" PTSET:"+HdngSet[0][2]+" PADJ:"+FLYADJ[2]).//+" Padj2:"+plimadj).
          log2file("      spdprob:"+spdprob+" vprob:"+vprob+" altprob:"+altprob+" plimprob:"+plimprob).
          log2file("      hdngset[3]:"+LISTTOSTRING(hdngset[3])).
        }
    }
//#endregion
//#region string ops
function clearall{
  PRINTLINE("",0,15).  PRINTLINE("",0,16).  PRINTLINE().
}
FUNCTION GetColor{ //GetColor("STR", "RED")
  local parameter StrIn, clr is "GRN", opt is 1.
  if colorprint = 0  return strin.
  local colp to "". local colpo to "".
  if clr = 0 set clr to "GRN".
  if clr = "GRN" and opt = 2 return strin.
  if clr = 4 set clr to "WHT".
  if clr = 3 set clr to "ORN".
  if clr = 2 set clr to "RED".
  if clr = 1 set clr to "CYN".
    if FindCl:HASKEY(clr) {
      IF StrIn:LENGTH > widthlim-20 SET OPT TO 0.
      if opt = 1 or opt = 2 set colpo to "{COLOR}".
      set colp to  FindCl[clr].
      if dbglog > 3 log2file("        GETCOLOR:"+strin+" CLR:"+CLR+" OPT:"+opt+ " OUT:"+colp+StrIn+colpo).
    }else return StrIn.
  return colp+StrIn+colpo.
}
function PrintTheQ{
  local PLN to PRINTQ:POP:split("<sp>").
  PRINTLINE(PLN[0],PLN[1]).
  IF dbglog > 1 log2file("PRINT:"+PLN[0]).
  set printpause to 1.
  set refreshTimer2 to TIME:SECONDS.
}
FUNCTION Removespecial{
  local parameter input, toRemove IS "%".
  if input:typename = "String"{
    if toRemove = "%" {set input to input:REPLACE(toRemove, " Percent").}else{
    set input to input:REPLACE(toRemove, "").}}
  return input.
}
function formatTime{
  local parameter t, OP IS 0.
  IF T < 0 RETURN "PASSED".
  local h is 0.
  local dy is 0.
  local FTAns is "".
  local m is floor(t/60). 
  local s is floor(t-m*60).
  if m > 60 {
    set h to floor(m/60).
    set m to floor(m-(h*60)).
  }
   if h > 24 {
    set dy to floor(h/24).
    set h to floor(h-(dy*24)).
  }
    if dy> 0  set FTAns to FTAns+"0"+d + "DY:".
    if h > 0  set FTAns to FTAns+"0"+h + ":". else IF OP = 1 set FTAns to FTAns+ "00:".
    if FLOOR(m) > 9 set FTAns to FTAns+ m. else set FTAns to FTAns+ "0" + m.
    if FLOOR(s) > 9 set FTAns to FTAns+ ":" + s. else set FTAns to FTAns+ ":0" + s.
  return FTAns.
}
function log2file{
  local parameter str.
  log formattime(time:seconds-boottime,1)+":  "+str to DebugLog.
}
FUNCTION PRINTLINE{
LOCAL PARAMETER WORD is "",cl is 0, line is 17.
IF CL = "GRN" SET CL TO 0.
if line <> 14 PRINT BIGEMPTY2 AT (1,line). else PRINT BIGEMPTY AT (1,line).
if line > heightlim-2 print " " at (line,widthlim).
if word <> "" {
  if colorprint > 0 and cl <> 0 set word to getcolor(word,cl).
  PRINT WORD AT (1,line).}
  IF dbglog > 1{if word <> "" log2file("   PRINTLINE:"+WORD+" AT("+line+")"). else if dbglog > 1 log2file("   CLEARLINE:("+line+")").}
}
function makehud{
  local parameter word, lim is 9.
  until word:length>lim{set word to " "+word+" ".}
  if word:length>lim set word to word:substring(0,lim+1).
  return word.
}
FUNCTION RemoveLetters{
  local parameter input,toRemove IS "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ%:".
  if input:istype("scalar") return input:tostring.
  for i in range(0, toRemove:length) {set input to input:REPLACE(toRemove[I], "").}
  return input.
}
function clearrow{
local parameter rownum, OPTN IS 1.
      IF OPTN =1 {
      set HudOpts[rownum][1] to "                              ".
      set HudOpts[rownum][2] to "                    ".
      set HudOpts[rownum][3] to "                              ".
      }
      printline("",0,hudstart-rownum).
}
function clearto{
  local parameter st, end.
   for i in range(st, end) {PRINTLINE("",0,i). PRINT " " AT (0,I).}
}
function safekey{
  local parameter lx, ky.
  if lx:haskey(ky) return lx[ky].
  return 0.
}
function glt{
  local parameter n1,n2, opt is 0.
  if opt = 0{
  if n1 > n2 return "^".
  if n1 < n2 return "v".
  }else{
  if n1 > n2 return ">".
  if n1 < n2 return "<".
  }
  return " ".
}
FUNCTION LISTTOSTRING{
  LOCAL parameter LSTIN3.
  if not lstin3:typename:contains("list") set lstin3 to list(lstin3).
  LOCAL L2SAns TO "".
  FOR ITM IN LSTIN3:copy{
    //if itm <> "" 
    set L2SAns to L2SAns+itm:tostring+",".
  }
  return L2SAns:tostring.
}
FUNCTION PADMID{
  LOCAL PARAMETER STRING, AMT is widthlim.
        LOCAL SP TO (AMT-STRING:LENGTH)/2.
        local sp2 to 0.
        if ceiling(sp)>sp {
          set sp to floor(sp).
          set sp2 to ceiling(sp).
        }
        LOCAL ST TO STRING:PADLEFT(SP+STRING:LENGTH-1).
        SET   ST TO ST:PADRIGHT(SP2+ST:LENGTH+SP).
        RETURN ST.
}
Function DeDup{
  local parameter lstin2.
  local lst2 to lstin2:copy.
  local lstout is list().
  for it in lst2 if not lstout:contains(it) lstout:add(it).  
  return lstout.
}
function listadd{
  local parameter lin, ad, OPT IS 0.
  if not ad:typename:contains("list") set ad to list(ad).
  if dbglog = 3 log2file("          LISTADD"+LISTTOSTRING(lin)+"+"+LISTTOSTRING(ad)).
  IF OPT = 0{
    for i in ad{
      lin:add(i).
    }
  }ELSE{
    for i in ad{
      IF NOT LIN:CONTAINS(AD) lin:add(i).
    }
  }
  if dbglog = 3 log2file("          LISTOUT"+LISTTOSTRING(lin)).
  return lin.
}
function FillList{
local parameter FillInList, lng.
  if not FillInList:typename:contains("list") return FillInList.
  UNTIL FillInList:LENGTH > lng{
    FillInList:ADD("").
  }
  return FillInList:copy.
}
function ReplaceWords{
  local parameter strin, wrdsin is ReplWRDS[0], wrdsout is ReplWRDS[1].
  if strin:typename()  <> "string" set strin to strin:tostring.
  if wrdsin:typename()  = "string" set wrdsin  to wrdsin:split("/").
  if wrdsout:typename() = "string" set wrdsout to wrdsout:split("/").
  if wrdsin:contains(strin) set strin to wrdsout[wrdsin:find(strin)].
  return strin.   
}
FUNCTION StrginAct{
  local parameter strin.
  local stroutb is "".
  IF strin:istype("STRING"){
    SET stroutb to removeletters(strin:tostring).
    if stroutb <> "" SET stroutb TO stroutb:tonumber.
    SET strouta TO RemoveLetters(strin:TOSTRING,"0123456789").
    return list(strouta,stroutb).
  }
}
function splitlist{
  local parameter SpLstIn ,splopt is 1.
  if SpLstIn:contains("/") return SpLstIn:split("/"). else if splopt = 1 return list(SpLstIn). else return SpLstIn.
}
//#endregion
//#region get ops
function getstatus{
local parameter Inum, tagnum, optn is 1, row IS 1, rnd is 0, dbglvl is 2.
local optn1 to optn*3-2.
  local MDL1 to modulelist[0][inum][optn1].
  local MDL2 to modulelist[1][inum][optn1].
  local Fld to modulelist[2][inum][optn1].
  
  local GSAns to "        ".
  local p to  prtlist[Inum][tagnum][getgoodpart(Inum,tagnum,1)].
  IF dbglog > dbglvl log2file("GETSTATUS-"+itemlist[Inum]+":"+prtTagList[Inum][tagnum]+":"+optn1+" row:"+row+" rnd:"+rnd+" MODULE1:"+LISTTOSTRING(MDL1)+" MODULE2:"+LISTTOSTRING(MDL2)+" FIELD:"+LISTTOSTRING(Fld)).
    for k in list(MDL1,MDL2){
      if p:hasmodule(k){
        if p:getmodule(k):hasFIELD(Fld){
          set GSAns to Removespecial(P:GETMODULE(k):getfield(Fld)). 
          set HudOpts[row][1] to Fld. 
          set HudOpts[row][2] to ":".
          break.
        }
      }
    }
        IF GSAns <> "        "{
        if rnd > 0 set GSAns to round(GSAns, rnd).
        IF dbglog > dbglvl log2file("    "+" GSAns:"+GSAns).
        if rnd = -1  return GSAns.
        if rnd = -2  return round(GSAns, 2).
        if rnd > -20 AND RND < -9  return ROUND(GSAns,ABS(RND+10)). // RETURN ROUND LAST DIGIT (-11 = ROUND 1)
        if rnd > -30 AND RND < -19  return Fld+":"+ROUND(GSAns,ABS(RND+20)).// RETURN NANME + ROUND LAST DIGIT (-21 = ROUND 1)
        if rnd = -30  return Fld+":"+GSAns.// RETURN NANME + GSAns
        }
        
        return GSAns+"                            ".
}
fUNCTION GetMultiModule{
  local parameter PrtIN, GrabFied, ModName is "".
  local count to 0. LOCAL FLDNM TO "".  LOCAL FLDVL TO "". LOCAL TMPLST TO LIST().
    for m in PrtIN:modules{
      LOCAL GetMod TO PrtIN:GETMODULEBYINDEX(count).
        if GetMod:ALLFIELDNAMES:empty {}else{
          if GrabFied = ""{
              SET FLDNM TO GetMod:ALLFIELDNAMES[0].
              IF M:contains(Modname){
                SET FLDVL TO "".
                TMPLST:add(list(fldnm,FLDVL,count,m)). //fieldname, value, index, module
              }
          }else{
              SET FLDNM TO GetMod:ALLFIELDNAMES[0].
              IF FLDNM:contains(GrabFied){
                SET FLDVL TO GetMod:GETFIELD(FLDNM).
                TMPLST:add(list(fldnm,FLDVL,count,m)).
              }
            }
      }
      set count to count+1.
    }
TMPLST:insert(0,TMPLST:length).
return TMPLST.
}
function GetActions{
    local parameter opt, ModList, inum, tnum, optnin, evac, OpYes, OpNo is list("zzz"),dbglvl is 0.//return setting,list parts in , inum, tagnum, op 4 list, what to check 1=ac,2=ev,3=fld.
    LOCAL OPTTMP TO OPT.
    local prtid to "".
    IF NOT OpYes:istype("list") SET OpYes TO LIST(OpYes).
    IF NOT OpNo:istype("list") SET OpNo TO LIST(OpNo).
    if opt:istype("string"){ local tmpopt to StrginAct(opt). set opt to tmpopt[0].set prtid to tmpopt[1].}
     if DbgLog > dbglvl {if inum <> 0{ log2file("               GETACTIONS:"+ItemList[inum]+":"+prttaglist[inum][tnum]+" EVAC"+evac).}
      if DbgLog > min(dbglvl+1,2) {        log2file("                optIN:"+OPTTMP+" inum:"+inum).
        IF opt = "OnOff" {                 log2file("                  On:"+LISTTOSTRING(OpYes)+" Off:"+LISTTOSTRING(OpNo)).}
        else{                              log2file("                  OpYes:"+LISTTOSTRING(OpYes)+" OpNo :"+LISTTOSTRING(OpNo)+ "ModList:"+LISTTOSTRING(ModList) ).
        }
      }
     }
      local RtnAns to 0.
      LOCAL LM TO 0.
      IF EVAC = 0 {SET LM TO 1. set evac to 3.}
      IF EVAC = 5 {SET LM TO 3. set evac to 2.}
      IF EVAC = 6 {SET LM TO 3. set evac to 3.}
      local optn3 to optnin*3.
      local optn2 to optn3-1.
      local optn1 to optn3-2.
      local pm to "".
      local mdl to "".
      local opout1 to "".
      local opout2 to "".
      local evmin to evac.
      local evmax to evac.
      local p to "".
      if evac = 3 {set evmin to 1. set evmax to 2.}
      if inum = 0 set p to tnum. else {if PRTID = "" set prtid to getgoodpart(Inum,tnum,2,ModList). set p to PrtList[inum][tnum][prtid].}
      if prtid = 0 {if dbglog > 0 log2file("              NO GOOD PART"). set modlist to list().}else{if dbglog > 0 log2file("               PART("+prtid+"):"+p).}
      for e in range(evmin,evmax+1){if dbglog > dbglvl+1  log2file("                         EV:("+e+")").
        if RtnAns > 0 break.
        if e > evmax break.
        local dbthr is 2. // SET TO LOWER TO ADD MORE DEBUG
        set evac to e.
        for md in ModList:copy{if dbglog > dbglvl+1  log2file("                           MD:("+md+")").
          IF MD:istype("STRING") {
            if ship:modulesnamed(md):length > 0 {
              if p:hasmodule(md){
                if evac = 1 set pm to p:getmodule(md):AllEventNames.
                if evac = 2 set pm to p:getmodule(md):AllActionNames.
                if evac = 4 set pm to p:getmodule(md):AllfieldNames.
                if dbglog > dbglvl+1  log2file("                          AllItems:("+LISTTOSTRING(PM)+")").//dddd
                for k in pm{
                  if RtnAns > lm break.
                  for op in opyes{
                    if RtnAns > 0 break.
                    if op <>"" {if dbglog > dbglvl+1  log2file("                                IF-ON :("+k+")"+"CONTAINS:("+op+")"). 
                      if (k:contains(op) or k = op) {if dbglog > dbglvl+1  log2file("                             (YES)").  
                        if getEvAct(p,md,k,e,-1,DBTHR) {if dbglog > dbglvl+1  log2file("                              (PROCESSED)").  
                          IF EVAC = 4 SET opout2 TO p:getmodule(md):GETFIELD(K).
                            set opout1 to k. 
                            set RtnAns to 1.
                            set mdl to md.
                          break.
                        }
                      }
                    }
                  }
                  IF EVAC <> 4 {
                    for op in opno{
                      if RtnAns > LM break.
                      if op <> "" {if dbglog > dbglvl+1  log2file("                                 IF-OFF:("+k+")"+"CONTAINS:("+op+")").  
                        if (k:contains(op) or k = op){
                          if getEvAct(p,md,k,e,-1,DBTHR) {if dbglog > dbglvl+1  log2file("                              (PROCESSED)").  
                            set opout2 to k.
                            set RtnAns to RtnAns+2.
                            set mdl to md.
                            break.
                          }
                        }
                      }
                    }
                  }
                }if RtnAns > 0 break.
              }if RtnAns > 0 break.
            }if RtnAns > 0 break.
          }ELSE{IF MD = 0 RETURN 0.}
        }
      }
      if DbgLog > min(dbglvl+1,2) log2file( "                       mdl:"+mdl+" op out1:"+opout1+" op out2:"+opout2+" RtnAns:"+RtnAns+" evac:"+evac+" PrtId:"+prtid+" PM:"+LISTTOSTRING(PM)).
      if opt = 1 {set modulelist[0][inum][optn1] to mdl. set modulelist[0][inum][optn2] to opout1. set modulelist[0][inum][optn3] to opout2. return RtnAns.}
      if opt = 2 or opt = "Actions"{return list(mdl,opout1,opout2,RtnAns,evac).}
      if opt = 3 or opt = "Modules" return PM.
      if opt = 4 or opt = "OnOff" {if dbglog > dbglvl  log2file("                       OnOff:("+RtnAns+")"). return RtnAns.}
      if opt = 5 {set modulelist[0][inum][optn1] to mdl. set modulelist[0][inum][optn2] to opout1. set modulelist[0][inum][optn3] to opout2. return list(mdl,opout1,opout2,RtnAns,evac).}
   }
function getEvAct{
  local parameter p,m,ev, mode, val is 0, dbt is 2.
  if p:istype("list"){
    set pl to p:copy.
    for pl2 in pl { if  not BadPart(pl2) {set p to pl2. break.}
    }
  }
  if BadPart(p) AND VAL <> -1 return false.
  local GTAns to "".
  local tname to "".
  if not ev:istype("string") set ev to ev:tostring.
  if mode < 30 and val > 0  set dbt to MIN(val,3).
  if dbglog > dbt log2file("              GETEVACT:"+mode+" PART:"+p+" MODULE:"+m+" EVENT:"+EV+".").
  if not p:hasmodule(m) {if dbglog > dbt log2file("                       NO MODULE:"+m). return false.}else{
  local pm to p:getmodule(m).
  if mode = 1  {set GTAns to pm:hasevent(ev).  if dbglog > dbt-1{set tname to listtostring(pm:AllEventNames) +":"+p+"("+m+")"+"hasevent:"+EV.}}else{
  if mode = 2  {set GTAns to pm:hasaction(ev). if dbglog > dbt-1{set tname to listtostring(pm:AllActionNames)+":"+p+"("+m+")"+"hasaction:"+EV.}}else{
  if mode = 3  {set GTAns to pm:hasfield(ev).  if dbglog > dbt-1{set tname to listtostring(pm:AllfieldNames) +":"+p+"("+m+")"+"hasfield:"+EV.}}else{
  if mode = 4  {set GTAns to pm:hasfield(ev).  if dbglog > dbt-1{set tname to listtostring(pm:AllfieldNames) +":"+p+"("+m+")"+"hasfield:"+EV.}}else{
  if mode = 10 {if  pm:hasevent(ev){pm:doevent(ev).        }if dbglog > dbt-1{set tname to "doevent:"+EV. set GTAns to pm:hasevent(ev). }}else{
  if mode = 20 {if pm:hasaction(ev){pm:doaction(ev, True). }if dbglog > dbt-1{set tname to "doaction:"+EV. set GTAns to pm:hasaction(ev).}}else{
  if mode = 30 {if  pm:hasfield(ev){set GTAns to pm:GETFIELD(ev).}if dbglog > dbt-1{set tname to "getfield:"+EV.}}else{
  if mode = 40 {if  pm:hasfield(ev){pm:SETFIELD(ev,val). set GTAns to pm:GETFIELD(ev).}if dbglog > dbt-1{set tname to "setfield:"+EV+" TO:"+val.}}
  }}}}}}}}
  IF MODE = 30 AND VAL > -1 AND GTAns:TYPENAME = "SCALAR" SET GTAns TO ROUND(GTAns,VAL).
  if dbglog > dbt-1 log2file("                "+tname+" GTAns:"+GTAns).
  return GTAns.
}
function CheckTrue{
    local parameter md, pt, MDL, FLD, ValTrue, ValFalse, vx is 0, dbglvl is 2.
    if md <> 40 {
    if getEvAct(pt,MDL,FLD,md,vx,dbglvl)  = False set CTAns to ValFalse. else set CTAns to ValTrue.
    }else{
    if getEvAct(pt,MDL,FLD,30,vx,dbglvl)  =  True {
      for p1 in pl getEvAct(p1,MDL,FLD,40,False).
      set CTAns to ValFalse. 
      }else {
        for p1 in pl getEvAct(p1,MDL,FLD,40,True).
        set CTAns to ValTrue. 
      }
    }
    return CTAns.
}
function checkDcp{
local parameter Prt, Word.
local p to PRT:DECOUPLER.
local DCPAns to 0.
local pt to "".
if p <> "none"{
  if p:TAG:tostring:contains(word){set DCPAns to 1. set pt to p.}else{
    until DCPAns=1 or p = "None"{
      set p to p:parent:decoupler.
      if p <> "none"{if p:TAG:tostring:contains(word) set DCPAns to 1. set pt to p.}
    }
  }
}
return list(DCPAns,pt).
}
function getRTVesselTargets {
  IF dbglog > 0 log2file("GET VESSEL TARGETS").
  local parameter opt is 1.
  local availableTargets to list("no-target","active-vessel").
  if opt = 1{availableTargets:add("Mission Control").
  list targets in allTargets.
  for v in allTargets {set targetName to v:NAME.
      if targetName:contains("Ast.") set targetName to "". 
      if targetName:contains("Debris") set targetName to "". 
          if targetName <>"" {availableTargets:add(targetName).}
      }
        LIST BODIES IN bodList.
        for v in bodList {availableTargets:add(v:name).}
}
  availableTargets:insert(0,availableTargets:length).
  IF dbglog > 1 log2file("    "+LISTTOSTRING(availableTargets)).
  return availableTargets.
}
Function GetRange{//returns TRUE if within (percent) percent of (val), 0 = return true/false, 1 = return high/low value
  local parameter val, comp, percent, opt is 1.
    local GRAns is false.
    if val < comp*(1+(percent/100)) and val > comp*(1-(percent/100)) set GRAns to True.
    if val = comp  set GRAns to True.
    if opt = 1 return GRAns.
    if opt = 2 return list(comp*(1-(percent/100)), comp*(1+(percent/100))).
}
function getgoodpart{ // verifies tags are equal
    local parameter Iin, Tin, opt is 0, mds is "", flds is "".
    if MeterList[1][Iin][0] = 0 set opt to 0.
    IF dbglog > 2 log2file("                        GetGoodPart:Item:"+iin+" TAG:"+tin+" OPT:"+opt).
    if opt = 0 {
  for p in range (0,PrtList[Iin][Tin][0]) {if not BadPart(PrtList[Iin][Tin][p+1], prttaglist[Iin][Tin]) return p+1.} return 0.
    }else{
      if mds  = "" set mds  to MeterList[1][iin].
      if flds = "" set flds to MeterList[2][iin][0].
      if not flds:typename:contains("list") set flds to list(flds).
          IF dbglog > 2 log2file("                          mds:"+LISTTOSTRING(mds)+" flds:"+LISTTOSTRING(flds)).
    if opt > 0 local modcnt to list().
    local addlst to list(-1,0).
    until addlst:length > PrtList[Iin][Tin][0] addlst:add(0).
    for ggm in mds{
      for p in range (0,PrtList[Iin][Tin][0]) { 
        local p1 to p+1.
        local pt to PrtList[Iin][Tin][p1].
        if  pt:hasmodule(ggm) {
          if not BadPart(pt, prttaglist[Iin][Tin]) { 
            set addlst[p1] to addlst[p1]+1.
            if opt = 1 {if flds:length > 1 for f in flds{if pt:getmodule(ggm):ALLFIELDNAMES:contains(f) set addlst[p1] to addlst[p1]+1.}} //    if MeterList[1][Iin][0] = 0 set opt to 0.
          }
        }
      }
    }
      local mx to 0. local mxo to 1.
      for i in range(0,addlst:length) {if addlst[i] > mx {set mx to addlst[i]. set mxo to i.}}
      if dbglog > 2 log2file("                          :PRT:"+mxo+" HAS "+MX+" MODULES/FIELDS"). 
      return max(mxo,1).
    }
}
function BoolNum{//bool to number
local parameter NumIn, opt is 0.
if dbglog > 2 log2file("              BoolNum:"+Numin).
if opt = 0{
  if numin="true" return 1.
  if numin="false" return 0.
}
set NumTst to removeletters(numin).
if numtst:length = numin:tostring:length{
  if numin:hassuffix("tonumber") return numin:tonumber. else  return numin.
}else{return list(numin).}
}
//#endregion
//#region file and part ops
function sendboot{
  IF dbglog > 0 log2file("BOOTLOOPCHECK").
     local P TO PROCESSOR(CORE:PART:TAG).
      if loadattempts < 0 {
        until CORE:MESSAGES:EMPTY{
          SET RECEIVED TO CORE:MESSAGES:POP.
        }
      IF P:CONNECTION:SENDMESSAGE(loadattempts).}
      else{IF P:CONNECTION:SENDMESSAGE(loadattempts).}
    }
function SaveAutoSettings{
  LOCAL parameter OP IS 1, op2 is 1.
  if op2 = 1 partcheck().
  local loadp to 20.  if colorprint > 0{ set loadp to loadp+9. PRINT " " AT (80,LNstp-1).}
  if op2 = 2 {set loadp to loadp+1. print "." at (loadp,LNstp-1).}
  if dbglog > 0 log2file("SAVE AUTO SETTINGS").
  set saveflag to 0.
  if prtcount <> SHIP:PARTS:LENGTH set prtcount to SHIP:PARTS:LENGTH.
  file_exists().
  set autovallist[0][0][2] to HEIGHT.
  set autovallist[0][0][1] to HdngSet.
  set autoRstList[0][0][0] to AUTOLOCK.
  if defined (HSel) set AutoDspList[0][0][0] to hsel[2][1]. else set  AutoDspList[0][0][0] to 1.
  if defined (hsel) set AutoDspList[0][0][1] to hsel[2][2]. else set  AutoDspList[0][0][1] to 1.
  if loadattempts = -1 {if autovallist[0][0][0] > 1001 set autovallist[0][0][0] to 1001.}
  if debug > 2 {
    log2file(LISTTOSTRING("AutoDspList:"+AutoDspList)).
    log2file(LISTTOSTRING("autovallist:"+autovallist)).
    log2file(LISTTOSTRING("itemlist:"+itemlist)).
    log2file(LISTTOSTRING("prttaglist:"+prttaglist)).
    log2file(LISTTOSTRING("prtlist:"+prtlist)).
    log2file(LISTTOSTRING("autoRstList:"+autoRstList)).
    log2file(LISTTOSTRING("AutoRscList:"+AutoRscList)).
    log2file(LISTTOSTRING("AutoTRGList:"+AutoTRGList)).
  }
  local listout to list(AutoDspList, autovallist,itemlist,prttaglist, prtlist, autoRstList, AutoRscList ,AutoTRGList, MONITORID).
  if op = 1 WRITEJSON(listout, SubDirSV + autofile).
  if op = 2 WRITEJSON(listout, SubDirSV + AutofileBAK).
}
function BootLoopFix{
  IF dbglog > 0 log2file("BOOTLOOPFIX").
  desktop().
  set line to 2.
    local refreshTimer to TIME:SECONDS.
    local isdone to 0.
    sendboot().
        print  "                     IT SEEMS LIKE YOU'RE IN A BOOT LOOP.           " at (1,line).set line to line+1.
        print  "                     WOULD YOU LIKE TO DELETE AUTO FILE?            " at (1,line).set line to line+1.
        print "                                                                     " at (1,line).set line to line+1.   
        print "                                    _____                            " at (1,line).set line to line+1.
        print "                                    |- -|                            " at (1,line).set line to line+1.
        print "                                    |O|O|                            " at (1,line).set line to line+1.
        print "                                    | | |                            " at (1,line).set line to line+1.
        print "                                    | | |                            " at (1,line).set line to line+1.
        print "                                    | |_|                            " at (1,line).set line to line+1.
        print "                                    |___                             " at (1,line).set line to line+1.
        print "                                                   " at (1,line).set line to line+1.           
        print "                   SELECTING LOAD WILL PAUSE AUTO TRIGGERS           " at (1,line).set line to line+1.  
        PRINT getcolor(  "  DELETE  |   LOAD   |" ,"RED",0)at (0,heightlim).
        IF file_exists(autofileBAK) PRINT getcolor("| lOAD BKP  |") AT (42,heightlim).
      function button7{print "Settings discarded."at (1,line+1).set line to line+1. wait 1. SET isDone to 1. set loadattempts to -1. sendboot(). IF file_exists(autofile) DELETEPATH(SubDirSV +autofile). SET LOADBKP TO 0.}buttons:setdelegate(7,button7@).
      function button8{SET isDone to 1. if loadattempts > 3 {set loadattempts to -1. sendboot().} set RunAuto to 3.}buttons:setdelegate(8,button8@).
      function button10{
        set loadattempts to -1. sendboot().
        SET LOADBKP TO 2.
        SET isDone to 1.
        set refreshTimer to TIME:seconds+1000000.
        }buttons:setdelegate(10,button10@).
      until isDone > 0 {
      if loadattempts > 3 {
        print "Auto Deleting in " + ROUND((10- (TIME:SECONDS - refreshTimer)),0) + " SECONDS      " at (1,17).
        if TIME:SECONDS - refreshTimer > 10 {button7().}}
      else{
          print "                 ONE MORE CYCLE WILL TRIGGER AUTO DELETE OPTION      " at (1,4).
        print "Selecting No and Resetting Monitor Selection in" + ROUND((10- (TIME:SECONDS - refreshTimer)),0) + " SECONDS      " at (1,17).
        if TIME:SECONDS - refreshTimer > 10 {set monitorselected to 0. setmonvis().button8().}
      }
      }
    }
function file_exists{
  parameter fileName is " ".
  cd(proot).
  IF NOT exists(SubDirSV) CREATEDIR(SubDirSV).
  if filename <> "" {
      cd(SubDirSV).
      local fileList is list().
      local found is false.
      list files in fileList.
      for file in fileList {if file = fileName set found to true.}
      if dbglog > 0 log2file("    FILE EXIST?: "+fileName + ": "+found).
    return found.
  }
}
function partcheck{
  local loadp to 27. if colorprint > 0{ set loadp to loadp+9. PRINT " " AT (80,LNstp-1).}
  local parameter opt is 1.
  LOCAL GR TO 0. 
   set checktime to time:seconds.
   if CheckPartLists() = 1 set gr to 1. ELSE set  PrtListcur to SetPartList(ship:ALLTAGGEDPARTS(),1).
     if DbgLog > 0 log2file("PARTCHECK:"+opt).
      for i in range (1,itemlist[0]+1){
        local ItemName to ITEMLIST[I]:tostring..
        local cnt1 to 0.
        //IF I = itemlist[0]+1 BREAK.
        if DbgLog > 2 log2file("    Item:"+I ).
       if opt > 1 { set loadp to loadp+1. print "." at (loadp,LNstp-1).}
        for t in range (1,prtTAGList[I][0]+1){
            IF OPT = 1 IF I = FLYTAG OR I = AGTAG or (i = CMDTag and t > cmdln) BREAK.
            local TgName to PRTTAGLIST[I][T]:tostring.
          //IF t = prtTAGList[I][0]+1 BREAK.
          set cnt to 0.
          if DbgLog > 2 log2file("        Tag:"+T ).
          for p in range (1,prtList[I][T][0]+1){
            if badpart(prtList[I][T][P], prtTagList[i][t]) set prtList[I][T][P] to core:part.
            LOCAL ChkPart to prtList[I][T][P]:tostring.
            if DbgLog > 2 log2file("          Part:"+P ).
            if prtList[I][T]:length < p+1 prtList[I][T]:add(CORE:PART).
            //IF p = prtList[I][T][0]+1 BREAK.
            local validpart to 1.
            if i <> agtag and i <> flyTag and not (i = CMDTag and t > cmdln){
              if prtList[I][T][P]:typename = "String" {set validpart to 0. 
                if DbgLog > 0 and not lostparts:contains(ChkPart+"-"+CNT) {log2file("        "+ItemName+":"+TgName+" REMOVED - IS STRING" ). 
                lostparts:add(ChkPart+"-"+CNT).}
              }else{
              IF prtList[I][T][P]:TAG = ""{set validpart to 0.
                set prtList[I][T][P] to CORE:PART.
                if DbgLog > 0 and not lostparts:contains(ChkPart+"-"+CNT) log2file("       "+ItemName+":"+TgName+" REMOVED - PART GONE" ).
                lostparts:add(ChkPart+"-"+CNT).
              }ELSE{
              if ChkPart = core:part:tostring {
                if not ChkPart:contains("tag="+TgName) {set validpart to 0.
                  if DbgLog > 0 and not lostparts:contains(ChkPart+"-"+CNT) log2file("        "+ItemName+":"+TgName+" REMOVED - NOT FOUND" ) .
                  lostparts:add(ChkPart+"-"+CNT).
                  }
                }
              }}}
            IF dbglog > 1{log2file("   "+ItemName+"("+i+")"+TgName+"("+t+")"+PRTLIST[i][t][p]+"("+p+")-"+validpart ).}
            if CheckPartLists() = 1 set gr to 1.
            IF prtList[I][T][P]:TAG = "" {set prtList[I][T][P] to CORE:PART. set ChkPart to CORE:PART. set gr to 1. set validpart to 0.}
            if validpart = 1 and ship:alltaggedparts():tostring:contains(ChkPart){
              set cnt1 to 1.
              if opt > 1 {

                if t > autoTRGList[0][I]:length-1 {
                  if DbgLog > 2 log2file(i+"-"+t+"-"+p).
                  until autoTRGList[0][I]:length-1 > t autoTRGList[0][I]:add(0). //workaround, never found the bugm but it works now
                }
                
                if autoTRGList[0][I][T] < 0{
                  if DbgLog > 0 log2file("     "+ItemName+":"+TgName+" SET TO RUN").
                  set AutoDspList[I][T] to abs(AutoDspList[I][T]).
                  set autoTRGList[0][I][T] to 0.
                }
              }
            }
            else{
              set gr to 1.
              IF prtList[I][T][P]:TAG = "" {set prtList[I][T][P] to CORE:PART.}
              ELSE{
                if ChkPart <> CORE:PART:tostring.{
                    if not lostparts:contains(ChkPart+"-"+CNT) and validpart = 1{
                      set validpart to 0.
                      if DbgLog > 0  log2file("        "+ItemName+":"+TgName+" REMOVED - NO TAG ="+TgName:tostring ).
                      lostparts:add(prtList[I][T][P]:tostring+"-"+CNT).
                    }
                }
              }
              set cnt to cnt+1.
              set prtList[I][T][P] to CORE:PART.
            }
            if i = agtag OR i = flyTag or (i = CMDTag and t > cmdln) SET CNT TO 0.
            LOCAL PCNT TO prtList[I][T][0].
            IF PCNT:typename = "String" SET PCNT TO PCNT:TONUMBER.
            SET PCNT TO PCNT-1.
            if cnt > PCNT and autoTRGList[0][I][T] > -1{
              set gr to 1.
              if DbgLog > 0 log2file("          TAG:"+ItemName+":"+TgName+" SET TO SKIP").
              set autoTRGList[0][I][T] to 0-abs(AutoDspList[I][T])-1.
              set AutoDspList[I][T] to 0-abs(AutoDspList[I][T]).
            }
          }
      }
      if i = agtag OR i = flyTag or (i = CMDTag) SET CNT1 TO 1.
      if cnt1 = 0 and AutoRscList[0][I] <> 2{
         if DbgLog > 0 log2file("           ITEM:"+ItemName+" SET TO SKIP").
        SET AutoRscList[0][I] to 0.
        }

      if opt > 1 and cnt1 = 1 and AutoRscList[0][I] = 0 {
         if DbgLog > 0 log2file("           ITEM:"+ItemName+" SET TO RUN").
        SET AutoRscList[0][I] to 1.
        }
    }
    if gr=1 {
      local rscl to getRSCList(ship:resources,1).
      set rsclist to rscl[0].
      set RscNum to rscl[1].
      set rsclist2 to rscl[2].
    }
}
function addlist{ //delete me when done with old files
IF dbglog > 0 log2file("ADDLIST****************").
  for i in range(1,itemlist[0]+1){
  AutoDspList[0]:add(list(0)).
    for t in range(1,prtTAGList[I][0]+1){
      AutoDspList[0][I]:add(list(0)).
      WAIT 0.001.
    }
  }
  if AutoValList[0][0]:length = 1 AutoValList[0][0]:add(list(3,0,0,0,0,0,0)).
  if AutoValList[0][0]:length = 2 AutoValList[0][0]:add(HEIGHT).
  if AutoValList[0][0]:length = 3 AutoValList[0][0]:add(LIST(15,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1)).
  if AutoValList[0][0]:length = 4 AutoValList[0][0]:add(LIST(refreshRateSlow,refreshRateFast,debug,dbglog,HLon,SPEEDSET[0],SPEEDSET[1],SPEEDSET[1],SPEEDSET[1],0,0,0,0,0,0,0,0,0,0,0,0)).
  return.
}
Function CheckPartLists{
  local pf to 0.
  if alltagged:length <> ship:ALLTAGGEDPARTS():length {
  fixpl(). 
  set pf to 1.
  if dbglog > 0 log2file("    ALLTAGGED list off - FIXING").
  }
  return pf.
}
function fixpl{
  if DbgLog > 2 log2file("       FIXPL" ).
  set PrtListcur to SetPartList(ship:ALLTAGGEDPARTS(),1). 
  set alltagged to ship:ALLTAGGEDPARTS(). 
}
function CheckAttached{
  local parameter lin1, opt is 0.
  if not (defined prtlistcur) return lin1.
  if DbgLog > 2 log2file("       CHECKATTACHED"+listtostring(lin1)).
  for check in range (0,lin1:length) {
    if opt = 0 {
      IF lin1[check]:hassuffix("tag"){if lin1[check]:TAG = "" SET lin1[check] TO CORE:PART.} else SET lin1[check] TO CORE:PART.
      IF lin1[check]:hassuffix("ALLTAGGEDPARTS"){IF lin1[check]:ALLTAGGEDPARTS:LENGTH < 1 SET lin1[check] TO CORE:PART.} else SET lin1[check] TO CORE:PART.
    }else{
      IF not lin1[check]:hassuffix("tag") SET lin1[check] TO CORE:PART.
    }
  }
  return lin1.
}
function BadPart{ //checks if tags are equal and that a tag exists
  local parameter Pin, TagTarg is "".
  IF Pin:hassuffix("tag"){if tagtarg <> "" {if pin:tag <> tagTarg return True.}if Pin:TAG = "" Return True.}else Return True.
  IF Pin:hassuffix("ALLTAGGEDPARTS"){IF Pin:ALLTAGGEDPARTS:LENGTH < 1 Return True.} else Return True.
  return False.
}
function TrimModules{
  local parameter lstin, TmPrt is ship, tmopt is 0.
  if DbgLog > 2 log2file("       TrimModules:"+LISTTOSTRING(lstin)).
  local lstout to lstin:copy.
    for m in lstin{if TmPrt:modulesnamed(m):length = 0 lstout:remove(lstout:find(m)).}
  if DbgLog > 2 log2file("    TrimmedModules:"+LISTTOSTRING(lstout)).
  if lstout:length = 0 and tmopt = 1 set lstout to list(0).
  return lstout:copy.
}
function TrimFields{
  local parameter tmpl, modulesin, itemnum is hsel[2][1],tagnum is hsel[2][2], BotFields is list().
  local mde to 0.
  local fnd to 0.
  if ModulesIn:LENGTH = 1 AND ModulesIn[0]:contains("/") set modulesin to splitlist(ModulesIn[0]).
  if not tmpl[0]:typename:contains("list") {set tmpl to list(tmpl). set mde to 1.}
  for i in tmpl[0] if i <> "" {set fnd to 1. break.}
  if fnd = 1 {
    if DbgLog > 2 log2file("       TrimFields:"+LISTTOSTRING(tmpl[0])+" Modules:"+LISTTOSTRING(modulesin)+" MODE:"+mde).
    local fndlist to lexicon().
    local FL to tmpl[0]:copy.
    if mde = 0 and itemnum <> -1 set FL to FL:sublist(1, FL:length).
    if itemnum = -1 set itemnum to HSel[2][1].
    for f in FL fndlist:add(f,0).
    local cnt to 0.
    local botlstAlt to FL:copy.
      if BotFields:length > 0 and mde = 1{local cnt to 0. if DbgLog > 2 log2file("       KeepFieldsinBBB:").
        for j in BotFields{if DbgLog > 2 log2file("       KeepFieldsinCCC:").
          if j[0]:tonumber < mtrcur[5]+1 {if DbgLog > 2 log2file("       KeepFieldsinDDD:").
            set botlstAlt to BotFields[cnt]:copy:sublist(1,BotFields[cnt]:length).
            //if DbgLog > 2 log2file("       KeepFieldsin:"+LISTTOSTRING(BotFields[cnt]:copy:sublist(1,BotFields[cnt]:length))).
          } set cnt to cnt+1.}
      }
        if DbgLog > 2 log2file("       KeepFields:"+LISTTOSTRING(botlstAlt)).
    for m in ModulesIn{//if DbgLog > 2 log2file("            MODULE:"+M).
      for p in range (0,PrtList[itemnum][tagnum][0]) {
        local pt to PrtList[itemnum][tagnum][p+1]. //if DbgLog > 2 log2file("             part("+p+"):"+PT).
          if  pt:hasmodule(m){   //if DbgLog > 2 log2file("               HASMOD:"+m).
          for f in FL{if cnt = fl:length break. 
            LOCAL F2 TO  F:TOSTRING:REPLACE("\","/"). //if DbgLog > 2 log2file("                  FIND-NAME:"+F+" - NAMECLEAN-"+F2).
            if fndlist[F] = 0 {
              if pt:getmodule(m):ALLFIELDNAMES:contains(F2) {//if DbgLog > 2 log2file("                   FOUND:"+F2+"-ALLFIELDNAMES").
                if botlstAlt:contains(f){//if DbgLog > 2 log2file("                   FOUND:"+F+"-BOTLISTALT").
                  set fndlist[F] to 1. 
                  set cnt to cnt+1.}
                }
            }
          }
        }
      }
    }
    for k in FL{
      if fndlist[k] = 0 {
        if tmpl[0]:find(k) > -1 {
        LOCAL FNDA to tmpl[0]:find(k).
        local lng to tmpl:length.
        local skp to 0.
        IF DBGLOG > 2 log2file("        FNDA:"+K+" = "+FNDA+"  LENGTH:"+LNG+" ALTFND:"+tmpl[0]:find(k)).
          if tmpl:length > 1 IF tmpl[1][FNDA]:contains("/"){local tmpspl to tmpl[1][FNDA]:split("/").if tmpspl[tmpspl:length-1] = "-2" set skp to 1.}
            if skp = 0{
              for j in range(0,max(1,lng)){ 
                if tmpl[j]:length > max(1-mde,FNDA-1) {
                  IF DBGLOG > 2 log2file("          J:"+J+" "+tmpl[j][FNDA]+" REMOVED").
                  tmpl[j]:remove(FNDA).
                }
              }
            }
        }
      }
    }
  }
  if DbgLog > 2 log2file("    TrimmedFields:"+LISTTOSTRING(tmpl[0])).
  if mde = 0 return tmpl:copy. else return tmpl[0]:copy.
}
function TrimModules2{
  local parameter lstin, itemnum is hsel[2][1],tagnum is hsel[2][2]..
  if DbgLog > 2 log2file("       TrimModules2:"+LISTTOSTRING(lstin)).
  local lstout to lstin:copy.
  local listMid is list().
  for m in lstin{for p in range (0,PrtList[itemnum][tagnum][0]) {local pt to PrtList[itemnum][tagnum][p+1].if pt:hasmodule(m) {listmid:add(m).break.}}}
  for m in lstin if not listmid:contains(m) lstout:remove(lstout:find(m)).
  if DbgLog > 2 log2file("    TrimmedModules2:"+LISTTOSTRING(lstout)).
  return lstout.
}
function CleanList{
  local parameter lsin, TagNameIn.
  if dbglog > 1 log2file("        CLEANLIST:"+TagNameIn+":"+LISTTOSTRING(lsin)).
  local lsout to list().
  for itm in lsin {if itm:typename = "Part" if itm:tag = TagNameIn lsout:add(itm).} 
  return lsout.
}
Function SpeedBoost{
  local parameter onoff is "on", silent is 0.
  if ship:electriccharge < 50 SET ONOFF TO "off".
  if onoff = "on"  {set CPUSPD to SPEEDSET[1]. if silent = 0 print "*" at (widthlim,heightlim-1).}
  else {set CPUSPD to SPEEDSET[0].  if silent = 0 print " " at (widthlim,heightlim-1).} 
  set config:ipu to Speeds[1][CPUSPD].
  if BtnActn = 1   print "*" at (0,heightlim-1).
}
Function LastIn{
  local parameter amt is 0.
  if amt = 0 {Set LastInput to time:seconds. set pscnt to 0.}
  else {if amt < 0 {if round(time:seconds-lastinput,0) < abs(amt) return true. else return false.}
  else {            if round(time:seconds-lastinput,0) > abs(amt) return true. else return false.}}
    if LastIn(60) {
        PRINTQ:PUSH(" POWER SAVE MODE DEACTIVATED"+"<sp>"+"WHT"). 
        set CPUSPD to SPEEDSET[0].
    }
}
//#endregion
//#region Borrowed 
function setmonvis{
  if dbglog > 0  log2file("SETMONITOR").
  LOCAL refreshTimer to TIME:SECONDS-2.
  //Initialize local variables
  local isDone to 0.
  local ch to "".
  local totalMonitors to addons:kpm:getmonitorcount().
 
  function selectedMonitor
  {
    local parameter index.
    set buttons:currentmonitor to index.
    set id to addons:kpm:getguidshort(index).
    set monitorGUID to addons:kpm:getguidshort(index).
    set monitorselected to 1.
  }
  //Main loop
  function setmonvismain{
    //buttons:setdelegate(7,button7@).
    local function button13{set isDone to 1. SET MONITORID TO monitorGUID.}
    local function button11{set isDone to 1. SET MONITORID TO "0000000"+ monitorIndex.}
        //buttons:setdelegate(13,button13@).
    CLEARSCREEN.
    ///print UI layout
    print "          |          |   SELECT MONITOR    |          |          |XXXXXXXXXX|" at (0,0).
    print "|          |          |          |          |FORCE NUM |          |  SELECT  |" at (0,20).
    print "TOTAL MONITORS: " + totalMonitors AT (2,1).
    print "INSTRUCTIONS: ALLOW PROGRAM TO CYCLE THROUGH MONITORS, CLICK SELECY"AT (1,5). 
    print "WHEN THE CORRECT MONITOR IS SELECTED THE PROGRAM WILL PROCEED. "AT (1,6).
    print "YOU CAN USE NUMPAD 4 AND 6 TO MANUALLY CYCLE IF KOS WINDOW IS OPEN. "AT (1,7).
    print "SELECT FORCE NUM TO FORCE THIS SHIP TO ALWAYS USE THIS MONITOR NUMBER." AT (1,8).
    IF FORCEMON > 0 print "AUTOSELECT SET TO MONITOR "+(ForceMon-1) AT (1,12).
    //Sub loop
    UNTIL isDone > 0 
    { 
      IF MonAutoCyc = 1 {
        print "CYCLING TO NEXT MONITOR IN " + ROUND((3- (TIME:SECONDS - refreshTimer)),0) + " SECONDS      " at (1,17).

      if TIME:SECONDS - refreshTimer > 3 or forcemon > 0{
             if forcemon > 0  or totalMonitors = 1{
            if monitorIndex = forcemon-1 or totalMonitors = 1{
              if totalMonitors = 1 set monitorindex to 0.
              set monitorGUID to addons:kpm:getguidshort(monitorIndex). 
              set buttons:currentmonitor to monitorIndex.
              set id to addons:kpm:getguidshort(monitorIndex).
              set monitorselected to 1. 
              PRINT "MONITOR FORCED TO MON "+monitorIndex. break.
            }}
    if totalMonitors = 0{clearscreen. 
    print "CLICK STBY TWICE TO CYCLE SCRIPT." AT (1,1). 
    print "CLICK STBY TWICE TO CYCLE SCRIPT." AT (1,2). 
    print "CLICK STBY TWICE TO CYCLE SCRIPT." AT (1,3).
    print "   CLICK THIS BUTTON TWICE!!!!." AT (1,15). print "<-----------------------" AT (1,16).}
        SET refreshTimer to TIME:SECONDS.
        if monitorIndex < totalMonitors-1{
        set monitorIndex to monitorIndex + 1.
        selectedMonitor(monitorIndex).
        buttons:setdelegate(11,button11@).
        buttons:setdelegate(13,button13@).
        print "              " AT (32,17).
        }else{set monitorIndex to 0.}
      }
      }
      print "CURRENT MONITOR: " + monitorIndex + "     " AT (2,2).
      print "MONITOR ID: " + id+"    " AT (2,3).
      //Numpad listener
      if terminal:input:haschar{set ch to terminal:input:getchar().}
      if ch = "8"{SET ch to "".}
      if ch = "2"{SET ch to "".}
      if ch = "4"{ SET refreshTimer to TIME:SECONDS.
        set MonAutoCyc to 0.
        if monitorIndex > 0{
          set monitorIndex to monitorIndex - 1.
          selectedMonitor(monitorIndex).
          print "              " AT (32,17).
        }
         print "AUTO CYCLE CANCELED                              " at (0,4).
        SET ch to "".
      }
      if ch = "6"{ SET refreshTimer to TIME:SECONDS.
        set MonAutoCyc to 0.
        if monitorIndex < totalMonitors-1{
          set monitorIndex to monitorIndex + 1.
          selectedMonitor(monitorIndex).
          print "              " AT (32,17).
        }
         print "AUTO CYCLE CANCELED                              " at (0,4).
        SET ch to "".
      }
      wait 0.001.
    }
  clearscreen.
  }
  setmonvismain().
}  
function east_for {
  parameter ves is ship.

  return vcrs(ves:up:vector, ves:north:vector).
}
function compass_for {
  parameter ves is ship,thing is "default".
  local pointing is ves:facing:forevector.
  if not thing:istype("string") {
    set pointing to type_to_vector(ves,thing).
  }
  local east is east_for(ves).
  local trig_x is vdot(ves:north:vector, pointing).
  local trig_y is vdot(east, pointing).
  local result is arctan2(trig_y, trig_x).
  if result < 0 {
    return 360 + result.
  } else {
    return result.
  }
}
function pitch_for {
  parameter ves is ship,thing is "default".
  local pointing is ves:facing:forevector.
  if not thing:istype("string") {
    set pointing to type_to_vector(ves,thing).
  }
  return 90 - vang(ves:up:vector, pointing).
}
function roll_for {
  parameter ves is ship,thing is "default".

  local pointing is ves:facing.
  if not thing:istype("string") {
    if thing:istype("vessel") or pointing:istype("part") {
      set pointing to thing:facing.
    } else if thing:istype("direction") {
      set pointing to thing.
    } else {
      print "type: " + thing:typename + " is not reconized by roll_for".
	}
  }
  local trig_x is vdot(pointing:topvector,ves:up:vector).
  if abs(trig_x) < 0.0035 {//this is the dead zone for roll when within 0.2 degrees of vertical
    return 0.
  } else {
    local vec_y is vcrs(ves:up:vector,ves:facing:forevector).
    local trig_y is vdot(pointing:topvector,vec_y).
    return arctan2(trig_y,trig_x).
  }
}
function compass_and_pitch_for {
  parameter ves is ship,thing is "default".
  local pointing is ves:facing:forevector.
  if not thing:istype("string") {
    set pointing to type_to_vector(ves,thing).
  }
  local east is east_for(ves).
  local trig_x is vdot(ves:north:vector, pointing).
  local trig_y is vdot(east, pointing).
  local trig_z is vdot(ves:up:vector, pointing).
  local compass is arctan2(trig_y, trig_x).
  if compass < 0 {
    set compass to 360 + compass.
  }
  local pitch is arctan2(trig_z, sqrt(trig_x^2 + trig_y^2)).
  return list(compass,pitch).
}
function bearing_between {
  parameter ves,thing_1,thing_2.
  local vec_1 is type_to_vector(ves,thing_1).
  local vec_2 is type_to_vector(ves,thing_2).
  local fake_north is vxcl(ves:up:vector, vec_1).
  local fake_east is vcrs(ves:up:vector, fake_north).
  local trig_x is vdot(fake_north, vec_2).
  local trig_y is vdot(fake_east, vec_2).
  return arctan2(trig_y, trig_x).
}
function type_to_vector {
  parameter ves,thing.
  if thing:istype("vector") {
    return thing:normalized.
  } else if thing:istype("direction") {
    return thing:forevector.
  } else if thing:istype("vessel") or thing:istype("part") {
    return thing:facing:forevector.
  } else if thing:istype("geoposition") or thing:istype("waypoint") {
    return (thing:position - ves:position):normalized.
  } else {
    print "type: " + thing:typename + " is not recognized by lib_navball".
  }
}
FUNCTION vertical_aoa {
  LOCAL srfVel IS VXCL(SHIP:FACING:STARVECTOR,SHIP:VELOCITY:SURFACE).//surface velocity excluding any yaw component 
  RETURN VANG(SHIP:FACING:FOREVECTOR,srfVel).
}
//#endregion 