function get_geoposition_along_heading {
    declare parameter starting_LATLNG, vec_heading, distance.

     if vec_heading > 360 {
        set vec_heading to vec_heading - 360.
    } 
    if vec_heading < 0 {
        set vec_heading to vec_heading + 360.
    }

    // Convert heading and lat/lng to radians
    local vec_heading_rad to vec_heading.
    local lat_rad to starting_LATLNG:lat * constant:degtorad.
    local lng_rad to starting_LATLNG:lng * constant:degtorad.

    // Define Kerbin's radius (600,000 meters)
    local planet_radius to 600000.

    // Calculate angular distance (in radians) from the given distance
    local angular_distance to distance / planet_radius.

    // Calculate new latitude using the spherical law of cosines
    local new_lat_rad to arcsin(sin(lat_rad) * cos(angular_distance) + cos(lat_rad) * sin(angular_distance) * cos(vec_heading_rad)).

    // Calculate new longitude using spherical law of cosines
    local new_lng_rad to lng_rad + arctan2(
        sin(vec_heading_rad) * sin(angular_distance) * cos(lat_rad),
        cos(angular_distance) - sin(lat_rad) * sin(new_lat_rad)
    ).

    // Convert the result back to degrees
    local new_lat to new_lat_rad * constant:radtodeg.
    local new_lng to new_lng_rad * constant:radtodeg.

    // Return the new geoposition as a LATLNG object
    return latlng(new_lat, new_lng).
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
    
    // Radius of Kerbin in km
    local rad to 600.  
    
    // Convert latitudes and longitudes to radians and calculate deltas
    local lat1_rad to geopos1:lat * constant:degtorad.
    local lat2_rad to geopos2:lat * constant:degtorad.
    local dlat to (geopos2:lat - geopos1:lat) * constant:degtorad.
    local dlng to (geopos2:lng - geopos1:lng) * constant:degtorad.

    

    // Haversine formula components
    local a to sin(dlat / 2) * sin(dlat / 2) +
           cos(lat1_rad) * cos(lat2_rad) *
           sin(dlng / 2) * sin(dlng / 2).
    local c to 2 * arctan2(sqrt(a), sqrt(1 - a)).

    // Return distance in km and log for debugging
    local distance to rad * c.
    
    return distance.
}
function calcdistance_m {
    parameter geopos1, geopos2.
    
    // Radius of Kerbin in km
    local rad to 600.  
    
    // Convert latitudes and longitudes to radians and calculate deltas
    local lat1_rad to geopos1:lat * constant:degtorad.
    local lat2_rad to geopos2:lat * constant:degtorad.
    local dlat to (geopos2:lat - geopos1:lat) * constant:degtorad.
    local dlng to (geopos2:lng - geopos1:lng) * constant:degtorad.

    

    // Haversine formula components
    local a to sin(dlat / 2) * sin(dlat / 2) +
           cos(lat1_rad) * cos(lat2_rad) *
           sin(dlng / 2) * sin(dlng / 2).
    local c to 2 * arctan2(sqrt(a), sqrt(1 - a)).

    // Return distance in km and log for debugging
    local distance to rad * c.
    
    return distance*1000.
}
function heading_between {
    parameter current_position.
    parameter target_position.  // Target position as a vector (lat, long) in degrees.
    
    // Constants
    local x is 0.
    local y is 0.
    local a_heading is 0.
    local deg_to_rad to constant:pi / 180.

    // Current Position of the ship
    

    // Convert current and target latitude and longitude from degrees to radians
    local current_lat to current_position:lat * deg_to_rad.
    local current_long to current_position:lng * deg_to_rad.
    local target_lat to target_position:lat * deg_to_rad.
    local target_long to target_position:lng * deg_to_rad.

    // Calculate the delta between the current and target longitudes
    local delta_long to target_long - current_long.
    // Normalize delta_long to the range [-π, π]
    set delta_long to delta_long - 2 * constant:pi * floor((delta_long + constant:pi) / (2 * constant:pi)).

    // Calculate the heading using spherical trigonometry
    set y to sin(delta_long) * cos(target_lat).
    set x to cos(current_lat) * sin(target_lat) - sin(current_lat) * cos(target_lat) * cos(delta_long).

    set a_heading to arctan2(y, x).  // Calculate heading in radians

    until a_heading >= 0 and a_heading < 360{
        if a_heading >= 360 {
            set a_heading to a_heading - 360.
        } 
        if a_heading < 0 {
            set a_heading to a_heading + 360.
        }   
    }

    // Distance threshold to detect if the current position is effectively the same as the target position
    local distance_threshold to 0.00001.  // Adjust this value as needed for precision
    local lat_diff to current_lat - target_lat.
    local long_diff to current_long - target_long.
    local distance_squared to lat_diff^2 + long_diff^2.

    if distance_squared < distance_threshold^2 {
        
        return 0.  // Alternatively, return 'undefined' or another indicator for "already at target"
    }
    
    // Return the calculated heading
    return a_heading.
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
        return.
    }

    set h to arcsin(sin_h).
    return h. // Adjust for prograde or retrograde as needed.
}
function calc_hacstate{
    parameter hac_pos.
    parameter hac_rad.
    parameter hac_heading.
    parameter ERCL_HED.
    parameter hac_side.

    log hac_pos to log10.txt.
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

    log state to log10.txt.
    return state.
}
function define_TEAM_interface {
    parameter rnw_start.
    parameter rnw_heading.
    parameter rnw_altitude.

    local target_altitude is 0.
    // Calculate the target altitude
    if rnw_altitude + AVES["TEAMAltitude"]*(4/5) > AVES["TEAMAltitude"]{
        set target_altitude to AVES["TEAMAltitude"].
    } else {
        set target_altitude to rnw_altitude + AVES["TEAMAltitude"]*(4/5).
    }

    local target_latlng is latlng(0, 0).
    local ercl_2hac to get_geoposition_along_heading(rnw_start,rnw_heading+180,Aves["HacDistance"]).
    if calcdistance(ship:geoposition,rnw_start) > calcdistance(ship:geoposition,ecrl_2hac){
        set target_latlng to get_geoposition_along_heading(rnw_start,rnw_heading+180,calculate_distance_from_alt(AVES["TEAMAltitude"])).
    }else{set target_latlng to get_geoposition_along_heading(ercl_2hac,compass_for_prograde()+180,calculate_distance_from_alt(AVES["TEAMAltitude"])).}

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