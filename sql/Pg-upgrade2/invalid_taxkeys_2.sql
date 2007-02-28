-- @tag: invalid_taxkeys_2
-- @description: Ung&uuml;ltige Steuerschl&uuml;ssel in den Kontenrahmendefinitionen und daraus resultierende falsche Eintr&auml;ge in anderen Tabellen werden korrigiert.
-- @depends: release_2_4_2
UPDATE chart SET taxkey_id = 0 WHERE taxkey_id ISNULL;
