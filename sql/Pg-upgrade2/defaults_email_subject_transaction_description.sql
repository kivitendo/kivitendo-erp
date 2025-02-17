-- @tag: defaults_email_subject_transaction_description
-- @description: Einstellung, ob die Vorgangsbezeichnung im E-Mail Betreff vorbelegt wird
-- @depends: release_3_9_1

ALTER TABLE defaults ADD COLUMN email_subject_transaction_description boolean DEFAULT FALSE;
