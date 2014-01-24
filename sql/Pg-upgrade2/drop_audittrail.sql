-- @tag: drop_audittrail
-- @description: Tabelle audittrail wird nicht mehr benutzt
-- @depends: release_3_0_0
-- @ignore: 0
ALTER TABLE defaults DROP COLUMN audittrail;
DROP TABLE audittrail;
