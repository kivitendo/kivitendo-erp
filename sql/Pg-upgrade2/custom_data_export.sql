-- @tag: custom_data_export
-- @description: Benutzerdefinierter Datenexport
-- @depends: release_3_5_0
CREATE TYPE custom_data_export_query_parameter_type_enum AS ENUM ('text', 'number', 'date', 'timestamp');

CREATE TABLE custom_data_export_queries (
  id           SERIAL,
  name         TEXT      NOT NULL,
  description  TEXT      NOT NULL,
  sql_query    TEXT      NOT NULL,
  access_right TEXT,
  itime        TIMESTAMP NOT NULL DEFAULT now(),
  mtime        TIMESTAMP NOT NULL DEFAULT now(),

  PRIMARY KEY (id)
);

CREATE TABLE custom_data_export_query_parameters (
  id             SERIAL,
  query_id       INTEGER NOT NULL,
  name           TEXT NOT NULL,
  description    TEXT,
  parameter_type custom_data_export_query_parameter_type_enum NOT NULL,
  itime          TIMESTAMP NOT NULL DEFAULT now(),
  mtime          TIMESTAMP NOT NULL DEFAULT now(),

  PRIMARY KEY (id),
  FOREIGN KEY (query_id) REFERENCES custom_data_export_queries (id) ON DELETE CASCADE
);

CREATE TRIGGER mtime_custom_data_export_queries
BEFORE UPDATE ON custom_data_export_queries
FOR EACH ROW EXECUTE PROCEDURE set_mtime();

CREATE TRIGGER mtime_custom_data_export_query_parameters
BEFORE UPDATE ON custom_data_export_query_parameters
FOR EACH ROW EXECUTE PROCEDURE set_mtime();
