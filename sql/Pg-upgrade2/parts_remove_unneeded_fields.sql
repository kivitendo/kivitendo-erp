-- @tag: part_remove_unneeded_fields
-- @description: Removing colums assembly, inventory_accno_id, expense_accno_id, income_accno_id
-- @depends: part_type_enum

ALTER TABLE parts DROP COLUMN assembly;
ALTER TABLE parts DROP COLUMN inventory_accno_id;
ALTER TABLE parts DROP COLUMN expense_accno_id;
ALTER TABLE parts DROP COLUMN income_accno_id;
-- keep for now:
-- ALTER TABLE parts DROP COLUMN makemodel;
