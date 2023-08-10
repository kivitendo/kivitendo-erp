-- @tag: charts_cleared
-- @description: Ausziffern für Konten ermöglichen
-- @depends: release_3_8_0
-- @ignore: 0

CREATE TABLE cleared_group (
  id SERIAL PRIMARY KEY,
  employee_id INTEGER NOT NULL REFERENCES employee(id),
  itime timestamp DEFAULT now()
);

-- deleting an acc_trans record shouldn't be possible unless all cleared entries have been deleted
-- deleting the cleared_group should remove all cleared entries
CREATE TABLE cleared (
  acc_trans_id      bigint UNIQUE NOT NULL REFERENCES acc_trans(acc_trans_id),
  cleared_group_id  int    NOT NULL REFERENCES cleared_group(id) ON DELETE CASCADE,
  primary key (cleared_group_id, acc_trans_id)
);

-- which charts should be activated for clearing
ALTER TABLE chart ADD COLUMN clearing BOOLEAN DEFAULT false NOT NULL;
