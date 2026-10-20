// Libraries/lib_navigation.ks
// Purpose: navigation helpers for geopositions, HAC creation, TEAM interface and approach calculations.
// - Spherical trig helpers for building approach waypoints and HAC entries.
// - Functions here are used by the entry guidance and team guidance code.
// Notes: comments only.
function navigation_longitude_delta {
    parameter delta_deg.
    until delta_deg >= -180 and delta_deg <= 180 {
        if delta_deg > 180 { set delta_deg to delta_deg-360. }
        if delta_deg < -180 { set delta_deg to delta_deg+360. }
    }
    return delta_deg.
}

// kOS trigonometry consumes and returns degrees. Convert only the physical
// arc length/radius ratio, which is measured in radians.
function get_geoposition_along_heading {
    parameter starting_LATLNG, vec_heading, distance.
    local angular_deg is distance / SHIP:BODY:RADIUS * constant:radtodeg.
    local start_lat is starting_LATLNG:lat.
    local new_lat is arcsin(max(-1,min(1,
        sin(start_lat)*cos(angular_deg)+cos(start_lat)*sin(angular_deg)*cos(vec_heading)))).
    local longitude_offset is arctan2(
        sin(vec_heading)*sin(angular_deg)*cos(start_lat),
        cos(angular_deg)-sin(start_lat)*sin(new_lat)).
    return latlng(new_lat,navigation_longitude_delta(starting_LATLNG:lng+longitude_offset)).
}

// Function to calculate geoposition on a circular heading
function get_geoposition_on_circle {
    declare parameter center_LATLNG, radius,circle_direction, circle_heading.


     if circle_heading > 360 {
        set circle_heading  to circle_heading  - 360.
    } 
    if circle_heading  < 0 {
        set circle_heading  to circle_heading  + 360.
    }
    if circle_direction = "clockwise" {
        set circle_heading  to circle_heading  - 90.
    } else {
        set circle_heading  to circle_heading  + 90.
    }
    return get_geoposition_along_heading(center_LATLNG, circle_heading, radius).
}

function calcdistance {
    parameter geopos1, geopos2.
    return calcdistance_m(geopos1,geopos2)/1000.
}

function calcdistance_m {
    parameter geopos1, geopos2.
    local delta_lat is geopos2:lat-geopos1:lat.
    local delta_lng is navigation_longitude_delta(geopos2:lng-geopos1:lng).
    local haversine is max(0,min(1,
        sin(delta_lat/2)^2+cos(geopos1:lat)*cos(geopos2:lat)*sin(delta_lng/2)^2)).
    local central_angle_deg is 2*arctan2(sqrt(haversine),sqrt(1-haversine)).
    return SHIP:BODY:RADIUS * central_angle_deg * constant:degtorad.
}

function heading_between {
    parameter current_position, target_position.
    local delta_lng is navigation_longitude_delta(target_position:lng-current_position:lng).
    if abs(target_position:lat-current_position:lat) < 0.000000001 and abs(delta_lng) < 0.000000001 { return 0. }
    local bearing_y is sin(delta_lng)*cos(target_position:lat).
    local bearing_x is cos(current_position:lat)*sin(target_position:lat)-
        sin(current_position:lat)*cos(target_position:lat)*cos(delta_lng).
    local bearing_deg is arctan2(bearing_y,bearing_x).
    if bearing_deg < 0 { set bearing_deg to bearing_deg+360. }
    return bearing_deg.
}

// Project a runway start onto its local heading and check cross-track and
// alignment tolerances supplied by the selected craft's AVES configuration.
function takeoff_runway_geometry {
    parameter runway_length_m, distance_from_start_m, start_bearing_error_deg, facing_error_deg.
    parameter geometry_config.
    local along_distance is distance_from_start_m * cos(start_bearing_error_deg).
    local cross_distance is distance_from_start_m * sin(start_bearing_error_deg).
    // A tolerated origin behind the threshold earns no extra runway.
    local remaining_distance is runway_length_m - max(0,along_distance).
    local valid is runway_length_m > 0 and along_distance >= -geometry_config["start_tolerance_m"] and
        along_distance < runway_length_m and abs(cross_distance) <= geometry_config["cross_track_tolerance_m"] and
        abs(facing_error_deg) <= geometry_config["facing_tolerance_deg"].
    return lex("valid",valid,"along_track_m",along_distance,
        "cross_track_m",cross_distance,"remaining_m",max(0,remaining_distance)).
}

