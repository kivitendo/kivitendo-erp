-- @tag: defaults_produce_assembly_transfer_service
-- @description: Mandantenkonfiguration: Erzeugnis mit Dienstleistungen, Dienstleistung kann verbraucht werden
-- @depends: release_3_5_7

ALTER TABLE defaults ADD COLUMN produce_assembly_transfer_service  BOOLEAN DEFAULT FALSE;
