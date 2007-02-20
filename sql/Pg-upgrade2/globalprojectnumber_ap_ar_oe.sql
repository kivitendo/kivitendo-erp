-- @tag: globalprojectnumber_ap_ar_oe
-- @description: Neue Spalte f&uuml;r eine globale Projektnummer in Einkaufs- und Verkaufsbelegen
-- @depends: release_2_4_1
ALTER TABLE ap ADD COLUMN globalproject_id integer;
ALTER TABLE ap ADD FOREIGN KEY (globalproject_id) REFERENCES project (id);
ALTER TABLE ar ADD COLUMN globalproject_id integer;
ALTER TABLE ar ADD FOREIGN KEY (globalproject_id) REFERENCES project (id);
ALTER TABLE oe ADD COLUMN globalproject_id integer;
ALTER TABLE oe ADD FOREIGN KEY (globalproject_id) REFERENCES project (id);
