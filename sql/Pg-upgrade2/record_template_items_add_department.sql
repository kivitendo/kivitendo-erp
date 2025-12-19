-- @tag: record_template_items_add_department
-- @description: Abteilung in record_template_items
-- @depends: release_4_0_0

ALTER TABLE record_template_items ADD department_id INTEGER;
