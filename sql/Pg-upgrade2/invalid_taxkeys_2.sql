-- @tag: invalid_taxkeys_2
-- @description: Ung&uuml;ltige Steuerschl&uuml;ssel in den Kontenrahmendefinitionen und daraus resultierende falsche Eintr&auml;ge in anderen Tabellen werden korrigiert.
-- @depends: release_2_4_2
SET datestyle = 'German';

INSERT INTO taxkeys (chart_id, tax_id, taxkey_id, pos_ustva, startdate)
       SELECT id, 0, 0, 0, '01.01.1970' FROM chart WHERE taxkey_id ISNULL;

UPDATE chart SET taxkey_id = 0 WHERE taxkey_id ISNULL;
