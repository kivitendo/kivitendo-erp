-- @tag: defaults_assembly_level
-- @description: Mandantenkonfiguration: Erzeugnis fertigen und alle Untererzeugnisse mitfertigen (standardmäßig deaktiviert)
-- @depends: release_3_5_6_1

ALTER TABLE defaults ADD COLUMN produce_assembly_multiple_levels BOOLEAN DEFAULT FALSE;
