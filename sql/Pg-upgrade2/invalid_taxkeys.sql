-- @tag: invalid_taxkesy
-- @description: Ung&uuml;ltige Steuerschl&uuml;ssel in den Kontenrahmendefinitionen und daraus resultierende falsche Eintr&auml;ge in anderen Tabellen werden korrigiert.
-- @depends: tax_primary_key_taxkeys_foreign_keys
UPDATE chart SET taxkey_id = 0 WHERE taxkey_id NOT IN (SELECT DISTINCT taxkey_id FROM taxkeys);
UPDATE taxkeys SET taxkey_id = 0, tax_id = 0 WHERE taxkey_id NOT IN (SELECT DISTINCT taxkey_id FROM taxkeys);
