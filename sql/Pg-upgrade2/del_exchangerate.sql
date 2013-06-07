-- @tag: del_exchangerate
-- @description: Löscht Trigger del_exchangerate und macht damit das Löschen von Belegen wieder möglich.
-- @depends: release_3_0_0
-- @encoding: utf-8

DROP TRIGGER IF EXISTS del_exchangerate ON ar;
DROP TRIGGER IF EXISTS del_exchangerate ON ap;
DROP TRIGGER IF EXISTS del_exchangerate ON oe;

