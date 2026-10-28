-- @tag: records_add_notes_bottom
-- @description: zweites Bemerkungsfeld (unter der Positionstabelle) auf allen druckbaren Belegen hinzufügen
-- @depends: release_4_1_0

ALTER TABLE oe              ADD COLUMN notes_bottom text;
ALTER TABLE delivery_orders ADD COLUMN notes_bottom text;
ALTER TABLE ar              ADD COLUMN notes_bottom text;
ALTER TABLE ap              ADD COLUMN notes_bottom text;
ALTER TABLE reclamations    ADD COLUMN notes_bottom text;