function heading_to_target {
    parameter target_position.  // Target position as a vector (lat, long) in degrees.

    return heading_between(ship:geoposition, target_position).
}
function runway_start_distance_to_centerline {
    // Parameter: runway_start_start, runway_start_end, ship_position (alle als Geopositionen)
   
    

    // Berechne den Vektor der Landebahn
    local runway_start_vector is (runway_end:LATLNG - runway_start:LATLNG).

    // Berechne den Vektor vom Start der Landebahn zum Schiff
    local ship_vector is (ship:geoposition:LATLNG - runway_start:LATLNG).

    // Berechne die Projektion des Schiffsvektors auf den Landebahnvektor
    local projection_length is VDOT(ship_vector, runway_start_vector) / VDOT(runway_start_vector, runway_start_vector).
    local projection_vector is projection_length * runway_start_vector.

    // Berechne den orthogonalen Vektor (vom Schiff zur Landebahn)
    local orthogonal_vector is ship_vector - projection_vector.

    // Berechne die Distanz in Metern (Länge des orthogonalen Vektors)
    return orthogonal_vector:MAG * body:radius.  // Skaliere mit dem Planetenradius
}
function create_HAC{
    set hac_ercl to get_geoposition_along_heading(runway_start,runway_heading+180,AVES["HacDistance"]).
    set HAC to lex(
    "HAC1",
    get_geoposition_along_heading(hac_ercl,runway_heading+90,AVES["HacRadius"]),
    "HAC2",
    get_geoposition_along_heading(hac_ercl,runway_heading-90,AVES["HacRadius"])).


    set hac_ercl_alt to calculate_glideslope_alt(AVES["HacDistance"]). 
    return lex(
        "HAC1",HAC["HAC1"],
        "HAC2",HAC["HAC2"],
        "HAC_ERCL",hac_ercl,
        "HAC_ERCL_ALT",hac_ercl_alt
    ).
}
//Hac 1 is clockwise /HAc 2 is anticlockwise
function choose_hac{

    local HAC_Distance is lex(
        "Hac1",
        calcdistance(
        ship:geoposition,get_geoposition_on_circle(HAC["Hac1"],AVES["HacRadius"],"clockwise",compass_for())),
        "Hac2",
        calcdistance(
        ship:geoposition,get_geoposition_on_circle(HAC["Hac2"],AVES["HacRadius"],"anticlockwise",compass_for()))).
    if HAC_Distance["HAC1"] > HAC_Distance["HAC2"]{
        set Active_HAC_entry to get_geoposition_on_circle(HAC["Hac1"],AVES["HacRadius"],"clockwise",compass_for()).
        set Active_HAC to "HAC1".
        set HAC_Direction to "Clockwise".
    } else{
        set Active_HAC_entry to get_geoposition_on_circle(HAC["Hac2"],AVES["HacRadius"],"anticlockwise",compass_for()).
        set Active_HAC to "HAC2".
        set HAC_Direction to "Anticlockwise".
    }

    return lex(
        "Active_HAC",Active_HAC,
        "Active_HAC_entry",Active_HAC_entry,
        "HAC_Direction",HAC_Direction
    ).
}
function calculate_heading {
    parameter inclination.
    parameter latitude_.

    set sin_h to cos(inclination) / cos(latitude_).
    if abs(sin_h) > 1 {
        print "Inclination not possible from this latitude.".
        return -1.
    }

    set h to arcsin(sin_h).
    until h >= 0 and h < 360 {
        if h < 0 { set h to h + 360. }
        if h >= 360 { set h to h - 360. }
    }
    return h.
}

