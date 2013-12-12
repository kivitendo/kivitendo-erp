-- @tag: filemanagement_feature
-- @description: "Zusätzliche Config flags für Filemanagement"
-- @depends: release_3_4_1
ALTER TABLE defaults ADD COLUMN doc_delete_printfiles       boolean DEFAULT false;
ALTER TABLE defaults ADD COLUMN doc_max_filesize            integer DEFAULT 1000000;
ALTER TABLE defaults ADD COLUMN doc_storage                 boolean DEFAULT false;
ALTER TABLE defaults ADD COLUMN doc_storage_for_documents   text default 'Filesystem';
ALTER TABLE defaults ADD COLUMN doc_storage_for_attachments text default 'Filesystem';
ALTER TABLE defaults ADD COLUMN doc_storage_for_images      text default 'Filesystem';
ALTER TABLE defaults ADD COLUMN doc_files                   boolean DEFAULT false;
ALTER TABLE defaults ADD COLUMN doc_files_rootpath          text default '';
ALTER TABLE defaults ADD COLUMN doc_webdav                  boolean DEFAULT false;
ALTER TABLE defaults ADD COLUMN doc_database                boolean DEFAULT false;
