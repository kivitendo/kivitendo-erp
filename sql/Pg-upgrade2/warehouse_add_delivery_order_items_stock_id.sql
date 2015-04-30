-- @tag: warehouse_add_delivery_order_items_stock_id
-- @description: Constraints für inventory auf delivery_order (dois und do). Ferner sinnvolle Umbenennung zumindestens von einer Spalte (orderitems -> dois). <br><b>Falls die Constraint nicht gesetzt werden kann, kontaktieren Sie einen Dienstleister und / oder löschen sie die Verknüpfung der Warenbewegung mit Lieferschein auf eigene Verantwortung mit: "UPDATE inventory SET oe_id = NULL WHERE oe_id NOT IN (select id from delivery_orders);"<br>Hintergrund: Eingelagerte Lieferscheine können / sollen nicht gelöscht werden, allerdings weist dieser Datenbestand genau diesen Fall auf.</b>
-- @depends: release_3_1_0 remove_obsolete_trigger
ALTER TABLE inventory RENAME orderitems_id TO delivery_order_items_stock_id;
ALTER TABLE inventory ADD CONSTRAINT delivery_order_items_stock_id_fkey FOREIGN KEY (delivery_order_items_stock_id) REFERENCES delivery_order_items_stock (id);
ALTER TABLE inventory ADD CONSTRAINT oe_id_fkey FOREIGN KEY (oe_id) REFERENCES delivery_orders (id);
