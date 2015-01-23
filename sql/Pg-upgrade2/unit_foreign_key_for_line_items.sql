-- @tag: unit_foreign_key_for_line_items
-- @description: Fremdschlüssel auf »unit« für Beleg-Positionstabellen
-- @depends: release_3_0_0 oe_do_delete_via_trigger
ALTER TABLE orderitems           ADD FOREIGN KEY (unit) REFERENCES units (name);
ALTER TABLE delivery_order_items ADD FOREIGN KEY (unit) REFERENCES units (name);
ALTER TABLE invoice              ADD FOREIGN KEY (unit) REFERENCES units (name);
