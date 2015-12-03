-- FIXME: THIS SHOULD HAPPEN EARLIER
--        It's slow to update every row (or at least my queries are)
--        but it's fast to generate this data early (just b_id)

-- Create smaller 'learnstreets' table as subselection of streets (raw data)
DROP TABLE if exists learnstreets;

CREATE TABLE learnstreets AS SELECT compkey AS id,
                               -- FIXME: LineMerge has undesired behavior of stitching together
                               -- MultiLineStrings (makes new connections) - instead, explode
                               -- MultiLineStrings into new rows of LineStrings
		                       ST_LineMerge(wkb_geometry) AS geom
	                      FROM streets;

-- Delete redundantly-keyed streets (id = compkey is not unique), make id
-- a unique index (similar to primary key)
DELETE FROM learnstreets
      WHERE id IN (SELECT id
                     FROM (SELECT id, ROW_NUMBER() OVER (partition BY id
                                                             ORDER BY id) AS rnum
                             FROM learnstreets) AS t
                    WHERE t.rnum > 1);

CREATE UNIQUE INDEX street_id ON learnstreets (id);

-- Make polygons out of street network (e.g. a simple block is a quadrilateral)
DROP TABLE IF EXISTS boundary_polygons CASCADE;

CREATE TABLE boundary_polygons AS
      SELECT g.path[1] AS gid, geom
        FROM (SELECT (ST_Dump(ST_Polygonize(learnstreets.geom))).*
      	        FROM learnstreets) AS g;

CREATE INDEX boundary_polygons_index
          ON boundary_polygons
       USING gist(geom);


-- Remove polygons that overlap with one another (I don't remember why this
-- is important)
DELETE FROM boundary_polygons
      WHERE gid in (SELECT b1.gid
                      FROM boundary_polygons b1,
                           boundary_polygons b2
                     WHERE ST_Overlaps(b1.geom, b2.geom)
                  GROUP BY b1.gid
                    HAVING count(b1.gid) > 1);

-- Find all sidewalks what are within a polygons
DROP TABLE IF EXISTS grouped_sidewalks;

CREATE TABLE grouped_sidewalks AS SELECT b.gid AS b_id,
                                         s.compkey AS s_id,
                                         s.wkb_geometry AS s_geom
                                    FROM (SELECT *
                                            FROM v_sidewalks) AS s
                                           -- FROM v_sidewalks AS q
                                           -- WHERE GeometryType(q.wkb_geometry) = 'LINESTRING') AS s
                              INNER JOIN boundary_polygons AS b
                                      ON ST_Within(s.wkb_geometry, b.geom);

-- Find all sidewalks that is not assigned to any polygons because of offshoots.
-- (i.e. they weren't properly inside polygon, but their middle point is).
-- FIXME: this never updates anything. Not sure why, but I'd guess
-- ST_Line_Interpolate_Point doesn't work on multilinestrings
UPDATE grouped_sidewalks
   SET b_id = query.b_id
  FROM (SELECT b.gid AS b_id,
               s.s_id,
               s.s_geom AS s_geom
          FROM (SELECT *
                  FROM grouped_sidewalks
                 WHERE b_id IS NULL) AS s
    INNER JOIN boundary_polygons AS b
            ON ST_Within(ST_Line_Interpolate_Point(s.s_geom, 0.5), b.geom) = True) AS query
 WHERE grouped_sidewalks.s_id = query.s_id;

-- For each unassigned put to the closest polygons (deleted)
/*
UPDATE grouped_sidewalks
   SET b_id = query.b_id
  FROM (SELECT DISTINCT ON (s.s_id) s.s_id as s_id,
                                    u.id as b_id
                      FROM (SELECT *
                              FROM grouped_sidewalks
                             WHERE b_id IS NULL) AS s
                INNER JOIN union_polygons AS u
                        ON u.id=s.b_id
                  ORDER BY s.s_id, ST_Distance(s.s_geom, u.geom)) AS query
 WHERE grouped_sidewalks.s_id = query.s_id;
*/

-- Update learndata to include si_bid and sj_bid
ALTER TABLE learndata DROP COLUMN IF EXISTS bid_i;
ALTER TABLE learndata ADD COLUMN bid_i integer;
ALTER TABLE learndata DROP COLUMN IF EXISTS bid_j;
ALTER TABLE learndata ADD COLUMN bid_j integer;

-- TODO: make this step faster. Maybe by dropping indices first?
UPDATE learndata AS l
   SET bid_i = g.b_id
  FROM grouped_sidewalks AS g
 WHERE l.id_i = g.s_id;

UPDATE learndata AS l
   SET bid_j = g.b_id
  FROM grouped_sidewalks AS g
 WHERE l.id_j = g.s_id;
