-- @tag: deliveryorder_transnumbers
-- @description: Nummernkreise für neue lieferscheintypen
-- @depends: release_3_5_8

ALTER TABLE defaults ADD COLUMN sudonumber TEXT;
ALTER TABLE defaults ADD COLUMN rdonumber TEXT;

UPDATE defaults SET
  sudonumber = '0',
  rdonumber = '0';

