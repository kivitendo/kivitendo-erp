-- @tag: defaults_posting_records_add
-- @description: Einstellung, ob Belege (PDF) zu einer Buchung hinzugefügt werden sollen
-- @depends: release_3_5_6_1

ALTER TABLE defaults ADD COLUMN ir_add_doc BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE defaults ADD COLUMN ar_add_doc BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE defaults ADD COLUMN ap_add_doc BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE defaults ADD COLUMN gl_add_doc BOOLEAN NOT NULL DEFAULT true;
