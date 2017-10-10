-- @tag: transfer_type_assembled
-- @description: Transfertyp &quot;gefertigt&quot; wird ben&ouml;tigt.
-- @depends: release_3_4_0 warehouse

INSERT INTO transfer_type (direction, description, sortkey) VALUES ('in', 'assembled', (SELECT COALESCE(MAX(sortkey), 0) + 1 FROM transfer_type));
