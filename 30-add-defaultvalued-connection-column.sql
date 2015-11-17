/* Add column for whether or not sidewalks are connected

Defaults to 0 (not connected).
*/
ALTER TABLE learndata
    DROP COLUMN IF EXISTS connected,
        ADD COLUMN connected integer;

UPDATE learndata SET connected = 0;
