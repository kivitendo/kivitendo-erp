-- @tag: delete_warehouse_for_assembly
-- @description: Entfernen von: Konfigurations-Option für das Fertigen von Erzeugnissen aus dem Standardlager
-- @depends: release_3_5_7
ALTER TABLE defaults DROP column transfer_default_warehouse_for_assembly;
