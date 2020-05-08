-- @tag: contact_titles_own_table
-- @description: Eigene Tabelle für Titel bei Ansprechpersonen
-- @depends: release_3_5_5

CREATE TABLE contact_titles (
  id          SERIAL,
  description TEXT      NOT NULL,
  PRIMARY KEY (id),
  UNIQUE (description)
);

UPDATE contacts SET cp_title = trim(cp_title) WHERE cp_title NOT LIKE trim(cp_title);

INSERT INTO contact_titles (description)
  SELECT DISTINCT cp_title FROM contacts WHERE cp_title IS NOT NULL AND cp_title NOT LIKE '' ORDER BY cp_title;
