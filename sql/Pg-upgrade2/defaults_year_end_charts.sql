-- @tag: defaults_year_end_charts
-- @description: Standardkonten für Jahresabschluß
-- @depends: release_3_5_4

ALTER TABLE defaults ADD COLUMN carry_over_account_chart_id     INTEGER REFERENCES chart(id);
ALTER TABLE defaults ADD COLUMN profit_carried_forward_chart_id INTEGER REFERENCES chart(id);
ALTER TABLE defaults ADD COLUMN loss_carried_forward_chart_id   INTEGER REFERENCES chart(id);
