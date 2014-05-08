-- @tag: requirement_spec_items_item_type_index
-- @description: Pflichtenhefte: Index für requirement_spec_items.item_type
-- @depends: requirement_specs
CREATE INDEX requirement_spec_items_item_type_key ON requirement_spec_items (item_type);
