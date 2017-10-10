-- @tag: letter_date_type
-- @description: Briefe: Datumsfeld als Datum speichern
-- @depends: release_3_2_0 letter
ALTER TABLE letter ADD column date_date DATE;
UPDATE letter SET date_date = date::DATE;
ALTER TABLE letter DROP COLUMN date;
ALTER TABLE letter RENAME COLUMN date_date TO date;

