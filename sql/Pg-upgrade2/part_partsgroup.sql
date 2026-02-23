-- @tag: part_partsgroup
-- @description: Artikel Warengruppen Tabelle
-- @depends: release_4_0_0
-- @ignore: 0

CREATE TABLE part_partsgroup (
  parts_id INTEGER NOT NULL,
  partsgroup_id INTEGER NOT NULL,

  FOREIGN KEY (parts_id)    REFERENCES parts(id),
  FOREIGN KEY (partsgroup_id) REFERENCES partsgroup(id),

  PRIMARY KEY(parts_id, partsgroup_id)
);

INSERT INTO part_partsgroup (parts_id, partsgroup_id)
SELECT id, partsgroup_id FROM parts WHERE partsgroup_id IS NOT NULL;
