-- @tag: inventory_shippingdate_not_null
-- @description: shippingdate not null, leeres shippingdate für nachträglich wie itime setzen
-- @depends: release_3_4_0 inventory_fix_shippingdate_assemblies

UPDATE inventory SET shippingdate = itime WHERE shippingdate IS NULL;
ALTER TABLE inventory ALTER COLUMN shippingdate SET NOT NULL;
