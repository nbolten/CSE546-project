\timing
/*SET LOCAL synchronous_commit TO OFF;*/
UPDATE learndata AS l
   SET connected = 1
  FROM (SELECT * FROM connections) AS c
  /*FROM (SELECT * FROM connections LIMIT 2) AS c*/
 WHERE l.id_i = c.id_i AND l.id_j = c.id_j;
/*SET LOCAL synchronous_commit TO ON;*/
