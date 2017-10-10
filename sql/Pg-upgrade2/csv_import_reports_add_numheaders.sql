-- @tag: csv_import_reports_add_numheaders
-- @description: Anzahl der Header-Zeilen in Csv Import Report speichern
-- @depends: csv_import_report_cache

ALTER TABLE csv_import_reports ADD COLUMN numheaders INTEGER;
UPDATE csv_import_reports SET numheaders = 1;
ALTER TABLE csv_import_reports ALTER COLUMN numheaders SET NOT NULL;
