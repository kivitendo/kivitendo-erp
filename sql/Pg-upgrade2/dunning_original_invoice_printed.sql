-- @tag: dunning_original_invoice_printed
-- @description: In der Tabelle dunning merken, ob beim Mahnlauf die originale Rechnung gedruckt wurde
-- @depends: release_3_5_6_1

ALTER TABLE dunning ADD COLUMN original_invoice_printed BOOLEAN DEFAULT false;
