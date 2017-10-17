-- @tag: create_pieces
-- @description: neue Tabelle für Exemplare einer Produktionseinheit
-- @depends: release_3_5_0 defaults_add_feature_production create_batches

CREATE TABLE pieces (
  id              SERIAL               PRIMARY KEY,
  itime           TIMESTAMP            NOT NULL DEFAULT now(),
  mtime           TIMESTAMP,
  deleted         BOOLEAN              NOT NULL DEFAULT FALSE,
  serialnumber    TEXT                 NOT NULL,
  weight          REAL,
  notes           TEXT,

  producer_id     integer NOT NULL REFERENCES vendor          (id) ON DELETE RESTRICT,
  part_id         integer NOT NULL REFERENCES parts           (id) ON DELETE RESTRICT,
  batch_id        integer          REFERENCES batches         (id) ON DELETE RESTRICT,
  delivery_in_id  integer          REFERENCES delivery_orders (id) ON DELETE RESTRICT,
  delivery_out_id integer          REFERENCES delivery_orders (id) ON DELETE RESTRICT,
  bin_id          integer          REFERENCES bin             (id) ON DELETE RESTRICT,
  employee_id     integer          REFERENCES employee        (id) ON DELETE SET NULL,

  UNIQUE (producer_id, part_id, batch_id, serialnumber)
);

CREATE TRIGGER mtime_pieces BEFORE UPDATE ON pieces FOR EACH ROW EXECUTE PROCEDURE set_mtime();
