/*
Copy distance, angle, and intersection if they correspond to end vectors that
are closest together.
*/
DROP TABLE IF EXISTS shortest_vector_pairs;
CREATE TABLE shortest_vector_pairs AS SELECT DISTINCT
                                                   ON (id_i, id_j) *
                                                 FROM vector_pairs
                                             ORDER BY id_i, id_j, distance ASC;

ALTER TABLE nearby_sidewalks DROP COLUMN IF EXISTS near_vec_i;
ALTER TABLE nearby_sidewalks DROP COLUMN IF EXISTS near_vec_j;
ALTER TABLE nearby_sidewalks ADD COLUMN near_vec_i geometry;
ALTER TABLE nearby_sidewalks ADD COLUMN near_vec_j geometry;

/*
FIXME: this is very slow. It is actually faster to recreate the nearby_sidwalks
table entirely than to update every row.
*/
UPDATE nearby_sidewalks AS ns
   SET near_vec_i = vp.vec1,
       near_vec_j = vp.vec2
  FROM shortest_vector_pairs AS vp
 WHERE ns.id_i = vp.id_i
   AND ns.id_j = vp.id_j;

/*
Add metrics for the two closest vectors as well as line connecting them
(for visualization).
*/

CREATE OR REPLACE FUNCTION angle_between(vec1 geometry, vec2 geometry)
RETURNS double precision AS $$

BEGIN
/* Take the smallest one and proceed */
RETURN ST_Azimuth(ST_StartPoint(vec1), ST_EndPoint(vec1)) - ST_Azimuth(ST_StartPoint(vec2), ST_EndPoint(vec2));

END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION intersection(vec1 geometry, vec2 geometry) RETURNS geometry AS $$

DECLARE
  end1 geometry;
  end2 geometry;
  azimuth1 double precision;
  azimuth2 double precision;
  v1x double precision;
  v1y double precision;
  v2x double precision;
  v2y double precision;
  p1x double precision;
  p1y double precision;
  p2x double precision;
  p2y double precision;
  slope1 double precision;
  slope2 double precision;
  intercept1 double precision;
  intercept2 double precision;
  x double precision;
  y double precision;

BEGIN
/* With the azimuths and endpoints, we can now calculate the intersection */
/* vectors for each azimuth */
end1 = ST_EndPoint(vec1);
end2 = ST_EndPoint(vec2);

azimuth1 := ST_Azimuth(ST_StartPoint(vec1), end1);
azimuth2 := ST_Azimuth(ST_StartPoint(vec2), end2);

v1x := cos(azimuth1);
v1y := sin(azimuth1);
v2x := cos(azimuth2);
v2y := sin(azimuth2);

p1x := ST_X(end1);
p1y := ST_Y(end1);
p2x := ST_X(end2);
p2y := ST_Y(end2);

/*
Hacky way to avoid divide by 0 errors
*/
IF (v1x = 0) THEN
  v1x := 0.0000000001;
END IF;

IF (v2x = 0) THEN
  v2x := 0.0000000001;
END IF;

slope1 := v1y / v1x;
slope2 := v2y / v2x;

intercept1 := slope1 * -p1x + p1y;
intercept2 := slope2 * -p2x + p2y;

/* BIG FIXME: Abandoned this for now as it still produces divide by 0 errors */
/* FIXME: Sometimes, slope1 = slope2 somehow and it generates a divide by 0 error. I don't know how that happens.
          If this is the case, they are parallel and have no intersection.
*/
/*
Hacky fix biases slope 1 to be slightly higher than average.
*/
IF ((slope1 - slope2) = 0) THEN
  slope1 := slope1 + 0.0000000001;
END IF;

x := (intercept2 - intercept1) / (slope1 - slope2);
y := slope1 * x + intercept1;

RETURN ST_MakePoint(x, y);

END
$$ LANGUAGE plpgsql;


ALTER TABLE nearby_sidewalks DROP COLUMN IF EXISTS near_angle,
                             DROP COLUMN IF EXISTS near_distance,
                             DROP COLUMN IF EXISTS near_line;
ALTER TABLE nearby_sidewalks ADD COLUMN near_angle double precision,
                             ADD COLUMN near_distance double precision,
                             ADD COLUMN near_line geometry;

UPDATE nearby_sidewalks
   SET        near_angle = angle_between(near_vec_i, near_vec_j),
           near_distance = ST_Distance(ST_EndPoint(near_vec_i), ST_EndPoint(near_vec_j)),
               near_line = ST_MakeLine(ST_EndPoint(near_vec_i), ST_EndPoint(near_vec_j));
