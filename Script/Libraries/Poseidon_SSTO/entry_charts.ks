// Passive, one-time chart selection. Never simulate a trajectory or issue controls.
RUNONCEPATH("0:/Libraries/Poseidon_SSTO/entry_chart_catalog.ks").

function entry_chart_extent {
    parameter samples, energy_min, energy_max.
    local result is lex("valid",false,"range_min",999999999,"range_max",0).
    // Intersect every segment with the energy band, including page boundaries
    // between the sparse prediction samples. No extrapolation past the trace.
    for sample_index in range(1,samples:length) {
        local point0 is samples[sample_index-1].
        local point1 is samples[sample_index].
        local e0 is point0["energy"]. local e1 is point1["energy"].
        local lower_energy is max(energy_min,min(e0,e1)).
        local upper_energy is min(energy_max,max(e0,e1)).
        if lower_energy <= upper_energy {
            for probe_energy in list(lower_energy,upper_energy) {
                local fraction is 0.
                if abs(e1-e0) > 0.001 { set fraction to (probe_energy-e0)/(e1-e0). }
                local probe_range is point0["range"]+fraction*(point1["range"]-point0["range"]).
                set result["range_min"] to min(result["range_min"],probe_range).
                set result["range_max"] to max(result["range_max"],probe_range).
                if abs(e1-e0) <= 0.001 {
                    set result["range_min"] to min(result["range_min"],point1["range"]).
                    set result["range_max"] to max(result["range_max"],point1["range"]).
                }
                set result["valid"] to true.
            }
        }
    }
    return result.
}

function entry_chart_choose {
    parameter choices, energy_min, energy_max, range_min, range_max.
    local selected is choices[choices:length-1].
    local best_area is 999999999999999.
    local fits is false.
    for candidate in choices {
        if candidate["energy_min"] <= energy_min and candidate["energy_max"] >= energy_max and
           candidate["range_min"] <= range_min and candidate["range_max"] >= range_max {
            local area is (candidate["energy_max"]-candidate["energy_min"])*
                (candidate["range_max"]-candidate["range_min"]).
            if area < best_area {
                set selected to candidate. set best_area to area. set fits to true.
            }
        }
    }
    local result is selected:copy.
    set result["fits"] to fits.
    return result.
}

function entry_chart_select {
    parameter samples, current_energy, current_range.
    local selected_pages is list().
    local first_ceiling is max(290000,current_energy+10000).
    if samples:length > 0 { set first_ceiling to max(first_ceiling,samples[0]["energy"]+10000). }
    local boundaries is list(list(260000,first_ceiling),
        list(210000,260000),list(170000,210000),list(140000,170000),list(0,140000)).
    local fallback_ranges is list(1100000,800000,600000,300000,180000).
    for page_index in range(0,5) {
        local limits is boundaries[page_index].
        local extent is entry_chart_extent(samples,limits[0],limits[1]).
        local lower_range is 0. local upper_range is fallback_ranges[page_index].
        if extent["valid"] {
            local padding is max(10000,(extent["range_max"]-extent["range_min"])*0.1).
            set lower_range to max(0,extent["range_min"]-padding).
            set upper_range to extent["range_max"]+padding.
            // A trace ending inside a page cannot describe the rest of that
            // page. Retain zero range for its unpredicted tail.
            if samples[samples:length-1]["energy"] > limits[0] { set lower_range to 0. }
        }
        if current_energy >= limits[0] and current_energy <= limits[1] {
            set lower_range to min(lower_range,max(0,current_range-10000)).
            set upper_range to max(upper_range,current_range+10000).
        }
        selected_pages:add(entry_chart_choose(entry_chart_catalog[page_index],
            limits[0],limits[1],lower_range,upper_range)).
    }
    return selected_pages.
}
