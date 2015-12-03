/* Find sidewalks that are Within 100 meters at their closest point */
CREATE OR REPLACE FUNCTION angle_between(geom1 geometry, geom2 geometry) RETURNS double precision AS $$
DECLARE
  g1merge geometry;
  g2merge geometry;
  g1start geometry;
  g1end geometry;
  g2start geometry;
  g2end geometry;
  g1target geometry;
  g2target geometry;
  g1sd double precision;
  g1ed double precision;
  g2sd double precision;
  g2ed double precision;
  azimuth1 double precision;
  azimuth2 double precision;
  azimuth double precision;
BEGIN
/*
Get the start and end points of geom1
*/
g1merge := ST_LineMerge(geom1);
g2merge := ST_LineMerge(geom2);

g1start := ST_Startpoint(g1merge);
g1end := ST_Endpoint(g1merge);
g2start := ST_Startpoint(g2merge);
g2end := ST_Endpoint(g2merge);

g1target := ST_MakeLine(ST_Startpoint(g1merge), ST_Endpoint(g1merge));
g2target := ST_MakeLine(ST_Startpoint(g2merge), ST_Endpoint(g2merge));

/* Get the distance from geom1 start/end to geom2 start/end */
g1sd := ST_Distance(g1start, g2target);
g1ed := ST_Distance(g1end, g2target);
g2sd := ST_Distance(g2start, g1target);
g2ed := ST_Distance(g2end, g1target);

/* Take the smallest one and proceed */
IF g1sd < g1ed THEN
    azimuth1 := ST_Azimuth(ST_PointN(g1merge, 2), g1start);
ELSE
    azimuth1 := ST_Azimuth(ST_PointN(g1merge, ST_NPoints(g1merge) - 1), g1end);
END IF;

IF g2sd < g2ed THEN
    azimuth2 := ST_Azimuth(ST_PointN(g2merge, 2), g2start);
ELSE
    azimuth2 := ST_Azimuth(ST_PointN(g2merge, ST_NPoints(g2merge) - 1), g2end);
END IF;

azimuth := azimuth2 - azimuth1;

RETURN abs(azimuth);

END
$$ LANGUAGE plpgsql;


DROP FUNCTION intersection(geom1 geometry, geom2 geometry);
CREATE OR REPLACE FUNCTION intersection(geom1 geometry, geom2 geometry) RETURNS geometry AS $$
DECLARE
  g1merge geometry;
  g2merge geometry;
  g1start geometry;
  g1end geometry;
  g2start geometry;
  g2end geometry;
  g1target geometry;
  g2target geometry;
  end1 geometry;
  end2 geometry;
  g1sd double precision;
  g1ed double precision;
  g2sd double precision;
  g2ed double precision;
  azimuth1 double precision;
  azimuth2 double precision;
  azimuth double precision;
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
/*
Get the start and end points of geom1
*/
g1merge := ST_LineMerge(geom1);
g2merge := ST_LineMerge(geom2);

g1start := ST_Startpoint(g1merge);
g1end := ST_Endpoint(g1merge);
g2start := ST_Startpoint(g2merge);
g2end := ST_Endpoint(g2merge);

g1target := ST_MakeLine(ST_Startpoint(g1merge), ST_Endpoint(g1merge));
g2target := ST_MakeLine(ST_Startpoint(g2merge), ST_Endpoint(g2merge));

/* Get the distance from geom1 start/end to geom2 start/end */
g1sd := ST_Distance(g1start, g2target);
g1ed := ST_Distance(g1end, g2target);
g2sd := ST_Distance(g2start, g1target);
g2ed := ST_Distance(g2end, g1target);

/* Take the smallest one and proceed */
IF g1sd < g1ed THEN
    end1 := g1start;
    azimuth1 := ST_Azimuth(ST_PointN(g1merge, 2), g1start);
ELSE
    end1 = g1end;
    azimuth1 := ST_Azimuth(ST_PointN(g1merge, ST_NPoints(g1merge) - 1), g1end);
END IF;

IF g2sd < g2ed THEN
    end2 := g2start;
    azimuth2 := ST_Azimuth(ST_PointN(g2merge, 2), g2start);
ELSE
    end2 := g2end;
    azimuth2 := ST_Azimuth(ST_PointN(g2merge, ST_NPoints(g2merge) - 1), g2end);
END IF;

/* With the azimuths and endpoints, we can now calculate the intersection */
/* vectors for each azimuth */
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


DROP TABLE IF EXISTS learndata;
CREATE TABLE learndata AS SELECT 0 as connected,
                                 si.compkey AS id_i,
                                 sj.compkey as id_j,
                                 si.wkb_geometry AS geom_i,
                                 sj.wkb_geometry AS geom_j,
                                 si.curbtype AS curbtype_i,
                                 sj.curbtype AS curbtype_j,
                                 si.sw_width AS sw_width_i,
                                 sj.sw_width AS sw_width_j,
                                 si.side AS side_i,
                                 sj.side AS side_j,
                                 si.surftype AS surftype_i,
                                 sj.surftype AS surftype_j,
                                 ST_Distance(si.wkb_geometry, sj.wkb_geometry) AS distance,
                                 ST_Intersects(si.wkb_geometry, sj.wkb_geometry) AS intersects,
                                 angle_between(si.wkb_geometry::geometry, sj.wkb_geometry::geometry) AS angle
                            FROM v_sidewalks AS si
                      INNER JOIN v_sidewalks AS sj
                              ON ST_DWithin(si.wkb_geometry, sj.wkb_geometry, 100)
                             AND si.ogc_fid != sj.ogc_fid;
