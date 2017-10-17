-- @tag: create_batches
-- @description: neue Tabelle für Produktionseinheiten
-- @depends: release_3_5_0 defaults_add_feature_production

CREATE TABLE batches (
  id             SERIAL               PRIMARY KEY,
  itime          TIMESTAMP            NOT NULL DEFAULT now(),
  mtime          TIMESTAMP,
  deleted        BOOLEAN              NOT NULL DEFAULT FALSE,
  batchnumber    TEXT                 NOT NULL,
  batchdate      DATE                 NOT NULL DEFAULT ('now'::text)::date,
  location       TEXT,
  process        TEXT,
  notes          TEXT,

  producer_id integer NOT NULL REFERENCES vendor   (id) ON DELETE RESTRICT,
  part_id     integer NOT NULL REFERENCES parts    (id) ON DELETE RESTRICT,
  employee_id integer          REFERENCES employee (id) ON DELETE SET NULL,

  UNIQUE (producer_id, part_id, batchnumber),
  UNIQUE (producer_id, part_id, batchdate, location, process)
);

CREATE TRIGGER mtime_batches BEFORE UPDATE ON batches FOR EACH ROW EXECUTE PROCEDURE set_mtime();
