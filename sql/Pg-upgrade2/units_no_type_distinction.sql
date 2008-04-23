-- @tag: units_no_type_distinction
-- @description: Aufhebung der Typenunterscheidung bei Einheiten
-- @depends: release_2_4_3
ALTER TABLE units ALTER COLUMN type DROP NOT NULL;

