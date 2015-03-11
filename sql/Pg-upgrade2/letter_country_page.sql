-- @tag: letter_country_page
-- @description: Brieffunktion Felder Update
-- @depends: letter

ALTER TABLE letter ADD COLUMN rcv_country TEXT;
ALTER TABLE letter ADD COLUMN page_created_for TEXT;

