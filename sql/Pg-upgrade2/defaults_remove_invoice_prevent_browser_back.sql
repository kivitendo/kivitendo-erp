-- @tag: defaults_remove_invoice_prevent_browser_back
-- @description: "Verhinderung Browser-Zurück-Knopf einstellbar in Mandantenkonfiguration" wieder raus
-- @depends: defaults_invoice_prevent_browser_back

ALTER TABLE defaults DROP COLUMN invoice_prevent_browser_back;
