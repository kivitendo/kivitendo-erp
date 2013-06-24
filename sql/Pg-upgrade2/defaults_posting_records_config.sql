-- @tag: defaults_posting_records_config
-- @description: Einstellung, ob und wann Belegbuchungen änderbar/löschbar sind.
-- @depends: release_2_7_0

ALTER TABLE defaults ADD COLUMN is_changeable integer NOT NULL DEFAULT 2;
ALTER TABLE defaults ADD COLUMN ir_changeable integer NOT NULL DEFAULT 2;
ALTER TABLE defaults ADD COLUMN ar_changeable integer NOT NULL DEFAULT 2;
ALTER TABLE defaults ADD COLUMN ap_changeable integer NOT NULL DEFAULT 2;
ALTER TABLE defaults ADD COLUMN gl_changeable integer NOT NULL DEFAULT 2;
