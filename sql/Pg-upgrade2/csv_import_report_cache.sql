-- @tag: csv_import_report_cache
-- @description: Csv Import Cache
-- @depends: csv_import_profiles_2
-- @encoding: utf-8

CREATE TABLE csv_import_reports (
  id                   SERIAL PRIMARY KEY,
  session_id           TEXT NOT NULL,
  profile_id           INTEGER NOT NULL REFERENCES csv_import_profiles(id),
  type                 TEXT NOT NULL,
  file                 TEXT NOT NULL
);

CREATE TABLE csv_import_report_rows (
  id                   SERIAL PRIMARY KEY,
  csv_import_report_id INTEGER NOT NULL REFERENCES csv_import_reports(id),
  col                  INTEGER NOT NULL,
  row                  INTEGER NOT NULL,
  value                TEXT
);

CREATE TABLE csv_import_report_row_status (
  id                   SERIAL PRIMARY KEY,
  csv_import_report_row_id INTEGER NOT NULL REFERENCES csv_import_report_rows(id),
  type                 TEXT NOT NULL,
  value                TEXT
);

ALTER TABLE csv_import_profiles DROP constraint "csv_import_profiles_name_key";
