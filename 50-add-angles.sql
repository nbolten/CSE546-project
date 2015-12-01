/* Add column for whether or not sidewalks are connected

Defaults to 0 (not connected).
*/
/*
ALTER TABLE learndata
    DROP COLUMN IF EXISTS radians,
        ADD COLUMN radians float8;
*/

/* Calculate angle between closest points */

/*
1. Turn multilinestrings into linestrings
2. For each one, find closest point
3. Find next point after closest point
4. Find azimuth between next point and closest point
5. Save to value
6. Once angles are recorded, find difference and save.
*/

UPDATE learndata
   SET connected = 1
  FROM connections as c
 WHERE si_id = c.yi_id AND sj_id = c.yj_id;
