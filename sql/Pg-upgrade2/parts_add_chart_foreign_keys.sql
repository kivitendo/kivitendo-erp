-- @tag: parts_add_chart_foreign_keys
-- @description: Warenkonten mit chart-Tabelle per Fremdschlüssel verknüpft.
-- @depends: release_3_4_1
-- @ignore: 0

ALTER TABLE parts ADD FOREIGN KEY (income_accno_id)    REFERENCES chart(id);
ALTER TABLE parts ADD FOREIGN KEY (inventory_accno_id) REFERENCES chart(id);
ALTER TABLE parts ADD FOREIGN KEY (expense_accno_id)   REFERENCES chart(id);
