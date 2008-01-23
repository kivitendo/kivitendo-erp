-- @tag: transfer_type_shipped
-- @description: Transfertyp &quot;verschickt&quot; wird ben&ouml;tigt.
-- @depends: warehouse
INSERT INTO transfer_type (direction, description, sortkey) VALUES ('out', 'shipped', (SELECT COALESCE(MAX(sortkey), 0) + 1 FROM transfer_type));
