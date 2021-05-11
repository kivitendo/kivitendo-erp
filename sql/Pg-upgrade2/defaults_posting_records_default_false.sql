-- @tag: defaults_posting_records_default_false
-- @description: Einstellung, ob Belege (PDF) zu einer Buchung hinzugefügt werden sollen
-- @depends: release_3_5_6_1 defaults_posting_records_add

ALTER TABLE defaults ALTER COLUMN ir_add_doc SET DEFAULT false;
ALTER TABLE defaults ALTER COLUMN ar_add_doc SET DEFAULT false;
ALTER TABLE defaults ALTER COLUMN ap_add_doc SET DEFAULT false;
ALTER TABLE defaults ALTER COLUMN gl_add_doc SET DEFAULT false;

UPDATE defaults set ir_add_doc='false';
UPDATE defaults set ar_add_doc='false';
UPDATE defaults set ap_add_doc='false';
UPDATE defaults set gl_add_doc='false';
