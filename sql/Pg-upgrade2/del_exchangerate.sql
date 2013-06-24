-- @tag: del_exchangerate
-- @description: Löscht Trigger del_exchangerate und macht damit das Löschen von Belegen wieder möglich.
-- @depends: release_3_0_0

DROP TRIGGER IF EXISTS del_exchangerate ON ar;
DROP TRIGGER IF EXISTS del_exchangerate ON ap;
DROP TRIGGER IF EXISTS del_exchangerate ON oe;
DROP TRIGGER IF EXISTS del_exchangerate ON delivery_orders;

DROP FUNCTION IF EXISTS del_exchangerate();
