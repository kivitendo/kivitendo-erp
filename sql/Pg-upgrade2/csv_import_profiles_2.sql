-- @tag: csv_import_profiles_2
-- @description: Tempflag in CSV-Import-Profilen
-- @depends: csv_import_profiles

ALTER TABLE csv_import_profiles ADD COLUMN login TEXT;
