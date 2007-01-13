-- @tag: customer_vendor_ustid_length
-- @description: Setzt das Feld &quot;ustid&quot; in den Tabellen &quot;customer&quot; und &quot;vendor&quot; auf 14 Zeichen: zwei Zeichen L&auml;nderk&uuml;rzel und bis zu zw&ouml;lf Zeichen f&uuml;r die Nummer.
-- @depends:
ALTER TABLE customer ADD COLUMN tmp varchar(14);
UPDATE customer SET tmp = ustid;
ALTER TABLE customer DROP COLUMN ustid;
ALTER TABLE customer RENAME tmp TO ustid;

ALTER TABLE vendor ADD COLUMN tmp varchar(14);
UPDATE vendor SET tmp = ustid;
ALTER TABLE vendor DROP COLUMN ustid;
ALTER TABLE vendor RENAME tmp TO ustid;
