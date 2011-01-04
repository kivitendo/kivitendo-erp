-- @tag: schema_normalization_3
-- @description: Datenbankschema Normalisierungen Teil 3
-- @depends: schema_normalization_2 acc_trans_id_uniqueness

ALTER TABLE acc_trans DROP COLUMN id;
ALTER TABLE acc_trans ADD PRIMARY KEY (acc_trans_id);
