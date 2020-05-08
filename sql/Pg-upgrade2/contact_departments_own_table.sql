-- @tag: contact_departments_own_table
-- @description: Eigene Tabelle für Abteilungen bei Ansprechpersonen
-- @depends: release_3_5_5

CREATE TABLE contact_departments (
  id          SERIAL,
  description TEXT    NOT NULL,
  PRIMARY KEY (id),
  UNIQUE (description)
);

UPDATE contacts SET cp_abteilung = trim(cp_abteilung) WHERE cp_abteilung NOT LIKE trim(cp_abteilung);

INSERT INTO contact_departments (description)
  SELECT DISTINCT cp_abteilung FROM contacts WHERE cp_abteilung IS NOT NULL AND cp_abteilung NOT LIKE '' ORDER BY cp_abteilung;
