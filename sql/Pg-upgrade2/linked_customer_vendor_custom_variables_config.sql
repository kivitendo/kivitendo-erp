-- @tag: linked_customer_vendor_custom_variables_config
-- @description: BDVs zwischen verbundenem Kunden/Lieferanten synchronisieren
-- @depends: release_4_0_0 linked_customer_vendor

ALTER TABLE public.custom_variable_configs ADD COLUMN sync_linked_cv BOOLEAN default false;
