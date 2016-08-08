-- @tag: prices_delete_cascade
-- @description: Preisgruppenpreise Löschen wenn Artikel gelöscht wird
-- @depends: release_3_4_1

-- delete price entries if part is deleted
ALTER TABLE prices DROP constraint "$1", ADD FOREIGN KEY (pricegroup_id) REFERENCES pricegroup(id) ON DELETE CASCADE;
ALTER TABLE prices DROP constraint "$2", ADD FOREIGN KEY (parts_id)      REFERENCES parts(id)      ON DELETE CASCADE;
