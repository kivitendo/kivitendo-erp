-- @tag: tax_zones_obsolete
-- @description: Steuerzonen auf ungültig setzen können
-- @depends: change_taxzone_id_0
ALTER TABLE tax_zones ADD COLUMN obsolete boolean DEFAULT FALSE;
