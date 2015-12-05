/* Same query but for generating the training dataset */
DROP TABLE IF EXISTS connections;
CREATE TABLE connections AS SELECT yi.id AS id_i,
                                   yj.id AS id_j
                              FROM clean_sidewalks AS yi
                        INNER JOIN clean_sidewalks AS yj
                                ON ST_DWithin(yi.geom, yj.geom, 0.01)
                             WHERE yi.id != yj.id;
