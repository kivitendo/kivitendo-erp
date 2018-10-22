-- @tag: defaults_add_feature_experimental2
-- @description: experimentelle Features mit einzelnen Optionen
-- @depends: defaults_add_feature_experimental

ALTER TABLE defaults RENAME COLUMN feature_experimental TO feature_experimental_order;
ALTER TABLE defaults ADD    COLUMN feature_experimental_assortment BOOLEAN NOT NULL DEFAULT TRUE;

UPDATE defaults SET feature_experimental_assortment = feature_experimental_order;
