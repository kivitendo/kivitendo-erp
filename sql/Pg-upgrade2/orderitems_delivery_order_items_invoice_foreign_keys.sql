-- @tag: orderitems_delivery_order_items_invoice_foreign_keys
-- @description: Fremdschlüssel für Tabellen oderitems, delivery_order_items, invoice
-- @depends: release_3_0_0
UPDATE orderitems           SET pricegroup_id = NULL WHERE pricegroup_id = 0;
UPDATE delivery_order_items SET pricegroup_id = NULL WHERE pricegroup_id = 0;
UPDATE invoice              SET pricegroup_id = NULL WHERE pricegroup_id = 0;

UPDATE orderitems           SET project_id = NULL WHERE project_id NOT IN (SELECT id FROM project);
UPDATE delivery_order_items SET project_id = NULL WHERE project_id NOT IN (SELECT id FROM project);
UPDATE invoice              SET project_id = NULL WHERE project_id NOT IN (SELECT id FROM project);

DELETE FROM orderitems WHERE trans_id NOT IN (SELECT id FROM oe);

ALTER TABLE orderitems           ADD FOREIGN KEY (trans_id)        REFERENCES oe            (id);
ALTER TABLE orderitems           ADD FOREIGN KEY (project_id)      REFERENCES project       (id);
ALTER TABLE orderitems           ADD FOREIGN KEY (pricegroup_id)   REFERENCES pricegroup    (id);
ALTER TABLE orderitems           ADD FOREIGN KEY (price_factor_id) REFERENCES price_factors (id);

ALTER TABLE delivery_order_items ADD FOREIGN KEY (pricegroup_id)   REFERENCES pricegroup    (id);

ALTER TABLE invoice              ADD FOREIGN KEY (project_id)      REFERENCES project       (id);
ALTER TABLE invoice              ADD FOREIGN KEY (pricegroup_id)   REFERENCES pricegroup    (id);
ALTER TABLE invoice              ADD FOREIGN KEY (price_factor_id) REFERENCES price_factors (id);
