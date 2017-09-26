-- @tag: alter_record_template_tables
-- @description: Haken Details anzeigen in Dialog-Vorlage ergänzen
-- @depends: release_3_5_0 create_record_template_tables

ALTER TABLE record_templates ADD column show_details BOOLEAN NOT NULL DEFAULT FALSE;

