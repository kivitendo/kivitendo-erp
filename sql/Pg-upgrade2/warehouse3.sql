-- @tag: warehouse3
-- @description: Defaultwert für onhand nochmal erneut setzen nach Bugfix für 1289 Gutschriften auf Rechnungen lösen Lagerbewegung aus
-- @depends: warehouse2 release_2_6_0
UPDATE parts SET onhand = COALESCE((SELECT SUM(qty) FROM inventory WHERE inventory.parts_id = parts.id), 0);
