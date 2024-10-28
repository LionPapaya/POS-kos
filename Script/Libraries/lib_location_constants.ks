



if not (defined location_constants) {
global location_constants is lex().
//runways should be added in this pattern "name_runway_##_start" where name is the name of the runway and ## is the runway number
//  If not added with this pattern then the automatic alias creation that add an end position based on the start of the same name but opposite number will fail


  local kerbinLocations is lex().
  // vertical landing locations
  kerbinLocations:add("launchpad", Kerbin:GeoPositionLatLng(-0.0972, -74.5577)).
  kerbinLocations:add("woomerang_launchpad", Kerbin:GeoPositionLatLng(45.2896, 136.1100)).
  kerbinLocations:add("desert_launchpad", Kerbin:GeoPositionLatLng(-6.5604, -143.9500)).
  kerbinLocations:add("VAB", Kerbin:GeoPositionLatLng(-0.0968, -74.6187)).
  location_constants:add("launchpad",kerbinLocations["launchpad"]).
  
  // horizontal landing locations
  kerbinLocations:add("KSC_runway_09_start", Kerbin:GeoPositionLatLng(-0.0486, -74.7247)).
  kerbinLocations:add("KSC_runway_09_overrun", Kerbin:GeoPositionLatLng(-0.0502, -74.4880)).  // runway "lip"
  kerbinLocations:add("KSC_runway_27_start", Kerbin:GeoPositionLatLng(-0.0502, -74.4925)).
  kerbinLocations:add("KSC_runway_27_overrun", Kerbin:GeoPositionLatLng(-0.0486, -74.7292)).  // runway "lip"
  kerbinLocations:add("l1_runway_09_start", Kerbin:GeoPositionLatLng(-.0489, -74.7101)).
  kerbinLocations:add("l1_runway_27_start", Kerbin:GeoPositionLatLng(-.0501, -74.5076)).
  kerbinLocations:add("l2_runway_09_start", Kerbin:GeoPositionLatLng(-.0486, -74.7134)).
  kerbinLocations:add("l2_runway_27_start", Kerbin:GeoPositionLatLng(-.0501, -74.5046)).
  kerbinLocations:add("Island_runway_09_start", Kerbin:GeoPositionLatLng(-1.5177, -71.9663)).
  kerbinLocations:add("Island_runway_27_start", Kerbin:GeoPositionLatLng(-1.5158, -71.8524)).
  kerbinLocations:add("Desert_runway_36_start", Kerbin:GeoPositionLatLng(-6.5998, -144.0409)).
  kerbinLocations:add("Desert_runway_18_start", Kerbin:GeoPositionLatLng(-6.4480, -144.0383)).
  kerbinLocations:add("Kojave-Sands_runway_04_start", Kerbin:geoPositionLAtLNG(5.96055511995133,-142.048184851691)).
  kerbinLocations:add("Kojave-Sands_runway_22_start", Kerbin:geoPositionLAtLNG(6.13297199391895,-141.913140218446)).
  kerbinLocations:add("Baikerbanur_runway_20_start", Kerbin:geoPositionLAtLNG(20.7129411302474,-146.475570851677)).
  kerbinLocations:add("Baikerbanur_runway_02_start", Kerbin:geoPositionLAtLNG(20.5047599225538,-146.546210825324)).
  kerbinLocations:add("Cape-Kerman_runway_33_start", Kerbin:geoPositionLAtLNG(24.8077321335363,-83.5669468911677)).
  kerbinLocations:add("Cape-Kerman_runway_15_start", Kerbin:geoPositionLAtLNG(24.9978909306997,-83.6861313634586)).
  kerbinLocations:add("Dununda_runway_21_start", Kerbin:geoPositionLAtLNG(-39.1959886871935, 116.303999722604)).
  kerbinLocations:add("Dununda_runway_03_start", Kerbin:geoPositionLAtLNG(-39.3940560932776, 116.17813674687)).
  kerbinLocations:add("Dununda_runway_27_start", Kerbin:geoPositionLAtLNG(-39.2912535835613, 116.375425444008)).
  kerbinLocations:add("Dununda_runway_09_start", Kerbin:geoPositionLAtLNG(-39.3049817841375, 116.105341365992)).
  kerbinLocations:add("Harvester_runway_26_start", Kerbin:geoPositionLAtLNG(-56.2821299654509, -10.8448390484342)).
  kerbinLocations:add("Harvester_runway_08_start", Kerbin:geoPositionLAtLNG(-56.309919605645, -11.1032383377186)).
  kerbinLocations:add("Hazard-Shallows_runway_23_start", Kerbin:geoPositionLAtLNG(-14.1780591155857, 155.301172358917)).
  kerbinLocations:add("Hazard-Shallows_runway_05_start", Kerbin:geoPositionLAtLNG(-14.2700919376955, 155.186515015969)).
  kerbinLocations:add("Jeb's-Junkyard_runway_01_start", Kerbin:geoPositionLAtLNG(6.85751395894117, -77.9588823468625)).
  kerbinLocations:add("Jeb's-Junkyard_runway_19_start", Kerbin:geoPositionLAtLNG(7.0554447635484, -77.9163323110796)).
  kerbinLocations:add("Kamberwick_runway_09_start", Kerbin:geoPositionLAtLNG(36.186783241262, 10.4611772649255)).
  kerbinLocations:add("Kamberwick_runway_27_start", Kerbin:geoPositionLAtLNG(36.1765084856458, 10.7404816156671)).
  kerbinLocations:add("Kerman-Atol_runway_29_start", Kerbin:geoPositionLAtLNG(-37.1128441534325, -70.8707212408829)).
  kerbinLocations:add("Kerman-Atol_runway_11_start", Kerbin:geoPositionLAtLNG(-37.0330929424495, -71.1315440759166)).
  kerbinLocations:add("Kola-Island_runway_02_start", Kerbin:geoPositionLAtLNG(-4.26920083013744, -72.1405286976817)).
  kerbinLocations:add("Kola-Island_runway_20_start", Kerbin:geoPositionLAtLNG(-4.058894604671154, -72.0806758868211)).
  kerbinLocations:add("Kermundsen_runway_01_start", Kerbin:geoPositionLAtLNG(-89.945805346582, 178.119572412765)).
  kerbinLocations:add("Kermundsen_runway_19_start", Kerbin:geoPositionLAtLNG(-89.8014181680094, -169.702226981836)).
  kerbinLocations:add("South-Field_runway_09_start", Kerbin:geoPositionLAtLNG(-47.0036691936948, -141.141419827073)).
  kerbinLocations:add("South-Field_runway_27_start", Kerbin:geoPositionLAtLNG(-47.0036691936948, -141.141419827073)).
  kerbinLocations:add("South-Lake_runway_25_start", Kerbin:geoPositionLAtLNG(-37.2472859973442, 52.6979769920877)).
  kerbinLocations:add("South-Lake_runway_07_start", Kerbin:geoPositionLAtLNG(-37.3184999102752, 52.4282807905092)).
  kerbinLocations:add("Area-15_runway_31_start", Kerbin:geoPositionLAtLNG(-60.6101231793587, 39.3817317024422)).
  kerbinLocations:add("Area-15_runway_13_start", Kerbin:geoPositionLAtLNG(-60.4656073371585, 39.0415304340361)).
  kerbinLocations:add("Uberdam_runway_04_start", Kerbin:geoPositionLAtLNG(38.4211711999107, -149.723741149902)).
  kerbinLocations:add("Uberdam_runway_22_start", Kerbin:geoPositionLAtLNG(38.5854595439214, -149.543490452891)).
  kerbinLocations:add("Meeda_runway_07_start", Kerbin:geoPositionLAtLNG(37.8366950123253, -109.982111417793)).
  kerbinLocations:add("Meeda_runway_25_start", Kerbin:geoPositionLAtLNG(37.8999298290764, -109.711909570404)).
  kerbinLocations:add("Meeda_runway_13_start", Kerbin:geoPositionLAtLNG(37.9476550998298, -109.948497118295)).
  kerbinLocations:add("Meeda_runway_31_start", Kerbin:geoPositionLAtLNG(37.7948455172056, -109.744760875005)).
  kerbinLocations:add("Nye-Island_runway_15_start", Kerbin:geoPositionLAtLNG(5.81260579600161, 108.709305623713)).
  kerbinLocations:add("Nye-Island_runway_33_start", Kerbin:geoPositionLAtLNG(5.6884684156503, 108.78504499384)).
  kerbinLocations:add("Round-Range_runway_28_start", Kerbin:geoPositionLAtLNG(-6.02376054801774, 99.6216145281208)).
  kerbinLocations:add("Round-Range_runway_10_start", Kerbin:geoPositionLAtLNG(-5.97769566977683, 99.4090912833298)).
  kerbinLocations:add("Polar-Alpha_runway_34_start", Kerbin:geoPositionLAtLNG(72.4910583705369, -78.4586967431993)).
  kerbinLocations:add("Polar-Alpha_runway_16_start", Kerbin:geoPositionLAtLNG(72.6254040968468, -78.6475159964753)).
  kerbinLocations:add("Sandy-Island_runway_04_start", Kerbin:geoPositionLAtLNG(-8.20789409639061, -42.4532574207131)).
  kerbinLocations:add("Sandy-Island_runway_22_start", Kerbin:geoPositionLAtLNG(-8.10433048889418, -42.3514625480154)).
  
  location_constants:add("runway_start",kerbinLocations["KSC_runway_09_start"]).
  location_constants:add("reverse_runway_start",kerbinLocations["KSC_runway_27_start"]).

  location_constants:add("kerbin",kerbinLocations).

  global KerbinRunwayalt is lex().
  KerbinRunwayalt:add("KSC_runway", 72).
  KerbinRunwayalt:add("Baikerbanur_runway", 417).
  KerbinRunwayalt:add("Cape-Kerman_runway", 77).
  KerbinRunwayalt:add("Dununda_runway", 458).
  KerbinRunwayalt:add("Harvester_runway", 3956).
  KerbinRunwayalt:add("Hazard-Shallows_runway", 24).
  KerbinRunwayalt:add("Jeb's-Junkyard_runway", 761).
  KerbinRunwayalt:add("Kamerwick_runway", 623).
  KerbinRunwayalt:add("Kerman-Atol_runway", 207).
  KerbinRunwayalt:add("Kojave-Sands_runway", 766).
  KerbinRunwayalt:add("Kola-Island_runway", 28).
  KerbinRunwayalt:add("Kermundsen_runway", 35).
  KerbinRunwayalt:add("South-Field_runway", 82).
  KerbinRunwayalt:add("South-Lake_runway", 75).
  KerbinRunwayalt:add("Area-15_runway", 1371).
  KerbinRunwayalt:add("Uberdam_runway", 501).
  KerbinRunwayalt:add("Meeda_runway", 25).
  KerbinRunwayalt:add("Nye-Island_runway", 323).
  KerbinRunwayalt:add("Round-Range_runway", 1188).
  KerbinRunwayalt:add("Polar-Alpha_runway", 34).
  KerbinRunwayalt:add("Sandy-Island_runway", 25).
  KerbinRunwayalt:add("Desert_runway", 824).
  KerbinRunwayalt:add("Island_runway", 136).


  

}




