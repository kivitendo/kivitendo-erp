-- @tag: inventory_fix_shippingdate_assemblies
-- @description: Shippingdate für assemblies und assembly_items nachträglich wie itime setzen.
-- @depends: release_3_4_0 warehouse transfer_type_assembled
update inventory set shippingdate = itime where comment ilike 'Verbraucht %' and shippingdate is null;
update inventory set shippingdate = itime where shippingdate is null and parts_id in (select id from parts where assembly);
