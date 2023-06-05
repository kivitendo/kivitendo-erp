-- @tag: add_business_models
-- @description: Tabelle für Kunden-/Lieferantentyp-Artikelnummern und Beschreibung
-- @depends: release_3_8_0

CREATE TABLE business_models (
  parts_id               integer NOT NULL,
  business_id            integer NOT NULL,
  model                  text,
  part_description       text,
  part_longdescription   text,

  itime                  timestamp              DEFAULT now(),
  mtime                  timestamp,

  FOREIGN KEY (parts_id)    REFERENCES parts(id),
  FOREIGN KEY (business_id) REFERENCES business(id),

  PRIMARY KEY(parts_id, business_id)
);

CREATE TRIGGER mtime_business_models BEFORE UPDATE ON business_models
    FOR EACH ROW EXECUTE PROCEDURE set_mtime();
