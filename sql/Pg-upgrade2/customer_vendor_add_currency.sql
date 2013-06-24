-- @tag: customer_vendor_add_currency
-- @description: Spalten für Währung bei Kunde/Lieferant
-- @depends: release_2_6_3
ALTER TABLE customer ADD COLUMN curr character(3);
ALTER TABLE vendor   ADD COLUMN curr character(3);
