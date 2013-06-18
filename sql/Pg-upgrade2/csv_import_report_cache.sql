-- @tag: csv_import_report_cache
-- @description: Csv Import Cache
-- @depends: csv_import_profiles_2

CREATE TABLE csv_import_reports (
  id                   SERIAL PRIMARY KEY,
  session_id           TEXT NOT NULL,
  profile_id           INTEGER NOT NULL REFERENCES csv_import_profiles(id),
  type                 TEXT NOT NULL,
  file                 TEXT NOT NULL,
  numrows              INTEGER NOT NULL
);

CREATE TABLE csv_import_report_rows (
  id                   SERIAL PRIMARY KEY,
  csv_import_report_id INTEGER NOT NULL REFERENCES csv_import_reports(id),
  col                  INTEGER NOT NULL,
  row                  INTEGER NOT NULL,
  value                TEXT
);

CREATE TABLE csv_import_report_status (
  id                   SERIAL PRIMARY KEY,
  csv_import_report_id INTEGER NOT NULL REFERENCES csv_import_reports(id),
  row                  INTEGER NOT NULL,
  type                 TEXT NOT NULL,
  value                TEXT
);

ALTER TABLE csv_import_profiles DROP constraint "csv_import_profiles_name_key";

CREATE INDEX "csv_import_report_rows_index_row" ON csv_import_report_rows (row);
