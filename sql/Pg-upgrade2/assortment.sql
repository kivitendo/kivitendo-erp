-- @tag: assortment_items
-- @description: Sortimentsartikel eingeführt
-- @depends: release_3_4_1 part_type_enum

-- adding a new value isn't allowed inside a transaction, which is what DBUpgrade automatically does
-- run this afterwards manually for now
-- ALTER TYPE part_type_enum ADD VALUE 'assortment';

CREATE TABLE assortment_items (
  assortment_id INTEGER REFERENCES parts(id) ON DELETE CASCADE, -- the part id of the assortment
  parts_id      INTEGER REFERENCES parts(id),
  itime         timestamp without time zone default now(),
  mtime         timestamp without time zone,
  qty           REAL NOT NULL,
  position      INTEGER NOT NULL,
  unit          character varying(20) NOT NULL REFERENCES units(name),
  CONSTRAINT assortment_part_pkey PRIMARY KEY (assortment_id, parts_id)
);

ALTER TABLE defaults ADD assortmentnumber TEXT;
