/* Find sidewalks that are Within 100 meters at their closest point */
DROP TABLE IF EXISTS learndata;
CREATE TABLE learndata AS SELECT si.ogc_fid AS si_id,
                                 sj.ogc_fid AS sj_id,
                                 si.wkb_geometry AS si_geom,
                                 sj.wkb_geometry AS sj_geom,
                                 ST_Distance(si.wkb_geometry, sj.wkb_geometry) AS distance
                            FROM v_sidewalks AS si
                      INNER JOIN v_sidewalks AS sj
                              ON ST_DWithin(si.wkb_geometry, sj.wkb_geometry, 100);
