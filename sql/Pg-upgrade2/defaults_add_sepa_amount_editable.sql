-- @tag: defaults_add_sepa_amount_editable
-- @description: Mandantekonfig: Beträge von SEPA Zahlungen gegen Editieren sperren
-- @depends: release_4_0_0

ALTER TABLE defaults ADD COLUMN sepa_amount_editable boolean NOT NULL DEFAULT FALSE;

