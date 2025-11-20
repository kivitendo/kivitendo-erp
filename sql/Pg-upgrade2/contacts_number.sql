-- @tag: contacts_number
-- @description: Ansprechpartnernummernkreis
-- @depends: release_3_9_2 shared_contacts

ALTER TABLE defaults ADD COLUMN contactnumber text;
ALTER TABLE contacts ADD COLUMN cp_number text;

WITH cte AS (SELECT cp_id, row_number() over(ORDER BY cp_id) AS seq FROM contacts)
UPDATE contacts SET cp_number = cte.seq FROM cte WHERE contacts.cp_id = cte.cp_id;
