function get_geoposition_along_heading {
    declare parameter starting_LATLNG, vec_heading, distance.

     if vec_heading > 360 {
        set vec_heading to vec_heading - 360.
    } 
    if vec_heading < 0 {
        set vec_heading to vec_heading + 360.
    }

    // Convert heading and lat/lng to radians
    set vec_heading_rad to vec_heading.
    set lat_rad to starting_LATLNG:lat * constant:degtorad.
    set lng_rad to starting_LATLNG:lng * constant:degtorad.

    // Define Kerbin's radius (600,000 meters)
    set planet_radius to 600000.

    // Calculate angular distance (in radians) from the given distance
    set angular_distance to distance / planet_radius.

    // Calculate new latitude using the spherical law of cosines
    set new_lat_rad to arcsin(sin(lat_rad) * cos(angular_distance) + cos(lat_rad) * sin(angular_distance) * cos(vec_heading_rad)).

    // Calculate new longitude using spherical law of cosines
    set new_lng_rad to lng_rad + arctan2(
        sin(vec_heading_rad) * sin(angular_distance) * cos(lat_rad),
        cos(angular_distance) - sin(lat_rad) * sin(new_lat_rad)
    ).

    // Convert the result back to degrees
    set new_lat to new_lat_rad * constant:radtodeg.
    set new_lng to new_lng_rad * constant:radtodeg.

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

    // Convert heading and lat/lng to radians
    set heading_rad to circle_heading * constant:degtorad.
    set lat_rad to center_LATLNG:lat * constant:degtorad.
    set lng_rad to center_LATLNG:lng * constant:degtorad.

    // Define Kerbin's radius (600,000 meters)
    set planet_radius to 600000.

    // Convert circle radius to angular distance (in radians)
    set angular_distance to radius / planet_radius.

    // Adjust the heading based on the circle direction (clockwise or anticlockwise)
    if circle_direction = "clockwise" {
        set adjusted_heading_rad to heading_rad.
    } else {
        set adjusted_heading_rad to -heading_rad.  // Invert heading for anticlockwise
    }

    // Calculate new latitude using the spherical law of cosines
    set new_lat_rad to arcsin(sin(lat_rad) * cos(angular_distance) + cos(lat_rad) * sin(angular_distance) * cos(adjusted_heading_rad)).

    // Calculate new longitude using spherical law of cosines
    set new_lng_rad to lng_rad + arctan2(
        sin(adjusted_heading_rad) * sin(angular_distance) * cos(lat_rad),
        cos(angular_distance) - sin(lat_rad) * sin(new_lat_rad)
    ).

    // Convert the result back to degrees
    set new_lat to new_lat_rad * constant:radtodeg.
    set new_lng to new_lng_rad * constant:radtodeg.

    // Return the new geoposition as a LATLNG object
    return latlng(new_lat, new_lng).
}

