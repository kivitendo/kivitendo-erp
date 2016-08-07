-- @tag: assembly_position
-- @description: Erzeugniselemente (assembly) erhalten eine Position
-- @depends: release_3_4_1
-- @ignore: 0

ALTER TABLE assembly ADD COLUMN position INTEGER;
