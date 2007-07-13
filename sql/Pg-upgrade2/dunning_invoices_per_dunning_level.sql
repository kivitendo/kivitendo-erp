-- @tag: dunning_invoices_per_dunning_level
-- @description: Umstellung der Konfiguration f&uuml;r das automatische Erzeugen von Rechnungen &uuml;ber Mahngeb&uuml;hren von &quot;global&quot; auf &quot;pro Mahnlevel&quot;
-- @depends: dunning_invoices_for_fees
ALTER TABLE dunning_config ADD COLUMN create_invoices_for_fees boolean;
ALTER TABLE dunning_config ALTER COLUMN create_invoices_for_fees SET DEFAULT TRUE;
UPDATE dunning_config SET create_invoices_for_fees =
  (SELECT dunning_create_invoices_for_fees FROM defaults LIMIT 1);
ALTER TABLE defaults DROP COLUMN dunning_create_invoices_for_fees;
