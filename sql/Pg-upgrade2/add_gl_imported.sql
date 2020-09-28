-- @tag: add_gl_imported
-- @description: Dialogbuchungsimport entsprechend kennzeichnen
-- @depends: release_3_5_6

ALTER TABLE gl ADD imported BOOLEAN DEFAULT 'f';

