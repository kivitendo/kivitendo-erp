-- @tag: defaults_invoice_prevent_browser_back
-- @description: Verhinderung Browser-Zurück-Knopf einstellbar in Mandantenkonfiguration
-- @depends: release_3_6_0

ALTER TABLE defaults ADD COLUMN invoice_prevent_browser_back boolean NOT NULL DEFAULT FALSE;
