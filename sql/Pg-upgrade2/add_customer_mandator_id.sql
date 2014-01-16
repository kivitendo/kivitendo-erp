-- @tag: add_customer_mandator_id
-- @description: Einführen einer Mandanten-ID- und Signatur-Datums-Spalte bei Kunden.
-- @depends: release_3_0_0

ALTER TABLE customer          ADD COLUMN mandator_id                  text;
ALTER TABLE customer          ADD COLUMN mandate_date_of_signature    date;
ALTER TABLE sepa_export_items ADD COLUMN vc_mandator_id               text;
ALTER TABLE sepa_export_items ADD COLUMN vc_mandate_date_of_signature date;

UPDATE sepa_export_items
SET vc_mandator_id = (
  SELECT c.customernumber
  FROM ar
  LEFT JOIN customer c ON (ar.customer_id = c.id)
  WHERE ar.id = sepa_export_items.ar_id
),
vc_mandate_date_of_signature = '2010-01-01'::date
WHERE ar_id IS NOT NULL;