// aliases
until not aliasing(location_constants) {}.

local function aliasing {
  parameter locationConstants.
  local didChange is false.
  for key in locationConstants:keys {
    local bodyLex is locationConstants[key].
    if bodyLex:istype("lexicon") {
      local bodyKeys is bodyLex:keys:copy.
      for currentKey in bodyKeys {
        if currentKey:contains("desert") {//desert to dessert aliasing
          local alias to currentKey:replace("desert", "dessert").
          if not bodyLex:haskey(alias) {
            bodyLex:add(alias,bodyLex[currentKey]).
            set didChange to true.
          }
        }

        if currentKey:matchespattern("runway_\d{1,2}_start$") {//runway_##_end aliasing
          local alias is currentKey:replace("start", "end").
          // now find the key that `alias` is an alias of
          if not bodyLex:haskey(alias) {
            local splitKey is currentKey:split("_").
            local currentNum is splitKey[splitKey:length - 2].
            local reverseNum is MOD(currentNum:toscalar(0) + 18,36):tostring.
            if reverseNum = "0" { set reverseNum to "36". }
            local reverseStr is currentKey:replace(currentNum,reverseNum).
            if not bodyLex:haskey(reverseStr) {
              set reverseStr to currentKey:replace(currentNum,"0" + reverseNum).
            }
            if bodyLex:haskey(reverseStr) {
              bodyLex:add(alias,bodyLex[reverseStr]).
              set didChange to true.
            }
          }
        }
      }
    }
  }
  return didChange.
}