function calcdistance {
    parameter geopos1, geopos2.
    
    // Radius of Kerbin in km
    set rad to 600.  
    
    // Convert latitudes and longitudes to radians and calculate deltas
    set lat1_rad to geopos1:lat * constant:degtorad.
    set lat2_rad to geopos2:lat * constant:degtorad.
    set dlat to (geopos2:lat - geopos1:lat) * constant:degtorad.
    set dlng to (geopos2:lng - geopos1:lng) * constant:degtorad.

    

    // Haversine formula components
    set a to sin(dlat / 2) * sin(dlat / 2) +
           cos(lat1_rad) * cos(lat2_rad) *
           sin(dlng / 2) * sin(dlng / 2).
    set c to 2 * arctan2(sqrt(a), sqrt(1 - a)).

    // Return distance in km and log for debugging
    set distance to rad * c.
    
    return distance.
}
function calcdistance_m {
    parameter geopos1, geopos2.
    
    // Radius of Kerbin in km
    set rad to 600.  
    
    // Convert latitudes and longitudes to radians and calculate deltas
    set lat1_rad to geopos1:lat * constant:degtorad.
    set lat2_rad to geopos2:lat * constant:degtorad.
    set dlat to (geopos2:lat - geopos1:lat) * constant:degtorad.
    set dlng to (geopos2:lng - geopos1:lng) * constant:degtorad.

    

    // Haversine formula components
    set a to sin(dlat / 2) * sin(dlat / 2) +
           cos(lat1_rad) * cos(lat2_rad) *
           sin(dlng / 2) * sin(dlng / 2).
    set c to 2 * arctan2(sqrt(a), sqrt(1 - a)).

    // Return distance in km and log for debugging
    set distance to rad * c.
    
    return distance*1000.
}
function heading_between {
    parameter current_position.
    parameter target_position.  // Target position as a vector (lat, long) in degrees.
    
    // Constants
    
    set deg_to_rad to constant:pi / 180.

    // Current Position of the ship
    

    // Convert current and target latitude and longitude from degrees to radians
    set current_lat to current_position:lat * deg_to_rad.
    set current_long to current_position:lng * deg_to_rad.
    set target_lat to target_position:lat * deg_to_rad.
    set target_long to target_position:lng * deg_to_rad.

    // Calculate the delta between the current and target longitudes
    set delta_long to target_long - current_long.
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
    set distance_threshold to 0.00001.  // Adjust this value as needed for precision
    set lat_diff to current_lat - target_lat.
    set long_diff to current_long - target_long.
    set distance_squared to lat_diff^2 + long_diff^2.

    if distance_squared < distance_threshold^2 {
        
        return 0.  // Alternatively, return 'undefined' or another indicator for "already at target"
    }
    
    // Return the calculated heading
    return a_heading.
}
function heading_to_target {
    parameter target_position.  // Target position as a vector (lat, long) in degrees.

    // Constants
    
    set deg_to_rad to constant:pi / 180.

    // Current Position of the ship
    set current_position to ship:geoposition.  // Returns (latitude, longitude) in degrees.

    // Convert current and target latitude and longitude from degrees to radians
    set current_lat to current_position:lat * deg_to_rad.
    set current_long to current_position:lng * deg_to_rad.
    set target_lat to target_position:lat * deg_to_rad.
    set target_long to target_position:lng * deg_to_rad.

    // Calculate the delta between the current and target longitudes
    set delta_long to target_long - current_long.
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
    set distance_threshold to 0.00001.  // Adjust this value as needed for precision
    set lat_diff to current_lat - target_lat.
    set long_diff to current_long - target_long.
    set distance_squared to lat_diff^2 + long_diff^2.

    if distance_squared < distance_threshold^2 {
        
        return 0.  // Alternatively, return 'undefined' or another indicator for "already at target"
    }
    
    // Return the calculated heading
    return a_heading.
}

// Haversine distance formula for calculating the distance between two geolocations

function convert_to_kerbin_coordinates {
    parameter lat, lng.
    
    // Scaling factor based on the ratio of Kerbin's radius to Earth's radius
    set scale_factor to 600 / 6371.
    
    // Convert latitude and longitude by scaling them down to Kerbin's size
    set kerbin_lat to lat * scale_factor.
    set kerbin_lng to lng * scale_factor.
    
    // log converted coordinates for debugging
   
    
    return latlng(kerbin_lat, kerbin_lng).
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


    set hac_ercl_alt to calculate_vertical_glideslope_alt(AVES["HacDistance"]). 
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
    if HAC_Distance["HAC1"] < HAC_Distance["HAC2"]{
        set Active_HAC_entry to get_geoposition_on_circle(HAC["Hac1"],AVES["HacRadius"],"clockwise",compass_for()).
        set Active_HAC to "HAC1".
        set HAC_Direction to "Clockwise".
    } else{
        set Active_HAC_entry to get_geoposition_on_circle(HAC["Hac2"],AVES["HacRadius"],"anticlockwise",compass_for()).
        set Active_HAC to "HAC2".
        set HAC_Direction to "Anticlockwise".
    }
}

