-- @tag: add_customer_dunning_lock
-- @description: Einführen von Mahnsperren für Kunden.
-- @depends: release_3_7_0

ALTER TABLE customer ADD COLUMN dunning_lock BOOLEAN NOT NULL DEFAULT FALSE;
