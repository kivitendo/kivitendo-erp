-- @tag: partsgroup_adjacency
-- @description: Warengruppe um parent_id erweitern
-- @depends: release_3_5_5 partsgroup_description

-- There is no specific code for upgrading from older versions, all existing
-- partsgroups start with parent_id NULL, which makes them top level
-- partsgroups

ALTER TABLE partsgroup ADD COLUMN parent_id INT REFERENCES partsgroup(id);

ALTER TABLE partsgroup ADD CONSTRAINT partsgroup_zero_cycle_check CHECK (id <> parent_id);

-- need to check during upgrade if they are unique, otherwise allow user to edit them (like upgrade for parts)
ALTER TABLE partsgroup ADD CONSTRAINT partsgroup_unique UNIQUE (partsgroup, parent_id);

-- this doesn't work for parent_id is null, allows all top level partsgroups to have the same sortkey
-- also doesn't seem to work for certain add_to_list / remove_from_list method
-- ALTER TABLE partsgroup ADD CONSTRAINT partsgroup_sortkey_unique UNIQUE (sortkey, parent_id);
