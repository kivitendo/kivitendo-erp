-- @tag: defaults_add_mail_new_record
-- @description: Send printout of record: prefer creating a new printout
-- @depends: release_3_9_2

ALTER TABLE defaults ADD COLUMN email_default_create_new_record_checked boolean DEFAULT true;
