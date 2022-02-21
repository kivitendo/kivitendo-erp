-- @tag: add_record_templates_transaction_description
-- @description: Vorgangsbezeichnung in Dialog-Vorlage ergänzen
-- @depends: release_3_5_8 create_record_template_tables

ALTER TABLE record_templates ADD COLUMN transaction_description TEXT;
