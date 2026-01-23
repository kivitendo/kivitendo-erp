-- @tag: contacts_add_country_id
-- @description: Land an Contacts
-- @depends: release_3_9_2 countries

ALTER TABLE contacts ADD COLUMN cp_country_id integer REFERENCES countries(id);
