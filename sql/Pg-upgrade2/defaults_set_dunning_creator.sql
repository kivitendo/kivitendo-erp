-- @tag: defaults_set_dunning_creator
-- @description: Ersteller der Mahnungen konfigurierbar machen
-- @depends: release_3_5_3

CREATE TYPE dunning_creator AS ENUM ('current_employee', 'invoice_employee');
ALTER TABLE defaults ADD COLUMN dunning_creator dunning_creator default 'current_employee';

