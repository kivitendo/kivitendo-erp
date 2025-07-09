-- @tag: file_versions_guid_as_primary_key
-- @description: guid-Spalte als Primärschlüssel
-- @depends: release_3_6_0 file_version

ALTER TABLE file_versions
   DROP CONSTRAINT  file_versions_pkey,
   ADD  UNIQUE      (guid),
   ADD  PRIMARY KEY (guid);
