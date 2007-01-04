-- @tag: tax_id_if_taxkey_is_0
-- @description: Aktualisierung der Spalte tax.id, wenn tax.taxkey = 0 ist.
-- @depends:
UPDATE tax SET id = 0 WHERE taxkey = 0;
UPDATE taxkeys SET tax_id = 0 WHERE taxkey_id = 0;
