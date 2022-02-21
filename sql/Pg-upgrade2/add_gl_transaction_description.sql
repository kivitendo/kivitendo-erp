-- @tag: add_gl_transaction_description
-- @description: Vorgangsbezeichnung für Dialogbuchungen
-- @depends: release_3_5_8

ALTER TABLE gl ADD transaction_description TEXT;
