-- @tag: defaults_add_rnd_accno_ids
-- @description: adds new columns 'rndgain_accno_id' and 'rndloss_accno_id' in table defaults, used to book roundings
-- @depends: release_3_1_0
ALTER TABLE defaults ADD COLUMN rndgain_accno_id Integer;
ALTER TABLE defaults ADD COLUMN rndloss_accno_id Integer;

