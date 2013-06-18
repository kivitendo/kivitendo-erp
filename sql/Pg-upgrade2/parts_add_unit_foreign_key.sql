-- @tag: parts_add_unit_foreign_key
-- @description: Einheiten die Waren zugeordnet sind entsprechend als Fremdschlüssel verknüpfen.
-- @depends: release_2_6_3
-- @ignore: 0
ALTER TABLE parts ADD FOREIGN KEY (unit) REFERENCES units(name);
