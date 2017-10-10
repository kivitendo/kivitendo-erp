-- @tag: oe_customer_vendor_fkeys
-- @description: Foreign Keys für customer und vendor in oe
-- @depends: release_2_6_3
UPDATE oe SET customer_id = NULL WHERE customer_id = 0;
UPDATE oe SET   vendor_id = NULL WHERE   vendor_id = 0;


ALTER TABLE oe ADD FOREIGN KEY (customer_id) REFERENCES customer(id);
ALTER TABLE oe ADD FOREIGN KEY (vendor_id)   REFERENCES vendor(id);
