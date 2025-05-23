-- @tag: customer_mandate_used
-- @description: Kundenstammdaten: Feld für Verfolgung, ob SEPA-Mandat benutzt wurde
-- @depends: release_3_9_2
ALTER TABLE customer
ADD COLUMN mandate_used BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE customer
SET mandate_used = TRUE
WHERE EXISTS (
  SELECT sei.sepa_export_id
  FROM sepa_export_items sei
  LEFT JOIN ar ON (sei.ar_id = ar.id)
  WHERE (ar.customer_id = customer.id)
    AND (sei.vc_mandator_id = customer.mandator_id)
  LIMIT 1
);

ALTER TABLE sepa_export_items
ADD COLUMN vc_mandate_used BOOLEAN NOT NULL DEFAULT TRUE;

UPDATE sepa_export_items sei1
SET vc_mandate_used = FALSE
WHERE (sei1.ar_id IS NOT NULL)
  AND (sei1.id = (
    SELECT sei2.id
    FROM sepa_export_items sei2
    LEFT JOIN ar ar2 ON (sei2.ar_id = ar2.id)
    WHERE (sei2.ar_id IS NOT NULL)
      AND (ar2.customer_id = (
             SELECT ar1.customer_id
             FROM ar ar1
             WHERE sei1.ar_id = ar1.id))
      AND (sei1.vc_mandator_id = sei2.vc_mandator_id)
    ORDER BY sei2.id
    LIMIT 1
));
