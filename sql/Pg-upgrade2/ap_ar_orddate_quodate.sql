-- @tag: ap_ar_orddate_quodate
-- @description: Spalten f&uuml;r Angebots- und Auftragsdatum bei Einkaufs- und Verkaufsrechnungen
-- @depends: release_2_4_1
ALTER TABLE ar ADD COLUMN orddate date;
ALTER TABLE ar ADD COLUMN quodate date;
ALTER TABLE ap ADD COLUMN orddate date;
ALTER TABLE ap ADD COLUMN quodate date;
