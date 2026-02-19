-- @tag: countries_add_sortorder
-- @description: Sort countries by relevance
-- @depends: release_4_0_0

ALTER TABLE countries ADD COLUMN sortorder integer;

UPDATE countries SET sortorder = 1 WHERE iso2 = 'DE';
UPDATE countries SET sortorder = 2 WHERE iso2 = 'CH';
UPDATE countries SET sortorder = 3 WHERE iso2 = 'AT';

UPDATE countries c SET sortorder = 4+i
  FROM (SELECT ROW_NUMBER() OVER (ORDER BY description) AS i, id FROM countries WHERE sortorder IS NULL ) ord
  WHERE c.id = ord.id;
