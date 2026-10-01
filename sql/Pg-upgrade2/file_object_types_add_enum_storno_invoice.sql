-- @tag: file_object_type_storno_invoice_as_enum
-- @description: Objekttype invoice_storno hinzufügen
-- @depends: file_object_type_as_enum
-- @ignore: 0

ALTER TYPE file_object_types ADD VALUE IF NOT EXISTS 'invoice_storno';
