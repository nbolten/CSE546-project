/*
Create a new, simplified sidewalk table, converting the (often discontinuous)
MULTILINESTRINGs into LINESTRINGs using ST_LineMerge. It's possible that this
introduces errors and should be considered a TODO for improving accuracy.

Add columns here to include them in downstream anlyses - e.g. to analyze
whether two sidewalks have the same curb type, need to include the curb type
column at this point.
*/
DROP TABLE IF EXISTS enhanced_sidewalks CASCADE;
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

DROP TABLE IF EXISTS nearby_sidewalks CASCADE;
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
                                     ON ST_DWithin(si.geom, sj.geom, 50)
                                    AND si.id < sj.id; -- ensures non-redundant

/*
Make a table that just includes vectors of i and j so they can be sorted
by distance
*/
DROP TABLE IF EXISTS vector_pairs;
CREATE TABLE vector_pairs AS SELECT id_i,
                                    id_j,
                                    start_vec_i AS vec1,
                                    start_vec_j AS vec2,
                                    ST_Distance(ST_EndPoint(start_vec_i), ST_EndPoint(start_vec_j)) AS distance
                               FROM nearby_sidewalks
                              UNION
                             SELECT id_i,
                                    id_j,
                                    start_vec_i AS vec1,
                                    end_vec_j AS vec2,
                                    ST_Distance(ST_EndPoint(start_vec_i), ST_EndPoint(end_vec_j)) AS distance
                               FROM nearby_sidewalks
                              UNION
                             SELECT id_i,
                                    id_j,
                                    end_vec_i AS vec1,
                                    start_vec_j AS vec2,
                                    ST_Distance(ST_EndPoint(end_vec_i), ST_EndPoint(start_vec_j)) AS distance
                               FROM nearby_sidewalks
                              UNION
                             SELECT id_i,
                                    id_j,
                                    end_vec_i AS vec1,
                                    end_vec_j AS vec2,
                                    ST_Distance(ST_EndPoint(end_vec_i), ST_EndPoint(end_vec_j)) AS distance
                               FROM nearby_sidewalks;
