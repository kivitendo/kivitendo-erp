-- @tag: dunning_invoices_for_fees
-- @description: Konfiguration f&uuml;r das automatische Erzeugen von Rechnungen &uuml;ber Mahngeb&uuml;hren sowie eine Verkn&uuml;pfung zwischen Mahnungen und den dazu erzeugten Rechnungen.
-- @depends: release_2_4_2
ALTER TABLE defaults ADD COLUMN dunning_create_invoices_for_fees boolean;
ALTER TABLE defaults ADD COLUMN dunning_AR_amount_fee integer;
ALTER TABLE defaults ADD COLUMN dunning_AR_amount_interest integer;
ALTER TABLE defaults ADD COLUMN dunning_AR integer;
UPDATE defaults SET dunning_create_invoices_for_fees = 'f';

ALTER TABLE dunning ADD COLUMN fee_interest_ar_id integer;
ALTER TABLE dunning ADD FOREIGN KEY (fee_interest_ar_id) REFERENCES ar (id);
