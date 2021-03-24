-- @tag: file_storage_dunning_documents
-- @description: Dateien f. Mahnungen von gemahnter Rechnung zum Mahnlauf verschieben
-- @depends: file_storage_dunning_invoice

-- for the original invoice, assume that the dunning_id is the one from a dunning row where the trans_id is
-- the old files object_id (the orig. invoice) and the itime of both tables are (almost) equal
WITH table_files AS
  (SELECT dunning.dunning_id, files.id FROM files LEFT JOIN dunning ON (dunning.trans_id = files.object_id)
     WHERE object_type ILIKE 'dunning_orig_invoice' AND file_type LIKE 'document' AND source LIKE 'created'
       AND ABS(EXTRACT(EPOCH FROM (dunning.itime - files.itime))) < 0.1)
  UPDATE files SET object_type = 'dunning', object_id = (SELECT dunning_id FROM table_files WHERE table_files.id = files.id)
     WHERE EXISTS (SELECT id FROM table_files WHERE table_files.id = files.id);

-- the dunning_id for the following types can be found in the filename
UPDATE files SET object_type = 'dunning', object_id = substring(file_name FROM '(\d+).pdf')::INT
  WHERE (object_type LIKE 'dunning1' OR object_type LIKE 'dunning2' OR object_type LIKE 'dunning3' OR object_type LIKE 'dunning_invoice')
    AND file_type LIKE 'document' AND source LIKE 'created';