// Find the runway currently occupied by the aircraft by comparing the vessel
// with every runway start point.  The nearest start point identifies both the
// runway and the direction from which the aircraft is departing.
function find_active_runway {
    // Use the global `location_constants` lexicon; prefer the per-body entry if present
    local runways is location_constants.
    if runways:haskey("kerbin") { set runways to runways["kerbin"]. }
    local closest_distance is 9999999999.
    local active_heading is -1.
    local active_start is "".
    local active_end is "".
    local active_altitude is -1.
    local active_location is "".
    local active_runway_num is "".

    for runway_key in runways:keys {
        // Match keys like "<Location>_runway_##_start" (e.g. KSC_runway_09_start)
        if runway_key:endswith("_start") {
            // Split into location and the rest (e.g. ["KSC","09_start"]).
            local parts is runway_key:split("_runway_").
            local runway_location is parts[0].
            local rest is parts[1].
            local runway_num is rest:split("_")[0].

            local end_key is runway_location + "_runway_" + runway_num + "_end".
            if runways:haskey(end_key) and KerbinRunwayalt:haskey(runway_location + "_runway") {
                local start_pos is runways[runway_key].
                local end_pos is runways[end_key].
                local distance_to_start is calcdistance_m(ship:geoposition, start_pos).
                if distance_to_start < closest_distance {
                    set closest_distance to distance_to_start.
                    set active_start to start_pos.
                    set active_end to end_pos.
                    set active_heading to heading_between(start_pos, end_pos).
                    set active_location to runway_location.
                    set active_runway_num to runway_num.
                    if KerbinRunwayalt:haskey(runway_location + "_runway") {
                        set active_altitude to KerbinRunwayalt[runway_location + "_runway"].
                    }
                }
            }
        }
    }
    return lex(
        "heading", active_heading,
        "start", active_start,
        "end", active_end,
        "altitude", active_altitude,
        "location", active_location,
        "runway_num", active_runway_num,
        "distance_m", closest_distance
    ).
}
function calc_hacstate{
    parameter hac_pos.
    parameter hac_rad.
    parameter hac_heading.
    parameter ERCL_HED.
    parameter hac_side.

    //log hac_rad to log10.txt.
    //log hac_heading to log10.txt.
    //log ERCL_HED to log10.txt.
    //log hac_side to log10.txt.

    local cur_dist is calcdistance_m(ship:geoposition,hac_pos).
    local cur_vel is ship:airspeed.
    local ercl_vel is AVES["ERCLSpeed"].
    local ercl_dist is AVES["HacDistance"].


    local dist is ercl_dist +calc_circle_distance(hac_rad,abs(ERCL_HED-hac_heading)).



        local vel is lin_interpol(dist,cur_dist,cur_vel,ercl_dist,ercl_vel).

        local state is lex(
            "dist",dist,
            "vel",vel,
            "alt",calculate_glideslope_alt(dist),
            "latlng",get_geoposition_on_circle(hac_pos,hac_rad,hac_side,hac_heading)
        ).

    return state.
}
// Signed offset from the runway centerline: positive is to the right of the
// landing heading. A straight-in bearing needs no offset; a crossing arrival
// gets more room to turn before it reaches the centerline.
function team_interface_lateral_offset {
    parameter approach_bearing, rnw_heading.
    local heading_error is approach_bearing - rnw_heading.
    until abs(heading_error) <= 180 {
        if heading_error > 180 { set heading_error to heading_error - 360. }
        if heading_error < -180 { set heading_error to heading_error + 360. }
    }
    local blend is max(0,min(1,(abs(heading_error)-20)/80)).
    local offset is 100000 * (3*blend^2 - 2*blend^3).
    if heading_error > 0 { return -offset. }
    return offset.
}

