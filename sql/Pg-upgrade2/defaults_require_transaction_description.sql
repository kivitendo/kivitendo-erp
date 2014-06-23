-- @tag: defaults_require_transaction_description
-- @description: Mandantenkonfiguration: optional Existenz der Vorgangsbezeichnung erzwingen
-- @depends: release_3_1_0
ALTER TABLE defaults ADD COLUMN require_transaction_description_ps BOOLEAN;
UPDATE defaults SET require_transaction_description_ps = FALSE;

ALTER TABLE defaults
  ALTER COLUMN require_transaction_description_ps SET DEFAULT FALSE,
  ALTER COLUMN require_transaction_description_ps SET NOT NULL;
