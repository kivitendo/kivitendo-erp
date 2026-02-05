-- @tag: chart_add_pos_er_detailed
-- @description: Spalte in Kontenrahmen für die Zuweisung bei der Schweizer Erfolgsrechnung (Detaillierte Variante)
-- @depends: release_3_9_2

ALTER TABLE chart ADD COLUMN pos_er_detailed INTEGER;
