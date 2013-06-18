-- @tag: gewichte
-- @description: Je nach Mandantenkonfiguration können Warengewichte in Angeboten/Aufträgen/Lieferscheinen/Rechnungen angezeigt werden oder nicht.
-- @depends: release_3_0_0

ALTER TABLE defaults ADD show_weight BOOLEAN NOT NULL DEFAULT FALSE;
