-- @tag: greetings_own_table
-- @description: Eigene Tabelle für Anreden
-- @depends: release_3_5_5

CREATE TABLE greetings (
  id          SERIAL,
  description TEXT      NOT NULL,
  PRIMARY KEY (id),
  UNIQUE (description)
);

UPDATE customer SET greeting = trim(greeting) WHERE greeting NOT LIKE trim(greeting);
UPDATE vendor   SET greeting = trim(greeting) WHERE greeting NOT LIKE trim(greeting);

INSERT INTO greetings (description)
  SELECT DISTINCT greeting FROM (SELECT greeting FROM customer UNION SELECT greeting FROM vendor) AS gr WHERE greeting IS NOT NULL AND greeting NOT LIKE '' ORDER BY greeting;
