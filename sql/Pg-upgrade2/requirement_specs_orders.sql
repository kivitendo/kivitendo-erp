-- @tag: requirement_specs_orders
-- @description: requirement_specs_orders
-- @depends: requirement_specs requirement_specs_section_templates

-- Remove unneeded columns
ALTER TABLE requirement_spec_versions DROP CONSTRAINT requirement_spec_versions_order_id_fkey;

ALTER TABLE requirement_spec_versions DROP COLUMN order_date;
ALTER TABLE requirement_spec_versions DROP COLUMN order_number;
ALTER TABLE requirement_spec_versions DROP COLUMN order_id;

-- Add new columns to existing tables
ALTER TABLE requirement_spec_items ADD COLUMN order_part_id INTEGER;
ALTER TABLE requirement_spec_items ADD FOREIGN KEY (order_part_id) REFERENCES parts (id) ON DELETE SET NULL;

ALTER TABLE defaults ADD COLUMN requirement_spec_section_order_part_id INTEGER;
ALTER TABLE defaults ADD FOREIGN KEY (requirement_spec_section_order_part_id) REFERENCES parts (id) ON DELETE SET NULL;

-- Create new tables
CREATE TABLE requirement_spec_orders (
  id                  SERIAL,
  requirement_spec_id INTEGER NOT NULL,
  order_id            INTEGER NOT NULL,
  version_id          INTEGER,
  itime               TIMESTAMP NOT NULL DEFAULT now(),
  mtime               TIMESTAMP NOT NULL DEFAULT now(),

  PRIMARY KEY (id),
  FOREIGN KEY (requirement_spec_id) REFERENCES requirement_specs         (id) ON DELETE CASCADE,
  FOREIGN KEY (order_id)            REFERENCES oe                        (id) ON DELETE CASCADE,
  FOREIGN KEY (version_id)          REFERENCES requirement_spec_versions (id) ON DELETE SET NULL,
  CONSTRAINT requirement_spec_id_order_id_unique UNIQUE (requirement_spec_id, order_id)
);

CREATE TRIGGER mtime_requirement_spec_orders BEFORE UPDATE ON requirement_spec_orders FOR EACH ROW EXECUTE PROCEDURE set_mtime();
