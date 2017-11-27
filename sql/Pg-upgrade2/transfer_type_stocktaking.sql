-- @tag: transfer_type_stocktaking
-- @description: neuer Transfertyp stocktaking für Inventur
-- @depends: warehouse

INSERT INTO transfer_type (direction, description, sortkey) VALUES ('in',  'stocktaking', (SELECT COALESCE(MAX(sortkey), 0) + 1 FROM transfer_type));
INSERT INTO transfer_type (direction, description, sortkey) VALUES ('out', 'stocktaking', (SELECT COALESCE(MAX(sortkey), 0) + 1 FROM transfer_type));
