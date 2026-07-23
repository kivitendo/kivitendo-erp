-- @tag: add_gl_use_as_direct_bank_import_template
-- @description: Dialogbuchungsvorlagen kennzeichnen die direkt als Quelle vom Bankimport bebucht werden dürfen
-- @depends: release_4_0_0

ALTER TABLE gl ADD bank_import_template boolean DEFAULT false;
ALTER TABLE record_templates ADD bank_import_template boolean DEFAULT false;


