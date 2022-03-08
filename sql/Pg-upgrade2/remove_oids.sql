-- @tag: remove_oids
-- @description: OIDs von Tabellen entfernen
-- @depends: release_3_6_0
ALTER TABLE assembly             SET WITHOUT OIDS;
ALTER TABLE delivery_order_items SET WITHOUT OIDS;
ALTER TABLE invoice              SET WITHOUT OIDS;
ALTER TABLE orderitems           SET WITHOUT OIDS;
ALTER TABLE parts                SET WITHOUT OIDS;
ALTER TABLE partsgroup           SET WITHOUT OIDS;
