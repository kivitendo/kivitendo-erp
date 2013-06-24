-- @tag: csv_import_profiles
-- @description: CSV-Import-Profile für Stammdaten
-- @depends: release_2_6_1
CREATE TABLE csv_import_profiles (
       id SERIAL        NOT NULL,
       name text        NOT NULL,
       type varchar(20) NOT NULL,
       is_default boolean DEFAULT FALSE,

       PRIMARY KEY (id),
       UNIQUE (name)
);

CREATE TABLE csv_import_profile_settings (
       id SERIAL                     NOT NULL,
       csv_import_profile_id integer NOT NULL,
       key text                      NOT NULL,
       value text,

       PRIMARY KEY (id),
       FOREIGN KEY (csv_import_profile_id) REFERENCES csv_import_profiles (id),
       UNIQUE (csv_import_profile_id, key)
);