function define_TEAM_interface {
    parameter rnw_start.
    parameter rnw_heading.
    parameter rnw_altitude.

    local target_altitude is 0.
    // TEAMAltitude is an altitude above the selected runway, not an
    // atmosphere-relative cap.  Keep the interface at that full height for
    // every runway, including low-elevation runways.
    set target_altitude to rnw_altitude + AVES["TEAMAltitude"].

    // Keep the glideslope station fixed. Use the bearing from the current
    // vessel position to this unshifted point to place the box laterally on
    // the incoming side, without running another entry simulation.
    local ercl_distance is calculate_distance_from_alt(target_altitude,rnw_altitude).
    local ercl_target is get_geoposition_along_heading(rnw_start,rnw_heading+180,ercl_distance).
    local approach_bearing is heading_between(ship:geoposition,ercl_target).
    local lateral_offset is team_interface_lateral_offset(approach_bearing,rnw_heading).
    local lateral_heading is rnw_heading+90.
    if lateral_offset < 0 { set lateral_heading to rnw_heading-90. }
    local target_latlng is get_geoposition_along_heading(ercl_target,lateral_heading,abs(lateral_offset)).

    // Define the TEAM interface box
    local team_interface_box is lexicon(
        "max_altitude", target_altitude+1000,
        "min_altitude", target_altitude-1000,
        "dist_tolerance", AVES["simulation"]["dist_tolerance"]
    ).

    // Return the lexicon with the TEAM interface box
    return lexicon(
        "target_altitude", target_altitude,
        "target_latlng", target_latlng,
        "ercl_target", ercl_target,
        "ercl_distance", ercl_distance,
        "approach_bearing", approach_bearing,
        "lateral_offset", lateral_offset,
        "team_interface_box", team_interface_box
    ).
}
function check_target_in_triangle {
    parameter target_point. // Target geocoordinate
    parameter point1. // First geocoordinate of the triangle
    parameter point2. // Second geocoordinate of the triangle
    parameter point3. // Third geocoordinate of the triangle

    // Function to calculate the area of a triangle given its vertices
    function triangle_area {
        parameter p1, p2, p3.
        return abs(p1:lat * (p2:lng - p3:lng) + p2:lat * (p3:lng - p1:lng) + p3:lat * (p1:lng - p2:lng)) / 2.
    }

    // Calculate the area of the triangle formed by the three points
    local area_total is triangle_area(point1, point2, point3).

    // Calculate the areas of the triangles formed with the target point
    local area1 is triangle_area(target_point, point2, point3).
    local area2 is triangle_area(point1, target_point, point3).
    local area3 is triangle_area(point1, point2, target_point).

    // Check if the sum of the areas of the smaller triangles equals the area of the main triangle
    local is_inside is abs(area_total - (area1 + area2 + area3)) < 0.001.

    // Calculate the distances from the target to each of the three points
    local distance1 is calcdistance_m(target_point, point1).
    local distance2 is calcdistance_m(target_point, point2).
    local distance3 is calcdistance_m(target_point, point3).

    // Return the result as a lexicon
    return lex("is_inside", is_inside, "distance1", distance1, "distance2", distance2, "distance3", distance3).
}
function check_target_in_square {
    parameter target_point. // Target geocoordinate
    parameter point1. // First geocoordinate of the square
    parameter point2. // Second geocoordinate of the square
    parameter point3. // Third geocoordinate of the square
    parameter point4. // Fourth geocoordinate of the square

    // Function to calculate the area of a triangle given its vertices
    function triangle_area {
        parameter p1, p2, p3.
        return abs(p1:lat * (p2:lng - p3:lng) + p2:lat * (p3:lng - p1:lng) + p3:lat * (p1:lng - p2:lng)) / 2.
    }

    // Calculate the area of the square formed by the four points (as two triangles)
    local area_total is triangle_area(point1, point2, point3) + triangle_area(point1, point3, point4).

    // Calculate the areas of the triangles formed with the target point
    local area1 is triangle_area(target_point, point1, point2).
    local area2 is triangle_area(target_point, point2, point3).
    local area3 is triangle_area(target_point, point3, point4).
    local area4 is triangle_area(target_point, point4, point1).

    // Check if the sum of the areas of the smaller triangles equals the area of the main square
    local is_inside is abs(area_total - (area1 + area2 + area3 + area4)) < 0.001.

    // Calculate the distances from the target to each of the four points
    local distance1 is calcdistance_m(target_point, point1).
    local distance2 is calcdistance_m(target_point, point2).
    local distance3 is calcdistance_m(target_point, point3).
    local distance4 is calcdistance_m(target_point, point4).

    // Return the result as a lexicon
    return lex("is_inside", is_inside, "distance1", distance1, "distance2", distance2, "distance3", distance3, "distance4", distance4).
}
function calc_turn_radius {
    parameter geopos1, hed1, geopos2, hed2.
    local hed1_rad to hed1 * constant:degtorad.
    local hed2_rad to hed2 * constant:degtorad.
    local distance is calcdistance_m(geopos1, geopos2).
    local delta_heading is abs(hed2_rad - hed1_rad).
    if delta_heading > constant:pi {
        set delta_heading to 2 * constant:pi - delta_heading.
    }
    // Protect against zero or near-zero heading difference which would produce
    // a division-by-zero (infinite radius). If the headings are effectively the
    // same (vehicle flying straight), return 0 as a sentinel (no meaningful turn).
    if abs(delta_heading) < 1e-6 {
        return 0.
    }

    // Calculate the turn radius using the formula: R = d / (2 * sin(Δθ / 2))
    local denom is 2 * sin(delta_heading / 2).
    if abs(denom) < 1e-9 {
        return 0.
    }
    local turn_radius is distance / denom.
    return turn_radius.
}
