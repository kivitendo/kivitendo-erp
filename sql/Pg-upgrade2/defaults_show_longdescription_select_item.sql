-- @tag: defaults_show_longdescription_select_item
-- @description: Mandantenkonfiguration: Optional Langtext in Auswahlliste bei Artikelauswahl anzeigen
-- @depends: release_3_3_0
ALTER TABLE defaults ADD COLUMN show_longdescription_select_item    boolean DEFAULT FALSE;
