-- @tag: defaults_drop_feature_vertreter
-- @description: Vertreter für Kunden (deaktiviert in 3.6) nun entfernt
-- @depends: release_3_9_2

ALTER TABLE defaults DROP COLUMN vertreter;
