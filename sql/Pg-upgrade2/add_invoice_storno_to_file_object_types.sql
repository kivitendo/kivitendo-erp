-- @tag: add_invoice_storno_to_file_object_types
-- @description: Typ invoice_storno (Verkaufsrechnungsstorno ausdrucken) zu Enum file_object_types hinzufügen
-- @depends: file_object_type_as_enum

ALTER TYPE file_object_types ADD VALUE 'invoice_storno';
