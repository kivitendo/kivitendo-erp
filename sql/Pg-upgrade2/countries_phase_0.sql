-- @tag: countries_phase_0
-- @description: Setzt Länder-Auswahlmenü als Pflichtfeld für Kunden und Lieferanten sowie als optionales Feld für abweichende Liefer- und Rechnungsadressen
-- @depends: release_4_0_0

CREATE TABLE countries (
  id             SERIAL PRIMARY KEY,
  iso2           TEXT NOT NULL UNIQUE,
  description_en TEXT NOT NULL,
  description_de TEXT NOT NULL,
  sortorder      INTEGER,
  itime          TIMESTAMP NOT NULL DEFAULT now(),
  mtime          TIMESTAMP
);

CREATE TRIGGER mtime_countries
BEFORE UPDATE ON countries
FOR EACH ROW
EXECUTE PROCEDURE set_mtime();


ALTER TABLE customer ADD COLUMN country_id INTEGER REFERENCES countries(id);
ALTER TABLE vendor   ADD COLUMN country_id INTEGER REFERENCES countries(id);
ALTER TABLE shipto                       ADD column shiptocountry_id INTEGER REFERENCES countries(id);
ALTER TABLE additional_billing_addresses ADD column country_id       INTEGER REFERENCES countries(id);
ALTER TABLE defaults ADD COLUMN address_country_id INTEGER REFERENCES countries(id);
ALTER TABLE contacts ADD COLUMN cp_country_id      INTEGER REFERENCES countries(id);
