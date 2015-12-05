UPDATE nearby_sidewalks AS nb
   SET connected = 1
  FROM connections AS c
 WHERE nb.id_i = c.id_i AND nb.id_j = c.id_j;
