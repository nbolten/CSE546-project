/*
Now, using the streets table, classify whether a 'near_line' segment (the
line drawn between the two sidewalks to be connected) intersects with the
street.
*/
CREATE INDEX nl_gix ON nearby_sidewalks USING GIST (near_line);

DROP TABLE IF EXISTS nearby_sidewalks_intersect;

CREATE TABLE nearby_sidewalks_intersect AS SELECT *
                                             FROM nearby_sidewalks AS ns
                                       INNER JOIN learnstreets AS s
                                               ON ST_Intersects(ns.near_line, s.geom);

DROP INDEX nl_gix;

ALTER TABLE nearby_sidewalks DROP COLUMN IF EXISTS intersects_street;
ALTER TABLE nearby_sidewalks ADD COLUMN intersects_street integer DEFAULT 0;

\timing
UPDATE nearby_sidewalks ns
   SET intersects_street = 1
  FROM nearby_sidewalks_intersect nsi
 WHERE ns.id_i = nsi.id_i
   AND ns.id_j = nsi.id_j
 LIMIT 100;
