-- @tag: letter_vendorletter
-- @description: Briefe jetzt auch für Lieferanten
-- @depends: release_3_4_1

ALTER TABLE letter ALTER COLUMN customer_id DROP NOT NULL;
ALTER TABLE letter ADD COLUMN vendor_id INTEGER REFERENCES vendor(id);

ALTER TABLE letter_draft ALTER COLUMN customer_id DROP NOT NULL;
ALTER TABLE letter_draft ADD COLUMN vendor_id INTEGER REFERENCES vendor(id);
