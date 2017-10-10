-- @tag: employee_drop_columns
-- @description: Obsolete Felder in employee entfernt und Datenfelder zum Speichern für die Historie der Mitarbeiter (nach Löschen eines Benutzer) hinzugefügt. Aktuell alle Felder die der Benutzer unter persönliche Einstellungen ändern kann
-- @depends: release_3_0_0
-- @ignore: 0
ALTER TABLE employee DROP COLUMN addr1;
ALTER TABLE employee DROP COLUMN addr2;
ALTER TABLE employee DROP COLUMN addr3;
ALTER TABLE employee DROP COLUMN addr4;
ALTER TABLE employee DROP COLUMN homephone;
ALTER TABLE employee DROP COLUMN workphone;
ALTER TABLE employee DROP COLUMN notes;
ALTER TABLE employee ADD COLUMN deleted_email text;
ALTER TABLE employee ADD COLUMN deleted_signature text;
ALTER TABLE employee ADD COLUMN deleted_tel text;
ALTER TABLE employee ADD COLUMN deleted_fax text;
