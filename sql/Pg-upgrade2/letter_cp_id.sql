-- @tag: letter_cp_id
-- @description: Ansprechpartner Link
-- @depends: letter_notes_internal

ALTER TABLE letter ADD COLUMN cp_id integer;
ALTER TABLE letter ADD FOREIGN KEY (cp_id) REFERENCES contacts(cp_id);
