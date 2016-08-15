-- @tag: add_test_mode_to_csv_import_report
-- @description: In CSV-Import-Berichtstabelle speichern, ob es ein Test war
-- @depends: release_3_4_1
ALTER TABLE csv_import_reports ADD COLUMN test_mode BOOLEAN;

UPDATE csv_import_reports SET test_mode = TRUE;

ALTER TABLE csv_import_reports ALTER COLUMN test_mode SET NOT NULL;
