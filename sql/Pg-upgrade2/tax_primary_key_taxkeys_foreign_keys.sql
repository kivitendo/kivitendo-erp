-- @tag: tax_primary_key_taxkeys_foreign_keys
-- @description: Legt in tax einen neuen Prim&auml;rschl&uuml;ssel und in taxkeys einen neuen Fremdschl&uuml;ssel auf tax an.
-- @depends: tax_id_if_taxkey_is_0
UPDATE taxkeys SET tax_id = 0 WHERE taxkey_id = 0;
ALTER TABLE tax ADD PRIMARY KEY (id);
ALTER TABLE taxkeys ADD FOREIGN KEY (tax_id) REFERENCES tax (id);
