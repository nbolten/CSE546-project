/* Same query but for generating the training dataset */
DROP TABLE IF EXISTS connections;
CREATE TABLE connections AS SELECT yi.o_id AS yi_id,
                                 yj.o_id AS yj_id
                            FROM yun_sidewalks_ready_routing AS yi
                      INNER JOIN yun_sidewalks_ready_routing AS yj
                              ON ST_DWithin(yi.geom, yj.geom, 0.1)
                           WHERE yi.iscrossing = 0 AND yj.iscrossing = 0;
