-- @tag: change_file_backend_to_enum
-- @description: Backend für Dateien auf Type Enum setzen
-- @depends: release_3_6_0

CREATE TYPE files_backends AS ENUM ('Filesystem', 'Webdav');

ALTER TABLE files ADD COLUMN backend_new files_backends;
UPDATE files SET backend_new = 'Filesystem' WHERE backend = 'Filesystem';
UPDATE files SET backend_new = 'Webdav'     WHERE backend = 'Webdav';
ALTER TABLE files ALTER COLUMN backend_new SET NOT NULL;
ALTER TABLE files DROP COLUMN backend;
ALTER TABLE files RENAME COLUMN backend_new TO backend;
