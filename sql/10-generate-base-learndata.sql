/*
Create a new, simplified sidewalk table, converting the (often discontinuous)
MULTILINESTRINGs into LINESTRINGs using ST_LineMerge. It's possible that this
introduces errors and should be considered a TODO for improving accuracy.

Add columns here to include them in downstream anlyses - e.g. to analyze
whether two sidewalks have the same curb type, need to include the curb type
column at this point.
*/
DROP TABLE IF EXISTS enhanced_sidewalks;
CREATE TABLE enhanced_sidewalks AS SELECT s.compkey AS id,
                                          ST_LineMerge(s.wkb_geometry) AS geom,
                                          ST_Length(s.wkb_geometry) AS length,
                                          s.curbtype AS curbtype,
                                          s.surftype AS surftype,
                                          s.sw_width AS sw_width,
                                          s.side AS side
                                     FROM v_sidewalks AS s;

/*
Add endpoint vectors - vectors pointing out of the ends of each sidewalk -
as LINESTRINGs between the second-to-last point and the endpoint.
*/
ALTER TABLE enhanced_sidewalks ADD COLUMN start_vec geometry,
                               ADD COLUMN end_vec geometry;
UPDATE enhanced_sidewalks
   SET start_vec = ST_MakeLine(ST_PointN(geom, 2), ST_Startpoint(geom)),
         end_vec = ST_MakeLine(ST_PointN(geom, ST_NPoints(geom) - 1), ST_PointN(geom, ST_NPoints(geom)));

/*
Now generate a new table that represents the relationships between two
sidewalks. Add a spatial index to speed up the DWithin comparison.
*/


CREATE INDEX geom_gix ON enhanced_sidewalks USING GIST (geom);

DROP TABLE IF EXISTS nearby_sidewalks;
CREATE TABLE nearby_sidewalks AS SELECT 0 as connected,
                                        si.id AS id_i,
                                        sj.id AS id_j,
                                        si.geom AS geom_i,
                                        sj.geom AS geom_j,
                                        si.length AS length_i,
                                        sj.length AS length_j,
                                        si.side AS side_i,
                                        sj.side AS side_j,
                                        si.sw_width AS sw_width_i,
                                        sj.sw_width AS sw_width_j,
                                        si.curbtype AS curbtype_i,
                                        sj.curbtype AS curbtype_j,
                                        si.surftype AS surftype_i,
                                        sj.surftype AS surftype_j,
                                        si.start_vec AS start_vec_i,
                                        si.end_vec AS end_vec_i,
                                        sj.start_vec AS start_vec_j,
                                        sj.end_vec AS end_vec_j,
                                        /* i to j relationships */
                                        -- TODO: compare 'side' via angle from North
                                        ST_Intersects(si.geom, sj.geom) AS intersects
                                   FROM enhanced_sidewalks AS si
                             INNER JOIN enhanced_sidewalks AS sj
                                     ON ST_DWithin(si.geom, sj.geom, 100)
                                    AND si.id < sj.id; -- ensures non-redundant

/*
Make a table that just includes vectors of i and j so they can be sorted
by distance
*/
DROP TABLE IF EXISTS vector_pairs;
CREATE TABLE vector_pairs AS SELECT id_i,
                                    id_j,
                                    start_vec_i AS vec1,
                                    start_vec_j AS vec2
                               FROM nearby_sidewalks
                              UNION
                             SELECT id_i,
                                    id_j,
                                    start_vec_i AS vec1,
                                    end_vec_j AS vec2
                               FROM nearby_sidewalks
                              UNION
                             SELECT id_i,
                                    id_j,
                                    end_vec_i AS vec1,
                                    start_vec_j AS vec2
                               FROM nearby_sidewalks
                              UNION
                             SELECT id_i,
                                    id_j,
                                    end_vec_i AS vec1,
                                    end_vec_j AS vec2
                               FROM nearby_sidewalks;

/*
Copy distance, angle, and intersection if they correspond to end vectors that
are closest together.
*/
ALTER TABLE nearby_sidewalks ADD COLUMN near_vec_i geometry;
ALTER TABLE nearby_sidewalks ADD COLUMN near_vec_j geometry;


UPDATE nearby_sidewalks
   SET near_vec_i = closest.vec1,
       near_vec_j = closest.vec2
  FROM (  SELECT vp.id_i, vp.id_j, vp.vec1, vp.vec2
            FROM vector_pairs AS vp
           WHERE vp.id_i = id_i AND vp.id_j = id_j
        ORDER BY ST_Distance(ST_EndPoint(vp.vec1), ST_EndPoint(vp.vec2))
           LIMIT 1) AS closest;

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

/* FIXME: Sometimes, slope1 = slope2 somehow and it generates a divide by 0 error. I don't know how that happens */
/* FIXME: My solution is to add the tiniest bit of noise - the 10th digit */
slope1 := v1y / v1x * (1 + random() * 0.0000000001);
slope2 := v2y / v2x * (1 + random() * 0.0000000001);

/*
raise notice 'Slope1: %', slope1;
raise notice 'Slope2: %', slope2;
*/
intercept1 := slope1 * -p1x + p1y;
intercept2 := slope2 * -p2x + p2y;

x := (intercept2 - intercept1) / (slope1 - slope2);
y := slope1 * x + intercept1;

RETURN ST_MakePoint(x, y);

END
$$ LANGUAGE plpgsql;


ALTER TABLE nearby_sidewalks ADD COLUMN near_angle double precision,
                             ADD COLUMN near_distance double precision,
                             ADD COLUMN near_intersection geometry,
                             ADD COLUMN near_line geometry;

UPDATE nearby_sidewalks
   SET        near_angle = angle_between(near_vec_i, near_vec_j),
           near_distance = ST_Distance(near_vec_i, near_vec_j),
       near_intersection = intersection(near_vec_i, near_vec_j),
               near_line = ST_MakeLine(ST_EndPoint(near_vec_i), ST_EndPoint(near_vec_i));

-- FIXME: Use near_intersection to make more metrics
