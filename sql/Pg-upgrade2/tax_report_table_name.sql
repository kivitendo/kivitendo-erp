-- @tag: tax_report_table_name
-- @description: Tabellenname den Regeln der englischen Grammatik angepasst
-- @depends: USTVA_abstraction USTVA_at
ALTER TABLE tax.report_categorys RENAME TO report_categories;
