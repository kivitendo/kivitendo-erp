-- @tag: exchangerate_in_arap
-- @description: Wechselkurs optional in Belegen und Banktransaktionen speichern
-- @depends: release_3_6_1

ALTER TABLE ar                ADD COLUMN exchangerate NUMERIC(15,5);
ALTER TABLE ap                ADD COLUMN exchangerate NUMERIC(15,5);
ALTER TABLE bank_transactions ADD COLUMN exchangerate NUMERIC(15,5);
