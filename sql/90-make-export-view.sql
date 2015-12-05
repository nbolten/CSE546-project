DROP VIEW IF EXISTS learndata;
CREATE VIEW learndata AS SELECT connected,
                                id_i,
                                id_j,
                                length_i,
                                length_j,
                                side_i,
                                side_j,
                                sw_width_i,
                                sw_width_j,
                                surftype_i,
                                surftype_j,
                                intersects,
                                near_angle,
                                near_distance,
                                near_line,
                                bid_i,
                                bid_j
                           FROM nearby_sidewalks;