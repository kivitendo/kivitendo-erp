-- @tag: inventory_add_used_for
-- @description: benutzt für Erzeugnis: used_for_assembly_id nachpflegen
-- @depends: release_4_0_0 inventory_add_used_for_assembly

UPDATE inventory used
SET used_for_assembly_id = assembled.parts_id
FROM inventory assembled
WHERE used.used_for_assembly_id IS NULL
  AND assembled.trans_type_id = (SELECT id FROM transfer_type WHERE description = 'assembled')
  AND assembled.used_for_assembly_id IS NULL
  AND used.trans_type_id = (SELECT id FROM transfer_type WHERE direction = 'out' AND description = 'used')
  AND used.trans_id = assembled.trans_id
