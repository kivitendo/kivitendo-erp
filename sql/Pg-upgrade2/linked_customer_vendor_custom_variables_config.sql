-- @tag: linked_customer_vendor_custom_variables_config
-- @description: BDVs zwischen verbundenem Kunden/Lieferanten synchronisieren
-- @depends: release_3_9_2

ALTER TABLE public.custom_variable_configs ADD COLUMN sync_linked_cv BOOLEAN default false;
