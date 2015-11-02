-- @tag: buchungsgruppen_forein_keys
-- @description: Fremdschlüssel für Tabelle buchungsgruppen
-- @depends: release_3_3_0
ALTER TABLE buchungsgruppen ADD FOREIGN KEY (inventory_accno_id) REFERENCES chart (id);
ALTER TABLE buchungsgruppen ALTER COLUMN     inventory_accno_id SET NOT NULL;
