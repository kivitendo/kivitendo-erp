-- @tag: drop_gifi
-- @description: Entfernt Spalten gifi_accno und pos_ustva aus der Tabelle chart. Tabelle gifi wird gelöscht.
-- @depends: release_3_0_0 

  --Lösche Tabelle gifi:
  DROP TABLE gifi;

  --Lösche Spalte gifi_accno aus chart:
  ALTER TABLE chart DROP COLUMN gifi_accno;

  --Lösche Spalte pos_ustva aus chart:
  ALTER TABLE chart DROP COLUMN pos_ustva;
