-- @tag: add_search_profiles
-- @description: Tabellen für Suchprofile (Speichern von Einstellungen in Berichtsmasken)
-- @depends: release_4_0_0
CREATE TYPE search_profiles_module_type AS ENUM (
  'ap/search'
);

CREATE TYPE search_profile_settings_value_type AS ENUM (
  'boolean',
  'date',
  'integer',
  'text'
);

CREATE TABLE search_profiles (
  id              SERIAL                      NOT NULL,
  employee_id     INTEGER                     NOT NULL,
  module          search_profiles_module_type NOT NULL,
  name            TEXT                        NOT NULL,
  default_profile BOOLEAN                     NOT NULL DEFAULT FALSE,
  itime           TIMESTAMP                   NOT NULL DEFAULT now(),
  mtime           TIMESTAMP,

  PRIMARY KEY (id),
  FOREIGN KEY (employee_id) REFERENCES employee (id) ON DELETE CASCADE
);

CREATE TRIGGER mtime_search_profiles
BEFORE UPDATE ON search_profiles
FOR EACH ROW
EXECUTE PROCEDURE set_mtime();

CREATE TABLE search_profile_settings (
  id                SERIAL                             NOT NULL,
  search_profile_id INTEGER                            NOT NULL,
  name              TEXT                               NOT NULL,
  type              search_profile_settings_value_type NOT NULL,
  boolean_value     BOOLEAN,
  integer_value     INTEGER,
  date_value        DATE,
  text_value        TEXT,
  itime             TIMESTAMP                          NOT NULL DEFAULT now(),
  mtime             TIMESTAMP,

  PRIMARY KEY (id),
  FOREIGN KEY (search_profile_id) REFERENCES search_profiles (id) ON DELETE CASCADE
);

CREATE TRIGGER mtime_search_profile_settings
BEFORE UPDATE ON search_profile_settings
FOR EACH ROW
EXECUTE PROCEDURE set_mtime();
