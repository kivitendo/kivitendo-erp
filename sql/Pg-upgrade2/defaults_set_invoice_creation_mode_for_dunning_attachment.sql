-- @tag: defaults_set_invoice_creation_mode_for_dunning_attachment
-- @description: Ursprungs-Rechnung von Mahnung konfigurierbar machen
-- @depends: release_3_7_0

CREATE TYPE invoice_creation_mode AS
  ENUM ('create_new', 'use_last_created_or_create_new');
ALTER TABLE defaults
  ADD COLUMN dunning_original_invoice_creation_mode invoice_creation_mode
  default 'create_new';

