-- @tag: customer_orderlock
-- @description: Boolean Auftragssperre benötigt bei shoporders
-- @depends: release_3_4_1 shops
-- @ignore: 0
ALTER TABLE customer ADD COLUMN order_lock boolean default 'f';
