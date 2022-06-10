-- @tag: on_delete_oe_version_trigger
-- @description: Löschen in OE muss auch das Löschen aller Unterversionen triggern
-- @depends: oe_version

ALTER TABLE oe_version
DROP CONSTRAINT oe_version_oe_id_fkey,
ADD CONSTRAINT oe_version_oe_id_fkey FOREIGN KEY (oe_id) REFERENCES oe(id) ON DELETE CASCADE;
