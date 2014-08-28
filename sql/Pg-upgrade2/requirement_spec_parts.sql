-- @tag: requirement_spec_parts
-- @description: Artikelzuweisung zu Pflichtenheften
-- @depends: release_3_1_0
CREATE TABLE requirement_spec_parts (
  id                  SERIAL         NOT NULL,
  requirement_spec_id INTEGER        NOT NULL,
  part_id             INTEGER        NOT NULL,
  unit_id             INTEGER        NOT NULL,
  qty                 NUMERIC(15, 5) NOT NULL,
  description         TEXT           NOT NULL,
  position            INTEGER        NOT NULL,

  PRIMARY KEY (id),
  FOREIGN KEY (requirement_spec_id) REFERENCES requirement_specs (id),
  FOREIGN KEY (part_id)             REFERENCES parts             (id),
  FOREIGN KEY (unit_id)             REFERENCES units             (id)
);
