-- @tag: chart_pos_er
-- @description: pos_er Feld in Konten für die Position in der Erfolgsrechnung
-- @depends: release_3_3_0
-- @may_fail: 1

ALTER TABLE chart ADD COLUMN pos_er INTEGER;
UPDATE chart SET pos_er = pos_eur;
