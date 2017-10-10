-- @tag: recorditem_active_price_source
-- @description: Preisquelle in Belegpositionen
-- @depends: release_3_1_0

ALTER TABLE orderitems           ADD COLUMN active_price_source TEXT NOT NULL DEFAULT '';
ALTER TABLE delivery_order_items ADD COLUMN active_price_source TEXT NOT NULL DEFAULT '';
ALTER TABLE invoice              ADD COLUMN active_price_source TEXT NOT NULL DEFAULT '';

UPDATE orderitems           SET active_price_source = 'pricegroup/' || pricegroup_id WHERE pricegroup_id > 0;
UPDATE delivery_order_items SET active_price_source = 'pricegroup/' || pricegroup_id WHERE pricegroup_id > 0;
UPDATE invoice              SET active_price_source = 'pricegroup/' || pricegroup_id WHERE pricegroup_id > 0;
