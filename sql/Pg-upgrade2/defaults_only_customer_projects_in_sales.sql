-- @tag: defaults_only_customer_projects_in_sales
-- @description: Mandantenkonfiguration: in Verkaufsbelegen nur Projekte des ausgewählten Kunden anbieten
-- @depends: release_3_1_0
ALTER TABLE defaults ADD COLUMN customer_projects_only_in_sales BOOLEAN;
UPDATE defaults SET customer_projects_only_in_sales = FALSE;
ALTER TABLE defaults
  ALTER COLUMN customer_projects_only_in_sales SET DEFAULT FALSE,
  ALTER COLUMN customer_projects_only_in_sales SET NOT NULL;
