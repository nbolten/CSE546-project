/* Set 'connected' column to 1 if si_id, sj_id match any yi_id, yj_id in
yun_sidewalks_ready_routing.
*/
UPDATE learndata
   SET connected = 1
  FROM connections as c
 WHERE si_id = c.yi_id AND sj_id = c.yj_id;
