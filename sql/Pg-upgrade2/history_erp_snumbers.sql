-- @tag: history_erp_snumbers
-- @description: Einführen der Buchungsnummern in die Historie
-- @depends: history_erp
ALTER TABLE history_erp ADD COLUMN snumbers text;
 