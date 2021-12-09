-- @tag: defaults_add_reclamations
-- @description: Add defaults show_delete, always_project, warn_no_reqdate and warn_duplicate_parts for reclamations
-- @depends: reclamations

--show_delete
ALTER TABLE defaults ADD COLUMN sales_reclamation_show_delete    boolean NOT NULL DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN purchase_reclamation_show_delete boolean NOT NULL DEFAULT TRUE;

--warn
ALTER TABLE defaults ADD COLUMN reclamation_warn_no_reqdate      boolean NOT NULL DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN reclamation_warn_duplicate_parts boolean NOT NULL DEFAULT TRUE;
